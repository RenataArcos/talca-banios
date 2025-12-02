import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/utils/auth_service.dart';

Future<void> openAuthSheet(BuildContext context, AuthService auth) async {
  final user = auth.currentUser;
  if (user != null) {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LoggedSheet(user: user, auth: auth),
    );
    return;
  }
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _LoginRegisterSheet(auth: auth),
  );
}

class _LoggedSheet extends StatelessWidget {
  const _LoggedSheet({required this.user, required this.auth});
  final User user;
  final AuthService auth;

  String _safeInitial(User u) {
    final s = (u.displayName ?? u.email ?? 'U').trim();
    return s.isEmpty ? 'U' : s.substring(0, 1).toUpperCase();
  }

  String _safeTitle(User u) => (u.displayName?.trim().isNotEmpty ?? false)
      ? u.displayName!.trim()
      : (u.email ?? '(sin nombre)');

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage: (user.photoURL?.isNotEmpty ?? false)
                      ? NetworkImage(user.photoURL!)
                      : null,
                  child: (user.photoURL?.isEmpty ?? true)
                      ? Text(_safeInitial(user))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _safeTitle(user),
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                await auth.signOut();
                if (context.mounted) Navigator.pop(context);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sesión cerrada')),
                  );
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginRegisterSheet extends StatefulWidget {
  const _LoginRegisterSheet({required this.auth});
  final AuthService auth;

  @override
  State<_LoginRegisterSheet> createState() => _LoginRegisterSheetState();
}

class _LoginRegisterSheetState extends State<_LoginRegisterSheet> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _authLoading = false;
  bool _isLogin = true;
  String _err = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _authLoading = true;
      _err = '';
    });
    try {
      final email = _emailCtrl.text.trim();
      final pass = _passCtrl.text.trim();
      User? u;
      if (_isLogin) {
        u = await widget.auth.signInEmail(email, pass);
      } else {
        u = await widget.auth.signUpEmail(email, pass);
      }
      if (u != null && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isLogin ? 'Sesión iniciada' : 'Cuenta creada'),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _err = widget.auth.mapError(e);
      });
    } finally {
      if (mounted) setState(() => _authLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _isLogin ? 'Iniciar sesión' : 'Crear cuenta',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _isLogin = !_isLogin;
                      _err = '';
                    }),
                    child: Text(
                      _isLogin
                          ? '¿No tienes cuenta? Regístrate'
                          : '¿Ya tienes cuenta? Inicia sesión',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _authLoading
                      ? null
                      : () async {
                          setState(() {
                            _authLoading = true;
                            _err = '';
                          });
                          try {
                            final u = await widget.auth.signInGoogle();
                            if (u != null && mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Sesión iniciada con Google'),
                                ),
                              );
                            }
                          } on FirebaseAuthException catch (e) {
                            if (mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(widget.auth.mapError(e)),
                                ),
                              );
                          } finally {
                            if (mounted) setState(() => _authLoading = false);
                          }
                        },
                  icon: _authLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.g_mobiledata),
                  label: const Text('Continuar con Google'),
                ),
              ),

              const SizedBox(height: 8),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('o con correo'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_err.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_err, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _authLoading ? null : _submit,
                  icon: const Icon(Icons.email),
                  label: Text(_isLogin ? 'Entrar con correo' : 'Crear cuenta'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
