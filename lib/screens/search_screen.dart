import 'dart:async';

import 'package:flutter/material.dart';

import '../models/memo.dart';
import '../utils/database_helper.dart';
import '../widgets/app_state_view.dart';
import 'memo_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Memo> _searchResults = [];
  bool _isSearching = false;
  String? _errorMessage;
  Timer? _debounce;
  int _requestGeneration = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _performSearch(value);
    });
  }

  Future<void> _performSearch(String query) async {
    final generation = ++_requestGeneration;
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _errorMessage = null;
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });
    try {
      final results = await DatabaseHelper.instance
          .searchMemos(query.trim())
          .timeout(const Duration(seconds: 10));
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _isSearching = false;
        _errorMessage = '検索できませんでした。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('検索')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: '記録名・内容・地図名で検索',
                    prefixIcon: Icon(Icons.search),
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: _scheduleSearch,
                  onSubmitted: _performSearch,
                ),
                const SizedBox(height: 16),
                Expanded(child: _buildResults()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_isSearching) {
      return const AppStateView(
        icon: Icons.search,
        title: '検索しています…',
        loading: true,
      );
    }
    if (_errorMessage != null) {
      return AppStateView(
        icon: Icons.error_outline,
        title: _errorMessage!,
        message: '時間をおいてもう一度お試しください。',
        onRetry: () => _performSearch(_searchController.text),
      );
    }
    if (_searchResults.isEmpty) {
      final hasQuery = _searchController.text.trim().isNotEmpty;
      return AppStateView(
        icon: hasQuery ? Icons.search_off : Icons.search,
        title: hasQuery ? '検索結果が見つかりませんでした' : 'キーワードを入力してください',
        message: hasQuery ? '別の言葉で検索してください。' : '記録名、内容、地図名から検索できます。',
      );
    }
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final memo = _searchResults[index];
        return Card(
          child: ListTile(
            title: Text(memo.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (memo.mapTitle != null) Text('地図: ${memo.mapTitle}'),
                if (memo.content.isNotEmpty)
                  Text(
                    memo.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MemoDetailScreen(memo: memo),
                ),
              );
              if (mounted) await _performSearch(_searchController.text);
            },
          ),
        );
      },
    );
  }
}
