import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'main_screen.dart';
import 'package:location_memo/utils/offline_mode_provider.dart';
import '../utils/collaboration_sync_coordinator.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({this.returnOnSuccess = true, super.key});

  final bool returnOnSuccess;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String get _normalizedEmail => _emailController.text.trim().toLowerCase();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final auth = FirebaseAuth.instance;
      if (_isLogin) {
        await auth.signInWithEmailAndPassword(
          email: _normalizedEmail,
          password: _passwordController.text,
        );
      } else {
        final credential = await auth.createUserWithEmailAndPassword(
          email: _normalizedEmail,
          password: _passwordController.text,
        );
        final user = credential.user;
        if (user != null) {
          final displayName = _displayNameController.text.trim();
          if (displayName.isNotEmpty) {
            await user.updateDisplayName(displayName);
          }
          await _upsertUserProfile(
            user,
            includeCreatedAt: true,
            additionalData: {
              'displayName': displayName.isNotEmpty ? displayName : null,
            },
          );
        }
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _upsertUserProfile(user);
      }

      await CollaborationSyncCoordinator.instance.flushPending();
      await _completeSignInFlow();
    } on FirebaseAuthException catch (error) {
      final message = _errorMessage(error);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('処理に失敗しました。時間をおいて再試行してください。')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _upsertUserProfile(
    User user, {
    bool includeCreatedAt = false,
    Map<String, dynamic>? additionalData,
  }) async {
    final data = <String, dynamic>{
      'email': user.email,
      'emailLower': user.email?.toLowerCase(),
      'displayName': user.displayName,
      'photoUrl': user.photoURL,
      'isGuest': user.isAnonymous,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (includeCreatedAt) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    if (additionalData != null) {
      data.addAll(additionalData);
    }

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    batch.set(
      firestore.collection('userProfiles').doc(user.uid),
      data,
      SetOptions(merge: true),
    );

    final email = user.email?.trim().toLowerCase();
    if (!user.isAnonymous && email != null && email.isNotEmpty) {
      batch.set(firestore.collection('shareDirectory').doc(email), {
        'uid': user.uid,
        'displayName': user.displayName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<void> _sendPasswordReset() async {
    final email = _normalizedEmail;
    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('先に有効なメールアドレスを入力してください。')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登録状況に応じて、パスワード再設定メールを送信しました。')),
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        final message = switch (error.code) {
          'network-request-failed' => 'ネットワークに接続できませんでした。通信状況を確認してください。',
          'too-many-requests' => '試行回数が多すぎます。しばらく待ってから再試行してください。',
          _ => '登録状況に応じて、パスワード再設定メールを送信しました。',
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _completeSignInFlow() async {
    if (!mounted) {
      return;
    }

    await context.read<OfflineModeProvider>().disableOfflineMode();

    if (!mounted) {
      return;
    }

    if (widget.returnOnSuccess && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    }
  }

  String _errorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'メールアドレスの形式が正しくありません';
      case 'user-disabled':
        return 'このアカウントは利用できません';
      case 'user-not-found':
      case 'wrong-password':
        return 'メールアドレスまたはパスワードが違います';
      case 'email-already-in-use':
        return 'すでに登録されているメールアドレスです';
      case 'weak-password':
        return 'より長く推測されにくいパスワードを設定してください';
      case 'too-many-requests':
        return '試行回数が多すぎます。しばらく待ってから再試行してください';
      case 'operation-not-allowed':
        return '現在このログイン方法は利用できません。';
      case 'network-request-failed':
        return 'ネットワークに接続できませんでした。通信状況を確認してください。';
      default:
        return '認証に失敗しました。時間をおいて再試行してください。';
    }
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _confirmPasswordController.clear();
      _obscurePassword = true;
      _obscureConfirmPassword = true;
    });
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@/]+@[^\s@/]+\.[^\s@/]+$').hasMatch(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'ログイン' : '新規登録')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _isLogin ? 'アカウントにログイン' : '新しくアカウントを作成',
                          style: theme.textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'メールアドレス',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          enableSuggestions: false,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'メールアドレスを入力してください';
                            }
                            if (!_isValidEmail(value.trim().toLowerCase())) {
                              return '有効なメールアドレスを入力してください';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        if (!_isLogin) ...[
                          TextFormField(
                            controller: _displayNameController,
                            decoration: const InputDecoration(
                              labelText: '表示名 (任意)',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            autofillHints: const [AutofillHints.name],
                            textInputAction: TextInputAction.next,
                            maxLength: 50,
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'パスワード',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'パスワードを表示'
                                  : 'パスワードを隠す',
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          obscureText: _obscurePassword,
                          autofillHints: [
                            _isLogin
                                ? AutofillHints.password
                                : AutofillHints.newPassword,
                          ],
                          textInputAction: _isLogin
                              ? TextInputAction.done
                              : TextInputAction.next,
                          onFieldSubmitted: _isLogin && !_isLoading
                              ? (_) => _submit()
                              : null,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'パスワードを入力してください';
                            }
                            if (!_isLogin && value.length < 8) {
                              return 'パスワードは8文字以上で設定してください';
                            }
                            return null;
                          },
                        ),
                        if (!_isLogin) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            decoration: InputDecoration(
                              labelText: 'パスワード (確認用)',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _obscureConfirmPassword
                                    ? '確認用パスワードを表示'
                                    : '確認用パスワードを隠す',
                                onPressed: () => setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                ),
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            obscureText: _obscureConfirmPassword,
                            autofillHints: const [AutofillHints.newPassword],
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: !_isLoading
                                ? (_) => _submit()
                                : null,
                            validator: (value) {
                              if (_isLogin) {
                                return null;
                              }
                              if (value == null || value.isEmpty) {
                                return '確認用のパスワードを入力してください';
                              }
                              if (value != _passwordController.text) {
                                return 'パスワードが一致しません';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(_isLogin ? 'ログイン' : 'アカウントを作成'),
                        ),
                        const SizedBox(height: 12),
                        if (_isLogin) ...[
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isLoading ? null : _sendPasswordReset,
                              child: const Text('パスワードを忘れた方'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        const Text(
                          'ログインしなくても端末内の記録機能は利用できます。'
                          'この画面を閉じると元の画面へ戻ります。',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _isLoading ? null : _toggleMode,
                          child: Text(
                            _isLogin
                                ? 'アカウントをお持ちでない方はこちら'
                                : 'すでにアカウントをお持ちの方はこちら',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
