import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';

// Web用のimport（条件付き）
import 'dart:html' as html
    show
        MediaRecorder,
        Blob,
        Url,
        AudioElement,
        window,
        navigator,
        MediaStream,
        Event,
        FileReader;
import 'dart:js_interop' as js;

class AudioService {
  static FlutterSoundRecorder? _recorder;
  static FlutterSoundPlayer? _player;
  static bool _isRecording = false;
  static bool _isPlaying = false;
  static String? _currentRecordingPath;
  static bool _isInitialized = false;

  // Web用の変数
  static html.MediaRecorder? _webRecorder;
  static html.AudioElement? _webPlayer;
  static List<html.Blob> _webRecordingChunks = [];
  static html.MediaStream? _webMediaStream;
  static String? _webRecordingData; // Base64エンコードされた音声データ

  // 初期化
  static Future<void> initialize() async {
    if (_isInitialized) return;

    if (kIsWeb) {
      await _initializeWeb();
    } else {
      _recorder = FlutterSoundRecorder();
      _player = FlutterSoundPlayer();

      await _recorder!.openRecorder();
      await _player!.openPlayer();
    }

    _isInitialized = true;
  }

  // Web用初期化
  static Future<void> _initializeWeb() async {
    try {
      // MediaRecorderの対応確認
      if (html.window.navigator.mediaDevices == null) {
        print('このブラウザではMediaRecorderがサポートされていません');
        return;
      }
      print('Web音声機能の初期化完了');
    } catch (e) {
      print('Web音声機能の初期化エラー: $e');
    }
  }

  // 録音権限をチェック
  static Future<bool> checkPermissions() async {
    if (kIsWeb) {
      return await _checkWebPermissions();
    } else {
      final microphoneStatus = await Permission.microphone.status;

      if (microphoneStatus.isDenied) {
        final result = await Permission.microphone.request();
        return result.isGranted;
      }

      return microphoneStatus.isGranted;
    }
  }

  // Web用権限チェック
  static Future<bool> _checkWebPermissions() async {
    try {
      // getUserMediaを試行して権限をチェック
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'audio': true,
      });

      // ストリームを即座に停止
      stream.getTracks().forEach((track) => track.stop());

      return true;
    } catch (e) {
      print('Web環境でのマイク権限エラー: $e');
      return false;
    }
  }

  // 録音開始
  static Future<bool> startRecording() async {
    try {
      if (kIsWeb) {
        return await _startWebRecording();
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

  // Web用録音開始
  static Future<bool> _startWebRecording() async {
    try {
      if (_isRecording) {
        print('既に録音中です');
        return false;
      }

      // 権限確認
      if (!await checkPermissions()) {
        print('マイクの権限が必要です');
        return false;
      }

      // MediaStreamを取得
      _webMediaStream = await html.window.navigator.mediaDevices!.getUserMedia({
        'audio': true,
      });

      // MediaRecorderを作成
      _webRecorder = html.MediaRecorder(_webMediaStream!);
      _webRecordingChunks.clear();

      // データが利用可能になったときのイベントリスナー
      _webRecorder!.addEventListener('dataavailable', (html.Event event) {
        final data = (event as dynamic).data;
        if (data.size > 0) {
          _webRecordingChunks.add(data);
        }
      });

      // 録音停止時のイベントリスナー
      _webRecorder!.addEventListener('stop', (html.Event event) {
        _finalizeWebRecording();
      });

      // 録音開始
      _webRecorder!.start();
      _isRecording = true;

      print('Web録音開始');
      return true;
    } catch (e) {
      print('Web録音開始エラー: $e');
      return false;
    }
  }

  // Web録音データの確定
  static void _finalizeWebRecording() {
    if (_webRecordingChunks.isNotEmpty) {
      final blob = html.Blob(_webRecordingChunks, 'audio/wav');
      final url = html.Url.createObjectUrl(blob);

      // Base64エンコードのためのFileReaderを使用
      final reader = html.FileReader();
      reader.onLoad.listen((event) {
        final result = reader.result as String;
        _webRecordingData = result;
        _currentRecordingPath = result; // Base64データをパスとして使用
      });
      reader.readAsDataUrl(blob);
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
        return await _stopWebRecording();
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

  // Web用録音停止
  static Future<String?> _stopWebRecording() async {
    try {
      if (_webRecorder == null || !_isRecording) {
        return null;
      }

      _webRecorder!.stop();
      _isRecording = false;

      // MediaStreamのトラックを停止
      if (_webMediaStream != null) {
        _webMediaStream!.getTracks().forEach((track) => track.stop());
      }

      // Base64データが準備されるまで少し待つ
      await Future.delayed(const Duration(milliseconds: 500));

      print('Web録音停止: ${_webRecordingData != null ? "データあり" : "データなし"}');
      return _webRecordingData;
    } catch (e) {
      print('Web録音停止エラー: $e');
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
        return await _playWebAudio(filePath);
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

  // Web用音声再生
  static Future<bool> _playWebAudio(String audioData) async {
    try {
      if (_isPlaying) {
        await stopPlaying();
      }

      // AudioElementを作成
      _webPlayer = html.AudioElement();
      _webPlayer!.src = audioData; // Base64データURL

      // 再生終了時のイベントリスナー
      _webPlayer!.addEventListener('ended', (html.Event event) {
        _isPlaying = false;
      });

      _webPlayer!.addEventListener('error', (html.Event event) {
        print('Web音声再生エラー');
        _isPlaying = false;
      });

      await _webPlayer!.play();
      _isPlaying = true;

      print('Web音声再生開始');
      return true;
    } catch (e) {
      print('Web音声再生エラー: $e');
      return false;
    }
  }

  // 再生停止
  static Future<void> stopPlaying() async {
    try {
      if (kIsWeb) {
        await _stopWebPlaying();
        return;
      }

      if (!_isInitialized || _player == null) return;

      await _player!.stopPlayer();
      _isPlaying = false;
      print('音声再生停止');
    } catch (e) {
      print('音声停止エラー: $e');
    }
  }

  // Web用再生停止
  static Future<void> _stopWebPlaying() async {
    try {
      if (_webPlayer != null) {
        _webPlayer!.pause();
        _webPlayer!.currentTime = 0;
        _isPlaying = false;
        print('Web音声再生停止');
      }
    } catch (e) {
      print('Web音声停止エラー: $e');
    }
  }

  // 再生中かどうか
  static bool get isPlaying => _isPlaying;

  // 音声ファイルを削除
  static Future<bool> deleteAudioFile(String filePath) async {
    try {
      if (kIsWeb) {
        // Web版: Base64データなので削除処理は不要
        _webRecordingData = null;
        print('Web音声データクリア');
        return true;
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
      if (_isRecording) {
        await stopRecording();
      }
      if (_isPlaying) {
        await stopPlaying();
      }

      if (kIsWeb) {
        // Web用リソース解放
        if (_webMediaStream != null) {
          _webMediaStream!.getTracks().forEach((track) => track.stop());
        }
        _webRecorder = null;
        _webPlayer = null;
        _webRecordingChunks.clear();
        _webMediaStream = null;
        _webRecordingData = null;
      } else {
        await _recorder?.closeRecorder();
        await _player?.closePlayer();
        _recorder = null;
        _player = null;
      }

      _isInitialized = false;
    } catch (e) {
      print('AudioService dispose エラー: $e');
    }
  }
}
