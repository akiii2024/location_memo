import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/memo.dart';
import 'api_config.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class AIService {
  static const String _apiKey = ApiConfig.geminiApiKey; // APIキーをここに設定

  /// デバッグ情報を表示
  static void printDebugInfo() {
    print('=== AI Service Debug Info ===');
    print('AI Service Debug: 実行環境: ${kIsWeb ? 'Web' : 'Native'}');
    print('AI Service Debug: APIキー設定状況: ${isConfigured}');
    print('AI Service Debug: APIキー長: ${_apiKey.length}');
    if (_apiKey.isNotEmpty) {
      print(
          'AI Service Debug: APIキー先頭10文字: ${_apiKey.substring(0, _apiKey.length > 10 ? 10 : _apiKey.length)}');
      print(
          'AI Service Debug: APIキー形式チェック: ${_apiKey.startsWith('AIza') ? '正常' : '異常'}');
    } else {
      print('AI Service Debug: APIキーが設定されていません');
    }
    print('AI Service Debug: 現在のURL: ${Uri.base}');
    print('AI Service Debug: HTTPS接続: ${Uri.base.scheme == 'https'}');
    print('============================');
  }

  /// APIキーの設定状況を詳細確認
  static Map<String, dynamic> checkApiKeyStatus() {
    final status = <String, dynamic>{};

    status['isEmpty'] = _apiKey.isEmpty;
    status['length'] = _apiKey.length;
    status['hasValidPrefix'] = _apiKey.startsWith('AIza');
    status['hasValidLength'] = _apiKey.length == 39;
    status['isDefaultValue'] =
        _apiKey == 'default_value' || _apiKey == 'YOUR_API_KEY';
    status['isConfigured'] = isConfigured;

    if (_apiKey.isNotEmpty) {
      status['preview'] =
          _apiKey.substring(0, _apiKey.length > 10 ? 10 : _apiKey.length);
    }

    return status;
  }

  /// APIキーが設定されているかどうか
  static bool get isConfigured {
    // Web環境ではAPIキーが設定されていない場合が多いため、
    // より詳細なチェックを行う
    if (_apiKey.isEmpty) {
      print('AI Service Debug: APIキーが空です');
      return false;
    }

    // Web環境での追加チェック
    if (kIsWeb) {
      print('AI Service Debug: Web環境で実行中');
      print('AI Service Debug: APIキー長: ${_apiKey.length}');
      print(
          'AI Service Debug: APIキー先頭10文字: ${_apiKey.substring(0, _apiKey.length > 10 ? 10 : _apiKey.length)}');

      // Web環境ではAPIキーが環境変数で設定されていない場合がある
      final isConfigured = _apiKey.isNotEmpty &&
          _apiKey != 'default_value' &&
          _apiKey != 'YOUR_API_KEY' &&
          _apiKey.length > 20;
      print('AI Service Debug: Web環境での設定状態: $isConfigured');

      if (!isConfigured) {
        print('AI Service Debug: Web環境でAPIキーが適切に設定されていません');
        print('AI Service Debug: APIキーの形式を確認してください（AIzaで始まる39文字）');
      }

      return isConfigured;
    }

    print('AI Service Debug: ネイティブ環境で実行中');
    print('AI Service Debug: APIキー長: ${_apiKey.length}');
    return true;
  }

  /// Gemini APIクライアントを取得（Web環境では使用しない）
  static GenerativeModel? get _model {
    // Web環境では常にHTTP直接リクエストを使用するため、SDKモデルは使用しない
    if (kIsWeb) {
      print('AI Service Debug: Web環境ではSDKモデルを使用しません');
      return null;
    }

    if (!isConfigured) {
      print('AI Service Debug: モデル初期化失敗 - 設定されていません');
      return null;
    }

    try {
      print('AI Service Debug: Geminiモデルを初期化中...');
      final model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: _apiKey,
      );
      print('AI Service Debug: モデル初期化成功');
      return model;
    } catch (e) {
      print('AI Service Debug: モデル初期化エラー: $e');
      return null;
    }
  }

  /// Web環境でのHTTP直接リクエスト（フォールバック）
  static Future<String?> _makeDirectApiRequest(String prompt) async {
    if (!kIsWeb) return null;

    try {
      print('AI Service Debug: Web環境でHTTP直接リクエスト開始');
      print('AI Service Debug: 現在のドメイン: ${Uri.base.toString()}');
      print('AI Service Debug: HTTPS接続: ${Uri.base.scheme == 'https'}');

      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_apiKey');

      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'topP': 0.95,
          'maxOutputTokens': 2048,
        }
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'location_memo/1.0',
        },
        body: json.encode(requestBody),
      );

      print('AI Service Debug: HTTP直接リクエスト レスポンス状態: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final text =
            responseData['candidates']?[0]?['content']?['parts']?[0]?['text'];
        print(
            'AI Service Debug: HTTP直接リクエスト 成功: ${text?.substring(0, text.length > 100 ? 100 : text.length)}...');
        return text;
      } else {
        print('AI Service Debug: HTTP直接リクエスト 失敗: ${response.statusCode}');
        print('AI Service Debug: エラーレスポンス: ${response.body}');

        // 詳細なエラー情報を表示
        if (response.statusCode == 400) {
          print('AI Service Debug: 400エラー - APIキーまたはリクエスト形式に問題があります');
        } else if (response.statusCode == 401) {
          print('AI Service Debug: 401エラー - APIキーが無効です');
        } else if (response.statusCode == 403) {
          print('AI Service Debug: 403エラー - APIキーの権限が不足しています');
        } else if (response.statusCode == 429) {
          print('AI Service Debug: 429エラー - API使用制限に達しています');
        } else if (response.statusCode == 500) {
          print('AI Service Debug: 500エラー - サーバー内部エラーです');
        }

        return null;
      }
    } catch (e) {
      print('AI Service Debug: HTTP直接リクエスト エラー詳細:');
      print('AI Service Debug: エラータイプ: ${e.runtimeType}');
      print('AI Service Debug: エラーメッセージ: $e');

      // Web環境での特定エラーの詳細情報
      if (kIsWeb) {
        print('AI Service Debug: Web環境でのエラー詳細:');
        if (e.toString().contains('minified:')) {
          print('AI Service Debug: minifiedエラー検出 - JavaScript SDKの問題');
          print('AI Service Debug: HTTP直接リクエストで回避済み');
        } else if (e.toString().contains('CORS')) {
          print('AI Service Debug: CORS エラー - ブラウザの制限');
        } else if (e.toString().contains('Connection')) {
          print('AI Service Debug: ネットワーク接続エラー');
        }
      }

      return null;
    }
  }

  /// Web環境での画像分析用HTTP直接リクエスト
  static Future<String?> _makeImageAnalysisRequest(Uint8List imageBytes) async {
    if (!kIsWeb) return null;

    try {
      print('AI Service Debug: Web環境で画像分析HTTP直接リクエスト開始');
      print('AI Service Debug: 画像データサイズ: ${imageBytes.length} bytes');

      // 画像をBase64エンコード
      final base64Image = base64Encode(imageBytes);
      print('AI Service Debug: Base64エンコード完了');

      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_apiKey');

      final requestBody = {
        'contents': [
          {
            'parts': [
              {
                'text': '''
この画像を分析して、フィールドワーク・自然観察記録として以下の項目を提案してください。

【分析対象】
写真に写っている自然物や現象を詳しく観察し、科学的な記録として適切な情報を抽出してください。

【出力項目】
1. タイトル: 簡潔で分かりやすい観察対象の名前（例：「ニホンアマガエル」「サクラの開花」）
2. 内容: 詳細な観察記録（形態、色彩、大きさ、行動、環境など具体的な特徴）
3. カテゴリ: 以下から最も適切なものを必ず選択
   - 植物（草本、木本、藻類、菌類など）
   - 動物（哺乳類、鳥類、魚類、両生類、爬虫類など）
   - 昆虫（チョウ、ガ、甲虫、ハチ、アリなど）
   - 鉱物（岩石、鉱物、結晶など）
   - 化石（植物化石、動物化石など）
   - 地形（地質構造、地層、地形特徴など）
   - その他（上記に当てはまらないもの）
4. 備考: 今後の観察で注意すべき点、関連する生態情報、季節性など

【注意事項】
- カテゴリは必ず上記7つの中から日本語で正確に選択してください
- 不明な場合は「その他」を選択してください
- 科学的な正確性を重視し、推測の場合はその旨を明記してください

【出力フォーマット】
以下のJSON形式で回答してください（他の文章は一切含めないでください）：
{
  "title": "観察対象の名前",
  "content": "詳細な観察記録と特徴",
  "category": "植物",
  "notes": "備考・追加情報"
}
'''
              },
              {
                'inline_data': {'mime_type': 'image/jpeg', 'data': base64Image}
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'topP': 0.95,
          'maxOutputTokens': 2048,
        }
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'location_memo/1.0',
        },
        body: json.encode(requestBody),
      );

      print(
          'AI Service Debug: 画像分析HTTP直接リクエスト レスポンス状態: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final text =
            responseData['candidates']?[0]?['content']?['parts']?[0]?['text'];
        print(
            'AI Service Debug: 画像分析HTTP直接リクエスト 成功: ${text?.substring(0, text.length > 100 ? 100 : text.length)}...');
        return text;
      } else {
        print('AI Service Debug: 画像分析HTTP直接リクエスト 失敗: ${response.statusCode}');
        print('AI Service Debug: エラーレスポンス: ${response.body}');
        return null;
      }
    } catch (e) {
      print('AI Service Debug: 画像分析HTTP直接リクエスト エラー詳細:');
      print('AI Service Debug: エラータイプ: ${e.runtimeType}');
      print('AI Service Debug: エラーメッセージ: $e');
      return null;
    }
  }

  /// API接続テスト
  static Future<bool> testApiConnection() async {
    print('AI Service Debug: API接続テスト開始');

    // 詳細デバッグ情報を表示
    printDebugInfo();

    // APIキーの詳細な状況を確認
    final keyStatus = checkApiKeyStatus();
    print('AI Service Debug: APIキー詳細状況: $keyStatus');

    if (!isConfigured) {
      print('AI Service Debug: API接続テスト失敗 - 設定されていません');
      if (keyStatus['isEmpty']) {
        print(
            'AI Service Debug: 解決策: lib/utils/api_config.dart でAPIキーを設定してください');
      } else if (keyStatus['isDefaultValue']) {
        print('AI Service Debug: 解決策: デフォルト値を実際のAPIキーに変更してください');
      } else if (!keyStatus['hasValidPrefix']) {
        print('AI Service Debug: 解決策: APIキーは"AIza"で始まる必要があります');
      } else if (!keyStatus['hasValidLength']) {
        print('AI Service Debug: 解決策: APIキーは39文字である必要があります');
      }
      return false;
    }

    // Web環境では最初からHTTP直接リクエストを試行
    if (kIsWeb) {
      print('AI Service Debug: Web環境でHTTP直接リクエストを試行');
      final result = await _makeDirectApiRequest('こんにちは、APIテストです。');
      final success = result != null && result.isNotEmpty;
      print('AI Service Debug: Web環境 API接続テスト結果: $success');
      return success;
    }

    // ネイティブ環境でのテスト
    try {
      final model = _model;
      if (model == null) {
        print('AI Service Debug: API接続テスト失敗 - モデルがnull');
        return false;
      }

      print('AI Service Debug: ネイティブ環境でのAPIリクエスト送信中...');
      final response = await model.generateContent([
        Content.text('こんにちは、APIテストです。'),
      ]);

      print('AI Service Debug: APIレスポンス受信');
      print('AI Service Debug: レスポンステキスト: ${response.text}');

      final success = response.text != null && response.text!.isNotEmpty;
      print('AI Service Debug: ネイティブ環境 API接続テスト結果: $success');
      return success;
    } catch (e) {
      print('AI Service Debug: ネイティブ環境 API接続テストエラー詳細:');
      print('AI Service Debug: エラータイプ: ${e.runtimeType}');
      print('AI Service Debug: エラーメッセージ: $e');
      print('AI Service Debug: エラートレース: ${StackTrace.current}');

      return false;
    }
  }

  /// 音声ファイルを文字起こし
  static Future<String?> transcribeAudio(String audioFilePath) async {
    print('AI Service Debug: 音声文字起こし開始');
    print('AI Service Debug: 音声ファイルパス: $audioFilePath');

    if (!isConfigured) {
      print('AI Service Debug: 音声文字起こし失敗 - 設定されていません');
      throw Exception('AIサービスが設定されていません。設定画面でAPIキーを設定してください。');
    }

    // Web環境では音声ファイルの処理が制限されているため、エラーメッセージを返す
    if (kIsWeb) {
      print('AI Service Debug: Web環境では音声文字起こしは制限されています');
      throw Exception(
          'Web環境では音声文字起こし機能は制限されています。\n\nモバイルアプリまたはデスクトップアプリをご利用ください。');
    }

    try {
      final model = _model;
      if (model == null) {
        print('AI Service Debug: 音声文字起こし失敗 - モデルがnull');
        throw Exception('AIモデルの初期化に失敗しました。');
      }

      // 音声ファイルを読み込み
      final audioFile = File(audioFilePath);
      if (!await audioFile.exists()) {
        print('AI Service Debug: 音声ファイルが存在しません: $audioFilePath');
        throw Exception('音声ファイルが見つかりません。');
      }

      print('AI Service Debug: 音声ファイル読み込み中...');
      final audioBytes = await audioFile.readAsBytes();
      print('AI Service Debug: 音声ファイルサイズ: ${audioBytes.length} bytes');

      // Gemini APIに音声データを送信
      print('AI Service Debug: Gemini APIに音声データ送信中...');
      final audioContent = DataPart('audio/aac', audioBytes);
      final prompt = Content.multi([
        TextPart(
            'この音声ファイルの内容を日本語で文字起こししてください。句読点や改行を適切に入れて、読みやすい形式で出力してください。文字起こしの際には、それ以外の情報は含めないでください。'),
        audioContent,
      ]);

      final response = await model.generateContent([prompt]);

      print('AI Service Debug: 音声文字起こしレスポンス受信');
      print('AI Service Debug: レスポンステキスト: ${response.text}');

      if (response.text != null && response.text!.isNotEmpty) {
        print('AI Service Debug: 音声文字起こし成功');
        return response.text!.trim();
      } else {
        print('AI Service Debug: 音声文字起こし失敗 - 空のレスポンス');
        throw Exception('音声の内容を認識できませんでした。');
      }
    } catch (e) {
      print('AI Service Debug: 音声文字起こしエラー詳細:');
      print('AI Service Debug: エラータイプ: ${e.runtimeType}');
      print('AI Service Debug: エラーメッセージ: $e');
      print('AI Service Debug: エラートレース: ${StackTrace.current}');

      // より詳細なエラー分類
      final errorMessage = e.toString().toLowerCase();

      if (errorMessage.contains('quota') || errorMessage.contains('exceeded')) {
        throw Exception(
            'Gemini APIの使用量制限に達しました。\n\n対処法：\n1. Google AI Studioで使用量を確認\n2. 課金設定を有効にする\n3. しばらく時間をおいてから再試行\n\n詳細: https://ai.google.dev/gemini-api/docs/rate-limits');
      } else if (errorMessage.contains('503') ||
          errorMessage.contains('overloaded') ||
          errorMessage.contains('unavailable')) {
        throw Exception('AIサーバーが一時的に混雑しています。\nしばらく時間をおいてから再試行してください。');
      } else if (errorMessage.contains('429') ||
          errorMessage.contains('rate limit')) {
        throw Exception('API使用回数制限に達しました。\nしばらく時間をおいてから再試行してください。');
      } else if (errorMessage.contains('401') ||
          errorMessage.contains('403') ||
          errorMessage.contains('unauthorized')) {
        throw Exception('API認証に失敗しました。\nAPIキーが正しく設定されているか確認してください。');
      } else if (errorMessage.contains('billing') ||
          errorMessage.contains('payment')) {
        throw Exception('課金設定に問題があります。\nGoogle Cloudで課金設定を確認してください。');
      } else if (errorMessage.contains('file size') ||
          errorMessage.contains('too large')) {
        throw Exception('音声ファイルが大きすぎます。\n録音時間を短くしてください。');
      } else {
        throw Exception('音声文字起こしに失敗しました。\n\nエラー詳細: ${e.toString()}');
      }
    }
  }

  /// 画像を分析してメモの内容を提案
  static Future<Map<String, String?>> analyzeImage(File imageFile) async {
    print('AI Service Debug: 画像分析開始');
    print('AI Service Debug: 画像ファイルパス: ${imageFile.path}');
    print('AI Service Debug: 画像ファイル存在: ${await imageFile.exists()}');

    if (!isConfigured) {
      print('AI Service Debug: 画像分析失敗 - 設定されていません');
      return {
        'title': null,
        'content': null,
        'category': null,
        'notes': null,
      };
    }

    try {
      print('AI Service Debug: 画像ファイル読み込み中...');
      final imageBytes = await imageFile.readAsBytes();
      print('AI Service Debug: 画像ファイルサイズ: ${imageBytes.length} bytes');

      String? responseText;

      // Web環境では最初からHTTP直接リクエストを使用
      if (kIsWeb) {
        print('AI Service Debug: Web環境でHTTP直接リクエストを使用');
        responseText = await _makeImageAnalysisRequest(imageBytes);
        if (responseText == null) {
          throw Exception('Web環境での画像分析に失敗しました。\n\nAPIキーまたはネットワーク接続を確認してください。');
        }
      } else {
        // ネイティブ環境ではSDKを使用
        final model = _model;
        if (model == null) {
          print('AI Service Debug: 画像分析失敗 - モデルがnull');
          throw Exception('AIモデルの初期化に失敗しました。');
        }

        final imageContent = DataPart('image/jpeg', imageBytes);

        print('AI Service Debug: Gemini APIに画像データ送信中...');
        final prompt = Content.multi([
          TextPart('''
この画像を分析して、フィールドワーク・自然観察記録として以下の項目を提案してください。

【分析対象】
写真に写っている自然物や現象を詳しく観察し、科学的な記録として適切な情報を抽出してください。

【出力項目】
1. タイトル: 簡潔で分かりやすい観察対象の名前（例：「ニホンアマガエル」「サクラの開花」）
2. 内容: 詳細な観察記録（形態、色彩、大きさ、行動、環境など具体的な特徴）
3. カテゴリ: 以下から最も適切なものを必ず選択
   - 植物（草本、木本、藻類、菌類など）
   - 動物（哺乳類、鳥類、魚類、両生類、爬虫類など）
   - 昆虫（チョウ、ガ、甲虫、ハチ、アリなど）
   - 鉱物（岩石、鉱物、結晶など）
   - 化石（植物化石、動物化石など）
   - 地形（地質構造、地層、地形特徴など）
   - その他（上記に当てはまらないもの）
4. 備考: 今後の観察で注意すべき点、関連する生態情報、季節性など

【注意事項】
- カテゴリは必ず上記7つの中から日本語で正確に選択してください
- 不明な場合は「その他」を選択してください
- 科学的な正確性を重視し、推測の場合はその旨を明記してください

【出力フォーマット】
以下のJSON形式で回答してください（他の文章は一切含めないでください）：
{
  "title": "観察対象の名前",
  "content": "詳細な観察記録と特徴",
  "category": "植物",
  "notes": "備考・追加情報"
}
'''),
          imageContent,
        ]);

        final response = await model.generateContent([prompt]);

        print('AI Service Debug: 画像分析レスポンス受信');
        print('AI Service Debug: レスポンステキスト: ${response.text}');

        if (response.text == null || response.text!.isEmpty) {
          print('AI Service Debug: 画像分析失敗 - 空のレスポンス');
          throw Exception('画像分析結果を取得できませんでした。');
        }

        responseText = response.text!;
      }

      // 共通のレスポンス処理
      if (responseText != null && responseText.isNotEmpty) {
        try {
          // レスポンステキストを取得
          String cleanedText = responseText.trim();

          // JSONブロックを抽出（```json``` や余分なテキストを除去）
          final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(cleanedText);
          if (jsonMatch != null) {
            cleanedText = jsonMatch.group(0)!;
            print('AI Service Debug: JSON抽出成功: $cleanedText');
          } else {
            print('AI Service Debug: JSON抽出失敗、生テキストを使用');
          }

          final jsonResponse = json.decode(cleanedText);

          // 必須フィールドの検証とデフォルト値設定
          final result = {
            'title': jsonResponse['title']?.toString()?.trim() ?? '観察記録',
            'content': jsonResponse['content']?.toString()?.trim() ?? '',
            'category': jsonResponse['category']?.toString()?.trim() ?? 'その他',
            'notes': jsonResponse['notes']?.toString()?.trim() ?? '',
          };

          print('AI Service Debug: 画像分析結果: $result');
          return result;
        } catch (e) {
          print('AI Service Debug: JSON解析エラー: $e');
          print('AI Service Debug: レスポンステキスト: $responseText');

          // JSONパースに失敗した場合は、生テキストから情報を抽出
          final fallbackResult = {
            'title': _extractTitleFromText(responseText),
            'content': _extractContentFromText(responseText),
            'category': _extractCategoryFromText(responseText),
            'notes': 'AI分析による提案（JSON解析失敗のため手動抽出）',
          };

          print('AI Service Debug: フォールバック結果: $fallbackResult');
          return fallbackResult;
        }
      }

      print('AI Service Debug: 画像分析失敗 - 空のレスポンス');
      throw Exception('画像分析結果を取得できませんでした。');
    } catch (e) {
      print('AI Service Debug: 画像分析エラー詳細:');
      print('AI Service Debug: エラータイプ: ${e.runtimeType}');
      print('AI Service Debug: エラーメッセージ: $e');
      print('AI Service Debug: エラートレース: ${StackTrace.current}');

      final errorMessage = e.toString().toLowerCase();

      if (errorMessage.contains('quota') || errorMessage.contains('exceeded')) {
        throw Exception(
            'Gemini APIの使用量制限に達しました。\n\n対処法：\n1. Google AI Studioで使用量を確認\n2. 課金設定を有効にする\n3. しばらく時間をおいてから再試行');
      } else if (errorMessage.contains('503') ||
          errorMessage.contains('overloaded')) {
        throw Exception('AIサーバーが一時的に混雑しています。\nしばらく時間をおいてから再試行してください。');
      } else if (errorMessage.contains('429')) {
        throw Exception('API使用回数制限に達しました。\nしばらく時間をおいてから再試行してください。');
      } else if (errorMessage.contains('401') || errorMessage.contains('403')) {
        throw Exception('API認証に失敗しました。\nAPIキーが正しく設定されているか確認してください。');
      } else {
        throw Exception('画像分析に失敗しました: ${e.toString()}');
      }
    }
  }

  /// テキストを分析してメモの改善を提案
  static Future<String> improveMemoContent(String currentContent) async {
    print('AI Service Debug: テキスト改善開始');
    print('AI Service Debug: 現在のコンテンツ長: ${currentContent.length}');

    if (!isConfigured) {
      print('AI Service Debug: テキスト改善失敗 - 設定されていません');
      return currentContent;
    }

    final prompt = '''
以下の自然観察記録の内容を、より詳細で科学的な観察記録になるように改善してください。
観察の精度を高め、専門的な視点も加えつつ、読みやすい文章にしてください。

元の内容：
$currentContent

改善のポイント：
- より具体的な観察事項の追加
- 科学的な記述の補強
- 構造化された記録形式
- 今後の観察で注意すべき点の提案
''';

    // Web環境では最初からHTTP直接リクエストを試行
    if (kIsWeb) {
      print('AI Service Debug: Web環境でHTTP直接リクエストを試行');
      final result = await _makeDirectApiRequest(prompt);
      if (result != null && result.isNotEmpty) {
        print('AI Service Debug: テキスト改善成功（HTTP直接）');
        return result.trim();
      } else {
        print('AI Service Debug: Web環境でHTTP直接リクエストが失敗');
        throw Exception('Web環境でのテキスト改善に失敗しました。\n\nAPIキーまたはネットワーク接続を確認してください。');
      }
    }

    try {
      final model = _model;
      if (model == null) {
        print('AI Service Debug: テキスト改善失敗 - モデルがnull');
        throw Exception('AIモデルの初期化に失敗しました。');
      }

      print('AI Service Debug: Gemini APIにテキスト改善リクエスト送信中...');
      final response = await model.generateContent([
        Content.text(prompt),
      ]);

      print('AI Service Debug: テキスト改善レスポンス受信');
      print('AI Service Debug: レスポンステキスト: ${response.text}');

      if (response.text != null && response.text!.isNotEmpty) {
        print('AI Service Debug: テキスト改善成功');
        return response.text!.trim();
      } else {
        print('AI Service Debug: テキスト改善失敗 - 空のレスポンス');
        throw Exception('改善提案を生成できませんでした。');
      }
    } catch (e) {
      print('AI Service Debug: テキスト改善エラー詳細:');
      print('AI Service Debug: エラータイプ: ${e.runtimeType}');
      print('AI Service Debug: エラーメッセージ: $e');
      print('AI Service Debug: エラートレース: ${StackTrace.current}');

      final errorMessage = e.toString().toLowerCase();

      if (errorMessage.contains('quota') || errorMessage.contains('exceeded')) {
        throw Exception(
            'Gemini APIの使用量制限に達しました。\n\n対処法：\n1. Google AI Studioで使用量を確認\n2. 課金設定を有効にする\n3. しばらく時間をおいてから再試行');
      } else if (errorMessage.contains('503') ||
          errorMessage.contains('overloaded')) {
        throw Exception('AIサーバーが一時的に混雑しています。\nしばらく時間をおいてから再試行してください。');
      } else if (errorMessage.contains('429')) {
        throw Exception('API使用回数制限に達しました。\nしばらく時間をおいてから再試行してください。');
      } else if (errorMessage.contains('401') || errorMessage.contains('403')) {
        throw Exception('API認証に失敗しました。\nAPIキーが正しく設定されているか確認してください。');
      } else {
        throw Exception('テキスト改善に失敗しました: ${e.toString()}');
      }
    }
  }

  /// 質問応答機能
  static Future<String> askQuestion(String question, List<Memo> context) async {
    print('AI Service Debug: 質問応答開始');
    print('AI Service Debug: 質問: $question');
    print('AI Service Debug: コンテキストメモ数: ${context.length}');

    if (!isConfigured) {
      print('AI Service Debug: 質問応答失敗 - 設定されていません');
      return 'AI機能を使用するには、APIキーの設定が必要です。設定画面でGemini APIキーを設定してください。';
    }

    // 過去のメモから関連する情報を抽出
    final contextInfo = context
        .take(10)
        .map((memo) =>
            'タイトル: ${memo.title}\n内容: ${memo.content ?? ""}\nカテゴリ: ${memo.category ?? "未分類"}')
        .join('\n\n');

    final prompt = '''
フィールドワークと自然観察に関する質問に答えてください。

過去の観察記録（参考情報）：
$contextInfo

質問：$question

回答は以下の点を考慮してください：
- 科学的で正確な情報を提供
- 初心者にも分かりやすい説明
- 過去の観察記録との関連性があれば言及
- 今後の観察や研究のアドバイスも含める
''';

    // Web環境では最初からHTTP直接リクエストを試行
    if (kIsWeb) {
      print('AI Service Debug: Web環境でHTTP直接リクエストを試行');
      final result = await _makeDirectApiRequest(prompt);
      if (result != null && result.isNotEmpty) {
        print('AI Service Debug: 質問応答成功（HTTP直接）');
        return result.trim();
      } else {
        print('AI Service Debug: Web環境でHTTP直接リクエストが失敗');
        throw Exception('Web環境での質問応答に失敗しました。\n\nAPIキーまたはネットワーク接続を確認してください。');
      }
    }

    try {
      final model = _model;
      if (model == null) {
        print('AI Service Debug: 質問応答失敗 - モデルがnull');
        throw Exception('AIモデルの初期化に失敗しました。');
      }

      print('AI Service Debug: Gemini APIに質問リクエスト送信中...');
      final response = await model.generateContent([
        Content.text(prompt),
      ]);

      print('AI Service Debug: 質問応答レスポンス受信');
      print('AI Service Debug: レスポンステキスト: ${response.text}');

      if (response.text != null && response.text!.isNotEmpty) {
        print('AI Service Debug: 質問応答成功');
        return response.text!.trim();
      } else {
        print('AI Service Debug: 質問応答失敗 - 空のレスポンス');
        throw Exception('回答を生成できませんでした。');
      }
    } catch (e) {
      print('AI Service Debug: 質問応答エラー詳細:');
      print('AI Service Debug: エラータイプ: ${e.runtimeType}');
      print('AI Service Debug: エラーメッセージ: $e');
      print('AI Service Debug: エラートレース: ${StackTrace.current}');

      final errorMessage = e.toString().toLowerCase();

      if (errorMessage.contains('quota') || errorMessage.contains('exceeded')) {
        throw Exception(
            'Gemini APIの使用量制限に達しました。\n\n対処法：\n1. Google AI Studioで使用量を確認\n2. 課金設定を有効にする\n3. しばらく時間をおいてから再試行');
      } else if (errorMessage.contains('503') ||
          errorMessage.contains('overloaded')) {
        throw Exception('AIサーバーが一時的に混雑しています。\nしばらく時間をおいてから再試行してください。');
      } else if (errorMessage.contains('429')) {
        throw Exception('API使用回数制限に達しました。\nしばらく時間をおいてから再試行してください。');
      } else if (errorMessage.contains('401') || errorMessage.contains('403')) {
        throw Exception('API認証に失敗しました。\nAPIキーが正しく設定されているか確認してください。');
      } else {
        throw Exception('質問応答に失敗しました: ${e.toString()}');
      }
    }
  }

  /// テキストからタイトルを抽出
  static String _extractTitleFromText(String text) {
    // 「タイトル:」「題名:」「名前:」などの後に続く内容を抽出
    final titleRegex =
        RegExp(r'(?:タイトル|題名|名前|title)[：:]\s*([^\n\r]+)', caseSensitive: false);
    final match = titleRegex.firstMatch(text);
    if (match != null) {
      return match.group(1)!.trim();
    }

    // 最初の行を基本的なタイトルとして使用
    final lines =
        text.split('\n').where((line) => line.trim().isNotEmpty).toList();
    if (lines.isNotEmpty) {
      return lines.first
          .trim()
          .substring(0, lines.first.length > 50 ? 50 : lines.first.length);
    }

    return '画像分析結果';
  }

  /// テキストから内容を抽出
  static String _extractContentFromText(String text) {
    // 「内容:」「説明:」「詳細:」などの後に続く内容を抽出
    final contentRegex = RegExp(
        r'(?:内容|説明|詳細|content)[：:]\s*([^\n\r]+(?:\n[^\n\r]+)*)',
        caseSensitive: false);
    final match = contentRegex.firstMatch(text);
    if (match != null) {
      return match.group(1)!.trim();
    }

    // 全体のテキストを内容として使用（最大500文字）
    final cleanText = text.replaceAll(RegExp(r'[：:]'), '').trim();
    return cleanText.length > 500
        ? '${cleanText.substring(0, 500)}...'
        : cleanText;
  }

  /// テキストからカテゴリを抽出
  static String _extractCategoryFromText(String text) {
    // カテゴリキーワードを検索
    final categories = ['植物', '動物', '昆虫', '鉱物', '化石', '地形'];
    final lowerText = text.toLowerCase();

    for (final category in categories) {
      if (lowerText.contains(category) ||
          lowerText.contains(category.toLowerCase())) {
        return category;
      }
    }

    // 追加のキーワードマッピング
    if (lowerText.contains('草') ||
        lowerText.contains('木') ||
        lowerText.contains('花') ||
        lowerText.contains('葉')) {
      return '植物';
    }
    if (lowerText.contains('鳥') ||
        lowerText.contains('魚') ||
        lowerText.contains('哺乳類')) {
      return '動物';
    }
    if (lowerText.contains('虫') ||
        lowerText.contains('蝶') ||
        lowerText.contains('蛾')) {
      return '昆虫';
    }
    if (lowerText.contains('石') || lowerText.contains('岩')) {
      return '鉱物';
    }

    return 'その他';
  }
}
