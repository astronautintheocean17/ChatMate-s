// test/link_text_test.dart
import 'package:chatmate/common/widgets/link-text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('splitLinks', () {
    test('leaves plain text alone', () {
      final segments = splitLinks('nothing to see here');
      expect(segments, hasLength(1));
      expect(segments.first.isLink, isFalse);
      expect(segments.first.text, 'nothing to see here');
    });

    test('finds an https link in the middle of a sentence', () {
      final segments = splitLinks(
        'look at https://example.com/page?q=1 before you answer',
      );

      expect(segments, hasLength(3));
      expect(segments[0].text, 'look at ');
      expect(segments[1].isLink, isTrue);
      expect(segments[1].text, 'https://example.com/page?q=1');
      expect(segments[1].url, 'https://example.com/page?q=1');
      expect(segments[2].text, ' before you answer');
    });

    test('normalizes bare www links', () {
      final segments = splitLinks('www.example.com');
      expect(segments, hasLength(1));
      expect(segments.first.text, 'www.example.com');
      expect(segments.first.url, 'https://www.example.com');
    });

    test('keeps trailing punctuation outside the link', () {
      final segments = splitLinks('read this: www.example.com.');

      expect(segments, hasLength(3));
      expect(segments[1].url, 'https://www.example.com');
      expect(segments[2].text, '.');
    });

    test('finds every link in a line', () {
      final segments = splitLinks('a https://one.dev b http://two.dev c');
      final links = segments.where((segment) => segment.isLink).toList();

      expect(links, hasLength(2));
      expect(links[0].url, 'https://one.dev');
      expect(links[1].url, 'http://two.dev');
    });

    test('empty input produces no segments', () {
      expect(splitLinks(''), isEmpty);
    });
  });

  group('hasLink', () {
    test('is true for http and www', () {
      expect(hasLink('go to http://a.b'), isTrue);
      expect(hasLink('go to www.a.b'), isTrue);
    });

    test('is false for plain text', () {
      expect(hasLink('see you at 8'), isFalse);
    });
  });

  group('normalizeUrl', () {
    test('adds https to www', () {
      expect(normalizeUrl('www.chatmate.app'), 'https://www.chatmate.app');
    });

    test('leaves an explicit scheme alone', () {
      expect(normalizeUrl('https://a.dev'), 'https://a.dev');
      expect(normalizeUrl('http://a.dev'), 'http://a.dev');
    });
  });
}
