import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';  // 一時的に無効化
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../models/memo.dart';
import '../models/map_info.dart';
import '../utils/database_helper.dart';
import '../utils/ai_service.dart';
import '../utils/audio_service.dart';

class AddMemoScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final int? mapId;

  const AddMemoScreen({
    Key? key,
    this.initialLatitude,
    this.initialLongitude,
    this.mapId,
  }) : super(key: key);

  @override
  _AddMemoScreenState createState() => _AddMemoScreenState();
}

class _AddMemoScreenState extends State<AddMemoScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _discovererController = TextEditingController();
  final TextEditingController _specimenNumberController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  double? _latitude;
  double? _longitude;
  bool _isLocationLoading = false;
  bool _isSaving = false;
  DateTime? _discoveryTime;
  String? _selectedCategory;
  int? _selectedMapId;
  List<MapInfo> _maps = [];

  // AI機能用の状態変数
  bool _isAnalyzing = false;
  File? _selectedImage;
  String? _audioPath;
  bool _isRecording = false;
  bool _isPlaying = false;

  final List<String> _categories = [
    '植物',
    '動物',
    '昆虫',
    '鉱物',
    '化石',
    '地形',
    'その他',
  ];

  @override
  void initState() {
    super.initState();
    _latitude = widget.initialLatitude;
    _longitude = widget.initialLongitude;
    _selectedMapId = widget.mapId; // 渡された地図IDを設定
    _discoveryTime = DateTime.now(); // デフォルトで現在時刻を設定
    _loadMaps();
  }

  Future<void> _loadMaps() async {
    try {
      final maps = await DatabaseHelper.instance.readAllMaps();
      setState(() {
        _maps = maps;
      });
    } catch (e) {
      // エラーは無視（地図が存在しない場合もある）
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocationLoading = true;
    });

    try {
      // 位置情報機能を一時的に無効化
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('位置情報機能は現在無効化されています')),
      );

      // デモ用の固定位置を設定
      setState(() {
        _latitude = 35.681236;
        _longitude = 139.767125;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('デモ位置を設定しました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('位置情報の取得に失敗しました: $e')),
      );
    } finally {
      setState(() {
        _isLocationLoading = false;
      });
    }
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _discoveryTime ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_discoveryTime ?? DateTime.now()),
      );

      if (time != null) {
        setState(() {
          _discoveryTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _saveMemo() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タイトルを入力してください')),
      );
      return;
    }

    // 保存確認ダイアログ
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('記録を保存'),
          content: const Text('この記録を保存しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 同じ地図の既存のメモを取得して次のピン番号を決定
      final existingMemos =
          await DatabaseHelper.instance.readMemosByMapId(_selectedMapId);
      int nextPinNumber = 1;
      if (existingMemos.isNotEmpty) {
        final maxPinNumber = existingMemos
            .where((memo) => memo.pinNumber != null)
            .map((memo) => memo.pinNumber!)
            .fold(0, (max, number) => number > max ? number : max);
        nextPinNumber = maxPinNumber + 1;
      }

      final memo = Memo(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        discoveryTime: _discoveryTime,
        discoverer: _discovererController.text.trim().isEmpty
            ? null
            : _discovererController.text.trim(),
        specimenNumber: _specimenNumberController.text.trim().isEmpty
            ? null
            : _specimenNumberController.text.trim(),
        category: _selectedCategory,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        pinNumber: nextPinNumber, // 自動的に次の番号を割り当て
        mapId: _selectedMapId, // 選択された地図ID
        audioPath: _audioPath, // 音声ファイルのパス
      );

      await DatabaseHelper.instance.create(memo);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('記録を保存しました（ピン番号: $nextPinNumber）'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存に失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '未設定';
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // 画像を選択して分析
  Future<void> _pickAndAnalyzeImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _isAnalyzing = true;
        });

        if (AIService.isConfigured) {
          try {
            final analysis = await AIService.analyzeImage(_selectedImage!);

            // 分析結果をフィールドに自動入力
            if (analysis['title'] != null && analysis['title']!.isNotEmpty) {
              _titleController.text = analysis['title']!;
            }
            if (analysis['content'] != null &&
                analysis['content']!.isNotEmpty) {
              _contentController.text = analysis['content']!;
            }
            if (analysis['category'] != null &&
                _categories.contains(analysis['category'])) {
              setState(() {
                _selectedCategory = analysis['category'];
              });
            }
            if (analysis['notes'] != null && analysis['notes']!.isNotEmpty) {
              _notesController.text = analysis['notes']!;
            }

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('AI分析が完了しました！フィールドが自動入力されました。'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (aiError) {
            // AI分析エラーの詳細な処理
            String errorMessage = '画像分析中にエラーが発生しました。';

            if (aiError.toString().contains('503') ||
                aiError.toString().contains('overloaded') ||
                aiError.toString().contains('unavailable')) {
              errorMessage = 'AIサーバーが一時的に混雑しています。\nしばらく時間をおいてから再試行してください。';
            } else if (aiError.toString().contains('429')) {
              errorMessage = 'AI機能の使用回数制限に達しました。\nしばらく時間をおいてから再試行してください。';
            } else if (aiError.toString().contains('401') ||
                aiError.toString().contains('403')) {
              errorMessage = 'AI機能の認証に失敗しました。\n設定画面でAPIキーを確認してください。';
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('AIサービスが設定されていません。\n設定画面でAPIキーを設定してください。'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('画像の選択に失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  // 音声録音の開始/停止
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // 録音停止
      final path = await AudioService.stopRecording();
      if (path != null) {
        setState(() {
          _audioPath = path;
          _isRecording = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('録音が完了しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // 録音開始
      final success = await AudioService.startRecording();
      if (success) {
        setState(() {
          _isRecording = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('録音を開始しました'),
            backgroundColor: Colors.blue,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('録音の開始に失敗しました'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 音声再生の開始/停止
  Future<void> _togglePlayback() async {
    if (_audioPath == null) return;

    if (_isPlaying) {
      await AudioService.stopPlaying();
      setState(() {
        _isPlaying = false;
      });
    } else {
      final success = await AudioService.playAudio(_audioPath!);
      if (success) {
        setState(() {
          _isPlaying = true;
        });

        // 再生完了を監視
        Future.delayed(const Duration(seconds: 1), () async {
          while (AudioService.isPlaying && mounted) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
          if (mounted) {
            setState(() {
              _isPlaying = false;
            });
          }
        });
      }
    }
  }

  // 音声削除
  Future<void> _deleteAudio() async {
    if (_audioPath != null) {
      await AudioService.deleteAudioFile(_audioPath!);
      setState(() {
        _audioPath = null;
        _isPlaying = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('音声メモを削除しました'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // AIアシスト機能
  Future<void> _showAIAssistant() async {
    if (!AIService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AIサービスが設定されていません。'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🤖 AI アシスタント'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.auto_fix_high, color: Colors.blue),
              title: const Text('内容を改善'),
              subtitle: const Text('現在の内容をより詳細に改善します'),
              onTap: () async {
                Navigator.pop(context);
                await _improveContent();
              },
            ),
            ListTile(
              leading: const Icon(Icons.help, color: Colors.green),
              title: const Text('質問する'),
              subtitle: const Text('フィールドワークについて質問できます'),
              onTap: () async {
                Navigator.pop(context);
                await _askQuestion();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  // 内容改善機能
  Future<void> _improveContent() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('改善する内容を入力してください'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final improved =
          await AIService.improveMemoContent(_contentController.text);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('改善提案'),
          content: SingleChildScrollView(
            child: Text(improved),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                _contentController.text = improved;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('内容を更新しました'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('適用'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('改善提案の生成に失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  // 質問機能
  Future<void> _askQuestion() async {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AIに質問'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'フィールドワークについて質問してください',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              final question = controller.text.trim();
              if (question.isNotEmpty) {
                Navigator.pop(context);

                setState(() {
                  _isAnalyzing = true;
                });

                try {
                  final memos = await DatabaseHelper.instance.readAllMemos();
                  final answer = await AIService.askQuestion(question, memos);

                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('質問: $question'),
                      content: SingleChildScrollView(
                        child: Text(answer),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('閉じる'),
                        ),
                      ],
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('回答の生成に失敗しました: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } finally {
                  setState(() {
                    _isAnalyzing = false;
                  });
                }
              }
            },
            child: const Text('質問'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: widget.initialLatitude != null && widget.initialLongitude != null
            ? const Text('選択地点の記録')
            : const Text('新しい記録'),
        actions: [
          IconButton(
            icon: _isAnalyzing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.smart_toy, color: Colors.blue),
            tooltip: 'AIアシスタント',
            onPressed: _isAnalyzing ? null : _showAIAssistant,
          ),
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            tooltip: '保存',
            onPressed: _isSaving ? null : _saveMemo,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 位置情報表示
            if (widget.initialLatitude != null &&
                widget.initialLongitude != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12.0),
                margin: const EdgeInsets.only(bottom: 16.0),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.blue.shade600),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Text(
                        'マップで選択した地点の記録を作成中\n緯度: ${widget.initialLatitude!.toStringAsFixed(6)}\n経度: ${widget.initialLongitude!.toStringAsFixed(6)}',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // 基本情報
            const Text('基本情報',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'タイトル *',
                border: OutlineInputBorder(),
                helperText: '必須項目',
              ),
            ),
            const SizedBox(height: 16),

            // カテゴリ選択
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'カテゴリ',
                border: OutlineInputBorder(),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // 発見時間
            InkWell(
              onTap: _selectDateTime,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '発見日時',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(_formatDateTime(_discoveryTime)),
              ),
            ),
            const SizedBox(height: 16),

            // 発見者
            TextField(
              controller: _discovererController,
              decoration: const InputDecoration(
                labelText: '発見者',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // 標本番号
            TextField(
              controller: _specimenNumberController,
              decoration: const InputDecoration(
                labelText: '標本番号',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // 地図選択
            if (_maps.isNotEmpty) ...[
              DropdownButtonFormField<int>(
                value: _selectedMapId,
                decoration: const InputDecoration(
                  labelText: '地図',
                  border: OutlineInputBorder(),
                  helperText: 'この記録を関連付ける地図を選択',
                ),
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('地図を選択しない'),
                  ),
                  ..._maps.map((map) {
                    return DropdownMenuItem<int>(
                      value: map.id,
                      child: Text(map.title),
                    );
                  }).toList(),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedMapId = value;
                  });
                },
              ),
            ],
            const SizedBox(height: 24),

            // 詳細情報
            const Text('詳細情報',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: '内容・説明',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              textAlignVertical: TextAlignVertical.top,
            ),
            const SizedBox(height: 16),

            // AI機能セクション
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.smart_toy, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'AI機能',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 画像分析ボタン
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isAnalyzing ? null : _pickAndAnalyzeImage,
                        icon: _isAnalyzing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.camera_alt),
                        label: Text(_isAnalyzing ? '分析中...' : '📸 写真を撮影してAI分析'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),

                    if (_selectedImage != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        height: 100,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // 音声録音セクション
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _toggleRecording,
                            icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                            label: Text(_isRecording ? '🎙️ 録音停止' : '🎙️ 音声録音'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _isRecording ? Colors.red : Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        if (_audioPath != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _togglePlayback,
                            icon: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow),
                            color: Colors.blue,
                            tooltip: _isPlaying ? '再生停止' : '再生',
                          ),
                          IconButton(
                            onPressed: _deleteAudio,
                            icon: const Icon(Icons.delete),
                            color: Colors.red,
                            tooltip: '削除',
                          ),
                        ],
                      ],
                    ),

                    if (_audioPath != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.audiotrack,
                                color: Colors.green.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '音声メモが録音されました',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_isRecording) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.fiber_manual_record,
                                color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Text(
                              '録音中...',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: '備考',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textAlignVertical: TextAlignVertical.top,
            ),
            const SizedBox(height: 24),

            // 位置情報
            const Text('位置情報',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '現在の位置情報',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ElevatedButton.icon(
                          onPressed:
                              _isLocationLoading ? null : _getCurrentLocation,
                          icon: _isLocationLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.location_on),
                          label: const Text('現在位置'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    if (_latitude != null && _longitude != null)
                      Text(
                        '保存される位置：\n緯度: ${_latitude!.toStringAsFixed(6)}\n経度: ${_longitude!.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 12),
                      )
                    else
                      const Text(
                        '位置情報が設定されていません',
                        style: TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 保存ボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveMemo,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: _isSaving
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('保存中...', style: TextStyle(fontSize: 16)),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save, size: 20),
                          SizedBox(width: 8),
                          Text('記録を保存', style: TextStyle(fontSize: 16)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // 保存内容の説明
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '保存される内容:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• タイトル: ${_titleController.text.trim().isEmpty ? "未入力" : _titleController.text.trim()}\n'
                    '• カテゴリ: ${_selectedCategory ?? "未選択"}\n'
                    '• 発見日時: ${_formatDateTime(_discoveryTime)}\n'
                    '• 発見者: ${_discovererController.text.trim().isEmpty ? "未入力" : _discovererController.text.trim()}\n'
                    '• 位置情報: ${_latitude != null && _longitude != null ? "設定済み" : "未設定"}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _discovererController.dispose();
    _specimenNumberController.dispose();
    _notesController.dispose();
    AudioService.dispose(); // AudioServiceのリソース解放
    super.dispose();
  }
}
