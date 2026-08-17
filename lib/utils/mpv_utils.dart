import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:media_kit/media_kit.dart';

abstract final class MpvUtils {
  static Map<String, String> parseOptions(String source) {
    final result = <String, String>{};
    final lines = source.split('\n');

    for (var index = 0; index < lines.length; index++) {
      var line = lines[index].trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      if (!line.startsWith('--')) {
        throw FormatException('第 ${index + 1} 行必须以 -- 开头，包的');
      }
      line = line.substring(2);

      final separator = line.indexOf('=');
      String name;
      String value;
      if (separator == -1) {
        name = line.trim();
        value = 'yes';
        if (name.startsWith('no-') && name.length > 3) {
          name = name.substring(3);
          value = 'no';
        }
      } else {
        name = line.substring(0, separator).trim();
        value = line.substring(separator + 1).trim();
      }

      if (name.isEmpty) {
        throw FormatException('第 ${index + 1} 行缺少参数名，不是哥们');
      }
      if (value.isEmpty) {
        throw FormatException('第 ${index + 1} 行缺少参数值，功德+1');
      }

      // 同一参数写多次时，后写的值覆盖前面的值。
      result[name] = value;
    }

    return result;
  }

  static Map<String, String> get customOptions =>
      parseOptions(Pref.customMpvOptions);

  static MPVLogLevel get logLevel =>
      MPVLogLevel.values.byName(Pref.mpvLogLevel);

  static Map<String, String> mergeOptions(Map<String, String> builtIn) => {
    ...builtIn,
    ...customOptions,
  };

  /// 删除与自定义参数冲突的 PiliPlus 按文件设置，让已经通过
  /// PlayerConfiguration 或 setProperty 应用的用户值保持最高优先级。
  /// 不把自定义值写入 loadfile extras，避免含逗号的复杂值被二次拆分。
  static void overridePerFileOptions(Map<String, String> options) {
    final custom = customOptions;
    options.removeWhere((key, _) => custom.containsKey(key));
  }

  /// media_kit 与 PiliPlus 在 mpv_initialize 之后还会写入一批属性。
  /// 再应用一次用户值，使重复项最终以用户设置为准；启动期专用选项
  /// 已经通过 PlayerConfiguration.options 在初始化前应用。
  static void applyRuntimeOverrides(NativePlayer player) {
    for (final entry in customOptions.entries) {
      player.setProperty(entry.key, entry.value);
    }
  }
}
