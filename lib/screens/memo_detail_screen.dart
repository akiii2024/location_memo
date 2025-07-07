import 'package:flutter/material.dart';
import '../models/memo.dart';
import '../utils/database_helper.dart';

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
    _titleController = TextEditingController(text: widget.memo.title);
    _contentController = TextEditingController(text: widget.memo.content);
    _discovererController = TextEditingController(text: widget.memo.discoverer ?? '');
    _specimenNumberController = TextEditingController(text: widget.memo.specimenNumber ?? '');
    _notesController = TextEditingController(text: widget.memo.notes ?? '');
    _discoveryTime = widget.memo.discoveryTime;
    _selectedCategory = widget.memo.category;
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
                  const Text('タイトル', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
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
                  const Text('基本情報', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  
                  if (widget.memo.category != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.category, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text('カテゴリ: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(widget.memo.category!),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  if (widget.memo.discoveryTime != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text('発見日時: ', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        const Text('発見者: ', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        const Text('標本番号: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(widget.memo.specimenNumber!),
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
                    const Text('内容・説明', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
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
                    const Text('備考', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(widget.memo.notes!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 位置情報
          if (widget.memo.latitude != null && widget.memo.longitude != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('位置情報', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('緯度: ${widget.memo.latitude!.toStringAsFixed(6)}\n経度: ${widget.memo.longitude!.toStringAsFixed(6)}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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
          const Text('基本情報', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
          const SizedBox(height: 24),

          // 詳細情報
          const Text('詳細情報', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

          // 位置情報（読み取り専用）
          if (widget.memo.latitude != null && widget.memo.longitude != null) ...[
            const Text('位置情報', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('位置情報（読み取り専用）', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text('緯度: ${widget.memo.latitude!.toStringAsFixed(6)}\n経度: ${widget.memo.longitude!.toStringAsFixed(6)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

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
                  latitude: widget.memo.latitude,
                  longitude: widget.memo.longitude,
                  discoveryTime: _discoveryTime,
                  discoverer: _discovererController.text.trim().isEmpty ? null : _discovererController.text.trim(),
                  specimenNumber: _specimenNumberController.text.trim().isEmpty ? null : _specimenNumberController.text.trim(),
                  category: _selectedCategory,
                  notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
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
                  _specimenNumberController.text = widget.memo.specimenNumber ?? '';
                  _notesController.text = widget.memo.notes ?? '';
                  _discoveryTime = widget.memo.discoveryTime;
                  _selectedCategory = widget.memo.category;
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
                    content: const Text('この記録を削除しますか？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('キャンセル'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('削除'),
                      ),
                    ],
                  ),
                );

                if (shouldDelete == true) {
                  await DatabaseHelper.instance.delete(widget.memo.id!);
                  Navigator.pop(context, true);
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
