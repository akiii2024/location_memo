import 'package:flutter/material.dart';
import '../models/memo.dart';
import '../utils/database_helper.dart';
import 'memo_detail_screen.dart';
import 'map_screen.dart';
import '../models/map_info.dart';

class PinListScreen extends StatefulWidget {
  const PinListScreen({Key? key}) : super(key: key);

  @override
  _PinListScreenState createState() => _PinListScreenState();
}

class _PinListScreenState extends State<PinListScreen> {
  List<Memo> _memos = [];
  List<Memo> _filteredMemos = [];
  String? _selectedCategory;
  String? _selectedMap;
  List<MapInfo> _maps = [];

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
    _selectedCategory = 'すべて'; // デフォルトで「すべて」を選択
    _selectedMap = 'すべて'; // デフォルトで「すべて」を選択
    _loadData();
  }

  Future<void> _loadData() async {
    final memos = await DatabaseHelper.instance.readAllMemosWithMapTitle();
    final maps = await DatabaseHelper.instance.readAllMaps();
    setState(() {
      _memos = memos;
      _maps = maps;
      _applyFilter();
    });
  }

  void _applyFilter() {
    List<Memo> filtered = List.from(_memos);

    // カテゴリフィルタ
    if (_selectedCategory != null && _selectedCategory != 'すべて') {
      filtered =
          filtered.where((memo) => memo.category == _selectedCategory).toList();
    }

    // 地図フィルタ
    if (_selectedMap != null && _selectedMap != 'すべて') {
      filtered =
          filtered.where((memo) => memo.mapTitle == _selectedMap).toList();
    }

    // ピン番号順にソート
    filtered.sort((a, b) {
      if (a.pinNumber == null && b.pinNumber == null) return 0;
      if (a.pinNumber == null) return 1;
      if (b.pinNumber == null) return -1;
      return a.pinNumber!.compareTo(b.pinNumber!);
    });

    setState(() {
      _filteredMemos = filtered;
    });
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

  void _openMapWithPin(Memo memo) async {
    if (memo.mapId != null) {
      final mapInfo = _maps.firstWhere(
        (map) => map.id == memo.mapId,
        orElse: () => MapInfo(
            id: memo.mapId, title: memo.mapTitle ?? 'ピンの地図', imagePath: null),
      );
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MapScreen(mapInfo: mapInfo),
        ),
      );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ピン一覧'),
        actions: [
          Icon(Icons.push_pin, color: Colors.grey[600]),
        ],
      ),
      body: Column(
        children: [
          // フィルタ部分
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // カテゴリフィルタ
                Row(
                  children: [
                    const Icon(Icons.category, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        hint: const Text('カテゴリで絞り込み'),
                        isExpanded: true,
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
                  ],
                ),
                const SizedBox(height: 8),
                // 地図フィルタ
                Row(
                  children: [
                    const Icon(Icons.map, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedMap,
                        hint: const Text('地図で絞り込み'),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                            value: 'すべて',
                            child: Text('すべて'),
                          ),
                          ..._maps.map((map) {
                            return DropdownMenuItem(
                              value: map.title,
                              child: Text(map.title),
                            );
                          }).toList(),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedMap = value;
                            _applyFilter();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 統計情報
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            color: Colors.grey[100],
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '${_filteredMemos.length}個のピンが見つかりました',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          // ピンリスト
          Expanded(
            child: _filteredMemos.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.push_pin, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'ピンが見つかりません',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '地図上にピンを追加してください',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _filteredMemos.length,
                    itemBuilder: (context, index) {
                      final memo = _filteredMemos[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getCategoryColor(memo.category),
                            child: Text(
                              memo.pinNumber?.toString() ?? '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
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
                                Row(
                                  children: [
                                    Icon(
                                      _getCategoryIcon(memo.category),
                                      size: 16,
                                      color: _getCategoryColor(memo.category),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(memo.category!),
                                  ],
                                ),
                              if (memo.mapTitle != null)
                                Row(
                                  children: [
                                    const Icon(Icons.map,
                                        size: 16, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(memo.mapTitle!),
                                  ],
                                ),
                              if (memo.discoveryTime != null)
                                Row(
                                  children: [
                                    const Icon(Icons.access_time,
                                        size: 16, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(_formatDateTime(memo.discoveryTime)),
                                  ],
                                ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              switch (value) {
                                case 'detail':
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          MemoDetailScreen(memo: memo),
                                    ),
                                  ).then((_) => _loadData());
                                  break;
                                case 'map':
                                  _openMapWithPin(memo);
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'detail',
                                child: Row(
                                  children: [
                                    Icon(Icons.info),
                                    SizedBox(width: 8),
                                    Text('詳細を見る'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'map',
                                child: Row(
                                  children: [
                                    Icon(Icons.map),
                                    SizedBox(width: 8),
                                    Text('地図で表示'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    MemoDetailScreen(memo: memo),
                              ),
                            );
                            _loadData();
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
