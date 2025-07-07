import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../models/memo.dart';

class PrintHelper {
  static Future<void> printMemoReport(List<Memo> memos, {String? mapImagePath}) async {
    final pdf = pw.Document();

    // デフォルトフォントを使用（日本語サポートなし）
    final font = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    // 地図付きページを追加
    if (mapImagePath != null && File(mapImagePath).existsSync()) {
      final mapImageBytes = await File(mapImagePath).readAsBytes();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'フィールドワーク記録地図',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 18,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Expanded(
                  child: pw.Container(
                    width: double.infinity,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    child: pw.Image(
                      pw.MemoryImage(mapImageBytes),
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  '記録数: ${memos.length}件',
                  style: pw.TextStyle(font: font, fontSize: 12),
                ),
                pw.Text(
                  '印刷日時: ${DateTime.now().toString().substring(0, 19)}',
                  style: pw.TextStyle(font: font, fontSize: 12),
                ),
              ],
            );
          },
        ),
      );
    }

    // メモ一覧ページを追加
    if (memos.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              pw.Text(
                '記録一覧',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 18,
                ),
              ),
              pw.SizedBox(height: 20),
              ...memos.map((memo) => _buildMemoItem(memo, font, boldFont)),
            ];
          },
        ),
      );
    }

    // PDFを表示・印刷
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static pw.Widget _buildMemoItem(Memo memo, pw.Font font, pw.Font boldFont) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 15),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            memo.title,
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 14,
            ),
          ),
          pw.SizedBox(height: 5),
          
          // 基本情報
          pw.Row(
            children: [
              if (memo.category != null) ...[
                pw.Text(
                  'カテゴリ: ${memo.category}',
                  style: pw.TextStyle(font: font, fontSize: 10),
                ),
                pw.SizedBox(width: 20),
              ],
              if (memo.discoveryTime != null) ...[
                pw.Text(
                  '発見日時: ${_formatDateTime(memo.discoveryTime!)}',
                  style: pw.TextStyle(font: font, fontSize: 10),
                ),
              ],
            ],
          ),
          
          if (memo.discoverer != null || memo.specimenNumber != null) ...[
            pw.SizedBox(height: 3),
            pw.Row(
              children: [
                if (memo.discoverer != null) ...[
                  pw.Text(
                    '発見者: ${memo.discoverer}',
                    style: pw.TextStyle(font: font, fontSize: 10),
                  ),
                  pw.SizedBox(width: 20),
                ],
                if (memo.specimenNumber != null) ...[
                  pw.Text(
                    '標本番号: ${memo.specimenNumber}',
                    style: pw.TextStyle(font: font, fontSize: 10),
                  ),
                ],
              ],
            ),
          ],
          
          if (memo.content.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              '説明: ${memo.content}',
              style: pw.TextStyle(font: font, fontSize: 11),
            ),
          ],
          
          if (memo.notes != null && memo.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 5),
            pw.Text(
              '備考: ${memo.notes}',
              style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600),
            ),
          ],
          
          if (memo.latitude != null && memo.longitude != null) ...[
            pw.SizedBox(height: 5),
            pw.Text(
              '位置: (${memo.latitude!.toStringAsFixed(6)}, ${memo.longitude!.toStringAsFixed(6)})',
              style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  static Future<void> printMemoList(List<Memo> memos) async {
    await printMemoReport(memos);
  }

  static Future<void> printMapWithMemos(List<Memo> memos, String? mapImagePath) async {
    await printMemoReport(memos, mapImagePath: mapImagePath);
  }

  static Future<void> savePdfReport(List<Memo> memos, {String? mapImagePath}) async {
    try {
      final pdf = pw.Document();
      final font = pw.Font.helvetica();
      final boldFont = pw.Font.helveticaBold();

      // 地図付きページを追加
      if (mapImagePath != null && File(mapImagePath).existsSync()) {
        final mapImageBytes = await File(mapImagePath).readAsBytes();
        
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'フィールドワーク記録地図',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 18,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Expanded(
                    child: pw.Container(
                      width: double.infinity,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                      ),
                      child: pw.Image(
                        pw.MemoryImage(mapImageBytes),
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    '記録数: ${memos.length}件',
                    style: pw.TextStyle(font: font, fontSize: 12),
                  ),
                  pw.Text(
                    '印刷日時: ${DateTime.now().toString().substring(0, 19)}',
                    style: pw.TextStyle(font: font, fontSize: 12),
                  ),
                ],
              );
            },
          ),
        );
      }

      // メモ一覧ページを追加
      if (memos.isNotEmpty) {
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            build: (pw.Context context) {
              return [
                pw.Text(
                  '記録一覧',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 18,
                  ),
                ),
                pw.SizedBox(height: 20),
                ...memos.map((memo) => _buildMemoItem(memo, font, boldFont)),
              ];
            },
          ),
        );
      }

      // ファイルを保存
      final output = await getApplicationDocumentsDirectory();
      final file = File('${output.path}/fieldwork_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());
      
      // 成功メッセージを返す（呼び出し元で表示）
      return;
    } catch (e) {
      throw Exception('PDFの保存に失敗しました: $e');
    }
  }
} 