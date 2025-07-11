import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';

// Web環境でのみWebAudioServiceをインポート
import 'web_audio_service_stub.dart' if (dart.library.html) 'web_audio_service.dart';

class AudioService {
  static FlutterSoundRecorder? _recorder;
  static FlutterSoundPlayer? _player;
  static bool _isRecording = false;
  static bool _isPlaying = false;
  static String? _currentRecordingPath;
  static bool _isInitialized = false;

  // 初期化
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (kIsWeb) {
        // Web環境での初期化確認
        print('Web環境での音声サービス初期化');
      } else {
        await _initializeMobile();
      }
      _isInitialized = true;
      print('AudioService 初期化完了');
    } catch (e) {
      print('AudioService 初期化エラー: $e');
      rethrow;
    }
  }

  // モバイル用初期化
  static Future<void> _initializeMobile() async {
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();

    await _recorder!.openRecorder();
    await _player!.openPlayer();
  }

  // 録音権限をチェック
  static Future<bool> checkPermissions() async {
    try {
      if (kIsWeb) {
        return await WebAudioService.checkMicrophonePermission();
      } else {
        return await _checkMobilePermissions();
      }
    } catch (e) {
      print('権限チェックエラー: $e');
      return false;
    }
  }

  // モバイル用権限チェック
  static Future<bool> _checkMobilePermissions() async {
    final microphoneStatus = await Permission.microphone.status;

    if (microphoneStatus.isDenied) {
      final result = await Permission.microphone.request();
      return result.isGranted;
    }

    return microphoneStatus.isGranted;
  }

  // 録音開始
  static Future<bool> startRecording() async {
    try {
      if (_isRecording) {
        print('既に録音中です');
        return false;
      }

      // 初期化
      await initialize();

      // 権限確認
      if (!await checkPermissions()) {
        print('マイクの権限が必要です');
        return false;
      }

      if (kIsWeb) {
        final success = await WebAudioService.startRecording();
        if (success) {
          _isRecording = true;
        }
        return success;
      } else {
        return await _startMobileRecording();
      }
    } catch (e) {
      print('録音開始エラー: $e');
      return false;
    }
  }

  // モバイル用録音開始
  static Future<bool> _startMobileRecording() async {
    try {
      // 録音ファイルのパスを生成
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${directory.path}/recording_$timestamp.aac';

      // 録音開始
      await _recorder!.startRecorder(
        toFile: _currentRecordingPath,
        codec: Codec.aacADTS,
      );

      _isRecording = true;
      print('モバイル録音開始: $_currentRecordingPath');
      return true;
    } catch (e) {
      print('モバイル録音開始エラー: $e');
      return false;
    }
  }

  // 録音停止
  static Future<String?> stopRecording() async {
    try {
      if (!_isRecording) {
        print('録音していません');
        return null;
      }

      if (kIsWeb) {
        final result = await WebAudioService.stopRecording();
        if (result != null) {
          _currentRecordingPath = result;
          _isRecording = false;
        }
        return result;
      } else {
        return await _stopMobileRecording();
      }
    } catch (e) {
      print('録音停止エラー: $e');
      _isRecording = false;
      return null;
    }
  }

  // モバイル用録音停止
  static Future<String?> _stopMobileRecording() async {
    try {
      await _recorder!.stopRecorder();
      _isRecording = false;
      print('モバイル録音停止: $_currentRecordingPath');
      return _currentRecordingPath;
    } catch (e) {
      print('モバイル録音停止エラー: $e');
      _isRecording = false;
      return null;
    }
  }

  // 録音中かどうか
  static bool get isRecording {
    if (kIsWeb) {
      return WebAudioService.isRecording;
    }
    return _isRecording;
  }

  // 音声ファイルを再生
  static Future<bool> playAudio(String filePath) async {
    try {
      if (_isPlaying) {
        await stopPlaying();
      }

      // 初期化
      await initialize();

      if (kIsWeb) {
        final success = await WebAudioService.playAudio(filePath);
        if (success) {
          _isPlaying = true;
        }
        return success;
      } else {
        return await _playMobileAudio(filePath);
      }
    } catch (e) {
      print('音声再生エラー: $e');
      return false;
    }
  }

  // モバイル用音声再生
  static Future<bool> _playMobileAudio(String filePath) async {
    try {
      if (!File(filePath).existsSync()) {
        print('音声ファイルが見つかりません: $filePath');
        return false;
      }

      await _player!.startPlayer(
        fromURI: filePath,
        codec: Codec.aacADTS,
        whenFinished: () {
          _isPlaying = false;
        },
      );

      _isPlaying = true;
      print('モバイル音声再生開始: $filePath');
      return true;
    } catch (e) {
      print('モバイル音声再生エラー: $e');
      return false;
    }
  }

  // 再生停止
  static Future<void> stopPlaying() async {
    try {
      if (kIsWeb) {
        await WebAudioService.stopPlaying();
        _isPlaying = false;
      } else {
        await _stopMobilePlaying();
      }
    } catch (e) {
      print('音声停止エラー: $e');
    }
  }

  // モバイル用再生停止
  static Future<void> _stopMobilePlaying() async {
    try {
      if (_isInitialized && _player != null) {
        await _player!.stopPlayer();
        _isPlaying = false;
        print('モバイル音声再生停止');
      }
    } catch (e) {
      print('モバイル音声停止エラー: $e');
    }
  }

  // 再生中かどうか
  static bool get isPlaying {
    if (kIsWeb) {
      return WebAudioService.isPlaying;
    }
    return _isPlaying;
  }

  // 音声ファイルを削除
  static Future<bool> deleteAudioFile(String filePath) async {
    try {
      if (kIsWeb) {
        // Web版: Base64データなので削除処理は不要
        print('Web音声データクリア');
        return true;
      } else {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
          print('音声ファイル削除: $filePath');
          return true;
        }
        return false;
      }
    } catch (e) {
      print('音声ファイル削除エラー: $e');
      return false;
    }
  }

  // 現在の録音パスを取得
  static String? get currentRecordingPath => _currentRecordingPath;

  // プラットフォーム情報を取得
  static String getPlatformInfo() {
    if (kIsWeb) {
      return 'Web';
    } else if (Platform.isAndroid) {
      return 'Android';
    } else if (Platform.isIOS) {
      return 'iOS';
    } else {
      return 'Unknown';
    }
  }

  // 音声形式の取得
  static String getAudioFormat() {
    if (kIsWeb) {
      return WebAudioService.getAudioFormat();
    } else {
      return 'aac';
    }
  }

  // ブラウザ情報の取得（Web環境のみ）
  static String getBrowserInfo() {
    if (kIsWeb) {
      return WebAudioService.getBrowserInfo();
    } else {
      return 'N/A (Not Web)';
    }
  }

  // Web Audio APIサポート状況（Web環境のみ）
  static bool isWebAudioSupported() {
    if (kIsWeb) {
      return WebAudioService.isSupported();
    } else {
      return false;
    }
  }

  // リソースの解放
  static Future<void> dispose() async {
    try {
      if (_isRecording) {
        await stopRecording();
      }
      if (_isPlaying) {
        await stopPlaying();
      }

      if (kIsWeb) {
        // Web用リソース解放
        WebAudioService.dispose();
      } else {
        // モバイル用リソース解放
        await _recorder?.closeRecorder();
        await _player?.closePlayer();
        _recorder = null;
        _player = null;
      }

      _currentRecordingPath = null;
      _isInitialized = false;
      print('AudioService リソース解放完了');
    } catch (e) {
      print('AudioService dispose エラー: $e');
    }
  }
}
