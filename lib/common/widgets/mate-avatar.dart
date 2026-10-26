// lib/common/widgets/mate-avatar.dart
// One circular avatar used everywhere: initials, deterministic colour.

import 'package:flutter/material.dart';

import '../../theme/app-theme.dart';

const List<Color> _avatarPalette = [
  Color(0xFF1DB954),
  Color(0xFF0E7A3A),
  Color(0xFF2E7DD1),
  Color(0xFF7B4BD1),
  Color(0xFFD14B7B),
  Color(0xFFD17B2E),
  Color(0xFF2E9C9C),
  Color(0xFF8A6D3B),
];

class MateAvatar extends StatelessWidget {
  const MateAvatar({
    super.key,
    required this.handle,
    this.size = 48,
    this.anonymous = false,
  });

  final String handle;
  final double size;

  /// Renders the neutral "?" avatar used for direct chats whose partner the
  /// room does not name.
  final bool anonymous;

  String get _initials {
    final clean = handle.trim();
    if (clean.isEmpty) return '?';
    final parts = clean
        .replaceAll('_', ' ')
        .split(' ')
        .where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return (parts.first.characters.first + parts.elementAt(1).characters.first)
        .toUpperCase();
  }

  Color get _color {
    if (anonymous) return AppColors.lightTextMuted;
    final key = handle.toLowerCase();
    if (key.isEmpty) return _avatarPalette.first;
    var hash = 0;
    for (final code in key.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return _avatarPalette[hash % _avatarPalette.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
      child: Text(
        anonymous ? '?' : _initials,
        style: AppText.serif(
          size * 0.4,
          color: Colors.white,
          w: FontWeight.w700,
          ls: -0.2,
        ),
      ),
    );
  }
}
