abstract final class ClipboardLinkParser {
  static final _candidatePattern = RegExp(
    r'(?:(?:https?|bilibili)\s*[:：]\s*(?://|／／)|(?://|／／)|www\.|(?<![@\w])(?:(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}|(?:\d{1,3}\.){3}\d{1,3}|localhost))[^\s<>"“”‘’，。；：！？、（）【】《》〈〉「」『』]*',
    caseSensitive: false,
    unicode: true,
  );

  static final _schemePrefixPattern = RegExp(
    r'^(https?|bilibili)\s*[:：]\s*(?://|／／)',
    caseSensitive: false,
  );
  static final _whitespacePattern = RegExp(r'\s');

  static const _alwaysTrailing = '.,;:!?，。；：！？、…';
  static const _trailingQuotes = '\"\'”’》〉」』';
  static const _closingPairs = <String, String>{
    ')': '(',
    ']': '[',
    '}': '{',
    '）': '（',
    '】': '【',
    '》': '《',
    '〉': '〈',
  };

  static String? firstLink(String text) {
    if (text.trim().isEmpty) return null;

    var source = text;
    if (source.length > 65536) {
      final boundary = source.lastIndexOf(_whitespacePattern, 65535);
      if (boundary < 0) return null;
      source = source.substring(0, boundary);
    }
    final normalizedText = source
        .replaceAll('\u200B', '')
        .replaceAll('\u200C', '')
        .replaceAll('\u200D', '')
        .replaceAll('\uFEFF', '');

    for (final match in _candidatePattern.allMatches(normalizedText)) {
      var candidate = match.group(0)!;
      candidate = candidate.replaceFirstMapped(
        _schemePrefixPattern,
        (match) => '${match.group(1)!.toLowerCase()}://',
      );
      candidate = candidate
          .replaceAll('／', '/')
          .replaceAll('？', '?')
          .replaceAll('＆', '&')
          .replaceAll('＝', '=');
      candidate = candidate.replaceAll(
        RegExp('&amp;', caseSensitive: false),
        '&',
      );
      candidate = _trimTrailing(candidate);
      if (candidate.isEmpty) continue;

      if (candidate.startsWith('//')) {
        candidate = 'https:$candidate';
      } else if (!RegExp(
        r'^[a-z][a-z0-9+.-]*://',
        caseSensitive: false,
      ).hasMatch(candidate)) {
        candidate = 'https://$candidate';
      }

      final uri = Uri.tryParse(candidate);
      if (uri == null) continue;
      final scheme = uri.scheme.toLowerCase();
      if (scheme != 'http' && scheme != 'https' && scheme != 'bilibili') {
        continue;
      }
      if (uri.host.isEmpty) continue;

      try {
        return uri
            .replace(scheme: scheme, host: uri.host.toLowerCase())
            .toString();
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static String _trimTrailing(String value) {
    while (value.isNotEmpty) {
      final last = value[value.length - 1];
      if (_alwaysTrailing.contains(last) || _trailingQuotes.contains(last)) {
        value = value.substring(0, value.length - 1);
        continue;
      }

      final opening = _closingPairs[last];
      if (opening != null && _count(value, last) > _count(value, opening)) {
        value = value.substring(0, value.length - 1);
        continue;
      }
      break;
    }
    return value;
  }

  static int _count(String value, String character) {
    var count = 0;
    for (var i = 0; i < value.length; i++) {
      if (value[i] == character) count++;
    }
    return count;
  }
}
