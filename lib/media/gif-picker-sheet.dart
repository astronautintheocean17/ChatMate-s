// lib/media/gif-picker-sheet.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app-theme.dart';
import 'giphy-service.dart';
import 'media-catalog.dart';
import 'media-prefs.dart';
import 'media-service.dart';

class GifChoice {
  const GifChoice.bundled(this.bundled) : online = null, file = null;
  const GifChoice.online(this.online) : bundled = null, file = null;
  const GifChoice.local(this.file) : bundled = null, online = null;

  final BundledGif? bundled;
  final GifSearchResult? online;
  final XFile? file;
}

Future<GifChoice?> showGifPicker(BuildContext context) {
  return showModalBottomSheet<GifChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _GifPickerSheet(),
  );
}

class _GifPickerSheet extends StatefulWidget {
  const _GifPickerSheet();

  @override
  State<_GifPickerSheet> createState() => _GifPickerSheetState();
}

class _GifPickerSheetState extends State<_GifPickerSheet> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<RecentGif> _recent = const [];
  List<GifSearchResult> _online = const [];
  bool _loading = false;
  bool _loadedTrending = false;
  String? _error;
  int _mode = 0;

  @override
  void initState() {
    super.initState();
    _loadRecent();
    if (GiphyConfig.enabled) {
      _loadOnline();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final recent = await MediaPrefs.recentGifs();
    if (!mounted) return;
    setState(() => _recent = recent);
  }

  Future<void> _loadOnline({String? query}) async {
    if (!GiphyConfig.enabled) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = (query == null || query.trim().isEmpty)
          ? await GiphyService.trending()
          : await GiphyService.search(query);
      if (!mounted) return;
      setState(() {
        _online = results;
        _loadedTrending = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _loadOnline(query: value);
    });
  }

  void _setMode(int mode) {
    setState(() => _mode = mode);
    if (mode == 2 && !_loadedTrending && !_loading) {
      _loadOnline();
    }
    if (mode == 1) _loadRecent();
  }

  Future<void> _pickFile() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    try {
      final bytes = await picked.readAsBytes();
      if (!MediaService.isGifBytes(bytes)) {
        throw const MediaException('That image is not a GIF.');
      }
      if (!mounted) return;
      Navigator.pop(context, GifChoice.local(picked));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.78;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 0),
              child: Row(
                children: [
                  Text(
                    'GIFS',
                    style: AppText.mono(
                      9.5,
                      color: AppTheme.muted(context),
                      ls: 1.4,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Pick a GIF from your gallery',
                    onPressed: _pickFile,
                    icon: const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 19,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
              child: Row(
                children: [
                  _ModeChip(
                    label: 'BUNDLED',
                    active: _mode == 0,
                    onTap: () => _setMode(0),
                  ),
                  const SizedBox(width: 7),
                  _ModeChip(
                    label: 'RECENT',
                    active: _mode == 1,
                    onTap: () => _setMode(1),
                  ),
                  const SizedBox(width: 7),
                  _ModeChip(
                    label: 'ONLINE',
                    active: _mode == 2,
                    onTap: () => _setMode(2),
                  ),
                ],
              ),
            ),
            if (_mode == 2 && GiphyConfig.enabled)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.bg(context),
                    border: Border.all(color: AppTheme.line(context)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  child: TextField(
                    controller: _search,
                    onChanged: _onSearch,
                    textInputAction: TextInputAction.search,
                    style: AppText.body(13, color: AppTheme.ink(context)),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 17,
                        color: AppTheme.muted(context),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 30,
                        minHeight: 20,
                      ),
                      hintText: 'Search Giphy',
                      hintStyle: AppText.body(
                        12.5,
                        color: AppTheme.muted(context),
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _mode == 0
                  ? _buildBundled()
                  : _mode == 1
                  ? _buildRecent()
                  : _buildOnline(),
            ),
            if (_mode == 2 && GiphyConfig.enabled)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Powered by GIPHY',
                    style: AppText.mono(
                      8,
                      color: AppTheme.muted(context),
                      ls: 1.1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _chooseBundled(BundledGif gif) {
    unawaited(MediaPrefs.recordGif(bundled: gif));
    Navigator.pop(context, GifChoice.bundled(gif));
  }

  void _chooseOnline(GifSearchResult gif) {
    unawaited(MediaPrefs.recordGif(online: gif));
    Navigator.pop(context, GifChoice.online(gif));
  }

  Widget _buildBundled() {
    return _GifGrid(
      children: [
        for (final gif in bundledGifs)
          _GifTile(
            label: gif.label,
            image: Image.asset(gif.assetPath, fit: BoxFit.cover),
            onTap: () => _chooseBundled(gif),
          ),
      ],
    );
  }

  Widget _buildRecent() {
    if (_recent.isEmpty) {
      return _GifEmpty(
        title: 'No recent GIFs yet.',
        body: 'The GIFs you send will show up here.',
        onAction: () => _setMode(0),
        actionLabel: 'BROWSE BUNDLED',
      );
    }
    return _GifGrid(
      children: [
        for (final gif in _recent)
          _GifTile(
            label: gif.label,
            image: gif.bundled != null
                ? Image.asset(gif.bundled!.assetPath, fit: BoxFit.cover)
                : Image.network(
                    gif.previewUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
            onTap: () {
              if (gif.bundled != null) {
                _chooseBundled(gif.bundled!);
              } else {
                _chooseOnline(gif.online!);
              }
            },
          ),
      ],
    );
  }

  Widget _buildOnline() {
    if (!GiphyConfig.enabled) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.public_off_rounded,
                size: 30,
                color: AppTheme.muted(context),
              ),
              const SizedBox(height: 14),
              Text(
                'Online GIF search is off.',
                textAlign: TextAlign.center,
                style: AppText.serif(22, color: AppTheme.ink(context)),
              ),
              const SizedBox(height: 8),
              Text(
                'Bundled GIFs work with no key and no network. To enable '
                'Giphy trending and search, run with:\n'
                '--dart-define=GIPHY_API_KEY=your_key',
                textAlign: TextAlign.center,
                style: AppText.body(
                  11.5,
                  color: AppTheme.muted(context),
                  h: 1.55,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => _setMode(0),
                child: const Text('BROWSE BUNDLED'),
              ),
            ],
          ),
        ),
      );
    }
    if (_loading && _online.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppTheme.accent(context),
        ),
      );
    }
    if (_error != null && _online.isEmpty) {
      return _GifEmpty(
        title: 'GIF search is unavailable.',
        body: _error!,
        onAction: () => _loadOnline(query: _search.text),
        actionLabel: 'TRY AGAIN',
      );
    }
    if (_online.isEmpty) {
      return _GifEmpty(
        title: 'No GIFs found.',
        body: 'Try a different word.',
        onAction: () => _loadOnline(),
        actionLabel: 'SHOW TRENDING',
      );
    }
    return _GifGrid(
      children: [
        for (final gif in _online)
          _GifTile(
            image: Image.network(
              gif.previewUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Center(
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.4,
                          color: AppTheme.accent(context),
                        ),
                      ),
                    ),
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            onTap: () => _chooseOnline(gif),
          ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
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
    return InkWell(
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
            8,
            color: active ? Colors.white : AppTheme.muted(context),
            ls: 1,
          ),
        ),
      ),
    );
  }
}

class _GifGrid extends StatelessWidget {
  const _GifGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.45,
      children: children,
    );
  }
}

class _GifTile extends StatelessWidget {
  const _GifTile({required this.image, required this.onTap, this.label});

  final Widget image;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.black, child: image),
            if (label != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 14, 8, 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.72),
                      ],
                    ),
                  ),
                  child: Text(
                    label!,
                    style: AppText.mono(8, color: Colors.white, ls: 1.2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GifEmpty extends StatelessWidget {
  const _GifEmpty({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.serif(22, color: AppTheme.ink(context)),
            ),
            const SizedBox(height: 7),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppText.body(12, color: AppTheme.muted(context), h: 1.5),
            ),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
