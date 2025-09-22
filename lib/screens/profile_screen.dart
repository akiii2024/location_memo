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
  bool _isConvertingGuest = false;
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

  Future<void> _startGuestAccountRegistration() async {
    if (_isConvertingGuest) {
      return;
    }

    final dialogEmailController = TextEditingController(text: _email ?? '');
    final dialogDisplayNameController =
        TextEditingController(text: _displayNameController.text.trim());
    final dialogPasswordController = TextEditingController();
    final dialogConfirmPasswordController = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();

    bool? registrationSucceeded;

    if (!mounted) {
      return;
    }

    registrationSucceeded = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        String? errorMessage;
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('アカウント登録'),
              content: SingleChildScrollView(
                child: Form(
                  key: dialogFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'メールアドレスとパスワードを登録すると、ゲストアカウントのデータを引き継いだまま通常のアカウントとして利用できます。',
                      ),
                      const SizedBox(height: 16),
                      if (errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: dialogEmailController,
                        decoration: const InputDecoration(
                          labelText: 'メールアドレス',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return 'メールアドレスを入力してください';
                          }
                          if (!text.contains('@')) {
                            return '有効なメールアドレスを入力してください';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: dialogDisplayNameController,
                        decoration: const InputDecoration(
                          labelText: '表示名 (任意)',
                          hintText: '例: 山田 太郎',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
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
                      TextFormField(
                        controller: dialogPasswordController,
                        decoration: const InputDecoration(
                          labelText: 'パスワード',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'パスワードを入力してください';
                          }
                          if (value.length < 6) {
                            return 'パスワードは6文字以上で設定してください';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: dialogConfirmPasswordController,
                        decoration: const InputDecoration(
                          labelText: 'パスワード (確認用)',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '確認用のパスワードを入力してください';
                          }
                          if (value != dialogPasswordController.text) {
                            return 'パスワードが一致しません';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop(false);
                        },
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!dialogFormKey.currentState!.validate()) {
                            return;
                          }

                          setStateDialog(() {
                            isSubmitting = true;
                            errorMessage = null;
                          });

                          if (mounted) {
                            setState(() {
                              _isConvertingGuest = true;
                            });
                          }

                          try {
                            await _linkAnonymousAccount(
                              dialogEmailController.text.trim(),
                              dialogPasswordController.text,
                              dialogDisplayNameController.text.trim(),
                            );

                            if (mounted) {
                              Navigator.of(dialogContext).pop(true);
                            }
                          } on FirebaseAuthException catch (error) {
                            final message = _guestRegistrationErrorMessage(error);
                            setStateDialog(() {
                              errorMessage = message;
                              isSubmitting = false;
                            });
                            if (mounted) {
                              setState(() {
                                _isConvertingGuest = false;
                              });
                            }
                          } catch (error) {
                            setStateDialog(() {
                              errorMessage = '登録に失敗しました: $error';
                              isSubmitting = false;
                            });
                            if (mounted) {
                              setState(() {
                                _isConvertingGuest = false;
                              });
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('登録する'),
                ),
              ],
            );
          },
        );
      },
    );

    dialogEmailController.dispose();
    dialogDisplayNameController.dispose();
    dialogPasswordController.dispose();
    dialogConfirmPasswordController.dispose();

    if (mounted) {
      setState(() {
        _isConvertingGuest = false;
      });
    }

    if (registrationSucceeded == true) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('アカウント登録が完了しました。')), 
      );

      await _loadProfile(showLoading: false);
    }
  }

  Future<void> _linkAnonymousAccount(
    String email,
    String password,
    String displayName,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('ユーザー情報を取得できませんでした。');
    }

    if (!user.isAnonymous) {
      throw StateError('ゲストアカウントではありません。');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    final result = await user.linkWithCredential(credential);
    final linkedUser = result.user ?? FirebaseAuth.instance.currentUser;

    if (linkedUser == null) {
      throw StateError('アカウント登録に失敗しました。');
    }

    final trimmedDisplayName = displayName.trim();
    if (trimmedDisplayName.isNotEmpty) {
      await linkedUser.updateDisplayName(trimmedDisplayName);
    }

    await linkedUser.reload();

    final refreshedUser = FirebaseAuth.instance.currentUser ?? linkedUser;

    final updateData = <String, dynamic>{
      'email': refreshedUser.email,
      'emailLower': refreshedUser.email?.toLowerCase(),
      'isGuest': false,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (trimmedDisplayName.isNotEmpty) {
      updateData['displayName'] = trimmedDisplayName;
    }

    await FirebaseFirestore.instance
        .collection('userProfiles')
        .doc(refreshedUser.uid)
        .set(updateData, SetOptions(merge: true));
  }

  String _guestRegistrationErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'メールアドレスの形式が正しくありません。';
      case 'email-already-in-use':
      case 'credential-already-in-use':
        return '入力されたメールアドレスはすでに利用されています。';
      case 'weak-password':
        return 'パスワードは6文字以上で設定してください。';
      case 'operation-not-allowed':
        return '現在この登録方法は利用できません。';
      case 'requires-recent-login':
        return 'セキュリティのため再度ログインしてからお試しください。';
      case 'network-request-failed':
        return 'ネットワークに接続できませんでした。通信状況を確認してください。';
      case 'provider-already-linked':
        return 'このゲストアカウントは既に登録済みです。';
      default:
        return '登録に失敗しました: ${error.message ?? error.code}';
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
    final secondaryTextColor =
        theme.textTheme.bodyMedium?.color?.withOpacity(0.7);
    final noteTextColor = theme.textTheme.bodySmall?.color?.withOpacity(0.7);

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
                      color: secondaryTextColor,
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
        if (_isAnonymous) ...[
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ゲストアカウントの登録',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'メールアドレスとパスワードを設定すると、他の端末でも同じデータを利用できるようになります。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isConvertingGuest
                          ? null
                          : _startGuestAccountRegistration,
                      icon: _isConvertingGuest
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add_alt_1_outlined),
                      label: Text(
                        _isConvertingGuest ? '処理中...' : 'アカウント登録に進む',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '登録しても現在のメモや地図の情報はそのまま引き継がれます。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: noteTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
