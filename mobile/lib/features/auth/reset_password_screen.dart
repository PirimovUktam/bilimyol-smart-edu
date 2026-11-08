import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _visible = false;
  bool _busy = false;
  bool _saved = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final client = SupabaseConfig.client!;
      await client.auth.updateUser(UserAttributes(password: _password.text));
      if (mounted) {
        _password.clear();
        setState(() => _saved = true);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Parol saqlanmadi. Havolani yoki aloqani tekshirib, qayta urinib ko‘ring.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SupabaseConfig.client?.auth.signOut(scope: SignOutScope.local);
      if (mounted) context.go('/login');
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Sessiyani yakunlab bo‘lmadi. Qayta urinib ko‘ring.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Parolni tiklash'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: AppCard(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _saved ? 'Parol yangilandi' : 'Yangi parol belgilang',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      if (!_saved) ...[
                        TextFormField(
                          controller: _password,
                          obscureText: !_visible,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: InputDecoration(
                            labelText: 'Yangi parol',
                            suffixIcon: IconButton(
                              tooltip: _visible
                                  ? 'Parolni yashirish'
                                  : 'Parolni ko‘rsatish',
                              onPressed: () =>
                                  setState(() => _visible = !_visible),
                              icon: Icon(
                                _visible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                          validator: (value) => (value?.length ?? 0) < 8
                              ? 'Kamida 8 ta belgi kiriting.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          obscureText: !_visible,
                          decoration: const InputDecoration(
                            labelText: 'Parolni takrorlang',
                          ),
                          validator: (value) => value != _password.text
                              ? 'Parollar bir-biriga mos kelmadi.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        AppButton(
                          text: 'Parolni saqlash',
                          isLoading: _busy,
                          onPressed: _save,
                        ),
                      ],
                      if (_error case final error?)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              error,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                      TextButton(
                        onPressed: _busy ? null : _leave,
                        child: Text(
                          _saved ? 'Kirish sahifasiga qaytish' : 'Bekor qilish',
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
    );
  }
}
