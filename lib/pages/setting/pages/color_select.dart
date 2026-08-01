import 'dart:io' show Platform;

import 'package:PiliPlus/common/widgets/animated_height.dart';
import 'package:PiliPlus/common/widgets/color_palette.dart';
import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/main.dart' show MyApp;
import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:PiliPlus/models/common/theme/theme_color_type.dart';
import 'package:PiliPlus/models/common/theme/theme_type.dart';
import 'package:PiliPlus/pages/home/view.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/pages/setting/slide_color_picker.dart';
import 'package:PiliPlus/pages/setting/widgets/popup_item.dart';
import 'package:PiliPlus/pages/setting/widgets/select_dialog.dart';
import 'package:PiliPlus/pages/setting/widgets/slider_dialog.dart';
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
  Brightness _toneBrightness = Brightness.light;
  bool _toneBrightnessInitialized = false;
  Map<ThemeUiElement, ThemeSchemeColor?> _colorAssignments =
      Pref.customThemeUiColorAssignments;
  final Set<ThemeSchemeColor> _expandedColors = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_toneBrightnessInitialized) {
      _toneBrightness = Theme.of(context).brightness;
      _toneBrightnessInitialized = true;
    }
  }

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

  Future<void> _showToneOffsetDialog(ThemeToneRole role) async {
    final value = Pref.customThemeToneOffset(_toneBrightness, role);
    final result = await showDialog<double>(
      context: context,
      builder: (context) => SliderDialog(
        title: Text('${role.label}明暗偏移'),
        value: value,
        min: -30,
        max: 30,
        divisions: 60,
        precise: 0,
      ),
    );
    if (result == null) return;
    final key = Pref.customThemeToneKey(_toneBrightness, role);
    if (result == 0) {
      await GStorage.setting.delete(key);
    } else {
      await GStorage.setting.put(key, result);
    }
    if (!mounted) return;
    setState(() {});
    Get.updateMyAppTheme();
  }

  Future<void> _resetToneOffsets() async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: const Text('重置明暗层级？'),
      content: Text(
        '将清除${_toneBrightness == Brightness.light ? '亮色' : '暗色'}主题中'
        '所有语义区域的明暗偏移，此操作无法撤销。',
      ),
    );
    if (!confirmed) return;
    await GStorage.setting.deleteAll(
      ThemeToneRole.values
          .map((role) => Pref.customThemeToneKey(_toneBrightness, role)),
    );
    if (!mounted) return;
    setState(() {});
    Get.updateMyAppTheme();
  }

  Future<void> _setColorAssignment(
    BuildContext anchorContext,
    ThemeUiElement target,
    ThemeSchemeColor? source,
  ) async {
    _preserveScrollAnchor(anchorContext);
    setState(() {
      _colorAssignments = {..._colorAssignments, target: source};
    });

    final stored = <String, String>{};
    for (final entry in _colorAssignments.entries) {
      if (entry.value == entry.key.defaultColor) continue;
      stored[entry.key.name] = entry.value?.name ?? '';
    }
    if (stored.isEmpty) {
      await GStorage.setting.delete(
        SettingBoxKey.customThemeColorAssignments,
      );
    } else {
      await GStorage.setting.put(
        SettingBoxKey.customThemeColorAssignments,
        stored,
      );
    }
    Get.updateMyAppTheme();
  }

  void _preserveScrollAnchor(BuildContext anchorContext) {
    final scrollable = Scrollable.maybeOf(anchorContext);
    final renderObject = anchorContext.findRenderObject();
    if (scrollable == null ||
        renderObject is! RenderBox ||
        !renderObject.attached) {
      return;
    }
    final anchorY = renderObject.localToGlobal(Offset.zero).dy;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollable.mounted || !anchorContext.mounted) return;
      final nextRenderObject = anchorContext.findRenderObject();
      if (nextRenderObject is! RenderBox || !nextRenderObject.attached) return;
      final position = scrollable.position;
      if (!position.hasPixels) return;
      final delta = nextRenderObject.localToGlobal(Offset.zero).dy - anchorY;
      if (delta.abs() < 0.5) return;
      final targetPixels = (position.pixels + delta)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if ((targetPixels - position.pixels).abs() >= 0.5) {
        position.jumpTo(targetPixels);
      }
    });
  }

  Future<void> _resetColorAssignments() async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: const Text('恢复 UI 颜色默认配置？'),
      content: const Text(
        '所有 UI 元素将重新使用各自默认的 Material 颜色，'
        '当前自定义分配和未配置状态都会被清除。此操作无法撤销。',
      ),
    );
    if (!confirmed) return;
    await GStorage.setting.delete(
      SettingBoxKey.customThemeColorAssignments,
    );
    if (!mounted) return;
    setState(() {
      _colorAssignments = {
        for (final element in ThemeUiElement.values)
          element: element.defaultColor,
      };
    });
    Get.updateMyAppTheme();
  }

  ColorScheme _previewColorScheme() {
    final seeds = (
      primary: ctr.primarySeed.value,
      secondary: ctr.secondarySeed.value,
      tertiary: ctr.tertiarySeed.value,
    );
    return seeds
        .asColorSchemeSeeds(_schemeVariant, _toneBrightness)
        .applyToneOffsets(Pref.customThemeToneOffsets(_toneBrightness));
  }

  Widget _brightnessSelector() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: SegmentedButton<Brightness>(
      segments: const [
        ButtonSegment(
          value: Brightness.light,
          label: Text('亮色主题'),
          icon: Icon(Icons.light_mode_outlined),
        ),
        ButtonSegment(
          value: Brightness.dark,
          label: Text('暗色主题'),
          icon: Icon(Icons.dark_mode_outlined),
        ),
      ],
      selected: {_toneBrightness},
      onSelectionChanged: (value) {
        setState(() => _toneBrightness = value.single);
      },
    ),
  );

  Widget _schemeColorTilePreview(ColorScheme colorScheme) => LayoutBuilder(
    builder: (context, constraints) {
      const preferredTileExtent = 24.0;
      final colors = ThemeSchemeColor.values;
      final crossAxisCount = (constraints.maxWidth / preferredTileExtent)
          .floor()
          .clamp(1, colors.length)
          .toInt();
      final tileExtent = constraints.maxWidth / crossAxisCount;
      final rowCount = (colors.length / crossAxisCount).ceil();
      return SizedBox(
        height: rowCount * tileExtent,
        child: GridView.builder(
          padding: EdgeInsets.zero,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 0,
            crossAxisSpacing: 0,
          ),
          itemCount: colors.length,
          itemBuilder: (context, index) => ColoredBox(
            color: colorScheme.colorFor(colors[index]),
          ),
        ),
      );
    },
  );

  Widget _colorAssignmentEditor(
    ColorScheme colorScheme,
    TextStyle subtitleStyle,
  ) {
    Color assignedColor(ThemeUiElement element) => colorScheme.colorFor(
      _colorAssignments[element] ?? element.defaultColor,
    );
    final unassignedCount = _colorAssignments.values
        .where((source) => source == null)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.grid_view_outlined),
          title: const Text('完整颜色表与具体 UI 元素'),
          subtitle: Text(
            '已拆分 ${ThemeUiElement.values.length} 个可独立着色部位；'
            '展开任一颜色即可配置',
          ),
        ),
        _brightnessSelector(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '未配置 UI 元素：$unassignedCount 个',
            style: subtitleStyle,
          ),
        ),
        _schemeColorTilePreview(colorScheme),
        if (unassignedCount > 0)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: assignedColor(
                ThemeUiElement.themeUnassignedWarningBackground,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '还有 $unassignedCount 个 UI 元素未配置颜色。'
              '它们会保留生成色，并出现在每个颜色的下拉菜单中。',
              style: TextStyle(
                color: assignedColor(
                  ThemeUiElement.themeUnassignedWarningContent,
                ),
              ),
            ),
          ),
        for (final family in ThemeColorFamily.values) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              family.label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final source in ThemeSchemeColor.values)
            if (source.family == family)
              _colorAssignmentTile(colorScheme, source),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: OutlinedButton.icon(
              onPressed: _resetColorAssignments,
              icon: const Icon(Icons.settings_backup_restore),
              label: const Text('恢复所有 UI 元素默认颜色'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _colorAssignmentTile(
    ColorScheme colorScheme,
    ThemeSchemeColor source,
  ) {
    final expanded = _expandedColors.contains(source);
    final assignedCount = _colorAssignments.values
        .where((assigned) => assigned == source)
        .length;
    final targets = _colorAssignments.entries
        .where((entry) => entry.value == source || entry.value == null)
        .map((entry) => entry.key)
        .toList();
    final color = colorScheme.colorFor(source);
    final hex = color
        .toARGB32()
        .toRadixString(16)
        .toUpperCase()
        .padLeft(8, '0');
    return ExpansionTile(
      key: PageStorageKey(source.name),
      leading: _SchemeColorSwatch(color: color),
      title: Text('${source.label}（${source.name}）'),
      subtitle: Text('ARGB #$hex · 已配置 $assignedCount 个 UI 元素'),
      initiallyExpanded: expanded,
      onExpansionChanged: (value) {
        setState(() {
          if (value) {
            _expandedColors.add(source);
          } else {
            _expandedColors.remove(source);
          }
        });
      },
      children: !expanded
          ? const []
          : targets.isEmpty
          ? const [
              Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Text('当前没有可分配的 UI 元素。请先从其他颜色中取消对应选项。'),
              ),
            ]
          : targets.map((target) {
              final assigned = _colorAssignments[target] == source;
              return Builder(
                key: ValueKey('${source.name}:${target.name}'),
                builder: (anchorContext) => CheckboxListTile(
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: assigned,
                  title: Text(target.label),
                  subtitle: Text(target.description),
                  onChanged: (checked) => _setColorAssignment(
                    anchorContext,
                    target,
                    (checked ?? false) ? source : null,
                  ),
                ),
              );
            }).toList(),
    );
  }

  Widget _toneOffsetTile(ThemeToneRole role) {
    final value = Pref.customThemeToneOffset(_toneBrightness, role);
    final sign = value > 0 ? '+' : '';
    return ListTile(
      dense: true,
      title: Text(role.label),
      subtitle: Text('${role.description}；负数更暗，正数更亮'),
      trailing: Text('$sign${value.toStringAsFixed(0)}'),
      onTap: () => _showToneOffsetDialog(role),
    );
  }

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
                setState(() => _schemeVariant = value);
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
                  const Divider(height: 24),
                  _colorAssignmentEditor(
                    _previewColorScheme(),
                    subTitleStyle,
                  ),
                  const Divider(height: 24),
                  const ListTile(
                    leading: Icon(Icons.contrast_outlined),
                    title: Text('语义区域明暗层级'),
                    subtitle: Text('只改变 HCT 明度，不改变已选种子色的色相'),
                  ),
                  _schemeColorTilePreview(_previewColorScheme()),
                  ...ThemeToneRole.values.map(_toneOffsetTile),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16, bottom: 8),
                      child: TextButton.icon(
                        onPressed: _resetToneOffsets,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('重置当前模式明暗层级'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Theme(
            data: _toneBrightness == Brightness.light
                ? ThemeUtils.lightTheme
                : ThemeUtils.darkTheme,
            child: Column(
              children: [
                Padding(
                  padding: padding,
                  child: ExcludeFocus(
                    child: IgnorePointer(
                      child: Builder(
                        builder: (context) => Container(
                          height: size.height / 2,
                          width: size.width,
                          color: Theme.of(context).colorScheme.surface,
                          child: const HomePage(),
                        ),
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

class _SchemeColorSwatch extends StatelessWidget {
  const _SchemeColorSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    ),
  );
}
