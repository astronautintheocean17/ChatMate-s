// lib/media/giphy-service.dart
//
// Optional online GIF search. Bundled GIFs work with no key and no network.
// To enable Giphy trending/search, run the app with:
//   flutter run --dart-define=GIPHY_API_KEY=your_key
// Giphy requires that results carry a visible "Powered by GIPHY" attribution;
// the GIF picker shows it whenever online results are displayed.
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'media-catalog.dart';
import 'media-service.dart';

class GiphyConfig {
  static const String apiKey = String.fromEnvironment(
    'GIPHY_API_KEY',
    defaultValue: '',
  );

  static bool get enabled => apiKey.trim().isNotEmpty;
}

class GifSearchResult {
  const GifSearchResult({
    required this.id,
    required this.title,
    required this.previewUrl,
    required this.downloadUrl,
    required this.width,
    required this.height,
  });

  final String id;
  final String title;
  final String previewUrl;
  final String downloadUrl;
  final int width;
  final int height;
}

class GiphyService {
  GiphyService._();

  static const String _host = 'api.giphy.com';

  static int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static Future<List<GifSearchResult>> trending({int limit = 24}) {
    return _load('/v1/gifs/trending', {'limit': '$limit', 'rating': 'pg-13'});
  }

  static Future<List<GifSearchResult>> search(String query, {int limit = 24}) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return trending(limit: limit);
    return _load('/v1/gifs/search', {
      'q': trimmed,
      'limit': '$limit',
      'rating': 'pg-13',
      'lang': 'en',
    });
  }

  static Future<List<GifSearchResult>> _load(
    String path,
    Map<String, String> query,
  ) async {
    if (!GiphyConfig.enabled) {
      throw const MediaException(
        'Online GIFs are not configured. The bundled GIFs still work offline.',
      );
    }
    final uri = Uri.https(_host, path, {
      'api_key': GiphyConfig.apiKey,
      ...query,
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw MediaException(
        'GIF search is unavailable right now (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['data'] is! List) {
      throw const MediaException('GIF search returned an unexpected reply.');
    }
    final results = <GifSearchResult>[];
    for (final row in decoded['data'] as List) {
      if (row is! Map) continue;
      final images = row['images'];
      if (images is! Map) continue;
      final preview = images['fixed_height_small'];
      final full = images['downsized_medium'] ?? images['fixed_height'];
      if (preview is! Map || full is! Map) continue;
      final downloadUrl = full['url'] as String?;
      final previewUrl = preview['url'] as String?;
      if (downloadUrl == null || previewUrl == null) continue;
      results.add(
        GifSearchResult(
          id: row['id'] as String? ?? downloadUrl,
          title: (row['title'] as String? ?? 'GIF').trim(),
          previewUrl: previewUrl,
          downloadUrl: downloadUrl,
          width: _asInt(full['width']),
          height: _asInt(full['height']),
        ),
      );
    }
    return results;
  }

  /// Downloads the chosen GIF and verifies it really is a GIF before upload.
  static Future<PreparedMedia> download(GifSearchResult result) async {
    final response = await http
        .get(Uri.parse(result.downloadUrl))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw const MediaException('That GIF could not be downloaded.');
    }
    final bytes = Uint8List.fromList(response.bodyBytes);
    if (!MediaService.isGifBytes(bytes)) {
      throw const MediaException('That download was not a GIF.');
    }
    if (bytes.length > MediaLimits.maxGifBytes) {
      throw const MediaException('That GIF is larger than 8 MB.');
    }
    return MediaService.prepareGifBytes(
      bytes,
      sourceLabel: result.title.isEmpty ? 'GIF' : result.title,
    );
  }
}
