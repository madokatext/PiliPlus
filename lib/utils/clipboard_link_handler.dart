import 'dart:async' show unawaited;

import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/clipboard_link_parser.dart';
import 'package:PiliPlus/utils/clipboard_link_suppression.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/services.dart' show Clipboard, PlatformException;
import 'package:flutter/widgets.dart';

final class ClipboardLinkHandler with WidgetsBindingObserver {
  ClipboardLinkHandler._();

  static final instance = ClipboardLinkHandler._();

  bool _started = false;
  bool _wasInBackground = false;
  bool _processing = false;

  void start() {
    if (_started || !PlatformUtils.isMobile) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
  }

  void stop() {
    if (!_started) return;
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
    _wasInBackground = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case .paused || .hidden:
        _wasInBackground = true;
        break;
      case .resumed:
        if (_wasInBackground) {
          _wasInBackground = false;
          unawaited(_readAndOpenLink());
        }
        break;
      case .inactive || .detached:
        break;
    }
  }

  Future<void> _readAndOpenLink() async {
    if (_processing || !Pref.openClipboardLinkOnResume) return;
    _processing = true;
    try {
      // Give app-links a chance to handle an Intent delivered by the same resume.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!_started || WidgetsBinding.instance.lifecycleState != .resumed) {
        return;
      }

      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final link = ClipboardLinkParser.firstLink(data?.text ?? '');
      if (!_started) return;
      final suppressAppGenerated = ClipboardLinkSuppression.consumeIfMatches(
        link,
      );
      if (link == null) return;
      if (suppressAppGenerated) {
        await GStorage.localCache.put(LocalCacheKey.lastClipboardLink, link);
        return;
      }

      final lastLink = GStorage.localCache.get(LocalCacheKey.lastClipboardLink);
      if (lastLink == link) return;

      // Persist before navigation to prevent overlapping resume callbacks from
      // opening the same clipboard entry twice.
      await GStorage.localCache.put(LocalCacheKey.lastClipboardLink, link);
      if (PiliScheme.receivedExternalLinkRecently) return;

      if (Pref.openInBrowser) {
        await PiliScheme.routePushFromUrl(
          link,
          selfHandle: true,
          external: true,
        );
      } else {
        await PiliScheme.routePushFromUrl(link, external: true);
      }
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('read clipboard failed: $e');
    } catch (e) {
      if (kDebugMode) debugPrint('open clipboard link failed: $e');
    } finally {
      _processing = false;
    }
  }
}
