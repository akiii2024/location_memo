import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import '../models/memo.dart';
import '../models/map_info.dart';
import '../utils/database_helper.dart';
import '../utils/print_helper.dart';
import '../widgets/custom_map_widget.dart';
import 'memo_detail_screen.dart';
import 'memo_list_screen.dart';
import 'add_memo_screen.dart';

class MapScreen extends StatefulWidget {
  final MapInfo? mapInfo;

  const MapScreen({Key? key, this.mapInfo}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Memo> _memos = [];
  String? _customMapPath;
  int _currentLayer = 0; // 現在選択されているレイヤー
  List<int> _layers = [0]; // 利用可能なレイヤー一覧
  final GlobalKey<CustomMapWidgetState> _mapWidgetKey =
      GlobalKey<CustomMapWidgetState>();
  Box? _layerNameBox; // レイヤー名ボックス

  String _layerDisplayName(int layer) {
    if (_layerNameBox == null) {
      return 'レイヤー${layer + 1}';
    }
    final key = _layerKey(layer);
    final saved = _layerNameBox!.get(key);
    return saved ?? 'レイヤー${layer + 1}';
  }

  String _layerKey(int layer) {
    final mapIdPart =
        widget.mapInfo?.id?.toString() ?? (_customMapPath ?? 'custom');
    return '${mapIdPart}_$layer';
  }

  Future<void> _renameCurrentLayer() async {
    final controller =
        TextEditingController(text: _layerDisplayName(_currentLayer));
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('レイヤー名を変更'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '新しいレイヤー名'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      if (_layerNameBox != null) {
        await _layerNameBox!.put(_layerKey(_currentLayer), newName);
      }
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMemos();
    _loadCustomMapPath();

    // レイヤー名保存用のBoxを初期化
    Hive.openBox('layer_names').then((box) {
      setState(() {
        _layerNameBox = box;
      });
    });

    // MapInfoに画像パスがある場合はカスタム地図を使用
    if (widget.mapInfo?.imagePath != null) {
      _customMapPath = widget.mapInfo!.imagePath;
    }
  }

  Future<void> _loadCustomMapPath() async {
    try {
      if (kIsWeb) {
        // Web版: Hiveから画像データを読み込み
        final box = await Hive.openBox('app_settings');
        final savedMapData = box.get('custom_map_image');
        if (savedMapData != null) {
          setState(() {
            _customMapPath = savedMapData; // Base64文字列
          });
        }
      } else {
        // モバイル版: ファイルシステムから読み込み
        final directory = await getApplicationDocumentsDirectory();
        final mapFile = File('${directory.path}/custom_map.png');
        if (await mapFile.exists()) {
          setState(() {
            _customMapPath = mapFile.path;
          });
        }
      }
    } catch (e) {
      print('地図ファイルの読み込み中にエラーが発生しました: $e');
    }
  }

  Future<void> _loadMemos() async {
    List<Memo> memos;

    if (widget.mapInfo != null) {
      // MapInfoがある場合は、そのIDでメモを読み込む
      memos =
          await DatabaseHelper.instance.readMemosByMapId(widget.mapInfo!.id);
    } else {
      // MapInfoがない場合は、地図画像パスでメモを読み込む
      memos = await DatabaseHelper.instance.readMemosByMapPath(_customMapPath);
    }

    // レイヤー一覧を更新
    final layerSet = memos.map((m) => m.layer ?? 0).toSet();
    if (!layerSet.contains(0)) layerSet.add(0);

    setState(() {
      _memos = memos;
      _layers = layerSet.toList()..sort();
      if (!_layers.contains(_currentLayer)) {
        _currentLayer = _layers.first;
      }
    });
  }

  void _onMapTap(double x, double y) async {
    // 現在の地図IDを取得
    int? currentMapId;
    if (widget.mapInfo != null) {
      currentMapId = widget.mapInfo!.id;
    } else {
      // MapInfoがない場合は、地図画像パスから地図IDを取得または作成
      currentMapId = await DatabaseHelper.instance.getOrCreateMapId(
        _customMapPath,
        'カスタム地図',
      );
    }

    // カスタム地図の場合、相対座標を緯度経度として使用
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMemoScreen(
          initialLatitude: x,
          initialLongitude: y,
          mapId: currentMapId,
          layer: _currentLayer,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.mapInfo?.title ?? 'フィールドワーク記録'),
            Text(_layerDisplayName(_currentLayer),
                style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'レイヤー名を変更',
            onPressed: _renameCurrentLayer,
          ),
          // レイヤー選択ボタン
          PopupMenuButton<int>(
            icon: const Icon(Icons.layers),
            tooltip: 'レイヤー選択',
            onSelected: (value) {
              if (value == -1) {
                // 新しいレイヤーを追加
                final newLayer = (_layers.isNotEmpty ? _layers.last + 1 : 1);
                setState(() {
                  _layers.add(newLayer);
                  _currentLayer = newLayer;
                });
              } else {
                setState(() {
                  _currentLayer = value;
                });
              }
            },
            itemBuilder: (context) => [
              ..._layers.map(
                (layer) => PopupMenuItem<int>(
                  value: layer,
                  child: Text(_layerDisplayName(layer)),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<int>(
                value: -1,
                child: Row(
                  children: [
                    Icon(Icons.add),
                    SizedBox(width: 8),
                    Text('レイヤーを追加'),
                  ],
                ),
              ),
            ],
          ),
          // 印刷ボタン
          PopupMenuButton<String>(
            icon: const Icon(Icons.print),
            tooltip: '印刷',
            onSelected: (value) async {
              try {
                switch (value) {
                  case 'print_map':
                    await PrintHelper.printMapImage(
                      _customMapPath,
                      mapName: widget.mapInfo?.title ?? 'カスタム地図',
                    );
                    break;
                  case 'print_map_with_pins':
                    final mapState = _mapWidgetKey.currentState;
                    if (mapState != null) {
                      await PrintHelper.printMapWithPins(
                        mapState.mapImagePath,
                        _memos
                            .where((m) => (m.layer ?? 0) == _currentLayer)
                            .toList(),
                        mapState.actualDisplayWidth,
                        mapState.actualDisplayHeight,
                        mapName: widget.mapInfo?.title ?? 'カスタム地図',
                      );
                    } else {
                      // フォールバック: デフォルトサイズを使用
                      await PrintHelper.printMapWithPins(
                        _customMapPath,
                        _memos
                            .where((m) => (m.layer ?? 0) == _currentLayer)
                            .toList(),
                        800.0,
                        600.0,
                        mapName: widget.mapInfo?.title ?? 'カスタム地図',
                      );
                    }
                    break;
                  case 'print_list':
                    await PrintHelper.printMemoReport(
                      _memos
                          .where((m) => (m.layer ?? 0) == _currentLayer)
                          .toList(),
                      mapName: widget.mapInfo?.title ?? 'カスタム地図',
                    );
                    break;
                  case 'save_pdf':
                    await PrintHelper.savePdfReport(
                      _memos
                          .where((m) => (m.layer ?? 0) == _currentLayer)
                          .toList(),
                      mapImagePath: _customMapPath,
                      mapName: widget.mapInfo?.title ?? 'カスタム地図',
                    );
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
              PopupMenuItem(
                value: 'print_map',
                child: Row(
                  children: [
                    Icon(
                      Icons.map,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                    const SizedBox(width: 8),
                    const Text('地図画像を印刷'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'print_map_with_pins',
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                    const SizedBox(width: 8),
                    const Text('ピン付き地図を印刷'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'print_list',
                child: Row(
                  children: [
                    Icon(
                      Icons.list,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                    const SizedBox(width: 8),
                    const Text('記録一覧を印刷'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'save_pdf',
                child: Row(
                  children: [
                    Icon(
                      Icons.save,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                    const SizedBox(width: 8),
                    const Text('PDFで保存'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.format_list_bulleted),
            tooltip: '記録一覧',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MemoListScreen(
                    memos: _memos
                        .where((m) => (m.layer ?? 0) == _currentLayer)
                        .toList(),
                    mapTitle: widget.mapInfo?.title ?? 'カスタム地図',
                  ),
                ),
              );
              _loadMemos();
            },
          ),
        ],
      ),
      body: CustomMapWidget(
        key: _mapWidgetKey,
        memos: _memos.where((m) => (m.layer ?? 0) == _currentLayer).toList(),
        onTap: _onMapTap,
        onMemoTap: _onMemoTap,
        customImagePath: _customMapPath,
        onMemosUpdated: _loadMemos, // メモ更新時のコールバックを追加
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // 現在の地図IDを取得
          int? currentMapId;
          if (widget.mapInfo != null) {
            currentMapId = widget.mapInfo!.id;
          } else {
            // MapInfoがない場合は、地図画像パスから地図IDを取得または作成
            currentMapId = await DatabaseHelper.instance.getOrCreateMapId(
              _customMapPath,
              'カスタム地図',
            );
          }

          // 地図の中心座標で新規メモ作成画面に遷移
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddMemoScreen(
                initialLatitude: 0.5, // 地図の中心
                initialLongitude: 0.5,
                mapId: currentMapId,
                layer: _currentLayer,
              ),
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
