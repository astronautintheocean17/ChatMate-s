// lib/media/media-preview-sheet.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/errors.dart';
import '../theme/app-theme.dart';
import 'media-catalog.dart';
import 'media-service.dart';

Future<bool?> showMediaPreview(
  BuildContext context, {
  required PreparedMedia media,
  required Future<void> Function(String? caption) onSend,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: AppTheme.surface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _MediaPreviewSheet(media: media, onSend: onSend),
  );
}

class _MediaPreviewSheet extends StatefulWidget {
  const _MediaPreviewSheet({required this.media, required this.onSend});

  final PreparedMedia media;
  final Future<void> Function(String? caption) onSend;

  @override
  State<_MediaPreviewSheet> createState() => _MediaPreviewSheetState();
}

class _MediaPreviewSheetState extends State<_MediaPreviewSheet> {
  final _caption = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final caption = _caption.text.trim();
      await widget.onSend(caption.isEmpty ? null : caption);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String get _title {
    if (widget.media.kind == MediaKind.video) return 'SEND VIDEO';
    if (widget.media.kind == MediaKind.gif) return 'SEND GIF';
    return 'SEND PHOTO';
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    final height = MediaQuery.sizeOf(context).height * 0.9;
    return PopScope(
      canPop: !_sending,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 10, 8),
                child: Row(
                  children: [
                    Text(
                      _title,
                      style: AppText.mono(
                        9.5,
                        color: AppTheme.muted(context),
                        ls: 1.4,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _sending
                          ? null
                          : () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: AppTheme.line(context)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: media.kind == MediaKind.video
                      ? _LocalVideoPreview(media: media)
                      : Image.memory(
                          media.bytes,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 9, 18, 0),
                child: Row(
                  children: [
                    Text(
                      '${media.width} × ${media.height}',
                      style: AppText.mono(
                        8.5,
                        color: AppTheme.muted(context),
                        ls: 0.6,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      humanBytes(media.sizeBytes),
                      style: AppText.mono(
                        8.5,
                        color: AppTheme.muted(context),
                        ls: 0.6,
                      ),
                    ),
                    if (media.durationMs != null) ...[
                      const SizedBox(width: 12),
                      Text(
                        durationLabel(media.durationMs!),
                        style: AppText.mono(
                          8.5,
                          color: AppTheme.accent(context),
                          ls: 0.6,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                  child: Text(
                    _error!,
                    style: AppText.body(12, color: AppTheme.accent(context)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.bg(context),
                    border: Border.all(color: AppTheme.line(context)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: _caption,
                    enabled: !_sending,
                    maxLength: MediaLimits.maxCaptionLength,
                    minLines: 1,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppText.body(13.5, color: AppTheme.ink(context)),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      hintText: 'Add a caption...',
                      hintStyle: AppText.body(
                        13,
                        color: AppTheme.muted(context),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  14,
                  10,
                  14,
                  12 + MediaQuery.paddingOf(context).bottom,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    onPressed: _sending ? null : _send,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent(context),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'SEND',
                            style: AppText.mono(
                              10,
                              color: Colors.white,
                              ls: 1.3,
                            ),
                          ),
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

class _LocalVideoPreview extends StatefulWidget {
  const _LocalVideoPreview({required this.media});

  final PreparedMedia media;

  @override
  State<_LocalVideoPreview> createState() => _LocalVideoPreviewState();
}

class _LocalVideoPreviewState extends State<_LocalVideoPreview> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final path = widget.media.localPath;
    if (path == null || path.isEmpty) return;
    final controller = VideoPlayerController.file(File(path));
    try {
      await controller.initialize();
      await controller.setLooping(true);
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
            builder: (context, value, _) => AnimatedOpacity(
              opacity: value.isPlaying ? 0 : 1,
              duration: const Duration(milliseconds: 160),
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white54),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
