// lib/users/screens/profile-screen.dart
// The Profile tab: my ChatMate ID, appearance, notifications and links.

import 'package:flutter/material.dart';

import '../../common/widgets/mate-avatar.dart';
import '../../common/widgets/theme-toggle-button.dart';
import '../../data/errors.dart';
import '../../data/models.dart';
import '../../data/profile-service.dart';
import '../../data/push-service.dart';
import '../../data/social-models.dart';
import '../../data/social-service.dart';
import '../../theme/app-theme.dart';
import 'groups-screen.dart';
import 'requests-screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Profile? _profile;
  List<ConversationEntry> _conversations = const [];
  List<ChatRequestItem> _requests = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await ProfileService.current();
      final conversations = await SocialService.conversations();
      final requests = await SocialService.requests();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _conversations = conversations;
        _requests = requests.where((r) => r.isIncoming).toList();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _groupCount =>
      _conversations.where((entry) => !entry.isDirect).length;

  int get _chatCount => _conversations.where((entry) => entry.isDirect).length;

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load();
  }

  Future<void> _changeHandle() async {
    final profile = _profile;
    if (profile == null) return;

    final controller = TextEditingController(text: profile.handle);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) =>
          _ChangeHandleDialog(controller: controller, current: profile.handle),
    );
    controller.dispose();

    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ChatMate ID updated.')));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppTheme.accent(context),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Row(
                children: [
                  Text(
                    'Profile',
                    style: AppText.serif(
                      24,
                      color: AppTheme.ink(context),
                      ls: -0.8,
                    ),
                  ),
                  const Spacer(),
                  const ThemeToggleButton(),
                ],
              ),
              const SizedBox(height: 22),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: AppText.body(12, color: AppTheme.muted(context)),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: _load, child: const Text('RETRY')),
                const SizedBox(height: 8),
              ],
              if (profile == null && _loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (profile != null) ...[
                _identityCard(profile),
                const SizedBox(height: 18),
                _statsRow(),
                const SizedBox(height: 20),
                _section('ACCOUNT'),
                _action(
                  icon: Icons.alternate_email_rounded,
                  title: 'Change ChatMate ID',
                  subtitle: 'Your old handle stops working',
                  onTap: _changeHandle,
                ),
                _action(
                  icon: Icons.mark_chat_unread_outlined,
                  title: 'Chat requests',
                  subtitle: _requests.isEmpty
                      ? 'Nothing waiting on you'
                      : '${_requests.length} waiting on you',
                  onTap: () => _open(const RequestsScreen()),
                  highlight: _requests.isNotEmpty,
                ),
                const SizedBox(height: 20),
                _section('ROOMS'),
                _action(
                  icon: Icons.groups_outlined,
                  title: 'Groups',
                  subtitle: '$_groupCount joined',
                  onTap: () => _open(const GroupsScreen()),
                ),
                const SizedBox(height: 20),
                _section('NOTIFICATIONS'),
                _notificationTile(),
                const SizedBox(height: 20),
                _section('PRIVACY'),
                _privacyCard(),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'CHATMATE · v2.0.0',
                    style: AppText.mono(
                      9,
                      color: AppTheme.muted(context),
                      ls: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _identityCard(Profile profile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.line(context)),
      ),
      child: Row(
        children: [
          MateAvatar(handle: profile.handle, size: 62),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SIGNED IN ANONYMOUSLY',
                  style: AppText.mono(
                    8.5,
                    color: AppTheme.muted(context),
                    ls: 1.3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '@${profile.handle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.serif(
                    23,
                    color: AppTheme.ink(context),
                    ls: -0.8,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Change ID',
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: _changeHandle,
          ),
        ],
      ),
    );
  }

  Widget _statsRow() {
    return Row(
      children: [
        Expanded(child: _stat('$_chatCount', 'CHATS')),
        const SizedBox(width: 10),
        Expanded(child: _stat('$_groupCount', 'GROUPS')),
        const SizedBox(width: 10),
        Expanded(child: _stat('${_requests.length}', 'REQUESTS')),
      ],
    );
  }

  Widget _stat(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.line(context)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppText.serif(22, color: AppTheme.ink(context), ls: -0.5),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppText.mono(8.5, color: AppTheme.muted(context), ls: 1.2),
          ),
        ],
      ),
    );
  }

  Widget _section(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(
      label,
      style: AppText.mono(9.5, color: AppTheme.muted(context), ls: 1.4),
    ),
  );

  Widget _action({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    final accent = AppTheme.accent(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlight
                  ? accent.withValues(alpha: 0.4)
                  : AppTheme.line(context),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: highlight ? accent : AppTheme.ink(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.body(
                        14,
                        color: AppTheme.ink(context),
                        w: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: AppText.body(
                        11.5,
                        color: highlight ? accent : AppTheme.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppTheme.muted(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notificationTile() {
    return ValueListenableBuilder<PushState>(
      valueListenable: PushService.state,
      builder: (context, state, _) {
        final subtitle = switch (state) {
          PushState.ready => 'On for this device',
          PushState.denied => 'Blocked in system settings',
          PushState.unavailable => 'Not available on this build',
          PushState.off => 'Not enabled yet',
        };

        return _action(
          icon: state == PushState.ready
              ? Icons.notifications_active_outlined
              : Icons.notifications_none_rounded,
          title: 'Push notifications',
          subtitle: subtitle,
          highlight: state == PushState.ready,
          onTap: () async {
            await PushService.boot();
            await PushService.syncToken();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  PushService.isReady
                      ? 'Notifications are on.'
                      : 'Notifications are not available right now.',
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _privacyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.line(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 16,
                color: AppTheme.accent(context),
              ),
              const SizedBox(width: 8),
              Text(
                'Anonymous by default',
                style: AppText.body(
                  13.5,
                  color: AppTheme.ink(context),
                  w: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Every message you send carries "anonymous" unless you turn the '
            'toggle on, or a room creator switches the whole room to revealed '
            'names. Direct chats show only the handle of the person you are '
            'talking to.',
            style: AppText.body(12, color: AppTheme.muted(context), h: 1.6),
          ),
        ],
      ),
    );
  }
}

class _ChangeHandleDialog extends StatefulWidget {
  const _ChangeHandleDialog({required this.controller, required this.current});

  final TextEditingController controller;
  final String current;

  @override
  State<_ChangeHandleDialog> createState() => _ChangeHandleDialogState();
}

class _ChangeHandleDialogState extends State<_ChangeHandleDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _error;
  bool _busy = false;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ProfileService.changeHandle(widget.controller.text);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(),
      title: Text(
        'Change your ID',
        style: AppText.serif(22, color: AppTheme.ink(context)),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your old handle stops working straight away. Rooms and chats '
              'stay exactly as they are.',
              style: AppText.body(12, color: AppTheme.muted(context), h: 1.5),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: widget.controller,
              autofocus: true,
              style: AppText.body(14, color: AppTheme.ink(context)),
              decoration: const InputDecoration(
                prefixText: '@',
                hintText: 'your_id',
                isDense: true,
              ),
              validator: (value) {
                final handle = ProfileService.normalizeHandle(value ?? '');
                if (!ProfileService.isValidHandle(handle)) {
                  return '3-24 characters, a-z 0-9 _';
                }
                if (handle == widget.current) return 'That is already your ID.';
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: AppText.body(12, color: Colors.red.shade400),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: _busy ? null : _save,
          child: _busy ? const Text('SAVING...') : const Text('SAVE'),
        ),
      ],
    );
  }
}
