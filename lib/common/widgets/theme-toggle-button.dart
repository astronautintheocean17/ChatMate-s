// lib/common/widgets/theme-toggle-button.dart
import 'package:flutter/material.dart';
import '../../theme/app-theme.dart';
import '../../theme/theme-controller.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: themeController.toggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surface(context),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _segment(
                    context,
                    icon: Icons.light_mode_rounded,
                    active: !isDark,
                  ),
                  const SizedBox(width: 4),
                  _segment(
                    context,
                    icon: Icons.dark_mode_rounded,
                    active: isDark,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _segment(
    BuildContext context, {
    required IconData icon,
    required bool active,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: active ? AppTheme.accent(context) : Colors.transparent,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Icon(
        icon,
        size: 16,
        color: active ? Colors.white : AppTheme.textMuted(context),
      ),
    );
  }
}
