// lib/common/screens/setup-required-screen.dart
import 'package:flutter/material.dart';

import '../../theme/app-theme.dart';

class SetupRequiredScreen extends StatelessWidget {
  final String? error;
  const SetupRequiredScreen({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final muted = AppTheme.muted(context);
    final line = AppTheme.line(context);
    final accent = AppTheme.accent(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.surface(context),
                border: Border.all(color: line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CHATMATE',
                    style: AppText.mono(11, color: accent, ls: 2),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Supabase is not\nconfigured yet.',
                    style: AppText.serif(38, color: ink, h: 1.02),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Open supabase/SETUP.md and follow steps 1-5. Then paste your '
                    'anon (public) key into lib/supabase-config.dart.',
                    style: AppText.body(15, color: muted),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Never use a service_role key in the app.',
                    style: AppText.body(14, color: accent, w: FontWeight.w600),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 18),
                    Divider(color: line),
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: AppText.mono(11, color: muted, ls: 0.2),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text(
                    'EVERY ROOM HAS A SECRET. SAY IT. SIGN NOTHING.',
                    style: AppText.mono(9.5, color: muted, ls: 1.2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
