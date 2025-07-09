import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';

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

    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();

    await _recorder!.openRecorder();
    await _player!.openPlayer();

    _isInitialized = true;
  }

  // 録音権限をチェック
  static Future<bool> checkPermissions() async {
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
      if (kIsWeb) {
        // Web版では音声録音機能は制限されます
        print('Web版では音声録音機能は利用できません');
        return false;
      }

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
      print('録音開始: $_currentRecordingPath');
      return true;
    } catch (e) {
      print('録音開始エラー: $e');
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

      await _recorder!.stopRecorder();
      _isRecording = false;

      print('録音停止: $_currentRecordingPath');
      return _currentRecordingPath;
    } catch (e) {
      print('録音停止エラー: $e');
      _isRecording = false;
      return null;
    }
  }

  // 録音中かどうか
  static bool get isRecording => _isRecording;

  // 音声ファイルを再生
  static Future<bool> playAudio(String filePath) async {
    try {
      if (kIsWeb) {
        // Web版では音声再生機能は制限されます
        print('Web版では音声再生機能は利用できません');
        return false;
      }

      if (_isPlaying) {
        await stopPlaying();
      }

      // 初期化
      await initialize();

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
      print('音声再生開始: $filePath');
      return true;
    } catch (e) {
      print('音声再生エラー: $e');
      return false;
    }
  }

  // 再生停止
  static Future<void> stopPlaying() async {
    try {
      if (!_isInitialized || _player == null) return;

      await _player!.stopPlayer();
      _isPlaying = false;
      print('音声再生停止');
    } catch (e) {
      print('音声停止エラー: $e');
    }
  }

  // 再生中かどうか
  static bool get isPlaying => _isPlaying;

  // 音声ファイルを削除
  static Future<bool> deleteAudioFile(String filePath) async {
    try {
      if (kIsWeb) {
        // Web版では音声ファイル削除機能は制限されます
        print('Web版では音声ファイル削除機能は利用できません');
        return false;
      }

      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print('音声ファイル削除: $filePath');
        return true;
      }
      return false;
    } catch (e) {
      print('音声ファイル削除エラー: $e');
      return false;
    }
  }

  // 現在の録音パスを取得
  static String? get currentRecordingPath => _currentRecordingPath;

  // リソースの解放
  static Future<void> dispose() async {
    try {
      if (_isRecording && _recorder != null) {
        await stopRecording();
      }
      if (_isPlaying && _player != null) {
        await stopPlaying();
      }

      await _recorder?.closeRecorder();
      await _player?.closePlayer();

      _recorder = null;
      _player = null;
      _isInitialized = false;
    } catch (e) {
      print('AudioService dispose エラー: $e');
    }
  }
}
