import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert'; // Base64デコード用
// Web環境での機能は動的に処理
import 'web_print_helper_stub.dart'
    if (dart.library.html) 'web_print_helper.dart';

import '../models/memo.dart';

class PrintHelper {
  // Web版対応: 画像パスが有効かどうかをチェック
  static bool _isValidImagePath(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return false;

    if (kIsWeb) {
      // Web版: Base64データURL形式またはBase64文字列かをチェック
      return imagePath.startsWith('data:image') ||
          (imagePath.length > 100 && _isBase64(imagePath));
    } else {
      // モバイル版: ファイルの存在をチェック
      return File(imagePath).existsSync();
    }
  }

  // Base64文字列かどうかをチェック
  static bool _isBase64(String str) {
    try {
      return base64.decode(str).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Web版対応: 画像データを読み込み
  static Future<Uint8List> _loadImageBytes(String? imagePath) async {
    if (imagePath == null) throw Exception('画像パスがありません');

    if (kIsWeb) {
      // Web版: Base64データから読み込み
      if (imagePath.startsWith('data:image')) {
        final base64Data = imagePath.split(',')[1];
        return base64.decode(base64Data);
      } else {
        return base64.decode(imagePath);
      }
    } else {
      // モバイル版: ファイルから読み込み
      return File(imagePath).readAsBytes();
    }
  }

  // モバイル・デスクトップ用かどうかを判定
  static bool _isMobileWeb() {
    if (!kIsWeb) return false;

    try {
      return WebPrintHelper.isMobileWeb();
    } catch (e) {
      return false;
    }
  }

  // 日本語フォントを取得するヘルパーメソッド
  static Future<pw.Font> _getJapaneseFont() async {
    try {
      // assetsからNotoSansJPフォントを読み込み
      final fontData =
          await rootBundle.load('assets/fonts/NotoSansJP-Regular.ttf');
      return pw.Font.ttf(fontData);
    } catch (e) {
      print('日本語フォント取得エラー: $e');
      // フォールバック: オンラインのNotoSansを試行
      try {
        return await PdfGoogleFonts.notoSansRegular();
      } catch (e2) {
        print('オンラインフォント取得エラー: $e2');
        // 最終フォールバック: デフォルトフォント
        return pw.Font.helvetica();
      }
    }
  }

  static Future<pw.Font> _getJapaneseBoldFont() async {
    try {
      // assetsからNotoSansJPボールドフォントを読み込み
      final fontData =
          await rootBundle.load('assets/fonts/NotoSansJP-Bold.ttf');
      return pw.Font.ttf(fontData);
    } catch (e) {
      print('日本語ボールドフォント取得エラー: $e');
      // フォールバック: オンラインのNotoSansを試行
      try {
        return await PdfGoogleFonts.notoSansBold();
      } catch (e2) {
        print('オンラインボールドフォント取得エラー: $e2');
        // 最終フォールバック: デフォルトフォント
        return pw.Font.helveticaBold();
      }
    }
  }

  // テキストスタイルを作成するヘルパーメソッド
  static pw.TextStyle _createTextStyle(pw.Font font, double fontSize,
      {PdfColor? color}) {
    return pw.TextStyle(
      font: font,
      fontSize: fontSize,
      color: color,
      // 日本語をサポートするフォントのみをフォールバックに使用
      // 必要に応じて他の日本語フォントを追加可能
    );
  }

  // Web版でのPDFダウンロード処理
  static void _downloadPdfInWeb(Uint8List pdfBytes, String filename) {
    if (!kIsWeb) return;

    try {
      WebPrintHelper.downloadPdfInWeb(pdfBytes, filename);
    } catch (e) {
      print('Web PDFダウンロードエラー: $e');
    }
  }

  // 印刷またはダウンロード処理（Web版の制限に対応）
  static Future<void> _printOrDownloadPdf(
      pw.Document pdf, String defaultFilename,
      {bool showSuccessMessage = true}) async {
    try {
      if (kIsWeb && _isMobileWeb()) {
        // モバイルWebブラウザ（iPhone Safari等）の場合は直接ダウンロード
        final pdfBytes = await pdf.save();
        _downloadPdfInWeb(pdfBytes, defaultFilename);

        if (showSuccessMessage) {
          print('PDFをダウンロードしました: $defaultFilename');
        }
      } else {
        // デスクトップブラウザまたはネイティブアプリの場合は印刷ダイアログを表示
        try {
          await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => pdf.save(),
          );
        } catch (printError) {
          // 印刷に失敗した場合はダウンロードにフォールバック
          print('印刷に失敗しました。ダウンロードします: $printError');
          final pdfBytes = await pdf.save();

          if (kIsWeb) {
            _downloadPdfInWeb(pdfBytes, defaultFilename);
          } else {
            // ネイティブアプリの場合はファイルシステムに保存
            final output = await getApplicationDocumentsDirectory();
            final file = File('${output.path}/$defaultFilename');
            await file.writeAsBytes(pdfBytes);
          }

          if (showSuccessMessage) {
            print('PDFをダウンロードしました: $defaultFilename');
          }
        }
      }
    } catch (e) {
      throw Exception('PDF処理に失敗しました: $e');
    }
  }

  // 地図画像とピンを合成するヘルパー関数
  static Future<Uint8List> _createMapWithPins(
    String? mapImagePath,
    List<Memo> memos,
    double mapWidth,
    double mapHeight,
  ) async {
    // 地図画像を読み込み
    final mapImageBytes = await _loadImageBytes(mapImagePath);
    final mapImage = await decodeImageFromList(mapImageBytes);

    // キャンバスを作成
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 地図画像を描画
    final paint = Paint();
    canvas.drawImage(mapImage, Offset.zero, paint);

    // 実際の画像サイズを使用
    final actualImageWidth = mapImage.width.toDouble();
    final actualImageHeight = mapImage.height.toDouble();

    // BoxFit.containの計算を行う（地図ウィジェットと同じ計算）
    final containerAspect = mapWidth / mapHeight;
    final imageAspect = actualImageWidth / actualImageHeight;

    double actualDisplayWidth, actualDisplayHeight, offsetX, offsetY;

    if (imageAspect > containerAspect) {
      // 画像の方が横長 - 幅に合わせる
      actualDisplayWidth = mapWidth;
      actualDisplayHeight = mapWidth / imageAspect;
      offsetX = 0.0;
      offsetY = (mapHeight - actualDisplayHeight) / 2;
    } else {
      // 画像の方が縦長または同じ - 高さに合わせる
      actualDisplayWidth = mapHeight * imageAspect;
      actualDisplayHeight = mapHeight;
      offsetX = (mapWidth - actualDisplayWidth) / 2;
      offsetY = 0.0;
    }

    // 表示座標から実際の画像座標への変換スケール
    final scaleX = actualImageWidth / actualDisplayWidth;
    final scaleY = actualImageHeight / actualDisplayHeight;

    // ピンを描画
    for (final memo in memos) {
      if (memo.latitude != null && memo.longitude != null) {
        // 地図ウィジェットと同じ計算方法でピン位置を計算
        final displayPinX = memo.latitude! * actualDisplayWidth + offsetX;
        final displayPinY = memo.longitude! * actualDisplayHeight + offsetY;

        // 表示座標を実際の画像座標に変換
        final imagePinX = displayPinX * scaleX;
        final imagePinY = displayPinY * scaleY;

        // ピンの色を決定
        final pinColor = _getCategoryColor(memo.category);

        // ピンのサイズを実際の画像サイズに合わせて調整
        final pinRadius = 15 * ((scaleX + scaleY) / 2);
        final strokeWidth = 2 * ((scaleX + scaleY) / 2);

        // ピンの円を描画
        final pinPaint = Paint()
          ..color = pinColor
          ..style = PaintingStyle.fill;

        canvas.drawCircle(
          Offset(imagePinX, imagePinY),
          pinRadius,
          pinPaint,
        );

        // ピンの境界線を描画
        final borderPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth;

        canvas.drawCircle(
          Offset(imagePinX, imagePinY),
          pinRadius,
          borderPaint,
        );

        // ピン番号を描画
        if (memo.pinNumber != null) {
          final fontSize = 12 * ((scaleX + scaleY) / 2);
          final textPainter = TextPainter(
            text: TextSpan(
              text: '${memo.pinNumber}',
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          textPainter.paint(
            canvas,
            Offset(
              imagePinX - textPainter.width / 2,
              imagePinY - textPainter.height / 2,
            ),
          );
        }
      }
    }

    // 画像を生成
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      mapImage.width,
      mapImage.height,
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // カテゴリに応じた色を取得
  static Color _getCategoryColor(String? category) {
    switch (category) {
      case '植物':
        return Colors.green;
      case '動物':
        return Colors.brown;
      case '昆虫':
        return Colors.orange;
      case '鉱物':
        return Colors.grey;
      case '化石':
        return Colors.purple;
      case '地形':
        return Colors.blue;
      default:
        return Colors.blue;
    }
  }

  // ピン付き地図を印刷する新しいメソッド
  static Future<void> printMapWithPins(
      String? mapImagePath, List<Memo> memos, double mapWidth, double mapHeight,
      {String? mapName}) async {
    if (!_isValidImagePath(mapImagePath)) {
      throw Exception('地図画像が見つかりません');
    }

    // 地図画像とピンを合成
    final combinedImageBytes = await _createMapWithPins(
      mapImagePath,
      memos,
      mapWidth,
      mapHeight,
    );

    // 日本語フォントを取得
    final font = await _getJapaneseFont();
    final boldFont = await _getJapaneseBoldFont();

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                mapName != null && mapName.isNotEmpty
                    ? mapName
                    : 'フィールドワーク地図（ピン付き）',
                style: _createTextStyle(boldFont, 18),
              ),
              pw.SizedBox(height: 20),
              pw.Expanded(
                child: pw.Container(
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                  ),
                  child: pw.Image(
                    pw.MemoryImage(combinedImageBytes),
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'ピン数: ${memos.where((m) => m.latitude != null && m.longitude != null).length}個',
                style: _createTextStyle(font, 12),
              ),
              pw.Text(
                '印刷日時: ${DateTime.now().toString().substring(0, 19)}',
                style: _createTextStyle(font, 12),
              ),
            ],
          );
        },
      ),
    );

    // 印刷またはダウンロード
    await _printOrDownloadPdf(
        pdf, 'fieldwork_map_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  static Future<void> printMapImage(String? mapImagePath,
      {String? mapName}) async {
    if (!_isValidImagePath(mapImagePath)) {
      throw Exception('地図画像が見つかりません');
    }

    // 日本語フォントを取得
    final font = await _getJapaneseFont();
    final boldFont = await _getJapaneseBoldFont();

    final pdf = pw.Document();
    final mapImageBytes = await _loadImageBytes(mapImagePath);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                mapName != null && mapName.isNotEmpty ? mapName : 'フィールドワーク地図',
                style: _createTextStyle(boldFont, 18),
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
                '印刷日時: ${DateTime.now().toString().substring(0, 19)}',
                style: _createTextStyle(font, 12),
              ),
            ],
          );
        },
      ),
    );

    // 印刷またはダウンロード
    await _printOrDownloadPdf(pdf,
        'fieldwork_map_image_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  static Future<void> printMemoReport(List<Memo> memos,
      {String? mapImagePath, String? mapName}) async {
    final pdf = pw.Document();

    // 日本語フォントを取得
    final font = await _getJapaneseFont();
    final boldFont = await _getJapaneseBoldFont();

    // 地図付きページを追加
    if (_isValidImagePath(mapImagePath)) {
      final mapImageBytes = await _loadImageBytes(mapImagePath);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  mapName != null && mapName.isNotEmpty
                      ? mapName
                      : 'フィールドワーク記録地図',
                  style: _createTextStyle(boldFont, 18),
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
                  style: _createTextStyle(font, 12),
                ),
                pw.Text(
                  '印刷日時: ${DateTime.now().toString().substring(0, 19)}',
                  style: _createTextStyle(font, 12),
                ),
              ],
            );
          },
        ),
      );
    }

    // メモ一覧ページを追加
    if (memos.isNotEmpty) {
      // 非同期でメモアイテムを構築
      final memoWidgets = await Future.wait(
        memos.map((memo) => _buildMemoItem(memo, font, boldFont)).toList(),
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              pw.Text(
                '記録一覧',
                style: _createTextStyle(boldFont, 18),
              ),
              pw.SizedBox(height: 20),
              ...memoWidgets,
            ];
          },
        ),
      );
    }

    // 印刷またはダウンロード
    await _printOrDownloadPdf(
        pdf, 'fieldwork_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  static Future<pw.Widget> _buildMemoItem(
      Memo memo, pw.Font font, pw.Font boldFont) async {
    List<pw.Widget> children = [
      pw.Text(
        memo.title,
        style: _createTextStyle(boldFont, 14),
      ),
      pw.SizedBox(height: 5),

      // 基本情報
      pw.Row(
        children: [
          if (memo.category != null) ...[
            pw.Text(
              'カテゴリ: ${memo.category}',
              style: _createTextStyle(font, 10),
            ),
            pw.SizedBox(width: 20),
          ],
          if (memo.discoveryTime != null) ...[
            pw.Text(
              '発見日時: ${_formatDateTime(memo.discoveryTime!)}',
              style: _createTextStyle(font, 10),
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
                style: _createTextStyle(font, 10),
              ),
              pw.SizedBox(width: 20),
            ],
            if (memo.specimenNumber != null) ...[
              pw.Text(
                '標本番号: ${memo.specimenNumber}',
                style: _createTextStyle(font, 10),
              ),
            ],
          ],
        ),
      ],

      if (memo.content.isNotEmpty) ...[
        pw.SizedBox(height: 8),
        pw.Text(
          '説明: ${memo.content}',
          style: _createTextStyle(font, 11),
        ),
      ],

      if (memo.notes != null && memo.notes!.isNotEmpty) ...[
        pw.SizedBox(height: 5),
        pw.Text(
          '備考: ${memo.notes}',
          style: _createTextStyle(font, 10, color: PdfColors.grey600),
        ),
      ],

      if (memo.latitude != null && memo.longitude != null) ...[
        pw.SizedBox(height: 5),
        pw.Text(
          '位置: (${memo.latitude!.toStringAsFixed(6)}, ${memo.longitude!.toStringAsFixed(6)})',
          style: _createTextStyle(font, 9, color: PdfColors.grey600),
        ),
      ],
    ];

    // 添付画像がある場合は画像セクションを追加
    if (memo.imagePaths != null && memo.imagePaths!.isNotEmpty) {
      children.addAll([
        pw.SizedBox(height: 8),
        pw.Text(
          '添付画像 (${memo.imagePaths!.length}枚):',
          style: _createTextStyle(font, 10, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 5),
      ]);

      // 画像を2列で配置
      for (int i = 0; i < memo.imagePaths!.length; i += 2) {
        List<pw.Widget> rowChildren = [];
        double rowHeight = 80.0; // デフォルトの最小高さ

        // 1枚目の画像のサイズを計算
        double height1 = 80.0;
        Uint8List? imageBytes1;
        try {
          imageBytes1 = await _loadImageBytes(memo.imagePaths![i]);
          final image1 = await decodeImageFromList(imageBytes1);
          final aspectRatio1 = image1.width / image1.height;
          // 列幅を約200pxと仮定してアスペクト比から高さを計算
          final calculatedHeight1 = 200.0 / aspectRatio1;
          height1 = calculatedHeight1.clamp(80.0, 150.0); // 最小80px、最大150px
        } catch (e) {
          height1 = 80.0; // エラー時はデフォルト高さ
        }

        // 2枚目の画像のサイズを計算（存在する場合）
        double height2 = 80.0;
        Uint8List? imageBytes2;
        if (i + 1 < memo.imagePaths!.length) {
          try {
            imageBytes2 = await _loadImageBytes(memo.imagePaths![i + 1]);
            final image2 = await decodeImageFromList(imageBytes2);
            final aspectRatio2 = image2.width / image2.height;
            final calculatedHeight2 = 200.0 / aspectRatio2;
            height2 = calculatedHeight2.clamp(80.0, 150.0);
          } catch (e) {
            height2 = 80.0;
          }
        }

        // 同一行の高さを揃える（高い方に合わせる）
        rowHeight = height1 > height2 ? height1 : height2;

        // 最初の画像
        if (imageBytes1 != null) {
          rowChildren.add(
            pw.Expanded(
              child: pw.Container(
                height: rowHeight,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.ClipRRect(
                  horizontalRadius: 4,
                  verticalRadius: 4,
                  child: pw.Image(
                    pw.MemoryImage(imageBytes1),
                    fit: pw.BoxFit.contain, // coverからcontainに変更して画像全体を表示
                  ),
                ),
              ),
            ),
          );
        } else {
          // 画像読み込みエラーの場合はプレースホルダーを表示
          rowChildren.add(
            pw.Expanded(
              child: pw.Container(
                height: rowHeight,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(4),
                  color: PdfColors.grey100,
                ),
                child: pw.Center(
                  child: pw.Text(
                    '画像読み込み\nエラー',
                    textAlign: pw.TextAlign.center,
                    style: _createTextStyle(font, 8, color: PdfColors.grey600),
                  ),
                ),
              ),
            ),
          );
        }

        // 2枚目の画像（存在する場合）
        if (i + 1 < memo.imagePaths!.length) {
          rowChildren.add(pw.SizedBox(width: 10));
          if (imageBytes2 != null) {
            rowChildren.add(
              pw.Expanded(
                child: pw.Container(
                  height: rowHeight,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.ClipRRect(
                    horizontalRadius: 4,
                    verticalRadius: 4,
                    child: pw.Image(
                      pw.MemoryImage(imageBytes2),
                      fit: pw.BoxFit.contain, // coverからcontainに変更
                    ),
                  ),
                ),
              ),
            );
          } else {
            rowChildren.add(
              pw.Expanded(
                child: pw.Container(
                  height: rowHeight,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                    color: PdfColors.grey100,
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      '画像読み込み\nエラー',
                      textAlign: pw.TextAlign.center,
                      style:
                          _createTextStyle(font, 8, color: PdfColors.grey600),
                    ),
                  ),
                ),
              ),
            );
          }
        } else {
          // 奇数枚の場合は空のスペースを追加
          rowChildren.add(pw.SizedBox(width: 10));
          rowChildren.add(pw.Expanded(child: pw.Container()));
        }

        children.add(
          pw.Row(
            children: rowChildren,
          ),
        );

        if (i + 2 < memo.imagePaths!.length) {
          children.add(pw.SizedBox(height: 5));
        }
      }
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 15),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  static String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  static Future<void> printMemoList(List<Memo> memos) async {
    await printMemoReport(memos);
  }

  static Future<void> printMapWithMemos(List<Memo> memos, String? mapImagePath,
      {String? mapName}) async {
    // 地図画像のみを印刷
    await printMapImage(mapImagePath, mapName: mapName);
  }

  static Future<void> savePdfReport(List<Memo> memos,
      {String? mapImagePath, String? mapName}) async {
    try {
      final pdf = pw.Document();
      // 日本語フォントを取得
      final font = await _getJapaneseFont();
      final boldFont = await _getJapaneseBoldFont();

      // 地図付きページを追加
      if (_isValidImagePath(mapImagePath)) {
        final mapImageBytes = await _loadImageBytes(mapImagePath);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    mapName != null && mapName.isNotEmpty
                        ? mapName
                        : 'フィールドワーク記録地図',
                    style: _createTextStyle(boldFont, 18),
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
                    style: _createTextStyle(font, 12),
                  ),
                  pw.Text(
                    '印刷日時: ${DateTime.now().toString().substring(0, 19)}',
                    style: _createTextStyle(font, 12),
                  ),
                ],
              );
            },
          ),
        );
      }

      // メモ一覧ページを追加
      if (memos.isNotEmpty) {
        // 非同期でメモアイテムを構築
        final memoWidgets = await Future.wait(
          memos.map((memo) => _buildMemoItem(memo, font, boldFont)).toList(),
        );

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            build: (pw.Context context) {
              return [
                pw.Text(
                  '記録一覧',
                  style: _createTextStyle(boldFont, 18),
                ),
                pw.SizedBox(height: 20),
                ...memoWidgets,
              ];
            },
          ),
        );
      }

      // ファイルを保存またはダウンロード
      if (kIsWeb) {
        // Web版: 直接ダウンロード
        final pdfBytes = await pdf.save();
        _downloadPdfInWeb(pdfBytes,
            'fieldwork_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      } else {
        // モバイル版: ファイルシステムに保存
        final output = await getApplicationDocumentsDirectory();
        final file = File(
            '${output.path}/fieldwork_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
        await file.writeAsBytes(await pdf.save());
      }

      // 成功メッセージを返す（呼び出し元で表示）
      return;
    } catch (e) {
      throw Exception('PDFの保存に失敗しました: $e');
    }
  }
}
