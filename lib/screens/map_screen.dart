import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
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
  final GlobalKey<CustomMapWidgetState> _mapWidgetKey =
      GlobalKey<CustomMapWidgetState>();

  @override
  void initState() {
    super.initState();
    _loadMemos();
    _loadCustomMapPath();

    // MapInfoに画像パスがある場合はカスタム地図を使用
    if (widget.mapInfo?.imagePath != null) {
      _customMapPath = widget.mapInfo!.imagePath;
    }
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
    List<Memo> memos;

    if (widget.mapInfo != null) {
      // MapInfoがある場合は、そのIDでメモを読み込む
      memos =
          await DatabaseHelper.instance.readMemosByMapId(widget.mapInfo!.id);
    } else {
      // MapInfoがない場合は、地図画像パスでメモを読み込む
      memos = await DatabaseHelper.instance.readMemosByMapPath(_customMapPath);
    }

    setState(() {
      _memos = memos;
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
        title: Text(widget.mapInfo?.title ?? 'フィールドワーク記録'),
        actions: [
          // 印刷ボタン
          PopupMenuButton<String>(
            icon: const Icon(Icons.print),
            tooltip: '印刷',
            onSelected: (value) async {
              try {
                switch (value) {
                  case 'print_map':
                    await PrintHelper.printMapImage(_customMapPath);
                    break;
                  case 'print_map_with_pins':
                    final mapState = _mapWidgetKey.currentState;
                    if (mapState != null) {
                      await PrintHelper.printMapWithPins(
                        mapState.mapImagePath,
                        _memos,
                        mapState.actualDisplayWidth,
                        mapState.actualDisplayHeight,
                      );
                    } else {
                      // フォールバック: デフォルトサイズを使用
                      await PrintHelper.printMapWithPins(
                        _customMapPath,
                        _memos,
                        800.0,
                        600.0,
                      );
                    }
                    break;
                  case 'print_list':
                    await PrintHelper.printMemoList(_memos);
                    break;
                  case 'save_pdf':
                    await PrintHelper.savePdfReport(_memos,
                        mapImagePath: _customMapPath);
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
                    Text('地図画像を印刷'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'print_map_with_pins',
                child: Row(
                  children: [
                    Icon(Icons.location_on),
                    SizedBox(width: 8),
                    Text('ピン付き地図を印刷'),
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
      body: CustomMapWidget(
        key: _mapWidgetKey,
        memos: _memos,
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
