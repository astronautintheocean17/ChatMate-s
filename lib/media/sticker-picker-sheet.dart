// lib/media/sticker-picker-sheet.dart
import 'package:flutter/material.dart';

import '../theme/app-theme.dart';
import 'media-catalog.dart';
import 'media-prefs.dart';

Future<StickerItem?> showStickerPicker(BuildContext context) {
  return showModalBottomSheet<StickerItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _StickerPickerSheet(),
  );
}

class _StickerPickerSheet extends StatefulWidget {
  const _StickerPickerSheet();

  @override
  State<_StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends State<_StickerPickerSheet> {
  List<String> _recent = const [];
  Set<String> _favorites = const {};
  int _tab = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final recent = await MediaPrefs.recentStickers();
    final favorites = await MediaPrefs.favoriteStickers();
    if (!mounted) return;
    setState(() {
      _recent = recent;
      _favorites = favorites;
      _loading = false;
    });
  }

  Future<void> _toggleFavorite(StickerItem item) async {
    final added = await MediaPrefs.toggleStickerFavorite(item.id);
    final favorites = await MediaPrefs.favoriteStickers();
    if (!mounted) return;
    setState(() => _favorites = favorites);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added ? 'Added to favourites.' : 'Removed from favourites.',
        ),
      ),
    );
  }

  void _choose(StickerItem item) {
    MediaPrefs.recordSticker(item.id);
    Navigator.pop(context, item);
  }

  List<StickerItem> get _tabItems {
    if (_tab == 0) {
      return _recent
          .map(stickerById)
          .whereType<StickerItem>()
          .toList(growable: false);
    }
    if (_tab == stickerPacks.length + 1) {
      return stickerPacks
          .expand((pack) => pack.items)
          .where((item) => _favorites.contains(item.id))
          .toList(growable: false);
    }
    return stickerPacks[_tab - 1].items;
  }

  String get _tabLabel {
    if (_tab == 0) return 'RECENT';
    if (_tab == stickerPacks.length + 1) return 'FAVOURITES';
    return stickerPacks[_tab - 1].name.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.62;
    final items = _tabItems;
    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 10, 2),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STICKERS',
                      style: AppText.mono(
                        9.5,
                        color: AppTheme.muted(context),
                        ls: 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _tabLabel,
                      style: AppText.serif(20, color: AppTheme.ink(context)),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                _PackChip(
                  label: 'RECENT',
                  active: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
                for (var index = 0; index < stickerPacks.length; index++)
                  _PackChip(
                    label: stickerPacks[index].name.toUpperCase(),
                    active: _tab == index + 1,
                    onTap: () => setState(() => _tab = index + 1),
                  ),
                _PackChip(
                  label: 'FAVOURITES',
                  active: _tab == stickerPacks.length + 1,
                  onTap: () => setState(() => _tab = stickerPacks.length + 1),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accent(context),
                    ),
                  )
                : items.isEmpty
                ? _StickerEmpty(
                    favourites: _tab == stickerPacks.length + 1,
                    recent: _tab == 0,
                    onBrowse: () => setState(() => _tab = 1),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                    itemCount: items.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                          childAspectRatio: 1,
                        ),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _StickerTile(
                        item: item,
                        favourite: _favorites.contains(item.id),
                        onTap: () => _choose(item),
                        onLongPress: () => _toggleFavorite(item),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
              child: Text(
                'Long-press a sticker to favourite it. Stickers are bundled '
                'with the app — no upload.',
                style: AppText.mono(
                  7.5,
                  color: AppTheme.muted(context),
                  ls: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackChip extends StatelessWidget {
  const _PackChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accent(context);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: active ? accent : Colors.transparent,
            border: Border.all(color: active ? accent : AppTheme.line(context)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: AppText.mono(
              7.5,
              color: active ? Colors.white : AppTheme.muted(context),
              ls: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

class _StickerTile extends StatelessWidget {
  const _StickerTile({
    required this.item,
    required this.favourite,
    required this.onTap,
    required this.onLongPress,
  });

  final StickerItem item;
  final bool favourite;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bg(context),
          border: Border.all(color: AppTheme.line(context)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(5),
              child: Image.asset(
                item.assetPath,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
            if (favourite)
              Positioned(
                top: 3,
                right: 3,
                child: Icon(
                  Icons.star_rounded,
                  size: 13,
                  color: AppTheme.accent(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StickerEmpty extends StatelessWidget {
  const _StickerEmpty({
    required this.favourites,
    required this.recent,
    required this.onBrowse,
  });

  final bool favourites;
  final bool recent;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              favourites
                  ? 'No favourites yet.'
                  : recent
                  ? 'No recent stickers yet.'
                  : 'Nothing here yet.',
              textAlign: TextAlign.center,
              style: AppText.serif(21, color: AppTheme.ink(context)),
            ),
            const SizedBox(height: 7),
            Text(
              favourites
                  ? 'Long-press any sticker to keep it close.'
                  : 'Pick one and it will appear here next time.',
              textAlign: TextAlign.center,
              style: AppText.body(12, color: AppTheme.muted(context), h: 1.5),
            ),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onBrowse, child: const Text('BROWSE')),
          ],
        ),
      ),
    );
  }
}
