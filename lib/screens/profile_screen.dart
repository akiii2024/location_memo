import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _email;
  String? _uid;
  bool _isAnonymous = false;
  DateTime? _createdAt;
  DateTime? _updatedAt;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile({bool showLoading = true}) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _errorMessage = 'ユーザー情報を取得できませんでした。';
          _isLoading = false;
        });
      }
      return;
    }

    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('userProfiles')
          .doc(user.uid)
          .get();
      final data = doc.data();

      final firestoreDisplayName = data != null
          ? data['displayName'] as String?
          : null;
      final createdAt = data != null ? data['createdAt'] : null;
      final updatedAt = data != null ? data['updatedAt'] : null;

      final initialDisplayName = (firestoreDisplayName?.trim().isNotEmpty ?? false)
          ? firestoreDisplayName!.trim()
          : (user.displayName ?? '');

      _displayNameController.text = initialDisplayName;

      DateTime? createdAtDate;
      if (createdAt is Timestamp) {
        createdAtDate = createdAt.toDate();
      }
      DateTime? updatedAtDate;
      if (updatedAt is Timestamp) {
        updatedAtDate = updatedAt.toDate();
      }

      if (mounted) {
        setState(() {
          _email = user.email;
          _uid = user.uid;
          _isAnonymous = user.isAnonymous;
          _createdAt = createdAtDate;
          _updatedAt = updatedAtDate;
          _errorMessage = null;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'プロフィール情報の取得に失敗しました。';
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('プロフィール情報の取得に失敗しました: $error')),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ユーザー情報を取得できませんでした。')),
        );
      }
      return;
    }

    final trimmedDisplayName = _displayNameController.text.trim();

    setState(() {
      _isSaving = true;
    });

    try {
      await user.updateDisplayName(
        trimmedDisplayName.isNotEmpty ? trimmedDisplayName : null,
      );
      await user.reload();

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final updateData = <String, dynamic>{
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (trimmedDisplayName.isNotEmpty) {
          updateData['displayName'] = trimmedDisplayName;
        } else {
          updateData['displayName'] = FieldValue.delete();
        }

        await FirebaseFirestore.instance
            .collection('userProfiles')
            .doc(currentUser.uid)
            .set(updateData, SetOptions(merge: true));
      }

      if (!mounted) {
        return;
      }

      FocusScope.of(context).unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プロフィールを更新しました')),
      );

      await _loadProfile(showLoading: false);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('プロフィールの更新に失敗しました: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year/$month/$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final displayName = _displayNameController.text.trim();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 2,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              child: Icon(
                Icons.person,
                color: theme.colorScheme.primary,
              ),
            ),
            title: Text(displayName.isEmpty ? '表示名は未設定です' : displayName),
            subtitle: Text(
              _isAnonymous
                  ? 'ゲストアカウントで利用中'
                  : (_email ?? 'メールアドレスは登録されていません'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '表示名の変更',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'アプリ内で表示される名前を設定できます。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(
                      labelText: '表示名',
                      prefixIcon: Icon(Icons.person_outline),
                      hintText: '例: 山田 太郎',
                    ),
                    textInputAction: TextInputAction.done,
                    maxLength: 30,
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.length > 30) {
                        return '表示名は30文字以内で入力してください';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveProfile,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_alt),
                      label: Text(_isSaving ? '保存中...' : '変更を保存'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('アカウント種別'),
                subtitle: Text(
                  _isAnonymous ? 'ゲストアカウント' : '通常アカウント',
                ),
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('メールアドレス'),
                subtitle: Text(_email ?? '未登録'),
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.key_outlined),
                title: const Text('ユーザーID (UID)'),
                subtitle: SelectableText(_uid ?? '-'),
              ),
              if (_createdAt != null || _updatedAt != null)
                const Divider(height: 0),
              if (_createdAt != null)
                ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('登録日時'),
                  subtitle: Text(_formatDateTime(_createdAt!)),
                ),
              if (_updatedAt != null)
                const Divider(height: 0),
              if (_updatedAt != null)
                ListTile(
                  leading: const Icon(Icons.update),
                  title: const Text('最終更新日時'),
                  subtitle: Text(_formatDateTime(_updatedAt!)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
