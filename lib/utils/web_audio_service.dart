// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// Flutter 3.35の正式対象であるJavaScriptビルド専用の条件付き実装。

import 'app_logger.dart';
import 'dart:html' as html;
import 'dart:async';

class WebAudioService {
  static html.MediaRecorder? _mediaRecorder;
  static html.AudioElement? _audioElement;
  static final List<html.Blob> _recordingChunks = [];
  static html.MediaStream? _mediaStream;
  static bool _isRecording = false;
  static bool _isPlaying = false;
  static Completer<String>? _recordingCompleter;

  // Web Audio APIのサポート確認
  static bool isSupported() {
    try {
      return html.window.navigator.mediaDevices != null;
    } catch (e) {
      return false;
    }
  }

  // マイク権限の確認
  static Future<bool> checkMicrophonePermission() async {
    try {
      if (!isSupported()) return false;

      // getUserMediaを試行して権限をチェック
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'audio': true,
      });

      // ストリームを即座に停止
      for (var track in stream.getTracks()) {
        track.stop();
      }

      return true;
    } catch (e) {
      appLog('マイク権限エラー: $e');
      return false;
    }
  }

  // 録音開始
  static Future<bool> startRecording() async {
    try {
      if (_isRecording) {
        appLog('既に録音中です');
        return false;
      }

      if (!isSupported()) {
        appLog('このブラウザではMediaRecorderがサポートされていません');
        return false;
      }

      // マイク権限の確認
      if (!await checkMicrophonePermission()) {
        appLog('マイクの権限が必要です');
        return false;
      }

      // MediaStreamを取得
      _mediaStream = await html.window.navigator.mediaDevices!.getUserMedia({
        'audio': true,
      });

      // MediaRecorderを作成
      String mimeType = 'audio/webm';
      if (!html.MediaRecorder.isTypeSupported(mimeType)) {
        mimeType = 'audio/wav';
        if (!html.MediaRecorder.isTypeSupported(mimeType)) {
          mimeType = ''; // ブラウザのデフォルト
        }
      }

      _mediaRecorder = html.MediaRecorder(_mediaStream!, {
        'mimeType': mimeType,
      });

      _recordingChunks.clear();
      _recordingCompleter = Completer<String>();

      // データが利用可能になったときのイベントリスナー
      _mediaRecorder!.addEventListener('dataavailable', (html.Event event) {
        final data = (event as html.BlobEvent).data;
        if (data != null && data.size > 0) {
          _recordingChunks.add(data);
        }
      });

      // 録音停止時のイベントリスナー
      _mediaRecorder!.addEventListener('stop', (html.Event event) {
        _finalizeRecording();
      });

      // エラーハンドリング
      _mediaRecorder!.addEventListener('error', (html.Event event) {
        appLog('録音エラー: ${event.toString()}');
        _isRecording = false;
        if (!_recordingCompleter!.isCompleted) {
          _recordingCompleter!.completeError('録音エラーが発生しました');
        }
      });

      // 録音開始
      _mediaRecorder!.start();
      _isRecording = true;

      appLog('Web録音開始 (${mimeType.isEmpty ? 'default' : mimeType})');
      return true;
    } catch (e) {
      appLog('録音開始エラー: $e');
      _cleanupRecording();
      return false;
    }
  }

  // 録音停止
  static Future<String?> stopRecording() async {
    try {
      if (!_isRecording || _mediaRecorder == null) {
        appLog('録音していません');
        return null;
      }

      _mediaRecorder!.stop();
      _isRecording = false;

      // 録音データの処理完了を待つ
      try {
        final recordingData = await _recordingCompleter!.future.timeout(
          const Duration(seconds: 5),
        );
        appLog('録音停止完了');
        return recordingData;
      } catch (e) {
        appLog('録音データ処理エラー: $e');
        return null;
      }
    } catch (e) {
      appLog('録音停止エラー: $e');
      _cleanupRecording();
      return null;
    }
  }

  // 録音データの確定処理
  static void _finalizeRecording() {
    try {
      if (_recordingChunks.isNotEmpty) {
        final blob = html.Blob(_recordingChunks);

        // Base64エンコードのためのFileReaderを使用
        final reader = html.FileReader();

        reader.onLoad.listen((event) {
          final result = reader.result as String;
          if (!_recordingCompleter!.isCompleted) {
            _recordingCompleter!.complete(result);
          }
        });

        reader.onError.listen((event) {
          appLog('録音データ読み込みエラー');
          if (!_recordingCompleter!.isCompleted) {
            _recordingCompleter!.completeError('録音データの読み込みに失敗しました');
          }
        });

        reader.readAsDataUrl(blob);
      } else {
        appLog('録音データがありません');
        if (!_recordingCompleter!.isCompleted) {
          _recordingCompleter!.completeError('録音データが空です');
        }
      }
    } catch (e) {
      appLog('録音データ確定エラー: $e');
      if (!_recordingCompleter!.isCompleted) {
        _recordingCompleter!.completeError('録音データの処理に失敗しました');
      }
    }
  }

  // 録音リソースのクリーンアップ
  static void _cleanupRecording() {
    try {
      if (_mediaStream != null) {
        for (var track in _mediaStream!.getTracks()) {
          track.stop();
        }
        _mediaStream = null;
      }
      _mediaRecorder = null;
      _recordingChunks.clear();
      _isRecording = false;
    } catch (e) {
      appLog('録音リソースクリーンアップエラー: $e');
    }
  }

  // 音声再生
  static Future<bool> playAudio(String audioData) async {
    try {
      if (_isPlaying) {
        await stopPlaying();
      }

      _audioElement = html.AudioElement();
      _audioElement!.src = audioData;
      _audioElement!.preload = 'auto';

      // 再生終了時のイベントリスナー
      _audioElement!.addEventListener('ended', (html.Event event) {
        _isPlaying = false;
        appLog('音声再生終了');
      });

      // エラーハンドリング
      _audioElement!.addEventListener('error', (html.Event event) {
        appLog('音声再生エラー: ${event.toString()}');
        _isPlaying = false;
      });

      // 再生可能状態になったら再生開始
      _audioElement!.addEventListener('canplay', (html.Event event) async {
        try {
          await _audioElement!.play();
          _isPlaying = true;
          appLog('音声再生開始');
        } catch (e) {
          appLog('音声再生開始エラー: $e');
          _isPlaying = false;
        }
      });

      // 音声データの読み込み開始
      _audioElement!.load();

      return true;
    } catch (e) {
      appLog('音声再生エラー: $e');
      _isPlaying = false;
      return false;
    }
  }

  // 再生停止
  static Future<void> stopPlaying() async {
    try {
      if (_audioElement != null) {
        _audioElement!.pause();
        _audioElement!.currentTime = 0;
        _isPlaying = false;
        appLog('音声再生停止');
      }
    } catch (e) {
      appLog('音声停止エラー: $e');
    }
  }

  // 録音中かどうか
  static bool get isRecording => _isRecording;

  // 再生中かどうか
  static bool get isPlaying => _isPlaying;

  // リソースの解放
  static void dispose() {
    try {
      _cleanupRecording();
      if (_audioElement != null) {
        _audioElement!.pause();
        _audioElement = null;
      }
      _isPlaying = false;
      appLog('WebAudioService リソース解放完了');
    } catch (e) {
      appLog('WebAudioService dispose エラー: $e');
    }
  }

  // 音声形式の取得
  static String getAudioFormat() {
    if (html.MediaRecorder.isTypeSupported('audio/webm')) {
      return 'webm';
    } else if (html.MediaRecorder.isTypeSupported('audio/wav')) {
      return 'wav';
    } else {
      return 'unknown';
    }
  }

  // ブラウザ情報の取得
  static String getBrowserInfo() {
    try {
      return html.window.navigator.userAgent;
    } catch (e) {
      return 'Unknown';
    }
  }
}
