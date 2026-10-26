// lib/media/media-catalog.dart
// Bundled, original artwork created by tools/generate_media_assets.py.
// Everything in this file is safe to ship: no stickers or GIFs are copied
// from WhatsApp, Giphy or any third-party pack.

class MediaKind {
  static const String text = 'text';
  static const String image = 'image';
  static const String gif = 'gif';
  static const String video = 'video';
  static const String sticker = 'sticker';
}

class MediaLimits {
  static const int maxVideoSeconds = 30;
  static const int maxCaptionLength = 1024;
  static const int maxTextLength = 4000;
  static const int maxGifBytes = 8 * 1024 * 1024;
  static const int maxImageBytes = 10 * 1024 * 1024;
  static const int maxVideoBytes = 25 * 1024 * 1024;
  static const int imageLongEdge = 1600;
  static const int imageQuality = 82;
}

class StickerItem {
  const StickerItem({required this.id, required this.label});

  final String id;
  final String label;

  String get assetPath => 'assets/stickers/$id.png';
}

class StickerPack {
  const StickerPack({
    required this.id,
    required this.name,
    required this.description,
    required this.items,
  });

  final String id;
  final String name;
  final String description;
  final List<StickerItem> items;
}

const List<StickerPack> stickerPacks = [
  StickerPack(
    id: 'blobs',
    name: 'Blobs',
    description: 'Soft little feelings',
    items: [
      StickerItem(id: 'blobs_happy', label: 'Happy'),
      StickerItem(id: 'blobs_laugh', label: 'Laughing'),
      StickerItem(id: 'blobs_sad', label: 'Sad'),
      StickerItem(id: 'blobs_angry', label: 'Angry'),
      StickerItem(id: 'blobs_love', label: 'Love'),
      StickerItem(id: 'blobs_sleepy', label: 'Sleepy'),
      StickerItem(id: 'blobs_cool', label: 'Cool'),
      StickerItem(id: 'blobs_nervous', label: 'Nervous'),
    ],
  ),
  StickerPack(
    id: 'moods',
    name: 'Moods',
    description: 'One-word answers',
    items: [
      StickerItem(id: 'moods_yes', label: 'Yes'),
      StickerItem(id: 'moods_no', label: 'Nope'),
      StickerItem(id: 'moods_wow', label: 'Wow'),
      StickerItem(id: 'moods_maybe', label: 'Maybe'),
      StickerItem(id: 'moods_brb', label: 'BRB'),
      StickerItem(id: 'moods_oops', label: 'Oops'),
      StickerItem(id: 'moods_thanks', label: 'Thanks'),
      StickerItem(id: 'moods_same', label: 'Same'),
    ],
  ),
  StickerPack(
    id: 'latenight',
    name: 'Late night',
    description: 'For after midnight',
    items: [
      StickerItem(id: 'latenight_tired', label: 'Tired'),
      StickerItem(id: 'latenight_awake', label: 'Awake'),
      StickerItem(id: 'latenight_overthinking', label: 'Overthinking'),
      StickerItem(id: 'latenight_coffee', label: 'Send coffee'),
      StickerItem(id: 'latenight_no_thoughts', label: 'No thoughts'),
      StickerItem(id: 'latenight_almost', label: 'Almost'),
      StickerItem(id: 'latenight_help', label: 'Help'),
      StickerItem(id: 'latenight_goodnight', label: 'Goodnight'),
    ],
  ),
];

final Map<String, StickerItem> _stickersById = {
  for (final pack in stickerPacks)
    for (final item in pack.items) item.id: item,
};

StickerItem? stickerById(String? id) => id == null ? null : _stickersById[id];

class BundledGif {
  const BundledGif({
    required this.id,
    required this.label,
    required this.searchTerms,
  });

  final String id;
  final String label;
  final List<String> searchTerms;

  String get assetPath => 'assets/gifs/$id.gif';
}

const List<BundledGif> bundledGifs = [
  BundledGif(id: 'yes', label: 'YES', searchTerms: ['yes', 'agree', 'ok']),
  BundledGif(
    id: 'nope',
    label: 'NOPE',
    searchTerms: ['no', 'nope', 'disagree'],
  ),
  BundledGif(id: 'lol', label: 'LOL', searchTerms: ['lol', 'laugh', 'funny']),
  BundledGif(id: 'wow', label: 'WOW', searchTerms: ['wow', 'shock', 'omg']),
  BundledGif(id: 'love', label: 'LOVE', searchTerms: ['love', 'heart', 'like']),
  BundledGif(id: 'hey', label: 'HEY', searchTerms: ['hey', 'hi', 'hello']),
];

List<BundledGif> searchBundledGifs(String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return bundledGifs;
  return bundledGifs
      .where(
        (gif) =>
            gif.label.toLowerCase().contains(needle) ||
            gif.searchTerms.any((term) => term.contains(needle)),
      )
      .toList(growable: false);
}

String humanBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String durationLabel(int milliseconds) {
  final total = (milliseconds / 1000).round();
  final minutes = total ~/ 60;
  final seconds = total % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
