// lib/common/screens/create-id-screen.dart

// lib/common/screens/create-id-screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chatmate/users/screens/home-screen.dart';
import '../../admin/screens/admin-login-screen.dart';
import '../../data/auth-service.dart';
import '../../data/errors.dart';
import '../../data/profile-service.dart';


class _C {
  // Dark theme — green / black / white
  static const bg = Color(0xFF0A0F0C);
  static const surface = Color(0xFF121815);
  static const ink = Color(0xFFF2F5F3); // foreground text
  static const accent = Color(0xFF1DB954);
  static const muted = Color(0xFF9AA6A0);
  static const line = Color(0xFF1F2A24);
}

class _T {
  static TextStyle serif(
    double size, {
    Color color = _C.ink,
    FontWeight w = FontWeight.w600,
    FontStyle style = FontStyle.normal,
    double h = 1.05,
    double ls = -0.5,
  }) =>
      GoogleFonts.fraunces(
        fontSize: size,
        color: color,
        fontWeight: w,
        fontStyle: style,
        height: h,
        letterSpacing: ls,
      );

  static TextStyle body(
    double size, {
    Color color = _C.ink,
    FontWeight w = FontWeight.w400,
    double h = 1.55,
  }) =>
      GoogleFonts.interTight(
        fontSize: size,
        color: color,
        fontWeight: w,
        height: h,
      );

  static TextStyle mono(
    double size, {
    Color color = _C.muted,
    FontWeight w = FontWeight.w500,
    double ls = 1.2,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        color: color,
        fontWeight: w,
        letterSpacing: ls,
      );
}

class CreateIdScreen extends StatefulWidget {
  const CreateIdScreen({super.key});

  @override
  State<CreateIdScreen> createState() => _CreateIdScreenState();
}

class _CreateIdScreenState extends State<CreateIdScreen> {
  final _idController = TextEditingController();
  bool _hover = false;
  bool _busy = false;
  bool _checking = false;
  bool? _available;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _idController.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    try {
      await AuthService.ensureAnonymousSession();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyError(error));
    }
  }

  String get _handle => ProfileService.normalizeHandle(_idController.text);

  bool get _formatValid => ProfileService.isValidHandle(_handle);

  void _onChanged(String value) {
    _debounce?.cancel();
    setState(() {
      _available = null;
      _error = null;
    });
    if (!_formatValid) {
      setState(() => _checking = false);
      return;
    }

    setState(() => _checking = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final available = await ProfileService.handleAvailable(_handle);
        if (!mounted) return;
        setState(() {
          _available = available;
          _checking = false;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _checking = false;
          _error = friendlyError(error);
        });
      }
    });
  }

  Future<void> _continue() async {
    if (_busy) return;
    if (!_formatValid) {
      setState(() => _error = 'Use 3-24 lowercase letters, numbers or underscores.');
      return;
    }
    if (_available != true) {
      setState(() => _error = 'Pick a ChatMate ID that is still available.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await AuthService.ensureAnonymousSession();
      await ProfileService.create(_handle);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
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
    final w = MediaQuery.sizeOf(context).width;
    final wide = w >= 980;
    final pad = wide ? 56.0 : (w >= 600 ? 36.0 : 20.0);

    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: pad, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top bar
                  Row(
                    children: [
                      _BackButton(onTap: () => Navigator.of(context).pop()),
                      const Spacer(),
                      Text(
                        '01 _ CREATE YOUR ID',
                        style: _T.mono(11, color: _C.accent, ls: 2),
                      ),
                    ],
                  ),
                  SizedBox(height: wide ? 72 : 40),

                  wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: _leftPanel(wide)),
                            const SizedBox(width: 80),
                            Expanded(flex: 5, child: _formPanel()),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _leftPanel(wide),
                            const SizedBox(height: 40),
                            _formPanel(),
                          ],
                        ),
                  SizedBox(height: wide ? 96 : 56),

                  // Footer line
                  Container(
                    padding: const EdgeInsets.only(top: 20),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: _C.line)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'CHATMATE _ SENDER NEVER REVEALED',
                            style: _T.mono(10.5, color: _C.muted, ls: 1.6),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── LEFT PANEL ─────────────────────────

  Widget _leftPanel(bool wide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Redaction visual
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: _C.ink.withValues(alpha: 0.35), width: 1),
          ),
          child: Text(
            'A NEW MEMBER',
            style: _T.mono(10, color: _C.ink, ls: 1.8),
          ),
        ),
        const SizedBox(height: 20),
        Text.rich(
          TextSpan(
            style: _T.serif(wide ? 72 : 48, h: 1.02, ls: -1.5),
            children: [
              const TextSpan(text: 'Pick a name\nfor the room.\n'),
              TextSpan(
                text: 'Not on the words.',
                style: _T.serif(
                  wide ? 72 : 48,
                  color: _C.accent,
                  w: FontWeight.w400,
                  style: FontStyle.italic,
                  h: 1.02,
                  ls: -1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Text(
            'Your ChatMate ID is how your circle finds you and adds you to a '
            'room. It is not stamped on anything you say. Choose something '
            'you like _ it will never sit next to a message.',
            style: _T.body(wide ? 17 : 15.5, color: _C.muted),
          ),
        ),
        SizedBox(height: wide ? 40 : 28),
        _rule('ID is for joining rooms only'),
        _rule('Messages never carry a sender'),
        _rule('No one _ not even admins _ can unmask'),
      ],
    );
  }

  Widget _rule(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: SizedBox(
              width: 8,
              height: 8,
              child: ColoredBox(color: _C.accent),
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              text,
              style: _T.body(15, color: _C.ink, w: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── FORM PANEL ─────────────────────────

  Widget _formPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _C.surface,
        border: Border.all(color: _C.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CHOOSE YOUR HANDLE', style: _T.mono(11, ls: 1.8)),
          const SizedBox(height: 20),
          TextField(
            controller: _idController,
            enabled: !_busy,
            onChanged: _onChanged,
            style: _T.serif(26, w: FontWeight.w500, h: 1.2, ls: -0.3),
            cursorColor: _C.accent,
            decoration: InputDecoration(
              hintText: 'nightowl_07',
              hintStyle: _T.serif(26,
                  color: _C.muted.withValues(alpha: 0.5),
                  w: FontWeight.w400,
                  style: FontStyle.italic),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '@',
                  style: _T.serif(26, color: _C.accent, w: FontWeight.w500),
                ),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 24, minHeight: 24),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
enabledBorder: const UnderlineInputBorder(
  borderSide: BorderSide(color: _C.line, width: 1.5),
),              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: _C.accent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Lowercase, numbers, and underscores. 3-24 characters.',
                  style: _T.mono(11, color: _C.muted, ls: 0.4),
                ),
              ),
              if (_checking)
                Text(
                  'CHECKING',
                  style: _T.mono(10, color: _C.muted, ls: 0.8),
                )
              else if (_available == true)
                Text(
                  'AVAILABLE',
                  style: _T.mono(10, color: _C.accent, ls: 0.8),
                )
              else if (_available == false)
                Text(
                  'TAKEN',
                  style: _T.mono(10, color: Color(0xFFE8452C), ls: 0.8),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: _T.body(12, color: const Color(0xFFE8452C), h: 1.4),
            ),
          ],
          const SizedBox(height: 32),
          _submitButton(),
          const SizedBox(height: 20),
          Row(
            children: [
              const SizedBox(
                width: 6,
                height: 6,
                child: ColoredBox(color: _C.accent),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Your ID is never attached to a message.',
                  style: _T.body(12.5, color: _C.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.only(top: 18),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _C.line)),
            ),
            child: Wrap(
              spacing: 14,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'By creating an ID you accept the Terms & Privacy.',
                  style: _T.mono(10, color: _C.muted, ls: 0.3),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminLoginScreen(),
                      ),
                    );
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text(
                      'ADMIN ACCESS',
                      style: _T.mono(
                        10,
                        color: _C.accent,
                        ls: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _submitButton() {
    final enabled = !_busy && _available == true;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: enabled ? _continue : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          color: !enabled
              ? _C.line
              : (_hover ? _C.accent : _C.ink),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _busy ? 'Creating…' : 'Continue',
                style: _T.body(16, color: _C.bg, w: FontWeight.w600),
              ),
              if (_busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _C.bg,
                  ),
                )
              else
                AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.only(left: _hover ? 20 : 8),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 18, color: _C.bg),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════ BACK BUTTON ═════════════════════════

class _BackButton extends StatefulWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _hover ? _C.ink : Colors.transparent,
            border: Border.all(color: _C.ink.withValues(alpha: 0.4), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_rounded,
                  size: 16, color: _hover ? _C.bg : _C.ink),
              const SizedBox(width: 8),
              Text(
                'BACK',
                style: _T.mono(11,
                    color: _hover ? _C.bg : _C.ink, ls: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
