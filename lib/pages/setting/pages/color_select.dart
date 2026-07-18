import 'dart:io' show Platform;

import 'package:PiliPlus/common/widgets/animated_height.dart';
import 'package:PiliPlus/common/widgets/color_palette.dart';
import 'package:PiliPlus/main.dart' show MyApp;
import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:PiliPlus/models/common/theme/theme_color_type.dart';
import 'package:PiliPlus/models/common/theme/theme_type.dart';
import 'package:PiliPlus/pages/home/view.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/pages/setting/slide_color_picker.dart';
import 'package:PiliPlus/pages/setting/widgets/popup_item.dart';
import 'package:PiliPlus/pages/setting/widgets/select_dialog.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/theme_utils.dart';
import 'package:collection/collection.dart';
import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class ColorSelectPage extends StatefulWidget {
  const ColorSelectPage({super.key});

  @override
  State<ColorSelectPage> createState() => _ColorSelectPageState();
}

class Item {
  Item({
    required this.expandedValue,
    required this.headerValue,
    this.isExpanded = false,
  });

  String expandedValue;
  String headerValue;
  bool isExpanded;
}

class _ColorSelectPageState extends State<ColorSelectPage> {
  final ctr = Get.put(_ColorSelectController());
  FlexSchemeVariant _schemeVariant = Pref.schemeVariant;

  Future<void> _onColorModeChanged(ThemeColorMode mode) async {
    if (mode == ctr.colorMode.value) return;
    if (mode == ThemeColorMode.dynamic &&
        !await MyApp.initPlatformState()) {
      SmartDialog.showToast('设备可能不支持动态取色');
      return;
    }
    ctr.colorMode.value = mode;
    await GStorage.setting.putAll({
      SettingBoxKey.themeColorMode: mode.index,
      // 同步旧键，保证降级到旧版本时仍能读取合理的取色状态。
      SettingBoxKey.dynamicColor: mode == ThemeColorMode.dynamic,
    });
    Get.updateMyAppTheme();
  }

  Future<void> _showColorModeDialog() async {
    final values = ThemeColorMode.values
        .where((e) => !Platform.isIOS || e != ThemeColorMode.dynamic)
        .map((e) => (e, e.label))
        .toList();
    final result = await showDialog<ThemeColorMode>(
      context: context,
      builder: (context) => SelectDialog<ThemeColorMode>(
        title: '配色模式',
        value: ctr.colorMode.value,
        values: values,
      ),
    );
    if (result != null) await _onColorModeChanged(result);
  }

  void _showSeedColorPicker({
    required String title,
    required Rx<Color> color,
    required String storageKey,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        clipBehavior: Clip.hardEdge,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        title: Text(title),
        content: SlideColorPicker(
          color: color.value,
          showAlpha: true,
          onChanged: (value) {
            if (value == null || value == color.value) return;
            color.value = value;
            GStorage.setting
                .put(storageKey, value.toARGB32())
                .whenComplete(Get.updateMyAppTheme);
          },
        ),
      ),
    );
  }

  Widget _seedColorTile({
    required String title,
    required Rx<Color> color,
    required String storageKey,
  }) => Obx(() {
    final value = color.value;
    final argb = value.toARGB32();
    final hex = argb.toRadixString(16).toUpperCase().padLeft(8, '0');
    final opacity = ((argb >>> 24) / 255 * 100).round();
    return ListTile(
      leading: _SeedColorSwatch(color: value),
      title: Text(title),
      subtitle: Text('ARGB #$hex · 不透明度 $opacity%'),
      onTap: () => _showSeedColorPicker(
        title: title,
        color: color,
        storageKey: storageKey,
      ),
    );
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    TextStyle titleStyle = theme.textTheme.titleMedium!;
    TextStyle subTitleStyle = theme.textTheme.labelMedium!.copyWith(
      color: theme.colorScheme.outline,
    );
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.viewPaddingOf(
      context,
    ).copyWith(top: 0, bottom: 0);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text('选择应用主题')),
      body: ListView(
        children: [
          ListTile(
            onTap: () async {
              final result = await showDialog<ThemeType>(
                context: context,
                builder: (context) => SelectDialog<ThemeType>(
                  title: '主题模式',
                  value: ctr.themeType.value,
                  values: ThemeType.values.map((e) => (e, e.desc)).toList(),
                ),
              );
              if (result != null) {
                try {
                  Get.find<MineController>().themeType.value = result;
                } catch (_) {}
                ctr.themeType.value = result;
                GStorage.setting.put(SettingBoxKey.themeMode, result.index);
                Get.changeThemeMode(ThemeUtils.themeMode = result.toThemeMode);
              }
            },
            leading: const Icon(Icons.flashlight_on_outlined),
            title: Text('主题模式', style: titleStyle),
            subtitle: Obx(
              () => Text(
                '当前模式：${ctr.themeType.value.desc}',
                style: subTitleStyle,
              ),
            ),
          ),
          Obx(
            () => ListTile(
              onTap: _showColorModeDialog,
              leading: const Icon(Icons.color_lens_outlined),
              title: Text('配色模式', style: titleStyle),
              subtitle: Text(
                '当前模式：${ctr.colorMode.value.label}',
                style: subTitleStyle,
              ),
            ),
          ),
          Obx(
            () => PopupListTile<FlexSchemeVariant>(
              enabled: ctr.colorMode.value != ThemeColorMode.dynamic,
              leading: const Icon(Icons.palette_outlined),
              title: const Text('调色板风格'),
              value: () => (_schemeVariant, _schemeVariant.variantName),
              itemBuilder: (_) => FlexSchemeVariant.values
                  .map(
                    (e) => PopupMenuItem(value: e, child: Text(e.variantName)),
                  )
                  .toList(),
              onSelected: (value, refresh) {
                _schemeVariant = value;
                GStorage.setting
                    .put(SettingBoxKey.schemeVariant, value.index)
                    .whenComplete(() {
                      refresh();
                      Get.updateMyAppTheme();
                    });
              },
            ),
          ),
          Padding(
            padding: padding + const .all(12),
            child: Obx(
              () => AnimatedHeight(
                expand: ctr.colorMode.value == ThemeColorMode.preset,
                duration: const Duration(milliseconds: 200),
                child: Wrap(
                  alignment: .center,
                  spacing: 22,
                  runSpacing: 18,
                  children: colorThemeTypes.mapIndexed(
                    (i, e) {
                      return GestureDetector(
                        behavior: .opaque,
                        onTap: () {
                          ctr.currentColor.value = i;
                          GStorage.setting
                              .put(SettingBoxKey.customColor, i)
                              .whenComplete(Get.updateMyAppTheme);
                        },
                        child: Column(
                          spacing: 3,
                          children: [
                            ColorPalette(
                              colorScheme: e.color.asColorSchemeSeed(
                                _schemeVariant,
                                theme.brightness,
                              ),
                              selected: ctr.currentColor.value == i,
                            ),
                            Text(
                              e.label,
                              style: TextStyle(
                                fontSize: 12,
                                color: ctr.currentColor.value != i
                                    ? theme.colorScheme.outline
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ).toList(),
                ),
              ),
            ),
          ),
          Obx(
            () => AnimatedHeight(
              expand: ctr.colorMode.value == ThemeColorMode.customMultiSeed,
              duration: const Duration(milliseconds: 200),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'A 通道参与种子色与明/暗基底的混合；生成后的 Material 色表仍保持不透明。',
                      style: subTitleStyle,
                    ),
                  ),
                  _seedColorTile(
                    title: '主种子色（Primary）',
                    color: ctr.primarySeed,
                    storageKey: SettingBoxKey.customPrimarySeed,
                  ),
                  _seedColorTile(
                    title: '次种子色（Secondary）',
                    color: ctr.secondarySeed,
                    storageKey: SettingBoxKey.customSecondarySeed,
                  ),
                  _seedColorTile(
                    title: '第三种子色（Tertiary）',
                    color: ctr.tertiarySeed,
                    storageKey: SettingBoxKey.customTertiarySeed,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: padding,
            child: ExcludeFocus(
              child: IgnorePointer(
                child: Container(
                  height: size.height / 2,
                  width: size.width,
                  color: theme.colorScheme.surface,
                  child: const HomePage(),
                ),
              ),
            ),
          ),
          ExcludeFocus(
            child: IgnorePointer(
              child: NavigationBar(
                destinations: NavigationBarType.values
                    .map(
                      (item) => NavigationDestination(
                        icon: item.icon,
                        label: item.label,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorSelectController extends GetxController {
  final Rx<ThemeColorMode> colorMode = Pref.themeColorMode.obs;
  final RxInt currentColor = Pref.customColor.obs;
  final Rx<ThemeType> themeType = Pref.themeType.obs;
  final Rx<Color> primarySeed = Pref.customThemeSeeds.primary.obs;
  final Rx<Color> secondarySeed = Pref.customThemeSeeds.secondary.obs;
  final Rx<Color> tertiarySeed = Pref.customThemeSeeds.tertiary.obs;
}

class _SeedColorSwatch extends StatelessWidget {
  const _SeedColorSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        const Row(
          children: [
            Expanded(child: ColoredBox(color: Colors.white)),
            Expanded(child: ColoredBox(color: Colors.black)),
          ],
        ),
        ColoredBox(color: color),
      ],
    ),
  );
}
