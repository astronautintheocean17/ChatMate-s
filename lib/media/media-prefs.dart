// lib/media/media-prefs.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'giphy-service.dart';
import 'media-catalog.dart';

class RecentGif {
  const RecentGif({this.bundled, this.online});

  final BundledGif? bundled;
  final GifSearchResult? online;

  String? get key => bundled == null ? online?.id : 'bundled:${bundled!.id}';

  String get label =>
      bundled == null ? (online?.title ?? 'GIF') : bundled!.label;

  String? get previewUrl => bundled == null ? online?.previewUrl : null;

  String? get downloadUrl => bundled == null ? online?.downloadUrl : null;
}

class MediaPrefs {
  MediaPrefs._();

  static const String _recentStickersKey = 'media.recent_stickers';
  static const String _favoriteStickersKey = 'media.favorite_stickers';
  static const String _recentGifsKey = 'media.recent_gifs';

  static Future<List<String>> recentStickers() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentStickersKey) ?? const [];
  }

  static Future<void> recordSticker(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_recentStickersKey) ?? <String>[];
    current.remove(id);
    current.insert(0, id);
    await prefs.setStringList(
      _recentStickersKey,
      current.take(24).toList(growable: false),
    );
  }

  static Future<Set<String>> favoriteStickers() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_favoriteStickersKey) ?? const []).toSet();
  }

  static Future<bool> toggleStickerFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_favoriteStickersKey) ?? []).toSet();
    final added = !current.contains(id);
    if (added) {
      current.add(id);
    } else {
      current.remove(id);
    }
    await prefs.setStringList(_favoriteStickersKey, current.toList());
    return added;
  }

  static Future<List<RecentGif>> recentGifs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_recentGifsKey) ?? const [];
    final results = <RecentGif>[];
    for (final entry in raw) {
      try {
        final map = jsonDecode(entry);
        if (map is! Map) continue;
        if (map['kind'] == 'bundled') {
          final match = bundledGifs.where((gif) => gif.id == map['id']);
          if (match.isNotEmpty) results.add(RecentGif(bundled: match.first));
        } else {
          results.add(
            RecentGif(
              online: GifSearchResult(
                id: map['id'] as String,
                title: map['title'] as String? ?? 'GIF',
                previewUrl: map['preview'] as String,
                downloadUrl: map['download'] as String,
                width: (map['width'] as num?)?.toInt() ?? 0,
                height: (map['height'] as num?)?.toInt() ?? 0,
              ),
            ),
          );
        }
      } catch (_) {
        // Ignore entries written by older builds.
      }
    }
    return results;
  }

  static Future<void> recordGif({
    BundledGif? bundled,
    GifSearchResult? online,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_recentGifsKey) ?? <String>[];
    final key = bundled == null ? online?.id : 'bundled:${bundled.id}';
    if (key == null) return;

    current.removeWhere((entry) {
      try {
        final map = jsonDecode(entry);
        if (map is! Map) return true;
        final entryKey = map['kind'] == 'bundled'
            ? 'bundled:${map['id']}'
            : map['id'];
        return entryKey == key;
      } catch (_) {
        return true;
      }
    });

    final Map<String, dynamic> payload;
    if (bundled != null) {
      payload = {'kind': 'bundled', 'id': bundled.id};
    } else {
      payload = {
        'kind': 'online',
        'id': online!.id,
        'title': online.title,
        'preview': online.previewUrl,
        'download': online.downloadUrl,
        'width': online.width,
        'height': online.height,
      };
    }
    current.insert(0, jsonEncode(payload));
    await prefs.setStringList(
      _recentGifsKey,
      current.take(12).toList(growable: false),
    );
  }
}
