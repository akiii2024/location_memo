import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/memo.dart';
import '../utils/database_helper.dart';
import '../utils/print_helper.dart';
import '../widgets/custom_map_widget.dart';
import 'memo_detail_screen.dart';
import 'memo_list_screen.dart';
import 'add_memo_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Memo> _memos = [];
  final MapController _mapController = MapController();
  LatLng _currentCenter = const LatLng(35.681236, 139.767125);
  bool _useCustomMap = false;
  String? _customMapPath;

  @override
  void initState() {
    super.initState();
    _loadMemos();
    _loadCustomMapPath();
  }

  Future<void> _loadCustomMapPath() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final mapFile = File('${directory.path}/custom_map.png');
      if (await mapFile.exists()) {
        setState(() {
          _customMapPath = mapFile.path;
        });
      }
    } catch (e) {
      print('地図ファイルの読み込み中にエラーが発生しました: $e');
    }
  }

  Future<void> _loadMemos() async {
    final memos = await DatabaseHelper.instance.readAllMemos();
    setState(() {
      _memos = memos;
    });
  }

  void _onMapTap(double x, double y) async {
    // カスタム地図の場合、相対座標を緯度経度として使用
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMemoScreen(
          initialLatitude: x,
          initialLongitude: y,
        ),
      ),
    );
    if (result == true) {
      _loadMemos();
    }
  }

  void _onMemoTap(Memo memo) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MemoDetailScreen(memo: memo),
      ),
    );
    if (result == true) {
      _loadMemos();
    }
  }

  Widget _buildOpenStreetMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        center: _currentCenter,
        zoom: 13.0,
        onTap: (tapPosition, point) async {
          // タップした地点の座標で新規メモ作成画面に遷移
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddMemoScreen(
                initialLatitude: point.latitude,
                initialLongitude: point.longitude,
              ),
            ),
          );
          if (result == true) {
            _loadMemos();
          }
        },
        onLongPress: (tapPosition, point) async {
          // 長押しでも同様の機能を提供（触覚フィードバック付き）
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('選択地点: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}'),
              duration: const Duration(seconds: 1),
            ),
          );
          
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddMemoScreen(
                initialLatitude: point.latitude,
                initialLongitude: point.longitude,
              ),
            ),
          );
          if (result == true) {
            _loadMemos();
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
        ),
        MarkerLayer(
          markers: _memos
              .where((memo) => memo.latitude != null && memo.longitude != null)
              .map((memo) => Marker(
                    point: LatLng(memo.latitude!, memo.longitude!),
                    width: 80.0,
                    height: 80.0,
                    child: GestureDetector(
                      onTap: () => _onMemoTap(memo),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _getCategoryColor(memo.category),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          _getCategoryIcon(memo.category),
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
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
        title: const Text('フィールドワーク記録'),
        actions: [
                     // 印刷ボタン
           PopupMenuButton<String>(
             icon: const Icon(Icons.print),
             tooltip: '印刷',
             onSelected: (value) async {
               try {
                 switch (value) {
                   case 'print_map':
                     await PrintHelper.printMapWithMemos(_memos, _useCustomMap ? _customMapPath : null);
                     break;
                   case 'print_list':
                     await PrintHelper.printMemoList(_memos);
                     break;
                   case 'save_pdf':
                     await PrintHelper.savePdfReport(_memos, mapImagePath: _useCustomMap ? _customMapPath : null);
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('PDFファイルを保存しました')),
                     );
                     break;
                 }
               } catch (e) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text('印刷に失敗しました: $e')),
                 );
               }
             },
             itemBuilder: (context) => [
               const PopupMenuItem(
                 value: 'print_map',
                 child: Row(
                   children: [
                     Icon(Icons.map),
                     SizedBox(width: 8),
                     Text('地図と記録を印刷'),
                   ],
                 ),
               ),
               const PopupMenuItem(
                 value: 'print_list',
                 child: Row(
                   children: [
                     Icon(Icons.list),
                     SizedBox(width: 8),
                     Text('記録一覧を印刷'),
                   ],
                 ),
               ),
               const PopupMenuItem(
                 value: 'save_pdf',
                 child: Row(
                   children: [
                     Icon(Icons.save),
                     SizedBox(width: 8),
                     Text('PDFで保存'),
                   ],
                 ),
               ),
             ],
           ),
           // 地図切り替えボタン
           IconButton(
             icon: Icon(_useCustomMap ? Icons.public : Icons.map),
             tooltip: _useCustomMap ? 'OpenStreetMapに切り替え' : 'カスタム地図に切り替え',
             onPressed: () {
               setState(() {
                 _useCustomMap = !_useCustomMap;
               });
             },
           ),
          IconButton(
            icon: const Icon(Icons.format_list_bulleted),
            tooltip: '記録一覧',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MemoListScreen()),
              );
              _loadMemos();
            },
          ),
        ],
      ),
      body: _useCustomMap
          ? CustomMapWidget(
              memos: _memos,
              onTap: _onMapTap,
              onMemoTap: _onMemoTap,
            )
          : _buildOpenStreetMap(),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (!_useCustomMap) ...[
            FloatingActionButton(
              heroTag: "current_location",
              mini: true,
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddMemoScreen(
                      initialLatitude: _currentCenter.latitude,
                      initialLongitude: _currentCenter.longitude,
                    ),
                  ),
                );
                if (result == true) {
                  _loadMemos();
                }
              },
              child: const Icon(Icons.my_location),
              tooltip: '現在の中心点で記録を追加',
            ),
            const SizedBox(height: 8),
          ],
          FloatingActionButton(
            heroTag: "add_memo",
            onPressed: () async {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('操作方法'),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '📍 記録の作成',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(_useCustomMap
                            ? '• カスタム地図をタップ → その地点で記録作成'
                            : '• マップをタップ → その地点で記録作成'),
                        if (!_useCustomMap) ...[
                          const Text('• マップを長押し → 座標確認後記録作成'),
                          const Text('• 📌ボタン → 現在の中心点で記録作成'),
                        ],
                        const SizedBox(height: 16),
                        const Text(
                          '🗺️ 記録の確認',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text('• カラーマーカーをタップ → 記録詳細表示'),
                        const Text('• 📄ボタン → 記録リスト表示'),
                        const SizedBox(height: 16),
                        const Text(
                          '🗺️ 地図について',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text('• 🌐ボタン → OpenStreetMapとカスタム地図を切り替え'),
                        const Text('• カスタム地図 → フィールドワーク用の画像/PDFを使用'),
                        const SizedBox(height: 16),
                        const Text(
                          '🎨 カテゴリ色分け',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          const Text('植物  '),
                          Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.brown, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          const Text('動物  '),
                          Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          const Text('昆虫'),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          const Text('鉱物  '),
                          Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.purple, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          const Text('化石  '),
                          Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          const Text('地形'),
                        ]),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('閉じる'),
                    ),
                  ],
                ),
              );
            },
            child: const Icon(Icons.help),
          ),
        ],
      ),
    );
  }
}