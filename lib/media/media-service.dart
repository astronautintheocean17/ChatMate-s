// lib/media/media-service.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_compress/video_compress.dart';

import '../data/auth-service.dart';
import 'media-catalog.dart';

class PreparedMedia {
  const PreparedMedia({
    required this.bytes,
    required this.mime,
    required this.extension,
    required this.width,
    required this.height,
    required this.kind,
    this.durationMs,
    this.localPath,
    this.sourceLabel,
  });

  final Uint8List bytes;
  final String mime;
  final String extension;
  final int width;
  final int height;
  final String kind;
  final int? durationMs;
  final String? localPath;
  final String? sourceLabel;

  int get sizeBytes => bytes.length;
}

class MediaException implements Exception {
  const MediaException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MediaService {
  MediaService._();

  static const String bucket = 'chat-media';
  static final Random _random = Random.secure();

  static SupabaseClient get _client => AuthService.client;

  static bool isGifBytes(Uint8List bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38;

  static bool isVideoPath(String path) {
    final value = path.toLowerCase();
    return value.endsWith('.mp4') ||
        value.endsWith('.mov') ||
        value.endsWith('.webm') ||
        value.endsWith('.m4v');
  }

  /// Images are re-encoded as JPEG so EXIF metadata (including GPS) is
  /// stripped before anything leaves the device.
  static Future<PreparedMedia> prepareImage(XFile file) async {
    final raw = await file.readAsBytes();
    if (raw.length > MediaLimits.maxImageBytes) {
      throw const MediaException(
        'That image is too large. Choose one under 10 MB.',
      );
    }
    final decoded = img.decodeImage(raw);
    if (decoded == null) {
      throw const MediaException('That file could not be read as an image.');
    }
    final upright = img.bakeOrientation(decoded);
    final scaled = _resize(upright);
    final encoded = img.encodeJpg(scaled, quality: MediaLimits.imageQuality);
    return PreparedMedia(
      bytes: Uint8List.fromList(encoded),
      mime: 'image/jpeg',
      extension: 'jpg',
      width: scaled.width,
      height: scaled.height,
      kind: MediaKind.image,
      sourceLabel: file.name,
    );
  }

  static Future<PreparedMedia> prepareGif(XFile file) async {
    final raw = await file.readAsBytes();
    return prepareGifBytes(raw, sourceLabel: file.name);
  }

  static Future<PreparedMedia> prepareGifBytes(
    Uint8List raw, {
    String? sourceLabel,
  }) async {
    if (!isGifBytes(raw)) {
      throw const MediaException('That file is not a GIF.');
    }
    if (raw.length > MediaLimits.maxGifBytes) {
      throw const MediaException(
        'That GIF is too large. GIFs must be 8 MB or smaller.',
      );
    }
    final decoded = img.decodeImage(raw);
    if (decoded == null) {
      throw const MediaException('That GIF could not be read.');
    }
    return PreparedMedia(
      bytes: raw,
      mime: 'image/gif',
      extension: 'gif',
      width: decoded.width,
      height: decoded.height,
      kind: MediaKind.gif,
      sourceLabel: sourceLabel,
    );
  }

  static Future<PreparedMedia> prepareBundledGif(BundledGif gif) async {
    final data = await rootBundle.load(gif.assetPath);
    return prepareGifBytes(
      data.buffer.asUint8List(),
      sourceLabel: '${gif.label}.gif',
    );
  }

  /// Videos are inspected first (so a four-minute clip is rejected before an
  /// expensive transcode), then compressed to 720p and capped at 25 MB.
  static Future<PreparedMedia> prepareVideo(XFile file) async {
    final original = file.path;
    if (original.isEmpty) {
      throw const MediaException('That video could not be opened.');
    }

    MediaInfo info;
    try {
      info = await VideoCompress.getMediaInfo(original);
    } catch (_) {
      throw const MediaException('That video could not be read.');
    }

    final originalMs = info.duration == null ? 0 : info.duration!.round();
    if (originalMs <= 0) {
      throw const MediaException('That video has no readable duration.');
    }
    if (originalMs > MediaLimits.maxVideoSeconds * 1000) {
      throw const MediaException('Videos can be at most 30 seconds long.');
    }

    MediaInfo? compressed;
    try {
      compressed = await VideoCompress.compressVideo(
        original,
        quality: VideoQuality.Res1280x720Quality,
        deleteOrigin: false,
        includeAudio: true,
      );
      if ((compressed?.filesize ?? 0) > MediaLimits.maxVideoBytes) {
        compressed = await VideoCompress.compressVideo(
          original,
          quality: VideoQuality.Res960x540Quality,
          deleteOrigin: false,
          includeAudio: true,
        );
      }
    } catch (_) {
      compressed = null;
    }

    final path = compressed?.path ?? original;
    final outFile = File(path);
    if (!await outFile.exists()) {
      throw const MediaException('That video could not be compressed.');
    }
    final raw = await outFile.readAsBytes();
    if (raw.length > MediaLimits.maxVideoBytes) {
      throw const MediaException(
        'That video is still over 25 MB after compression. Try a shorter clip.',
      );
    }

    final durationMs = (compressed?.duration ?? info.duration ?? originalMs)
        .round()
        .clamp(1000, MediaLimits.maxVideoSeconds * 1000);
    final extension = _videoExtension(path);
    final width = compressed?.width ?? info.width ?? 720;
    final height = compressed?.height ?? info.height ?? 1280;
    final swapped = info.orientation == 90 || info.orientation == 270;

    return PreparedMedia(
      bytes: raw,
      mime: mimeForExtension(extension),
      extension: extension,
      width: swapped ? height : width,
      height: swapped ? width : height,
      kind: MediaKind.video,
      durationMs: durationMs,
      localPath: path,
      sourceLabel: file.name,
    );
  }

  static img.Image _resize(img.Image source) {
    final longest = max(source.width, source.height);
    if (longest <= MediaLimits.imageLongEdge) return source;
    if (source.width >= source.height) {
      return img.copyResize(
        source,
        width: MediaLimits.imageLongEdge,
        interpolation: img.Interpolation.average,
      );
    }
    return img.copyResize(
      source,
      height: MediaLimits.imageLongEdge,
      interpolation: img.Interpolation.average,
    );
  }

  static String _videoExtension(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mov')) return 'mov';
    if (lower.endsWith('.webm')) return 'webm';
    return 'mp4';
  }

  static String mimeForExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'mp4':
        return 'video/mp4';
      default:
        return 'image/jpeg';
    }
  }

  static String objectPath(String roomId, String extension) {
    const alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final randomPart = List<String>.generate(
      20,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return '$roomId/${stamp}_$randomPart.$extension';
  }

  static Future<String> upload({
    required String roomId,
    required PreparedMedia media,
  }) async {
    final path = objectPath(roomId, media.extension);
    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          media.bytes,
          fileOptions: FileOptions(
            contentType: media.mime,
            cacheControl: '3600',
            upsert: false,
          ),
        );
    return path;
  }

  static Future<void> remove(String path) async {
    try {
      await _client.storage.from(bucket).remove([path]);
    } catch (_) {
      // Best-effort cleanup. A leftover private object cannot be reached
      // without a signed URL, so it is not a privacy leak.
    }
  }

  static Future<Map<String, String>> signedUrls(Iterable<String> paths) async {
    final unique = paths.where((path) => path.isNotEmpty).toSet().toList();
    if (unique.isEmpty) return const {};
    try {
      final results = await _client.storage
          .from(bucket)
          .createSignedUrlsResult(unique, 60 * 60);
      return {
        for (final result in results)
          if (result is SignedUrlSuccess) result.path: result.signedUrl,
      };
    } catch (_) {
      return const {};
    }
  }

  static Future<Uint8List> download(String path) =>
      _client.storage.from(bucket).download(path);
}
