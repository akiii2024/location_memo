import 'package:flutter/material.dart';
import 'package:location_memo/screens/main_screen.dart';
import 'package:location_memo/utils/tutorial_service.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({Key? key}) : super(key: key);

  @override
  _TutorialScreenState createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 6;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeTutorial();
    }
  }

  void _skipTutorial() {
    _completeTutorial();
  }

  void _completeTutorial() async {
    await TutorialService.setTutorialCompleted();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // スキップボタン
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: _skipTutorial,
                  child: Text(
                    'スキップ',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),

            // ページビュー
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _totalPages,
                itemBuilder: (context, index) {
                  return _buildTutorialPage(index);
                },
              ),
            ),

            // インジケーターとボタン
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // ページインジケーター
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_totalPages, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? theme.primaryColor
                              : theme.primaryColor.withOpacity(0.3),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  // 次へ / 開始ボタン
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _currentPage == _totalPages - 1 ? 'はじめる' : '次へ',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  Widget _buildTutorialPage(int index) {
    final theme = Theme.of(context);

    switch (index) {
      case 0:
        return _buildPageContent(
          icon: Icons.map_outlined,
          title: 'Location Memo へようこそ',
          description: 'フィールドワークでの記録を\n効率的に管理できるアプリです',
          details: '地図上に位置情報と一緒にメモを記録し、\n後で簡単に確認・印刷することができます。',
          theme: theme,
        );
      case 1:
        return _buildPageContent(
          icon: Icons.add_photo_alternate_outlined,
          title: '地図を追加',
          description: '調査エリアの地図画像を\nアプリに取り込めます',
          details: 'ホーム画面の「+」ボタンから\n地図画像を選択して追加してください。',
          theme: theme,
        );
      case 2:
        return _buildPageContent(
          icon: Icons.location_on_outlined,
          title: 'メモを記録',
          description: '地図上の任意の位置に\nメモを保存できます',
          details: '地図をタップすると、その場所に\n日時、テキスト、写真付きのメモを記録できます。',
          theme: theme,
        );
      case 3:
        return _buildPageContent(
          icon: Icons.print_outlined,
          title: '印刷・PDF出力',
          description: 'フィールドワークの成果を\n印刷やPDF保存できます',
          details: '地図画面の印刷メニューから\nピン付き地図やメモ一覧を出力できます。',
          theme: theme,
        );
      case 4:
        return _buildPageContent(
          icon: Icons.psychology_outlined,
          title: 'AI機能搭載',
          description: '最新のAI技術で\nメモ作成をサポート',
          details: 'AIがメモの内容を分析し、\n効率的な記録作成をお手伝いします。\nフィールドワークの質を向上させましょう！',
          theme: theme,
        );
      case 5:
        return _buildPageContent(
          icon: Icons.explore_outlined,
          title: '記録を活用',
          description: 'すべての準備が完了しました！',
          details: 'メモの検索や設定変更も可能です。\nAI機能と共に効率的なフィールドワーク記録を始めましょう。',
          theme: theme,
        );
      default:
        return Container();
    }
  }

  Widget _buildPageContent({
    required IconData icon,
    required String title,
    required String description,
    required String details,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // アイコン
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 60,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 40),

          // タイトル
          Text(
            title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.titleLarge?.color,
              fontFamily: 'NotoSansJP',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // 説明
          Text(
            description,
            style: TextStyle(
              fontSize: 18,
              color: theme.textTheme.bodyLarge?.color,
              fontFamily: 'NotoSansJP',
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // 詳細
          Text(
            details,
            style: TextStyle(
              fontSize: 14,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
              fontFamily: 'NotoSansJP',
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
