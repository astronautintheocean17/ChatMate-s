// lib/common/widgets/link-text.dart
// Clickable http / https / www links inside message bodies and captions.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app-theme.dart';

class LinkSegment {
  final String text;
  final String? url;

  const LinkSegment(this.text, this.url);

  bool get isLink => url != null;

  @override
  String toString() => 'LinkSegment($text, $url)';
}

final RegExp _linkPattern = RegExp(
  r'https?://[^\s<>]+|www\.[^\s<>]+',
  caseSensitive: false,
);

const String _trailingPunctuation = ".,;:!?)]}'";

/// Splits free text into plain and link segments.
///
/// Trailing punctuation is kept outside the link so that a sentence such as
/// "read this: www.example.com." still ends with a normal full stop.
List<LinkSegment> splitLinks(String text) {
  if (text.isEmpty) return const [];

  final segments = <LinkSegment>[];
  var cursor = 0;

  for (final match in _linkPattern.allMatches(text)) {
    var end = match.end;
    while (end > match.start && _trailingPunctuation.contains(text[end - 1])) {
      end--;
    }
    if (end <= match.start) continue;

    if (match.start > cursor) {
      segments.add(LinkSegment(text.substring(cursor, match.start), null));
    }
    final raw = text.substring(match.start, end);
    segments.add(LinkSegment(raw, normalizeUrl(raw)));
    cursor = end;
  }

  if (cursor < text.length) {
    segments.add(LinkSegment(text.substring(cursor), null));
  }

  return segments;
}

/// `www.example.com` is a link, but the platform needs a scheme to open it.
String normalizeUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.toLowerCase().startsWith('www.')) return 'https://$trimmed';
  return trimmed;
}

bool hasLink(String text) => _linkPattern.hasMatch(text);

Future<bool> openLink(String url) async {
  final uri = Uri.tryParse(normalizeUrl(url));
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Text that turns links into tappable spans without losing the wrapping and
/// the truncation behaviour of a normal [Text].
class LinkText extends StatefulWidget {
  const LinkText(
    this.text, {
    super.key,
    required this.style,
    this.linkColor,
    this.maxLines,
    this.textAlign,
  });

  final String text;
  final TextStyle style;
  final Color? linkColor;
  final int? maxLines;
  final TextAlign? textAlign;

  @override
  State<LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<LinkText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  void _clearRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();

    final segments = splitLinks(widget.text);
    final linkColor = widget.linkColor ?? AppTheme.accent(context);

    if (segments.isEmpty || !segments.any((segment) => segment.isLink)) {
      return Text(
        widget.text,
        style: widget.style,
        maxLines: widget.maxLines,
        overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
        textAlign: widget.textAlign,
      );
    }

    final spans = <InlineSpan>[];
    for (final segment in segments) {
      if (!segment.isLink) {
        spans.add(TextSpan(text: segment.text));
        continue;
      }
      final recognizer = TapGestureRecognizer()
        ..onTap = () => openLink(segment.url!);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: segment.text,
          recognizer: recognizer,
          style: TextStyle(
            color: linkColor,
            decoration: TextDecoration.underline,
            decorationColor: linkColor.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
      textAlign: widget.textAlign,
    );
  }
}
