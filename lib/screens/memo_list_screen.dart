import 'package:flutter/material.dart';
import '../models/memo.dart';
import '../utils/database_helper.dart';
import '../utils/print_helper.dart';
import 'memo_detail_screen.dart';
import 'add_memo_screen.dart';

class MemoListScreen extends StatefulWidget {
  final List<Memo>? memos; // オプショナルなメモリストを追加
  final String? mapTitle; // オプショナルなマップタイトルを追加

  const MemoListScreen({Key? key, this.memos, this.mapTitle}) : super(key: key);

  @override
  _MemoListScreenState createState() => _MemoListScreenState();
}

class _MemoListScreenState extends State<MemoListScreen> {
  List<Memo> _memos = [];
  List<Memo> _filteredMemos = [];
  String? _selectedCategory;

  final List<String> _categories = [
    'すべて',
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
    _loadMemos();
  }

  Future<void> _loadMemos() async {
    List<Memo> memos;

    if (widget.memos != null) {
      // メモリストが渡された場合はそれを使用
      memos = widget.memos!;
    } else {
      // メモリストが渡されなかった場合は全てのメモを読み込み
      memos = await DatabaseHelper.instance.readAllMemosWithMapTitle();
    }

    setState(() {
      _memos = memos;
      _applyFilter();
    });
  }

  void _applyFilter() {
    if (_selectedCategory == null || _selectedCategory == 'すべて') {
      _filteredMemos = List.from(_memos);
    } else {
      _filteredMemos =
          _memos.where((memo) => memo.category == _selectedCategory).toList();
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _getCategoryColor(String? category) {
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

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case '植物':
        return Icons.local_florist;
      case '動物':
        return Icons.pets;
      case '昆虫':
        return Icons.bug_report;
      case '鉱物':
        return Icons.diamond;
      case '化石':
        return Icons.history;
      case '地形':
        return Icons.terrain;
      default:
        return Icons.sticky_note_2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.mapTitle != null ? '${widget.mapTitle}の記録一覧' : '記録一覧'),
        actions: [
          // 印刷ボタン
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: '印刷',
            onPressed: () async {
              try {
                await PrintHelper.printMemoList(_filteredMemos);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('印刷に失敗しました: $e')),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // カテゴリフィルター
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.grey[100],
            child: Row(
              children: [
                const Text('カテゴリ: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedCategory ?? 'すべて',
                    isExpanded: true,
                    underline: Container(),
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                        _applyFilter();
                      });
                    },
                  ),
                ),
                Text('${_filteredMemos.length}件',
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),

          // メモリスト
          Expanded(
            child: _filteredMemos.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.note_alt_outlined,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('記録がありません', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredMemos.length,
                    itemBuilder: (context, index) {
                      final memo = _filteredMemos[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 4.0),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _getCategoryColor(memo.category),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getCategoryIcon(memo.category),
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            memo.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (memo.category != null)
                                Text(
                                  memo.category!,
                                  style: TextStyle(
                                    color: _getCategoryColor(memo.category),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              if (memo.mapTitle != null)
                                Text(
                                  '地図: ${memo.mapTitle}',
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              if (memo.discoveryTime != null)
                                Text(
                                  _formatDateTime(memo.discoveryTime),
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              if (memo.content.isNotEmpty)
                                Text(
                                  memo.content.length > 50
                                      ? '${memo.content.substring(0, 50)}...'
                                      : memo.content,
                                  style: const TextStyle(fontSize: 12),
                                ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (memo.specimenNumber != null) ...[
                                const Icon(Icons.numbers,
                                    size: 16, color: Colors.grey),
                                Text(
                                  memo.specimenNumber!,
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.grey),
                                ),
                              ] else ...[
                                const Icon(Icons.chevron_right),
                              ],
                            ],
                          ),
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    MemoDetailScreen(memo: memo),
                              ),
                            );
                            if (result == true) {
                              _loadMemos();
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddMemoScreen(),
            ),
          );
          if (result == true) {
            _loadMemos();
          }
        },
        child: const Icon(Icons.add),
        tooltip: '新しい記録を追加',
      ),
    );
  }
}
