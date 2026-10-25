// lib/users/screens/create-room-screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/errors.dart';
import '../../data/models.dart';
import '../../data/profile-service.dart';
import '../../data/room-service.dart';
import '../../theme/app-theme.dart';
import 'chat-room-screen.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _nameController = TextEditingController();
  final _inviteController = TextEditingController();
  final Map<String, Profile?> _invited = {};
  List<Profile> _suggestions = const [];
  Timer? _debounce;
  String _accessMode = 'request';
  bool _creating = false;
  bool _searching = false;
  String? _error;

  String get _visibility => _accessMode == 'request' ? 'private' : 'public';
  String get _joinMode => _accessMode == 'request' ? 'request' : 'open';
  bool get _openToAll => _accessMode == 'all';

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  void _search(String raw) {
    _debounce?.cancel();
    final query = ProfileService.normalizeHandle(raw);
    if (query.length < 2) {
      setState(() {
        _suggestions = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 320), () async {
      try {
        final results = await ProfileService.search(query, limit: 8);
        if (!mounted) return;
        setState(() {
          _suggestions = results
              .where((profile) => !_invited.containsKey(profile.handle))
              .toList();
        });
      } catch (_) {
        if (mounted) setState(() => _suggestions = const []);
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  void _addTyped(String raw) {
    final handle = ProfileService.normalizeHandle(raw);
    if (!ProfileService.isValidHandle(handle)) {
      setState(() => _error = 'ChatMate IDs are 3-24 characters.');
      return;
    }
    if (_invited.containsKey(handle)) {
      _inviteController.clear();
      return;
    }
    final match = _suggestions.where((p) => p.handle == handle).firstOrNull;
    setState(() {
      _invited[handle] = match;
      _suggestions = const [];
      _error = null;
    });
    _inviteController.clear();
  }

  void _addSuggestion(Profile profile) {
    setState(() {
      _invited[profile.handle] = profile;
      _suggestions = const [];
      _error = null;
    });
    _inviteController.clear();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give your room a name first.');
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      final memberIds = _invited.values
          .whereType<Profile>()
          .map((profile) => profile.id)
          .toList();
      final room = await RoomService.createRoom(
        name: name,
        visibility: _visibility,
        joinMode: _joinMode,
        openToAll: _openToAll,
        memberIds: memberIds,
      );

      final unresolved = _invited.entries
          .where((entry) => entry.value == null)
          .toList();
      final failures = <String>[];
      for (final entry in unresolved) {
        try {
          await RoomService.inviteMember(roomId: room.id, handle: entry.key);
        } catch (_) {
          failures.add('@${entry.key}');
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failures.isEmpty
                ? 'Room created. Code ${room.code}.'
                : 'Room created, but could not invite ${failures.join(', ')}.',
          ),
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(roomId: room.id, roomName: room.name),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bg(context),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
        ),
        title: Text(
          'NEW ROOM',
          style: AppText.mono(10, color: AppTheme.muted(context), ls: 1.8),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Text(
              'Make space\nfor honesty.',
              style: AppText.serif(38, color: AppTheme.ink(context), h: 0.98),
            ),
            const SizedBox(height: 10),
            Text(
              'You choose who gets in. Nobody sees who said what unless the '
              'sender chooses to reveal it.',
              style: AppText.body(13, color: AppTheme.muted(context), h: 1.55),
            ),
            const SizedBox(height: 30),
            const _SectionLabel('ROOM NAME'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 60,
              enabled: !_creating,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: const InputDecoration(
                hintText: 'e.g. Sunday confessions',
                counterText: '',
              ),
            ),
            const SizedBox(height: 26),
            const _SectionLabel('HOW PEOPLE JOIN'),
            const SizedBox(height: 8),
            _JoinModeOption(
              title: 'Request only',
              caption:
                  'Private. Hidden from search. Someone enters the room ID, '
                  'sends a request, and waits for your approval.',
              icon: Icons.lock_outline_rounded,
              selected: _accessMode == 'request',
              onTap: () => setState(() => _accessMode = 'request'),
            ),
            const SizedBox(height: 8),
            _JoinModeOption(
              title: 'Open link',
              caption:
                  'Public link only. Not in search. Anyone with the invite '
                  'link joins immediately — no approval needed.',
              icon: Icons.link_rounded,
              selected: _accessMode == 'link',
              onTap: () => setState(() => _accessMode = 'link'),
            ),
            const SizedBox(height: 8),
            _JoinModeOption(
              title: 'Open to all',
              caption:
                  'Public. Findable in search. Anyone can join immediately '
                  'with the link or without it — no approval needed.',
              icon: Icons.public_rounded,
              selected: _accessMode == 'all',
              onTap: () => setState(() => _accessMode = 'all'),
            ),
            const SizedBox(height: 8),
            Text(
              _accessMode == 'request'
                  ? 'Only you can add people by ID. Every join needs your '
                        'approval.'
                  : _accessMode == 'link'
                  ? 'The room stays out of search. Share its link or code; '
                        'people who have it enter instantly.'
                  : 'The room is in search. Anyone who finds it can enter '
                        'instantly, no link needed.',
              style: AppText.body(
                11.5,
                color: AppTheme.muted(context),
                h: 1.45,
              ),
            ),

            const SizedBox(height: 26),
            const _SectionLabel('INVITE PEOPLE'),
            const SizedBox(height: 8),
            Text(
              'Optional. Invited people must accept before they can join. '
              'You can also invite them later from room info.',
              style: AppText.body(12, color: AppTheme.muted(context), h: 1.45),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inviteController,
                    enabled: !_creating,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    onChanged: _search,
                    onSubmitted: _addTyped,
                    decoration: const InputDecoration(
                      hintText: 'handle',
                      prefixText: '@',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Add person',
                  onPressed: _creating
                      ? null
                      : () => _addTyped(_inviteController.text),
                  icon: const Icon(Icons.add_rounded, size: 20),
                ),
              ],
            ),
            if (_searching) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 1.5),
            ],
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.line(context)),
                ),
                child: Column(
                  children: _suggestions
                      .map(
                        (profile) => _SuggestionTile(
                          profile: profile,
                          onTap: () => _addSuggestion(profile),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            if (_invited.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _invited.entries
                    .map(
                      (entry) => _InviteChip(
                        handle: entry.key,
                        pending: entry.value == null,
                        onRemove: _creating
                            ? null
                            : () => setState(() => _invited.remove(entry.key)),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: AppText.body(12, color: AppTheme.accent(context)),
              ),
            ],
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _creating ? null : _create,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accent(context),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _creating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'CREATE ROOM',
                        style: AppText.mono(10, color: Colors.white, ls: 1.4),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'REQUEST-ONLY AND OPEN-LINK ROOMS ARE HIDDEN FROM SEARCH. '
              'OPEN-TO-ALL ROOMS ARE SEARCHABLE. EVERY ROOM GETS A SHAREABLE '
              'LINK AND CODE.',
              style: AppText.mono(8, color: AppTheme.muted(context), ls: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppText.mono(9, color: AppTheme.muted(context), ls: 1.4),
    );
  }
}

class _JoinModeOption extends StatelessWidget {
  const _JoinModeOption({
    required this.title,
    required this.caption,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String caption;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accent(context);
    return Material(
      color: selected
          ? accent.withValues(alpha: 0.06)
          : AppTheme.surface(context),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected ? accent : AppTheme.line(context),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? accent : AppTheme.muted(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: AppText.mono(
                        8.5,
                        color: selected ? accent : AppTheme.ink(context),
                        ls: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      caption,
                      style: AppText.body(
                        10.5,
                        color: AppTheme.muted(context),
                        h: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 15,
                color: selected ? accent : AppTheme.line(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.profile, required this.onTap});

  final Profile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final display = profile.displayName.trim();
    final showDisplay = display.isNotEmpty && display != profile.handle;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@${profile.handle}',
                    style: AppText.mono(
                      10,
                      color: AppTheme.ink(context),
                      ls: 0.4,
                    ),
                  ),
                  if (showDisplay) ...[
                    const SizedBox(height: 2),
                    Text(
                      display,
                      style: AppText.body(
                        10.5,
                        color: AppTheme.muted(context),
                        h: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'ADD',
              style: AppText.mono(8, color: AppTheme.accent(context), ls: 1.2),
            ),
            const SizedBox(width: 4),
            Icon(Icons.add_rounded, size: 15, color: AppTheme.accent(context)),
          ],
        ),
      ),
    );
  }
}

class _InviteChip extends StatelessWidget {
  const _InviteChip({
    required this.handle,
    required this.pending,
    required this.onRemove,
  });

  final String handle;
  final bool pending;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 5, 6),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppTheme.line(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '@$handle',
            style: AppText.mono(9, color: AppTheme.ink(context), ls: 0.3),
          ),
          if (pending) ...[
            const SizedBox(width: 6),
            Text(
              'PENDING',
              style: AppText.mono(7, color: AppTheme.muted(context), ls: 0.8),
            ),
          ],
          const SizedBox(width: 2),
          IconButton(
            tooltip: 'Remove',
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 24, height: 24),
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.close_rounded,
              size: 15,
              color: AppTheme.muted(context),
            ),
          ),
        ],
      ),
    );
  }
}
