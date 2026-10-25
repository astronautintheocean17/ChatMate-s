// lib/data/room-link-service.dart
/// Builds and reads the share-link format for a room.
///
/// A room link is the app's current URL with `?room=CODE`, for example:
/// `https://chatmate.example/?room=ABC123`.
class RoomLinkService {
  RoomLinkService._();

  static final RegExp _codePattern = RegExp(r'^[A-Z0-9]{6}$');

  /// A deployed origin can be supplied for non-web builds or when the app is
  /// served from a file URL:
  /// `--dart-define=CHATMATE_APP_ORIGIN=https://chatmate.example`
  static const String _configuredOrigin = String.fromEnvironment(
    'CHATMATE_APP_ORIGIN',
  );

  static String? normalizeCode(String? value) {
    final code = (value ?? '').trim().toUpperCase();
    return _codePattern.hasMatch(code) ? code : null;
  }

  /// Reads the first valid room code from the query string, fragment query or
  /// `/join/CODE` style path.
  static String? codeFromUri(Uri uri) {
    for (final key in const ['room', 'join', 'code']) {
      final code = normalizeCode(uri.queryParameters[key]);
      if (code != null) return code;
    }

    final fragment = uri.fragment;
    if (fragment.isNotEmpty) {
      final fragmentUri = Uri.tryParse(
        fragment.startsWith('/') ? fragment.substring(1) : fragment,
      );
      if (fragmentUri != null) {
        for (final key in const ['room', 'join', 'code']) {
          final code = normalizeCode(fragmentUri.queryParameters[key]);
          if (code != null) return code;
        }
      }
      final fragmentCode = normalizeCode(fragment.split('/').last);
      if (fragmentCode != null) return fragmentCode;
    }

    for (final segment in uri.pathSegments.reversed) {
      final code = normalizeCode(segment);
      if (code != null) return code;
    }
    return null;
  }

  static String? codeFromCurrentUrl() => codeFromUri(Uri.base);

  /// Builds a link that survives a static Flutter web deployment. The current
  /// path is kept; the previous query and fragment are replaced.
  static String linkForCode(String code, {Uri? base}) {
    final normalized = normalizeCode(code);
    if (normalized == null) {
      throw ArgumentError.value(code, 'code', 'A room code is 6 characters.');
    }

    var uri = base ?? Uri.base;
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      if (_configuredOrigin.isEmpty) {
        return '?room=$normalized';
      }
      uri = Uri.parse(_configuredOrigin);
    }

    final link = uri
        .replace(queryParameters: {'room': normalized}, fragment: '')
        .toString();
    return link.endsWith('#') ? link.substring(0, link.length - 1) : link;
  }
}
