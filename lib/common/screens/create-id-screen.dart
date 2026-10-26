// lib/common/screens/create-id-screen.dart
import 'dart:async';

import 'package:chatmate/common/screens/app-shell.dart';
import 'package:chatmate/users/screens/room-invite-screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../admin/screens/admin-login-screen.dart';
import '../../data/auth-service.dart';
import '../../data/errors.dart';
import '../../data/profile-service.dart';
import '../../data/push-service.dart';
import '../../theme/app-theme.dart';

class CreateIdScreen extends StatefulWidget {
  const CreateIdScreen({super.key, this.pendingRoomCode});

  /// A room code from an invite link. It is carried through onboarding so the
  /// new ChatMate ID lands on the room request instead of the home feed.
  final String? pendingRoomCode;

  @override
  State<CreateIdScreen> createState() => _CreateIdScreenState();
}

class _CreateIdScreenState extends State<CreateIdScreen> {
  final _idController = TextEditingController();
  final _focusNode = FocusNode();
  bool _busy = false;
  bool _checking = false;
  bool _focused = false;
  bool? _available;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
    _startSession();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
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
      setState(
        () => _error = 'Use 3-24 lowercase letters, numbers or underscores.',
      );
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
      // Now that a profile row exists, a push token can be attached to it.
      unawaited(PushService.syncToken());
      final pendingCode = widget.pendingRoomCode;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => pendingCode == null
              ? const AppShell()
              : RoomInviteScreen(code: pendingCode),
        ),
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
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Stack(
          children: [
            if (canPop)
              Positioned(
                left: 8,
                top: 4,
                child: IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    size: 20,
                    color: AppTheme.muted(context),
                  ),
                  tooltip: 'Back',
                ),
              ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: _card(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.line(context), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.5 : 0.07),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.accent(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.alternate_email_rounded,
                size: 24,
                color: AppTheme.accent(context),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Pick your ChatMate ID',
            textAlign: TextAlign.center,
            style: AppText.serif(25, color: AppTheme.ink(context), ls: -0.8),
          ),
          const SizedBox(height: 8),
          Text(
            'This is the only name anyone sees. No phone number, no email, '
            'nothing else.',
            textAlign: TextAlign.center,
            style: AppText.body(13, color: AppTheme.muted(context), h: 1.55),
          ),
          const SizedBox(height: 22),
          Text(
            'CHATMATE ID',
            style: AppText.mono(9.5, color: AppTheme.muted(context), ls: 1.5),
          ),
          const SizedBox(height: 8),
          _field(context),
          const SizedBox(height: 8),
          _status(context),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: AppText.body(
                11.5,
                color: Theme.of(context).colorScheme.error,
                h: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 20),
          _submitButton(context),
          const SizedBox(height: 16),
          Text(
            'Your ID is how someone asks to chat with you. It is never shown to '
            'a group unless you allow it.',
            textAlign: TextAlign.center,
            style: AppText.body(11, color: AppTheme.muted(context), h: 1.5),
          ),
          const SizedBox(height: 14),
          Divider(color: AppTheme.line(context), height: 1),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
              ),
              child: Text(
                'ADMIN ACCESS',
                style: AppText.mono(
                  9.5,
                  color: AppTheme.accent(context),
                  ls: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(BuildContext context) {
    final accent = AppTheme.accent(context);
    final good = _available == true;
    final bad = _available == false;

    final borderColor = bad
        ? Theme.of(context).colorScheme.error
        : (good || _focused)
        ? accent
        : AppTheme.line(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.bg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: (_focused || good) ? 1.8 : 1.2,
        ),
        boxShadow: _focused
            ? [BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 12)]
            : null,
      ),
      child: Row(
        children: [
          Text(
            '@',
            style: AppText.body(
              19,
              color: _focused ? accent : AppTheme.muted(context),
              w: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _idController,
              focusNode: _focusNode,
              autofocus: true,
              onChanged: _onChanged,
              onSubmitted: (_) => _continue(),
              textInputAction: TextInputAction.go,
              autocorrect: false,
              enableSuggestions: false,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[a-z0-9_]')),
                LengthLimitingTextInputFormatter(24),
              ],
              style: AppText.body(
                19,
                color: AppTheme.ink(context),
                w: FontWeight.w600,
              ),
              cursorColor: accent,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'yourname',
                hintStyle: AppText.body(
                  19,
                  color: AppTheme.muted(context).withValues(alpha: 0.6),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          if (_checking)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: AppTheme.muted(context),
              ),
            )
          else if (good)
            Icon(Icons.check_circle_rounded, size: 18, color: accent)
          else if (bad)
            Icon(
              Icons.cancel_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.error,
            ),
        ],
      ),
    );
  }

  Widget _status(BuildContext context) {
    final neutral = AppText.mono(9.5, color: AppTheme.muted(context), ls: 1.2);
    if (_checking) return Text('CHECKING AVAILABILITY…', style: neutral);
    if (_available == true) {
      return Text(
        '@$_handle IS AVAILABLE',
        style: AppText.mono(9.5, color: AppTheme.accent(context), ls: 1.2),
      );
    }
    if (_available == false) {
      return Text(
        '@$_handle IS TAKEN',
        style: AppText.mono(
          9.5,
          color: Theme.of(context).colorScheme.error,
          ls: 1.2,
        ),
      );
    }
    return Text('3-24 characters: a-z, 0-9, underscore', style: neutral);
  }

  Widget _submitButton(BuildContext context) {
    final enabled = !_busy && _available == true;
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: enabled ? _continue : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.accent(context),
          disabledBackgroundColor: AppTheme.line(context),
          foregroundColor: Colors.white,
          disabledForegroundColor: AppTheme.muted(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Continue', style: AppText.body(15, w: FontWeight.w600)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 17),
                ],
              ),
      ),
    );
  }
}
