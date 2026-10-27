// lib/common/widgets/swipe-to-reply.dart
// WhatsApp-style reply gesture: drag a row to the right, a reply arrow slides
// in behind it, and letting go past a short threshold starts a reply.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app-theme.dart';

class SwipeToReply extends StatelessWidget {
  const SwipeToReply({
    super.key,
    required this.itemId,
    required this.onReply,
    required this.child,
    this.enabled = true,
    this.backgroundPadding = const EdgeInsets.only(bottom: 8),
  });

  /// Keeps the dismissible key stable per message so the row does not rebuild
  /// into a fresh drag state on every stream update.
  final String itemId;
  final VoidCallback onReply;
  final Widget child;
  final bool enabled;

  /// Matches the gap the bubble itself keeps at the bottom of the row.
  final EdgeInsets backgroundPadding;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final accent = AppTheme.accent(context);
    return Dismissible(
      key: ValueKey('reply-$itemId'),
      direction: DismissDirection.startToEnd,
      // A short drag is enough — WhatsApp triggers well before half a bubble.
      dismissThresholds: const {DismissDirection.startToEnd: 0.18},
      resizeDuration: null,
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        onReply();
        // Never remove the row: the reply bar opens instead.
        return false;
      },
      background: Padding(
        padding: backgroundPadding,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.reply_rounded, size: 17, color: accent),
          ),
        ),
      ),
      child: child,
    );
  }
}
