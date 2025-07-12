import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/memo.dart';
import 'api_config.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AIService {
  static const String _apiKey = ApiConfig.geminiApiKey; // APIキーをここに設定

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
      final isConfigured = _apiKey.isNotEmpty && _apiKey != 'default_value';
      print('AI Service Debug: Web環境での設定状態: $isConfigured');
      return isConfigured;
    }

    print('AI Service Debug: ネイティブ環境で実行中');
    print('AI Service Debug: APIキー長: ${_apiKey.length}');
    return true;
  }

  /// Gemini APIクライアントを取得
  static GenerativeModel? get _model {
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

  /// API接続テスト
  static Future<bool> testApiConnection() async {
    print('AI Service Debug: API接続テスト開始');
    print('AI Service Debug: 設定状態: ${isConfigured}');

    if (!isConfigured) {
      print('AI Service Debug: API接続テスト失敗 - 設定されていません');
      return false;
    }

    try {
      final model = _model;
      if (model == null) {
        print('AI Service Debug: API接続テスト失敗 - モデルがnull');
        return false;
      }

      print('AI Service Debug: APIリクエスト送信中...');
      final response = await model.generateContent([
        Content.text('こんにちは'),
      ]);

      print('AI Service Debug: APIレスポンス受信');
      print('AI Service Debug: レスポンステキスト: ${response.text}');

      final success = response.text != null && response.text!.isNotEmpty;
      print('AI Service Debug: API接続テスト結果: $success');
      return success;
    } catch (e) {
      print('AI Service Debug: API接続テストエラー詳細:');
      print('AI Service Debug: エラータイプ: ${e.runtimeType}');
      print('AI Service Debug: エラーメッセージ: $e');
      print('AI Service Debug: エラートレース: ${StackTrace.current}');

      // Web環境特有のエラー情報
      if (kIsWeb) {
        print('AI Service Debug: Web環境でのエラー情報:');
        print('AI Service Debug: 現在のURL: ${Uri.base}');
        print('AI Service Debug: HTTPS接続: ${Uri.base.scheme == 'https'}');
      }

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
      final model = _model;
      if (model == null) {
        print('AI Service Debug: 画像分析失敗 - モデルがnull');
        throw Exception('AIモデルの初期化に失敗しました。');
      }

      print('AI Service Debug: 画像ファイル読み込み中...');
      final imageBytes = await imageFile.readAsBytes();
      print('AI Service Debug: 画像ファイルサイズ: ${imageBytes.length} bytes');

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

      if (response.text != null) {
        try {
          // レスポンステキストを取得
          String responseText = response.text!.trim();

          // JSONブロックを抽出（```json``` や余分なテキストを除去）
          final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(responseText);
          if (jsonMatch != null) {
            responseText = jsonMatch.group(0)!;
            print('AI Service Debug: JSON抽出成功: $responseText');
          } else {
            print('AI Service Debug: JSON抽出失敗、生テキストを使用');
          }

          final jsonResponse = json.decode(responseText);

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
          print('AI Service Debug: レスポンステキスト: ${response.text}');

          // JSONパースに失敗した場合は、生テキストから情報を抽出
          final text = response.text!;
          final fallbackResult = {
            'title': _extractTitleFromText(text),
            'content': _extractContentFromText(text),
            'category': _extractCategoryFromText(text),
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

    try {
      final model = _model;
      if (model == null) {
        print('AI Service Debug: テキスト改善失敗 - モデルがnull');
        throw Exception('AIモデルの初期化に失敗しました。');
      }

      print('AI Service Debug: Gemini APIにテキスト改善リクエスト送信中...');
      final prompt = Content.text('''
以下の自然観察記録の内容を、より詳細で科学的な観察記録になるように改善してください。
観察の精度を高め、専門的な視点も加えつつ、読みやすい文章にしてください。

元の内容：
$currentContent

改善のポイント：
- より具体的な観察事項の追加
- 科学的な記述の補強
- 構造化された記録形式
- 今後の観察で注意すべき点の提案
''');

      final response = await model.generateContent([prompt]);

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

    try {
      final model = _model;
      if (model == null) {
        print('AI Service Debug: 質問応答失敗 - モデルがnull');
        throw Exception('AIモデルの初期化に失敗しました。');
      }

      // 過去のメモから関連する情報を抽出
      final contextInfo = context
          .take(10)
          .map((memo) =>
              'タイトル: ${memo.title}\n内容: ${memo.content ?? ""}\nカテゴリ: ${memo.category ?? "未分類"}')
          .join('\n\n');

      print('AI Service Debug: Gemini APIに質問リクエスト送信中...');
      final prompt = Content.text('''
フィールドワークと自然観察に関する質問に答えてください。

過去の観察記録（参考情報）：
$contextInfo

質問：$question

回答は以下の点を考慮してください：
- 科学的で正確な情報を提供
- 初心者にも分かりやすい説明
- 過去の観察記録との関連性があれば言及
- 今後の観察や研究のアドバイスも含める
''');

      final response = await model.generateContent([prompt]);

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
