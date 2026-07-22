import 'package:PiliPlus/utils/clipboard_link_parser.dart';

abstract final class ClipboardLinkSuppression {
  static String? _appGeneratedLink;

  static void markAppGeneratedText(String text) {
    _appGeneratedLink = ClipboardLinkParser.firstLink(text);
  }

  static bool consumeIfMatches(String? link) {
    final shouldSuppress = link != null && _appGeneratedLink == link;
    // The marker only applies to the next foreground clipboard check.
    _appGeneratedLink = null;
    return shouldSuppress;
  }
}
