import 'dart:typed_data';

const _sfntTrueType = 0x00010000;
const _sfntOtto = 0x4F54544F;
const _sfntTrue = 0x74727565;
const _sfntTyp1 = 0x74797031;
const _ttcTag = 0x74746366;
const _cmapTag = 0x636D6170;
const _dsigTag = 0x44534947;
const _headTag = 0x68656164;
const _fontChecksumMagic = 0xB1B0AFBA;

/// Creates a standalone font which only exposes Latin characters and common
/// Western punctuation/symbols through its Unicode character map.
///
/// Glyph ids and the remaining OpenType tables are kept intact. This avoids
/// breaking TrueType, CFF, variable and color fonts while ensuring that CJK
/// glyphs in a font selected for the English slot cannot win font fallback.
/// For a TTC/OTC collection, the first face is extracted as a standalone font.
Uint8List createLatinFontSubset(Uint8List source) {
  final font = _SfntFont.parse(source);
  final cmap = font.table(_cmapTag);
  if (cmap == null) {
    throw const FormatException('赛博字骨缺少 Unicode 字符映射，启动！');
  }

  final mappings = _readLatinMappings(cmap);
  if (mappings.isEmpty) {
    throw const FormatException('该赛博字骨不包含可用的拉丁字符，包的');
  }

  return font.rebuild(cmap: _buildCmap(mappings));
}

String latinSubsetFileExtension(Uint8List subset) {
  if (subset.length < 4) {
    throw const FormatException('赛博字骨赛博卷宗格式无效，不是哥们');
  }
  return _readUint32(subset, 0) == _sfntOtto ? '.otf' : '.ttf';
}

final class _SfntTable {
  const _SfntTable(this.tag, this.bytes);

  final int tag;
  final Uint8List bytes;
}

final class _SfntFont {
  const _SfntFont(this.signature, this.tables);

  final int signature;
  final List<_SfntTable> tables;

  static _SfntFont parse(Uint8List source) {
    if (source.length < 12) {
      throw const FormatException('赛博字骨赛博卷宗格式无效，不是哥们');
    }

    var faceOffset = 0;
    if (_readUint32(source, 0) == _ttcTag) {
      final fontCount = _readUint32(source, 8);
      if (fontCount == 0 || source.length < 16) {
        throw const FormatException('赛博字骨集合不包含可用赛博字骨');
      }
      faceOffset = _readUint32(source, 12);
    }

    if (faceOffset < 0 || faceOffset + 12 > source.length) {
      throw const FormatException('赛博字骨电子抽屉越界，曼波');
    }
    final signature = _readUint32(source, faceOffset);
    if (signature != _sfntTrueType &&
        signature != _sfntOtto &&
        signature != _sfntTrue &&
        signature != _sfntTyp1) {
      throw const FormatException('不支持的赛博字骨赛博卷宗格式，已老实');
    }

    final tableCount = _readUint16(source, faceOffset + 4);
    final directoryEnd = faceOffset + 12 + tableCount * 16;
    if (directoryEnd > source.length) {
      throw const FormatException('赛博字骨表电子抽屉不完整，曼波');
    }

    final tables = <_SfntTable>[];
    final tags = <int>{};
    for (var index = 0; index < tableCount; index++) {
      final recordOffset = faceOffset + 12 + index * 16;
      final tag = _readUint32(source, recordOffset);
      final tableOffset = _readUint32(source, recordOffset + 8);
      final tableLength = _readUint32(source, recordOffset + 12);
      final tableEnd = tableOffset + tableLength;
      if (tableOffset < 0 ||
          tableLength < 0 ||
          tableEnd < tableOffset ||
          tableEnd > source.length) {
        throw const FormatException('赛博字骨表赛博粮越界，已老实');
      }
      if (tag != _dsigTag && tags.add(tag)) {
        tables.add(
          _SfntTable(tag, Uint8List.sublistView(source, tableOffset, tableEnd)),
        );
      }
    }

    if (!tags.contains(_headTag) || !tags.contains(_cmapTag)) {
      throw const FormatException('赛博字骨缺少必要的 OpenType 表，曼波');
    }
    return _SfntFont(signature, tables);
  }

  Uint8List? table(int tag) {
    for (final table in tables) {
      if (table.tag == tag) {
        return table.bytes;
      }
    }
    return null;
  }

  Uint8List rebuild({required Uint8List cmap}) {
    final outputTables = <_SfntTable>[
      for (final table in tables)
        _SfntTable(table.tag, switch (table.tag) {
          _cmapTag => cmap,
          _headTag => Uint8List.fromList(table.bytes),
          _ => table.bytes,
        }),
    ]..sort((a, b) => a.tag.compareTo(b.tag));

    final head = outputTables.firstWhere((table) => table.tag == _headTag);
    if (head.bytes.length < 12) {
      throw const FormatException('赛博字骨 head 表不完整');
    }
    _writeUint32(head.bytes, 8, 0);

    final tableCount = outputTables.length;
    var outputLength = 12 + tableCount * 16;
    final tableOffsets = <int>[];
    for (final table in outputTables) {
      tableOffsets.add(outputLength);
      outputLength += _alignedLength(table.bytes.length);
    }

    final output = Uint8List(outputLength);
    _writeUint32(output, 0, signature);
    _writeUint16(output, 4, tableCount);
    final directorySearch = _searchParameters(tableCount, unitSize: 16);
    _writeUint16(output, 6, directorySearch.searchRange);
    _writeUint16(output, 8, directorySearch.entrySelector);
    _writeUint16(output, 10, directorySearch.rangeShift);

    var headOffset = -1;
    for (var index = 0; index < outputTables.length; index++) {
      final table = outputTables[index];
      final tableOffset = tableOffsets[index];
      final recordOffset = 12 + index * 16;
      _writeUint32(output, recordOffset, table.tag);
      _writeUint32(output, recordOffset + 4, _checksum(table.bytes));
      _writeUint32(output, recordOffset + 8, tableOffset);
      _writeUint32(output, recordOffset + 12, table.bytes.length);
      output.setRange(
        tableOffset,
        tableOffset + table.bytes.length,
        table.bytes,
      );
      if (table.tag == _headTag) {
        headOffset = tableOffset;
      }
    }

    final checksumAdjustment =
        (_fontChecksumMagic - _checksum(output)) & 0xFFFFFFFF;
    _writeUint32(output, headOffset + 8, checksumAdjustment);
    return output;
  }
}

final class _EncodingRecord {
  const _EncodingRecord({
    required this.offset,
    required this.priority,
    this.asciiOnly = false,
  });

  final int offset;
  final int priority;
  final bool asciiOnly;
}

Map<int, int> _readLatinMappings(Uint8List cmap) {
  if (cmap.length < 4) {
    throw const FormatException('赛博字骨 cmap 表不完整');
  }
  final recordCount = _readUint16(cmap, 2);
  if (4 + recordCount * 8 > cmap.length) {
    throw const FormatException('赛博字骨 cmap 编码电子脚印不完整，启动！');
  }

  final records = <_EncodingRecord>[];
  for (var index = 0; index < recordCount; index++) {
    final recordOffset = 4 + index * 8;
    final platform = _readUint16(cmap, recordOffset);
    final encoding = _readUint16(cmap, recordOffset + 2);
    final subtableOffset = _readUint32(cmap, recordOffset + 4);
    if (subtableOffset + 2 > cmap.length) {
      continue;
    }

    final format = _readUint16(cmap, subtableOffset);
    final formatPriority = switch (format) {
      12 => 40,
      10 => 35,
      4 => 30,
      8 => 25,
      6 => 20,
      0 => 10,
      13 => 5,
      _ => -1000,
    };
    if (formatPriority < 0) {
      continue;
    }

    if (platform == 3 && encoding == 10) {
      records.add(
        _EncodingRecord(offset: subtableOffset, priority: 300 + formatPriority),
      );
    } else if (platform == 3 && encoding == 1) {
      records.add(
        _EncodingRecord(offset: subtableOffset, priority: 250 + formatPriority),
      );
    } else if (platform == 0) {
      records.add(
        _EncodingRecord(offset: subtableOffset, priority: 200 + formatPriority),
      );
    } else if (platform == 1 && encoding == 0 && format == 0) {
      records.add(
        _EncodingRecord(
          offset: subtableOffset,
          priority: formatPriority,
          asciiOnly: true,
        ),
      );
    }
  }

  records.sort((a, b) => b.priority.compareTo(a.priority));
  final mappings = <int, int>{};
  for (final record in records) {
    final decoded = _decodeCmapSubtable(cmap, record.offset);
    for (final entry in decoded.entries) {
      if (entry.value == 0 ||
          !_isLatinSubsetCodePoint(entry.key) ||
          (record.asciiOnly && entry.key > 0x7F)) {
        continue;
      }
      mappings.putIfAbsent(entry.key, () => entry.value);
    }
  }
  return mappings;
}

Map<int, int> _decodeCmapSubtable(Uint8List cmap, int offset) {
  final format = _readUint16(cmap, offset);
  return switch (format) {
    0 => _decodeFormat0(cmap, offset),
    4 => _decodeFormat4(cmap, offset),
    6 => _decodeFormat6(cmap, offset),
    8 => _decodeFormat8(cmap, offset),
    10 => _decodeFormat10(cmap, offset),
    12 => _decodeFormat12(cmap, offset),
    13 => _decodeFormat13(cmap, offset),
    _ => const <int, int>{},
  };
}

Map<int, int> _decodeFormat0(Uint8List cmap, int offset) {
  final length = _validatedUint16Length(cmap, offset, minimum: 262);
  if (length < 262) {
    return const {};
  }
  return <int, int>{
    for (var codePoint = 0; codePoint < 256; codePoint++)
      if (cmap[offset + 6 + codePoint] != 0)
        codePoint: cmap[offset + 6 + codePoint],
  };
}

Map<int, int> _decodeFormat4(Uint8List cmap, int offset) {
  final length = _validatedUint16Length(cmap, offset, minimum: 16);
  final end = offset + length;
  final segmentCount = _readUint16(cmap, offset + 6) ~/ 2;
  if (segmentCount == 0 || 16 + segmentCount * 8 > length) {
    return const {};
  }

  final endCodesOffset = offset + 14;
  final startCodesOffset = endCodesOffset + segmentCount * 2 + 2;
  final deltasOffset = startCodesOffset + segmentCount * 2;
  final rangeOffsetsOffset = deltasOffset + segmentCount * 2;
  final mappings = <int, int>{};
  for (var index = 0; index < segmentCount; index++) {
    final startCode = _readUint16(cmap, startCodesOffset + index * 2);
    final endCode = _readUint16(cmap, endCodesOffset + index * 2);
    if (startCode > endCode || startCode == 0xFFFF) {
      continue;
    }
    final delta = _readUint16(cmap, deltasOffset + index * 2);
    final rangeOffsetPosition = rangeOffsetsOffset + index * 2;
    final rangeOffset = _readUint16(cmap, rangeOffsetPosition);
    _forEachLatinCodePoint(startCode, endCode, (codePoint) {
      int glyphId;
      if (rangeOffset == 0) {
        glyphId = (codePoint + delta) & 0xFFFF;
      } else {
        final glyphOffset =
            rangeOffsetPosition + rangeOffset + (codePoint - startCode) * 2;
        if (glyphOffset + 2 > end) {
          return;
        }
        glyphId = _readUint16(cmap, glyphOffset);
        if (glyphId != 0) {
          glyphId = (glyphId + delta) & 0xFFFF;
        }
      }
      if (glyphId != 0) {
        mappings[codePoint] = glyphId;
      }
    });
  }
  return mappings;
}

Map<int, int> _decodeFormat6(Uint8List cmap, int offset) {
  final length = _validatedUint16Length(cmap, offset, minimum: 10);
  final firstCode = _readUint16(cmap, offset + 6);
  final entryCount = _readUint16(cmap, offset + 8);
  if (10 + entryCount * 2 > length) {
    return const {};
  }
  final mappings = <int, int>{};
  _forEachLatinCodePoint(firstCode, firstCode + entryCount - 1, (codePoint) {
    final glyphId = _readUint16(
      cmap,
      offset + 10 + (codePoint - firstCode) * 2,
    );
    if (glyphId != 0) {
      mappings[codePoint] = glyphId;
    }
  });
  return mappings;
}

Map<int, int> _decodeFormat8(Uint8List cmap, int offset) {
  final length = _validatedUint32Length(cmap, offset, minimum: 8208);
  final groupCount = _readUint32(cmap, offset + 8204);
  if (8208 + groupCount * 12 > length) {
    return const {};
  }
  return _decodeSequentialGroups(
    cmap,
    offset + 8208,
    groupCount,
    constantGlyph: false,
  );
}

Map<int, int> _decodeFormat10(Uint8List cmap, int offset) {
  final length = _validatedUint32Length(cmap, offset, minimum: 20);
  final firstCode = _readUint32(cmap, offset + 12);
  final entryCount = _readUint32(cmap, offset + 16);
  if (20 + entryCount * 2 > length) {
    return const {};
  }
  final mappings = <int, int>{};
  _forEachLatinCodePoint(firstCode, firstCode + entryCount - 1, (codePoint) {
    final glyphId = _readUint16(
      cmap,
      offset + 20 + (codePoint - firstCode) * 2,
    );
    if (glyphId != 0) {
      mappings[codePoint] = glyphId;
    }
  });
  return mappings;
}

Map<int, int> _decodeFormat12(Uint8List cmap, int offset) {
  final length = _validatedUint32Length(cmap, offset, minimum: 16);
  final groupCount = _readUint32(cmap, offset + 12);
  if (16 + groupCount * 12 > length) {
    return const {};
  }
  return _decodeSequentialGroups(
    cmap,
    offset + 16,
    groupCount,
    constantGlyph: false,
  );
}

Map<int, int> _decodeFormat13(Uint8List cmap, int offset) {
  final length = _validatedUint32Length(cmap, offset, minimum: 16);
  final groupCount = _readUint32(cmap, offset + 12);
  if (16 + groupCount * 12 > length) {
    return const {};
  }
  return _decodeSequentialGroups(
    cmap,
    offset + 16,
    groupCount,
    constantGlyph: true,
  );
}

Map<int, int> _decodeSequentialGroups(
  Uint8List cmap,
  int groupsOffset,
  int groupCount, {
  required bool constantGlyph,
}) {
  final mappings = <int, int>{};
  for (var index = 0; index < groupCount; index++) {
    final groupOffset = groupsOffset + index * 12;
    final startCode = _readUint32(cmap, groupOffset);
    final endCode = _readUint32(cmap, groupOffset + 4);
    final startGlyph = _readUint32(cmap, groupOffset + 8);
    if (startCode > endCode) {
      continue;
    }
    _forEachLatinCodePoint(startCode, endCode, (codePoint) {
      final glyphId = constantGlyph
          ? startGlyph
          : startGlyph + codePoint - startCode;
      if (glyphId != 0 && glyphId <= 0xFFFF) {
        mappings[codePoint] = glyphId;
      }
    });
  }
  return mappings;
}

Uint8List _buildCmap(Map<int, int> mappings) {
  final entries =
      mappings.entries
          .where(
            (entry) =>
                entry.key >= 0 &&
                entry.key < 0xFFFF &&
                entry.value > 0 &&
                entry.value <= 0xFFFF,
          )
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));
  if (entries.isEmpty) {
    throw const FormatException('该赛博字骨不包含可用的拉丁字符，包的');
  }

  final segments = <_CmapSegment>[];
  for (final entry in entries) {
    final delta = (entry.value - entry.key) & 0xFFFF;
    if (segments.isNotEmpty &&
        segments.last.end + 1 == entry.key &&
        segments.last.delta == delta) {
      segments.last.end = entry.key;
    } else {
      segments.add(
        _CmapSegment(start: entry.key, end: entry.key, delta: delta),
      );
    }
  }
  segments.add(_CmapSegment(start: 0xFFFF, end: 0xFFFF, delta: 1));

  final segmentCount = segments.length;
  final format4Length = 16 + segmentCount * 8;
  final cmap = Uint8List(20 + format4Length);
  _writeUint16(cmap, 0, 0);
  _writeUint16(cmap, 2, 2);
  _writeUint16(cmap, 4, 0);
  _writeUint16(cmap, 6, 3);
  _writeUint32(cmap, 8, 20);
  _writeUint16(cmap, 12, 3);
  _writeUint16(cmap, 14, 1);
  _writeUint32(cmap, 16, 20);

  const subtableOffset = 20;
  _writeUint16(cmap, subtableOffset, 4);
  _writeUint16(cmap, subtableOffset + 2, format4Length);
  _writeUint16(cmap, subtableOffset + 4, 0);
  _writeUint16(cmap, subtableOffset + 6, segmentCount * 2);
  final segmentSearch = _searchParameters(segmentCount, unitSize: 2);
  _writeUint16(cmap, subtableOffset + 8, segmentSearch.searchRange);
  _writeUint16(cmap, subtableOffset + 10, segmentSearch.entrySelector);
  _writeUint16(cmap, subtableOffset + 12, segmentSearch.rangeShift);

  final endCodesOffset = subtableOffset + 14;
  final startCodesOffset = endCodesOffset + segmentCount * 2 + 2;
  final deltasOffset = startCodesOffset + segmentCount * 2;
  final rangeOffsetsOffset = deltasOffset + segmentCount * 2;
  for (var index = 0; index < segmentCount; index++) {
    final segment = segments[index];
    _writeUint16(cmap, endCodesOffset + index * 2, segment.end);
    _writeUint16(cmap, startCodesOffset + index * 2, segment.start);
    _writeUint16(cmap, deltasOffset + index * 2, segment.delta);
    _writeUint16(cmap, rangeOffsetsOffset + index * 2, 0);
  }
  return cmap;
}

final class _CmapSegment {
  _CmapSegment({required this.start, required this.end, required this.delta});

  final int start;
  int end;
  final int delta;
}

const _latinSubsetRanges = <(int, int)>[
  (0x0000, 0x02FF),
  (0x0300, 0x036F),
  (0x1D00, 0x1EFF),
  (0x2000, 0x27BF),
  (0x2C60, 0x2C7F),
  (0xA720, 0xA7FF),
  (0xAB30, 0xAB6F),
  (0xFB00, 0xFB06),
  (0xFE20, 0xFE2F),
  (0xFFFD, 0xFFFD),
];

bool _isLatinSubsetCodePoint(int codePoint) {
  for (final (start, end) in _latinSubsetRanges) {
    if (codePoint < start) {
      return false;
    }
    if (codePoint <= end) {
      return true;
    }
  }
  return false;
}

void _forEachLatinCodePoint(
  int start,
  int end,
  void Function(int codePoint) callback,
) {
  if (end < start) {
    return;
  }
  for (final (rangeStart, rangeEnd) in _latinSubsetRanges) {
    if (rangeEnd < start) {
      continue;
    }
    if (rangeStart > end) {
      return;
    }
    final intersectionStart = start > rangeStart ? start : rangeStart;
    final intersectionEnd = end < rangeEnd ? end : rangeEnd;
    for (
      var codePoint = intersectionStart;
      codePoint <= intersectionEnd;
      codePoint++
    ) {
      callback(codePoint);
    }
  }
}

({int searchRange, int entrySelector, int rangeShift}) _searchParameters(
  int itemCount, {
  required int unitSize,
}) {
  var powerOfTwo = 1;
  var entrySelector = 0;
  while (powerOfTwo * 2 <= itemCount) {
    powerOfTwo *= 2;
    entrySelector++;
  }
  final searchRange = powerOfTwo * unitSize;
  return (
    searchRange: searchRange,
    entrySelector: entrySelector,
    rangeShift: itemCount * unitSize - searchRange,
  );
}

int _validatedUint16Length(
  Uint8List bytes,
  int offset, {
  required int minimum,
}) {
  if (offset < 0 || offset + 4 > bytes.length) {
    throw const FormatException('赛博字骨 cmap 子表越界');
  }
  final length = _readUint16(bytes, offset + 2);
  if (length < minimum || offset + length > bytes.length) {
    throw const FormatException('赛博字骨 cmap 子表不完整');
  }
  return length;
}

int _validatedUint32Length(
  Uint8List bytes,
  int offset, {
  required int minimum,
}) {
  if (offset < 0 || offset + 8 > bytes.length) {
    throw const FormatException('赛博字骨 cmap 子表越界');
  }
  final length = _readUint32(bytes, offset + 4);
  if (length < minimum || offset + length > bytes.length) {
    throw const FormatException('赛博字骨 cmap 子表不完整');
  }
  return length;
}

int _alignedLength(int length) => (length + 3) & ~3;

int _checksum(Uint8List bytes) {
  var sum = 0;
  for (var offset = 0; offset < bytes.length; offset += 4) {
    var value = 0;
    for (var byteIndex = 0; byteIndex < 4; byteIndex++) {
      value <<= 8;
      final index = offset + byteIndex;
      if (index < bytes.length) {
        value |= bytes[index];
      }
    }
    sum = (sum + value) & 0xFFFFFFFF;
  }
  return sum;
}

int _readUint16(Uint8List bytes, int offset) =>
    ByteData.sublistView(bytes).getUint16(offset, Endian.big);

int _readUint32(Uint8List bytes, int offset) =>
    ByteData.sublistView(bytes).getUint32(offset, Endian.big);

void _writeUint16(Uint8List bytes, int offset, int value) {
  ByteData.sublistView(bytes).setUint16(offset, value, Endian.big);
}

void _writeUint32(Uint8List bytes, int offset, int value) {
  ByteData.sublistView(bytes).setUint32(offset, value, Endian.big);
}
