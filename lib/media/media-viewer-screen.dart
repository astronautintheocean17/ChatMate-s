// lib/media/media-viewer-screen.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../common/utils/format.dart';
import '../data/models.dart';
import '../theme/app-theme.dart';
import 'media-actions.dart';

class MediaViewerScreen extends StatelessWidget {
  const MediaViewerScreen({
    super.key,
    required this.message,
    required this.url,
  });

  final ChatMessage message;
  final String url;

  String get _title => message.isVideo
      ? 'VIDEO'
      : message.isGif
      ? 'GIF'
      : 'PHOTO';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        titleSpacing: 0,
        title: Text(
          '$_title · ${dayLabel(message.createdAt)} '
          '${clockTime(message.createdAt)}',
          style: AppText.mono(9, color: Colors.white70, ls: 1.1),
        ),
        actions: [
          IconButton(
            tooltip: 'Save to device',
            icon: const Icon(Icons.download_rounded, size: 19),
            onPressed: () =>
                MediaActions.save(context, url: url, mime: message.mime),
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share_rounded, size: 19),
            onPressed: () =>
                MediaActions.share(context, url: url, mime: message.mime),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: message.isVideo
                ? _RemoteVideo(url: url, autoplay: true)
                : _StillMedia(url: url),
          ),
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              color: Colors.black,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.hasCaption) ...[
                    Text(
                      message.caption!,
                      style: AppText.body(13.5, color: Colors.white, h: 1.5),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    message.senderHandle == null
                        ? 'ANONYMOUS'
                        : '@${message.senderHandle}',
                    style: AppText.mono(
                      8.5,
                      color: Colors.white.withValues(alpha: 0.55),
                      ls: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StillMedia extends StatelessWidget {
  const _StillMedia({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      maxScale: 4,
      child: Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white.withValues(alpha: 0.7),
                value: progress.expectedTotalBytes == null
                    ? null
                    : progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 34,
                ),
                const SizedBox(height: 10),
                Text(
                  'This media could not be loaded.',
                  style: AppText.body(12.5, color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RemoteVideo extends StatefulWidget {
  const _RemoteVideo({required this.url, this.autoplay = false});

  final String url;
  final bool autoplay;

  @override
  State<_RemoteVideo> createState() => _RemoteVideoState();
}

class _RemoteVideoState extends State<_RemoteVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (widget.autoplay) await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _ready = true;
      });
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      setState(() => _error = 'This video could not be played.');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggle() {
    final controller = _controller;
    if (controller == null) return;
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Text(_error!, style: AppText.body(13, color: Colors.white54)),
      );
    }
    if (!_ready || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
      );
    }
    final controller = _controller!;
    return GestureDetector(
      onTap: _toggle,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio == 0
                  ? 9 / 16
                  : controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              return AnimatedOpacity(
                opacity: value.isPlaying ? 0 : 1,
                duration: const Duration(milliseconds: 160),
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white54),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: AppColors.green,
                  bufferedColor: Colors.white38,
                  backgroundColor: Colors.white12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fallback shown when a private object could not be signed.
class MissingMedia extends StatelessWidget {
  const MissingMedia({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 168 : double.infinity,
      height: compact ? 112 : 220,
      color: AppTheme.muted(context).withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_clock_outlined,
            size: compact ? 22 : 30,
            color: AppTheme.muted(context),
          ),
          const SizedBox(height: 7),
          Text(
            'Media unavailable',
            style: AppText.mono(
              compact ? 8 : 9.5,
              color: AppTheme.muted(context),
              ls: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

String mediaKindLabel(ChatMessage message) {
  if (message.isImage) return 'Photo';
  if (message.isGif) return 'GIF';
  if (message.isVideo) return 'Video';
  if (message.isSticker) return 'Sticker';
  return 'Message';
}
