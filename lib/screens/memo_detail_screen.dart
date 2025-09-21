import 'package:flutter/material.dart';
import '../models/memo.dart';
import '../models/map_info.dart';
import '../utils/database_helper.dart';
import '../utils/collaboration_sync_coordinator.dart';
import '../utils/image_helper.dart';
import 'location_picker_screen.dart';
import 'dart:io';

class MemoDetailScreen extends StatefulWidget {
  final Memo memo;

  const MemoDetailScreen({Key? key, required this.memo}) : super(key: key);

  @override
  _MemoDetailScreenState createState() => _MemoDetailScreenState();
}

class _MemoDetailScreenState extends State<MemoDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _discovererController;
  late TextEditingController _specimenNumberController;
  late TextEditingController _notesController;

  bool _isEditing = false;
  DateTime? _discoveryTime;
  String? _selectedCategory;
  double? _editingLatitude;
  double? _editingLongitude;
  bool _isLocationLoading = false;

  final List<String> _categories = [
    'カテゴリを選択してください',
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
    _titleController = TextEditingController(text: widget.memo.title);
    _contentController = TextEditingController(text: widget.memo.content);
    _discovererController =
        TextEditingController(text: widget.memo.discoverer ?? '');
    _specimenNumberController =
        TextEditingController(text: widget.memo.specimenNumber ?? '');
    _notesController = TextEditingController(text: widget.memo.notes ?? '');
    _discoveryTime = widget.memo.discoveryTime;
    // カテゴリがnullの場合や、リストに含まれていない場合はデフォルト値を設定
    // 必ず_categoriesに含まれる値を設定する
    if (widget.memo.category != null &&
        _categories.contains(widget.memo.category)) {
      _selectedCategory = widget.memo.category;
    } else {
      _selectedCategory = _categories[0]; // 'カテゴリを選択してください'
    }
    // 編集用位置情報を初期化
    _editingLatitude = widget.memo.latitude;
    _editingLongitude = widget.memo.longitude;
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

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '未設定';
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectLocation() async {
    setState(() {
      _isLocationLoading = true;
    });

    try {
      // 利用可能な地図を取得
      final maps = await DatabaseHelper.instance.readAllMaps();
      MapInfo? selectedMap;

      // 現在のメモの地図IDまたはデフォルトの地図を選択
      if (widget.memo.mapId != null && maps.isNotEmpty) {
        selectedMap = maps.firstWhere(
          (map) => map.id == widget.memo.mapId,
          orElse: () => maps.first,
        );
      } else if (maps.isNotEmpty) {
        selectedMap = maps.first;
      }

      final result = await Navigator.push<Map<String, double>>(
        context,
        MaterialPageRoute(
          builder: (context) => LocationPickerScreen(
            initialLatitude: _editingLatitude,
            initialLongitude: _editingLongitude,
            mapInfo: selectedMap,
          ),
        ),
      );

      if (result != null) {
        setState(() {
          _editingLatitude = result['latitude'];
          _editingLongitude = result['longitude'];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '位置を更新しました\n緯度: ${_editingLatitude!.toStringAsFixed(6)}\n経度: ${_editingLongitude!.toStringAsFixed(6)}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('位置選択中にエラーが発生しました: $e')),
      );
    } finally {
      setState(() {
        _isLocationLoading = false;
      });
    }
  }

  // ピン番号編集ダイアログを表示
  void _showPinNumberDialog() {
    final TextEditingController controller = TextEditingController(
      text: widget.memo.pinNumber?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ピン番号を編集'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('「${widget.memo.title}」のピン番号を設定してください'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ピン番号',
                  hintText: '1, 2, 3...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () async {
                final newNumber = int.tryParse(controller.text);
                if (newNumber != null && newNumber > 0) {
                  // メモを更新
                  final updatedMemo = Memo(
                    id: widget.memo.id,
                    title: widget.memo.title,
                    content: widget.memo.content,
                    latitude: widget.memo.latitude,
                    longitude: widget.memo.longitude,
                    discoveryTime: widget.memo.discoveryTime,
                    discoverer: widget.memo.discoverer,
                    specimenNumber: widget.memo.specimenNumber,
                    category: widget.memo.category,
                    notes: widget.memo.notes,
                    pinNumber: newNumber,
                  );

                  await DatabaseHelper.instance.update(updatedMemo);
                  try {
                    await CollaborationSyncCoordinator.instance
                        .onLocalMemoUpdated(updatedMemo);
                  } catch (error, stackTrace) {
                    debugPrint('Failed to sync memo update: $error');
                    debugPrintStack(stackTrace: stackTrace);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('共同編集への同期に失敗しました: $error'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }

                  // 画面を更新
                  setState(() {
                    widget.memo.pinNumber = newNumber;
                  });

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('ピン番号を $newNumber に更新しました')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('有効な番号を入力してください')),
                  );
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildViewMode() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // タイトル
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('タイトル',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(widget.memo.title, style: const TextStyle(fontSize: 18)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 基本情報
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('基本情報',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (widget.memo.category != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.category,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text('カテゴリ: ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(widget.memo.category!),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (widget.memo.discoveryTime != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.schedule,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text('発見日時: ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_formatDateTime(widget.memo.discoveryTime)),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (widget.memo.discoverer != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text('発見者: ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(widget.memo.discoverer!),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (widget.memo.specimenNumber != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.numbers, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text('標本番号: ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(widget.memo.specimenNumber!),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (widget.memo.pinNumber != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.push_pin,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text('ピン番号: ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${widget.memo.pinNumber}'),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _showPinNumberDialog,
                          child: const Icon(Icons.edit,
                              size: 16, color: Colors.blue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (widget.memo.mapTitle != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.map, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text('地図: ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(widget.memo.mapTitle!,
                            style: const TextStyle(color: Colors.blue)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 内容
          if (widget.memo.content.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('内容・説明',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(widget.memo.content),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 備考
          if (widget.memo.notes != null && widget.memo.notes!.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('備考',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(widget.memo.notes!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 添付画像
          if (widget.memo.imagePaths != null &&
              widget.memo.imagePaths!.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.photo_library,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          '添付画像 (${widget.memo.imagePaths!.length}枚)',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.memo.imagePaths!.length,
                        itemBuilder: (context, index) {
                          final imagePath = widget.memo.imagePaths![index];
                          return Container(
                            width: 120,
                            margin: const EdgeInsets.only(right: 8),
                            child: Stack(
                              children: [
                                // 画像
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: GestureDetector(
                                      onTap: () {
                                        // 画像をフルスクリーンで表示
                                        showDialog(
                                          context: context,
                                          builder: (context) => Dialog(
                                            backgroundColor: Colors.black,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                AppBar(
                                                  backgroundColor: Colors.black,
                                                  foregroundColor: Colors.white,
                                                  title:
                                                      Text('画像 ${index + 1}'),
                                                ),
                                                Expanded(
                                                  child: Center(
                                                    child: ImageHelper
                                                        .buildImageWidget(
                                                      imagePath,
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                      child: ImageHelper.buildImageWidget(
                                        imagePath,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                                // 画像番号
                                Positioned(
                                  bottom: 4,
                                  left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 位置情報
          if (widget.memo.latitude != null &&
              widget.memo.longitude != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('位置情報',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                            '緯度: ${widget.memo.latitude!.toStringAsFixed(6)}\n経度: ${widget.memo.longitude!.toStringAsFixed(6)}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildEditMode() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 基本情報
          const Text('基本情報',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'タイトル *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // カテゴリ選択
          DropdownButtonFormField<String>(
            value: _selectedCategory ?? _categories[0],
            decoration: const InputDecoration(
              labelText: 'カテゴリ',
              border: OutlineInputBorder(),
            ),
            items: () {
              // デバッグ用：valueとitemsの値をコンソールに出力
              print('=== DropdownButton Debug Info ===');
              print('Selected value: ${_selectedCategory ?? _categories[0]}');
              print('Available categories:');
              for (int i = 0; i < _categories.length; i++) {
                print('  [$i]: ${_categories[i]}');
              }
              print('===============================');

              return _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList();
            }(),
            onChanged: (value) {
              setState(() {
                if (value != null) {
                  _selectedCategory = value;
                }
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

          // 添付画像（読み取り専用）
          if (widget.memo.imagePaths != null &&
              widget.memo.imagePaths!.isNotEmpty) ...[
            const Text('添付画像',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              color: Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.photo_library, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          '添付画像 (${widget.memo.imagePaths!.length}枚)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '注意: 画像の編集機能は現在利用できません',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.memo.imagePaths!.length,
                        itemBuilder: (context, index) {
                          final imagePath = widget.memo.imagePaths![index];
                          return Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 8),
                            child: Stack(
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: ImageHelper.buildImageWidget(
                                      imagePath,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 4,
                                  left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // 位置情報
          const Text('位置情報',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '位置情報',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isLocationLoading ? null : _selectLocation,
                        icon: _isLocationLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.map),
                        label: const Text('位置編集'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_editingLatitude != null && _editingLongitude != null)
                    Text(
                      '設定された位置：\n緯度: ${_editingLatitude!.toStringAsFixed(6)}\n経度: ${_editingLongitude!.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 12),
                    )
                  else
                    const Text(
                      '位置情報が設定されていません\n「位置編集」ボタンから地図で位置を選択してください',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
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
              onPressed: () async {
                if (_titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('タイトルを入力してください')),
                  );
                  return;
                }

                final updatedMemo = Memo(
                  id: widget.memo.id,
                  title: _titleController.text.trim(),
                  content: _contentController.text.trim(),
                  latitude: _editingLatitude,
                  longitude: _editingLongitude,
                  discoveryTime: _discoveryTime,
                  discoverer: _discovererController.text.trim().isEmpty
                      ? null
                      : _discovererController.text.trim(),
                  specimenNumber: _specimenNumberController.text.trim().isEmpty
                      ? null
                      : _specimenNumberController.text.trim(),
                  category: _selectedCategory == 'カテゴリを選択してください'
                      ? null
                      : _selectedCategory,
                  notes: _notesController.text.trim().isEmpty
                      ? null
                      : _notesController.text.trim(),
                  pinNumber: widget.memo.pinNumber, // ピン番号を保持
                  mapId: widget.memo.mapId, // 地図IDを保持
                  audioPath: widget.memo.audioPath, // 音声パスを保持
                  imagePaths: widget.memo.imagePaths, // 画像パスを保持
                );

                await DatabaseHelper.instance.update(updatedMemo);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('記録を更新しました')),
                );
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
              ),
              child: const Text('保存', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '記録の編集' : '記録の詳細'),
        actions: [
          if (_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  // 元の値に戻す
                  _titleController.text = widget.memo.title;
                  _contentController.text = widget.memo.content;
                  _discovererController.text = widget.memo.discoverer ?? '';
                  _specimenNumberController.text =
                      widget.memo.specimenNumber ?? '';
                  _notesController.text = widget.memo.notes ?? '';
                  _discoveryTime = widget.memo.discoveryTime;
                  // カテゴリの値を安全に設定
                  if (widget.memo.category != null &&
                      _categories.contains(widget.memo.category)) {
                    _selectedCategory = widget.memo.category;
                  } else {
                    _selectedCategory = _categories[0];
                  }
                  // 編集用位置情報もリセット
                  _editingLatitude = widget.memo.latitude;
                  _editingLongitude = widget.memo.longitude;
                });
              },
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final shouldDelete = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('削除確認'),
                    content: const Text('この記録を削除しますか？\n関連する画像や音声ファイルも削除されます。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('キャンセル'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('削除'),
                      ),
                    ],
                  ),
                );

                if (shouldDelete == true) {
                  try {
                    // 画像ファイルを削除
                    if (widget.memo.imagePaths != null &&
                        widget.memo.imagePaths!.isNotEmpty) {
                      for (final imagePath in widget.memo.imagePaths!) {
                        final imageFile = File(imagePath);
                        if (await imageFile.exists()) {
                          await imageFile.delete();
                        }
                      }
                    }

                    // 音声ファイルを削除
                    if (widget.memo.audioPath != null &&
                        widget.memo.audioPath!.isNotEmpty) {
                      final audioFile = File(widget.memo.audioPath!);
                      if (await audioFile.exists()) {
                        await audioFile.delete();
                      }
                    }

                    // データベースから削除
                    await DatabaseHelper.instance.delete(widget.memo.id!);
                    try {
                      await CollaborationSyncCoordinator.instance
                          .onLocalMemoDeleted(widget.memo);
                    } catch (error, stackTrace) {
                      debugPrint('Failed to sync memo deletion: $error');
                      debugPrintStack(stackTrace: stackTrace);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('共同編集からの削除同期に失敗しました: $error'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }

                    // 成功メッセージを表示
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('記録を削除しました'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }

                    // 画面を閉じて、削除が成功したことを通知
                    Navigator.pop(context, true);
                  } catch (e) {
                    // エラーメッセージを表示
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('削除に失敗しました: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
            ),
          ],
        ],
      ),
      body: _isEditing ? _buildEditMode() : _buildViewMode(),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _discovererController.dispose();
    _specimenNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
