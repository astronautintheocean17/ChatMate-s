// lib/media/media-bubble-content.dart
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app-theme.dart';
import 'media-catalog.dart';
import 'media-viewer-screen.dart';

class MediaBubbleContent extends StatelessWidget {
  const MediaBubbleContent({
    super.key,
    required this.message,
    required this.url,
    required this.onOpen,
  });

  final ChatMessage message;
  final String? url;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: const MissingMedia(compact: true),
      );
    }
    if (message.isVideo) {
      return _VideoCard(message: message, onOpen: onOpen);
    }
    return _ImageCard(message: message, url: url!, onOpen: onOpen);
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({
    required this.message,
    required this.url,
    required this.onOpen,
  });

  final ChatMessage message;
  final String url;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final maxWidth = min(MediaQuery.sizeOf(context).width * 0.7, 286.0);
    final ratio = (message.width ?? 4) / max(1, message.height ?? 3);
    var width = maxWidth;
    var height = width / ratio;
    if (height > 350) {
      height = 350;
      width = height * ratio;
    }
    if (height < 112) {
      height = 112;
      width = (height * ratio).clamp(150, maxWidth);
    }

    return GestureDetector(
      onTap: onOpen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                url,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : Container(
                        color: Colors.black12,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.6,
                            color: AppTheme.accent(context),
                          ),
                        ),
                      ),
                errorBuilder: (_, _, _) => const MissingMedia(compact: true),
              ),
              if (message.isGif)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.58),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'GIF',
                      style: AppText.mono(7.5, color: Colors.white, ls: 1),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.message, required this.onOpen});

  final ChatMessage message;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final maxWidth = min(MediaQuery.sizeOf(context).width * 0.7, 286.0);
    final ratio = (message.width ?? 9) / max(1, message.height ?? 16);
    final width = maxWidth;
    final height = (width / ratio).clamp(160.0, 350.0);

    return GestureDetector(
      onTap: onOpen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.accent(context).withValues(alpha: 0.55),
                      Colors.black,
                    ],
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.42),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white54),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              Positioned(
                left: 7,
                bottom: 7,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.videocam_rounded,
                        size: 10,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        durationLabel(message.durationMs ?? 0),
                        style: AppText.mono(8, color: Colors.white, ls: 0.6),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
