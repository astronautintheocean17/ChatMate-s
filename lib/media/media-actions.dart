// lib/media/media-actions.dart
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import 'media-service.dart';

class MediaActions {
  MediaActions._();

  static String extensionForMime(String? mime) {
    switch (mime) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      case 'video/quicktime':
        return 'mov';
      case 'video/webm':
        return 'webm';
      case 'video/mp4':
        return 'mp4';
      default:
        return 'jpg';
    }
  }

  static MimeType _saverType(String? mime) {
    switch (mime) {
      case 'image/png':
        return MimeType.png;
      case 'image/gif':
        return MimeType.gif;
      case 'video/mp4':
        return MimeType.mp4Video;
      case 'image/jpeg':
        return MimeType.jpeg;
      default:
        return MimeType.custom;
    }
  }

  static String _fileName(String? mime) =>
      'chatmate_${DateTime.now().millisecondsSinceEpoch}.'
      '${extensionForMime(mime)}';

  static Future<Uint8List> _fetch(String url) async {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw MediaException(
        'The download failed (${response.statusCode}). Try again.',
      );
    }
    return Uint8List.fromList(response.bodyBytes);
  }

  static Future<void> save(
    BuildContext context, {
    required String url,
    required String? mime,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _fetch(url);
      final name = _fileName(mime);
      final type = _saverType(mime);
      await FileSaver.instance.saveFile(
        name: name,
        bytes: bytes,
        fileExtension: extensionForMime(mime),
        mimeType: type,
        customMimeType: type == MimeType.custom ? mime : null,
      );
      messenger.showSnackBar(const SnackBar(content: Text('Saved to device.')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $error')));
    }
  }

  static Future<void> share(
    BuildContext context, {
    required String url,
    required String? mime,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    try {
      final bytes = await _fetch(url);
      final name = _fileName(mime);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: mime ?? 'application/octet-stream',
              name: name,
            ),
          ],
          fileNameOverrides: [name],
          sharePositionOrigin: origin,
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not share: $error')),
      );
    }
  }
}
