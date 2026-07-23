import 'dart:io';
import 'dart:typed_data';

import 'package:PiliPlus/utils/latin_font_subset.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

enum LocalFontSlot {
  appChinese(
    label: 'App 中文字体',
    filePrefix: 'app_zh',
    fileKey: SettingBoxKey.appChineseFontFile,
    nameKey: SettingBoxKey.appChineseFontName,
    sample: '中文字体预览：天地玄黄',
  ),
  appEnglish(
    label: 'App 英文字体',
    filePrefix: 'app_en',
    fileKey: SettingBoxKey.appEnglishFontFile,
    nameKey: SettingBoxKey.appEnglishFontName,
    sample: 'English font preview: Aa 123',
  ),
  danmakuChinese(
    label: '弹幕中文字体',
    filePrefix: 'danmaku_zh',
    fileKey: SettingBoxKey.danmakuChineseFontFile,
    nameKey: SettingBoxKey.danmakuChineseFontName,
    sample: '中文弹幕预览：前方高能',
  ),
  danmakuEnglish(
    label: '弹幕英文字体',
    filePrefix: 'danmaku_en',
    fileKey: SettingBoxKey.danmakuEnglishFontFile,
    nameKey: SettingBoxKey.danmakuEnglishFontName,
    sample: 'Danmaku font preview: Aa 123',
  );

  const LocalFontSlot({
    required this.label,
    required this.filePrefix,
    required this.fileKey,
    required this.nameKey,
    required this.sample,
  });

  final String label;
  final String filePrefix;
  final String fileKey;
  final String nameKey;
  final String sample;

  bool get usesLatinSubset =>
      this == LocalFontSlot.appEnglish || this == LocalFontSlot.danmakuEnglish;
}

typedef LocalFontFamilies = ({
  String? primary,
  List<String> fallback,
});
class LocalFontCandidate {
  const LocalFontCandidate({
    required this.slot,
    required this.fileName,
    required this.sourceName,
    required this.family,
    required this.bytes,
  });

  final LocalFontSlot slot;
  final String fileName;
  final String sourceName;
  final String family;
  final Uint8List bytes;
}
abstract final class LocalFontManager {
  static const _fontDirectoryName = 'local_fonts';
  static const _latinSubsetCacheVersion = 'latin_v1';
  static const _allowedExtensions = <String>{'.ttf', '.otf', '.ttc'};

  static final Map<LocalFontSlot, String> _loadedFamilies = {};
  static final Set<String> _registeredFamilies = {};

  static Directory get _fontDirectory =>
      Directory(path.join(appSupportDirPath, _fontDirectoryName));

  static Future<void> loadSavedFonts() async {
    for (final slot in LocalFontSlot.values) {
      final fileName = _storedFileName(slot);
      if (fileName.isEmpty) {
        continue;
      }
      try {
        final fontFile = await _prepareSavedFont(slot, fileName);
        await _loadFont(slot, fontFile);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to load ${slot.label}: $e');
        }
      }
    }
    await _cleanupUnusedFontFilesQuietly();
  }

    /// 选择并解析字体，但不修改当前配置。
  ///
  /// 返回的字体只用于设置弹窗内预览；只有调用 [commitCandidate]
  /// 后才会写入文件、保存设置并成为当前字体。
  static Future<LocalFontCandidate?> pickCandidate(
    LocalFontSlot slot,
  ) async {
    final result = await FilePicker.pickFile(
      type: .custom,
      allowedExtensions: const ['ttf', 'otf', 'ttc'],
    );

    if (result == null) {
      return null;
    }

    final sourceName = path.basename(result.xFile.name);
    final extension = path.extension(sourceName).toLowerCase();

    if (!_allowedExtensions.contains(extension)) {
      throw const FormatException('仅支持 TTF、OTF 和 TTC 字体文件');
    }

    final sourceBytes = await result.xFile.readAsBytes();

    if (sourceBytes.isEmpty) {
      throw const FormatException('字体文件为空');
    }

    final fontBytes = slot.usesLatinSubset
        ? await compute(createLatinFontSubset, sourceBytes)
        : sourceBytes;

    final digest = sha256.convert(sourceBytes).toString();
    final cacheExtension = slot.usesLatinSubset
        ? latinSubsetFileExtension(fontBytes)
        : extension;
    final cacheMarker = slot.usesLatinSubset
        ? '_${_latinSubsetCacheVersion}_'
        : '_';

    final fileName =
        '${slot.filePrefix}$cacheMarker$digest$cacheExtension';

    // 注册字体只为了弹窗预览，不写入 _loadedFamilies，
    // 因此不会影响 App 或弹幕当前使用的字体。
    final family = await _registerFontBytes(
      slot,
      fileName,
      fontBytes,
    );

    return LocalFontCandidate(
      slot: slot,
      fileName: fileName,
      sourceName: sourceName,
      family: family,
      bytes: fontBytes,
    );
  }

  /// 确认使用候选字体。
  static Future<void> commitCandidate(
    LocalFontCandidate candidate,
  ) async {
    final slot = candidate.slot;
    final oldFileName = _storedFileName(slot);
    final fontFile = _fontFile(candidate.fileName);

    await fontFile.parent.create(recursive: true);
    await fontFile.writeAsBytes(candidate.bytes, flush: true);

    try {
      await GStorage.setting.putAll({
        slot.fileKey: candidate.fileName,
        slot.nameKey: candidate.sourceName,
      });
    } catch (_) {
      // 配置保存失败时保留旧配置，并删除本次新写入的文件。
      if (oldFileName != candidate.fileName) {
        await _deleteFileQuietly(fontFile, slot.label);
      }
      rethrow;
    }

    // 只有设置成功写入后，才切换当前活动字体。
    _loadedFamilies[slot] = candidate.family;

    await _cleanupUnusedFontFilesQuietly();
  }

  /// 保留旧接口，供其它可能存在的调用位置使用。
  static Future<bool> pickAndInstall(LocalFontSlot slot) async {
    final candidate = await pickCandidate(slot);

    if (candidate == null) {
      return false;
    }

    await commitCandidate(candidate);
    return true;
  }

  static Future<File> _prepareSavedFont(
    LocalFontSlot slot,
    String fileName,
  ) async {
    final savedFile = _fontFile(fileName);
    if (!slot.usesLatinSubset ||
        fileName.startsWith(
          '${slot.filePrefix}_${_latinSubsetCacheVersion}_',
        )) {
      return savedFile;
    }
    if (!await savedFile.exists()) {
      throw const FileSystemException('字体文件不存在');
    }

    final sourceBytes = await savedFile.readAsBytes();
    final subsetBytes = await compute(createLatinFontSubset, sourceBytes);
    final digest = sha256.convert(sourceBytes).toString();
    final subsetFileName =
        '${slot.filePrefix}_${_latinSubsetCacheVersion}_$digest'
        '${latinSubsetFileExtension(subsetBytes)}';
    final subsetFile = _fontFile(subsetFileName);
    await subsetFile.writeAsBytes(subsetBytes, flush: true);
    try {
      await GStorage.setting.put(slot.fileKey, subsetFileName);
    } catch (_) {
      await _deleteFileQuietly(subsetFile, slot.label);
      rethrow;
    }
    return subsetFile;
  }

  static Future<void> reset(LocalFontSlot slot) async {
    final oldFileName = _storedFileName(slot);
    await GStorage.setting.deleteAll([slot.fileKey, slot.nameKey]);
    _loadedFamilies.remove(slot);
    if (oldFileName.isNotEmpty) {
      await _deleteManagedFile(slot, oldFileName);
    }
  }

  static bool isConfigured(LocalFontSlot slot) =>
      _storedFileName(slot).isNotEmpty;

  static String selectionLabel(LocalFontSlot slot) {
    final fileName = _storedFileName(slot);
    if (fileName.isEmpty) {
      return '系统默认';
    }
    final displayName = GStorage.setting.get(
      slot.nameKey,
      defaultValue: fileName,
    );
    final suffix = _loadedFamilies.containsKey(slot) ? '' : '（文件不可用）';
    return '$displayName$suffix';
  }

  static String? familyFor(LocalFontSlot slot) => _loadedFamilies[slot];

  static LocalFontFamilies get appFontFamilies => _familiesFor(
    chinese: .appChinese,
    english: .appEnglish,
  );

  static LocalFontFamilies get danmakuFontFamilies => _familiesFor(
    chinese: .danmakuChinese,
    english: .danmakuEnglish,
  );

  static LocalFontFamilies _familiesFor({
    required LocalFontSlot chinese,
    required LocalFontSlot english,
  }) {
    final englishFamily = familyFor(english);
    final chineseFamily = familyFor(chinese);
    if (englishFamily != null) {
      return (
        primary: englishFamily,
        fallback: [?chineseFamily],
      );
    }
    if (chineseFamily != null) {
      return (
        primary: _systemLatinFontFamily,
        fallback: [chineseFamily],
      );
    }
    return (primary: null, fallback: const <String>[]);
  }

  static String get _systemLatinFontFamily {
    if (Platform.isAndroid) {
      return 'Roboto';
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return 'CupertinoSystemText';
    }
    if (Platform.isWindows) {
      return 'Segoe UI';
    }
    return 'sans-serif';
  }

    static Future<void> _loadFont(
    LocalFontSlot slot,
    File file, {
    Uint8List? bytes,
  }) async {
    if (!await file.exists()) {
      throw const FileSystemException('字体文件不存在');
    }

    final fileName = path.basename(file.path);
    final fontBytes = bytes ?? await file.readAsBytes();

    _loadedFamilies[slot] = await _registerFontBytes(
      slot,
      fileName,
      fontBytes,
    );
  }

  /// 把字体注册到 Flutter 字体系统，但不设置为当前活动字体。
  static Future<String> _registerFontBytes(
    LocalFontSlot slot,
    String fileName,
    Uint8List bytes,
  ) async {
    if (!fileName.startsWith('${slot.filePrefix}_')) {
      throw const FormatException('字体文件名无效');
    }

    final family =
        'PiliPlusLocalFont_${path.basenameWithoutExtension(fileName)}';

    if (!_registeredFamilies.contains(family)) {
      final loader = FontLoader(family)
        ..addFont(
          Future<ByteData>.value(
            ByteData.sublistView(bytes),
          ),
        );

      await loader.load();
      _registeredFamilies.add(family);
    }

    return family;
  }

  static String _storedFileName(LocalFontSlot slot) {
    final value = GStorage.setting.get(
      slot.fileKey,
      defaultValue: '',
    );
    return value is String ? path.basename(value) : '';
  }

  static File _fontFile(String fileName) =>
      File(path.join(_fontDirectory.path, path.basename(fileName)));

  static Future<void> _deleteManagedFile(
    LocalFontSlot slot,
    String fileName,
  ) async {
    final safeName = path.basename(fileName);
    if (!safeName.startsWith('${slot.filePrefix}_')) {
      return;
    }
    await _deleteFileQuietly(_fontFile(safeName), slot.label);
  }

  static Future<void> _cleanupUnusedFontFilesQuietly() async {
    final activeFileNames = LocalFontSlot.values
        .map(_storedFileName)
        .where((fileName) => fileName.isNotEmpty)
        .toSet();
    try {
      if (!await _fontDirectory.exists()) {
        return;
      }
      await for (final entity in _fontDirectory.list(followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        final fileName = path.basename(entity.path);
        if (activeFileNames.contains(fileName) ||
            !_allowedExtensions.contains(
              path.extension(fileName).toLowerCase(),
            )) {
          continue;
        }
        await _deleteFileQuietly(entity, '字体缓存');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to scan old font cache: $e');
      }
    }
  }

  static Future<void> _deleteFileQuietly(
    File file,
    String label,
  ) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to delete old $label: $e');
      }
    }
  }
}
