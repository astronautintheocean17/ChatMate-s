// lib/media/media-attach-sheet.dart
import 'package:flutter/material.dart';

import '../theme/app-theme.dart';

enum AttachChoice { imageCamera, imageGallery, gif, sticker, video }

Future<AttachChoice?> showMediaAttachSheet(
  BuildContext context, {
  bool includeSticker = true,
}) {
  return showModalBottomSheet<AttachChoice>(
    context: context,
    backgroundColor: AppTheme.surface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 34,
                height: 3,
                decoration: BoxDecoration(
                  color: AppTheme.line(sheetContext),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'SHARE SOMETHING',
              style: AppText.mono(
                9.5,
                color: AppTheme.muted(sheetContext),
                ls: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Private to this room. Links expire.',
              style: AppText.body(12.5, color: AppTheme.muted(sheetContext)),
            ),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.08,
              children: [
                _AttachTile(
                  icon: Icons.photo_camera_outlined,
                  label: 'CAMERA',
                  onTap: () =>
                      Navigator.pop(sheetContext, AttachChoice.imageCamera),
                ),
                _AttachTile(
                  icon: Icons.photo_library_outlined,
                  label: 'GALLERY',
                  onTap: () =>
                      Navigator.pop(sheetContext, AttachChoice.imageGallery),
                ),
                _AttachTile(
                  icon: Icons.gif_box_outlined,
                  label: 'GIF',
                  onTap: () => Navigator.pop(sheetContext, AttachChoice.gif),
                ),
                if (includeSticker)
                  _AttachTile(
                    icon: Icons.emoji_emotions_outlined,
                    label: 'STICKER',
                    onTap: () =>
                        Navigator.pop(sheetContext, AttachChoice.sticker),
                  ),
                _AttachTile(
                  icon: Icons.videocam_outlined,
                  label: 'VIDEO',
                  onTap: () => Navigator.pop(sheetContext, AttachChoice.video),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Images are compressed to 1600 px. Videos are cut off at 30 s '
              'and compressed to 720p.',
              style: AppText.body(
                10.5,
                color: AppTheme.muted(sheetContext),
                h: 1.45,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

enum VideoSource { camera, gallery }

Future<VideoSource?> showVideoSourceSheet(BuildContext context) {
  return showModalBottomSheet<VideoSource>(
    context: context,
    backgroundColor: AppTheme.surface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.videocam_outlined, size: 20),
            title: Text(
              'Record a video',
              style: AppText.body(14, color: AppTheme.ink(sheetContext)),
            ),
            subtitle: Text(
              'Up to 30 seconds',
              style: AppText.mono(
                8.5,
                color: AppTheme.muted(sheetContext),
                ls: 0.6,
              ),
            ),
            onTap: () => Navigator.pop(sheetContext, VideoSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.video_library_outlined, size: 20),
            title: Text(
              'Choose from gallery',
              style: AppText.body(14, color: AppTheme.ink(sheetContext)),
            ),
            subtitle: Text(
              'Longer clips are rejected',
              style: AppText.mono(
                8.5,
                color: AppTheme.muted(sheetContext),
                ls: 0.6,
              ),
            ),
            onTap: () => Navigator.pop(sheetContext, VideoSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _AttachTile extends StatelessWidget {
  const _AttachTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accent(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bg(context),
          border: Border.all(color: AppTheme.line(context)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 19, color: accent),
            ),
            const SizedBox(height: 8),
            Text(label, style: AppText.mono(8, color: accent, ls: 1)),
          ],
        ),
      ),
    );
  }
}
