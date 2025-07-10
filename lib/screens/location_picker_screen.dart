import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import '../models/memo.dart';
import '../models/map_info.dart';
import '../utils/database_helper.dart';
import '../widgets/custom_map_widget.dart';

class LocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final MapInfo? mapInfo;

  const LocationPickerScreen({
    Key? key,
    this.initialLatitude,
    this.initialLongitude,
    this.mapInfo,
  }) : super(key: key);

  @override
  _LocationPickerScreenState createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  List<Memo> _memos = [];
  String? _customMapPath;
  double? _selectedLatitude;
  double? _selectedLongitude;

  @override
  void initState() {
    super.initState();
    _selectedLatitude = widget.initialLatitude;
    _selectedLongitude = widget.initialLongitude;
    _loadMemos();
    _loadCustomMapPath();

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

    setState(() {
      _memos = memos;
    });
  }

  void _onMapTap(double x, double y) {
    setState(() {
      _selectedLatitude = x;
      _selectedLongitude = y;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '位置を選択しました: (${x.toStringAsFixed(6)}, ${y.toStringAsFixed(6)})'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _onMemoTap(Memo memo) {
    // 位置選択モードでは、既存のメモをタップした場合はその位置を選択
    setState(() {
      _selectedLatitude = memo.latitude;
      _selectedLongitude = memo.longitude;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${memo.title}の位置を選択しました'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _confirmLocationSelection() {
    if (_selectedLatitude != null && _selectedLongitude != null) {
      Navigator.pop(context, {
        'latitude': _selectedLatitude,
        'longitude': _selectedLongitude,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('位置を選択してください'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('位置を選択'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'ヘルプ',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('位置選択のヘルプ'),
                  content: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• 地図をタップして位置を選択してください'),
                      Text('• 既存のピンをタップしてその位置を選択することもできます'),
                      Text('• 位置を選択後、「位置を確定」ボタンで決定してください'),
                      Text('• ピンチ操作で地図を拡大・縮小できます'),
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
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 選択状態の表示
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: _selectedLatitude != null && _selectedLongitude != null
                  ? Colors.green.shade50
                  : Colors.grey.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _selectedLatitude != null && _selectedLongitude != null
                          ? Icons.location_on
                          : Icons.location_off,
                      color: _selectedLatitude != null &&
                              _selectedLongitude != null
                          ? Colors.green
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedLatitude != null && _selectedLongitude != null
                          ? '選択中の位置'
                          : '位置が未選択',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _selectedLatitude != null &&
                                _selectedLongitude != null
                            ? Colors.green.shade700
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                if (_selectedLatitude != null &&
                    _selectedLongitude != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '緯度: ${_selectedLatitude!.toStringAsFixed(6)}\n経度: ${_selectedLongitude!.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade600,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  const Text(
                    '地図をタップして位置を選択してください',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 地図表示
          Expanded(
            child: _customMapPath != null
                ? CustomMapWidget(
                    memos: _memos,
                    onTap: _onMapTap,
                    onMemoTap: _onMemoTap,
                    customImagePath: _customMapPath,
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.map_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '地図が設定されていません',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '地図を追加してから位置を選択してください',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('キャンセル'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed:
                    _selectedLatitude != null && _selectedLongitude != null
                        ? _confirmLocationSelection
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('位置を確定'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
