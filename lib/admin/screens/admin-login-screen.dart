// lib/admin/screens/admin-login-screen.dart
import 'package:flutter/material.dart';

import '../../data/auth-service.dart';
import '../../data/errors.dart';
import '../../theme/app-theme.dart';
import 'dashboard-screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final id = _idController.text.trim();
    final password = _passwordController.text;
    if (id.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter the admin ID and password.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await AuthService.adminSignIn(username: id, password: password);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppTheme.bg(context);
    final surface = AppTheme.surface(context);
    final ink = AppTheme.ink(context);
    final muted = AppTheme.muted(context);
    final line = AppTheme.line(context);
    final accent = AppTheme.accent(context);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: surface,
                  border: Border.all(color: line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'ADMIN ACCESS',
                          style: AppText.mono(10, color: accent, ls: 1.8),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Operators only.',
                      style: AppText.serif(32, color: ink),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This account is created in Supabase Auth. It is not a '
                      'ChatMate handle.',
                      style: AppText.body(12, color: muted, h: 1.45),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: _idController,
                      enabled: !_busy,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      style: AppText.body(14, color: ink),
                      decoration: InputDecoration(
                        labelText: 'Admin ID',
                        labelStyle: AppText.body(12, color: muted),
                        filled: true,
                        fillColor: bg,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: accent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _passwordController,
                      enabled: !_busy,
                      obscureText: _obscure,
                      onSubmitted: (_) => _submit(),
                      style: AppText.body(14, color: ink),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: AppText.body(12, color: muted),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18,
                          ),
                        ),
                        filled: true,
                        fillColor: bg,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: accent),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: AppText.body(12, color: accent, h: 1.4),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ink,
                          foregroundColor: bg,
                          shape: const RoundedRectangleBorder(),
                        ),
                        child: _busy
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: bg,
                                ),
                              )
                            : Text(
                                'SIGN IN',
                                style: AppText.mono(11, color: bg, ls: 1.6),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

