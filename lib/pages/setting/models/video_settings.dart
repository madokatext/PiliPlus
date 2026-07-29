import 'dart:io';

import 'package:PiliPlus/models/common/video/audio_quality.dart';
import 'package:PiliPlus/models/common/video/cdn_type.dart';
import 'package:PiliPlus/models/common/video/live_quality.dart';
import 'package:PiliPlus/models/common/video/video_decode_type.dart';
import 'package:PiliPlus/models/common/video/video_quality.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/pages/setting/widgets/ordered_multi_select_dialog.dart';
import 'package:PiliPlus/pages/setting/widgets/select_dialog.dart';
import 'package:PiliPlus/plugin/pl_player/models/audio_output_type.dart';
import 'package:PiliPlus/plugin/pl_player/models/hwdec_type.dart';
import 'package:PiliPlus/utils/filtering_text.dart';
import 'package:PiliPlus/utils/mpv_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/video_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

const _mpvLogLevels = <(String, String)>[
  ('error', '错误（error）'),
  ('warn', '警告（warn）'),
  ('info', '信息（info）'),
  ('v', '详细（v）'),
  ('debug', '调试（debug）'),
  ('trace', '跟踪（trace，最详细）'),
];

String _mpvLogLevelLabel(String value) =>
    _mpvLogLevels.firstWhere((item) => item.$1 == value).$2;

String _customMpvOptionsSubtitle() {
  final source = Pref.customMpvOptions.trim();
  if (source.isEmpty) {
    return '未设置。每行一个，格式：--参数=值；示例：--video-sync=audio';
  }
  try {
    final count = MpvUtils.parseOptions(source).length;
    return '已设置 $count 项。每行一个，格式：--参数=值；示例：--video-sync=audio';
  } catch (_) {
    return '当前内容格式有误，点击修改；格式：--参数=值';
  }
}

List<SettingsModel> get videoSettings => [
  const SwitchModel(
    title: '开启硬解',
    subtitle: '以较低功耗播放视频，若异常卡死请关闭',
    leading: Icon(Icons.flash_on_outlined),
    setKey: SettingBoxKey.enableHA,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '免登录1080P',
    subtitle: '免登录查看1080P视频',
    leading: Icon(Icons.hd_outlined),
    setKey: SettingBoxKey.p1080,
    defaultVal: true,
  ),
  NormalModel(
    title: 'B站定向流量支持',
    subtitle: '若套餐含B站定向流量，则会自动使用。可查阅运营商的流量记录确认。',
    leading: const Icon(Icons.perm_data_setting_outlined),
    getTrailing: (theme) => IgnorePointer(
      child: Transform.scale(
        scale: 0.8,
        alignment: Alignment.centerRight,
        child: Switch(
          value: true,
          onChanged: (_) {},
          thumbIcon: WidgetStateProperty.all(
            const Icon(Icons.lock_outline_rounded),
          ),
        ),
      ),
    ),
  ),
  NormalModel(
    title: 'CDN 设置',
    leading: const Icon(MdiIcons.cloudPlusOutline),
    getSubtitle: () => '当前顺序：${VideoUtils.cdnDescription}',
    onTap: _showCDNDialog,
  ),
  NormalModel(
    title: '直播 CDN 设置',
    leading: const Icon(MdiIcons.cloudPlusOutline),
    getSubtitle: () => '当前使用：${Pref.liveCdnUrl ?? "默认"}',
    onTap: _showLiveCDNDialog,
  ),
  const SwitchModel(
    title: 'CDN 测速',
    leading: Icon(Icons.speed),
    subtitle: '测速通过模拟加载视频实现，注意流量消耗，结果仅供参考',
    setKey: SettingBoxKey.cdnSpeedTest,
    defaultVal: true,
  ),
  SwitchModel(
    title: '音频不跟随 CDN 设置',
    subtitle: '直接采用备用 URL，可解决部分视频无声',
    leading: const Icon(MdiIcons.musicNotePlus),
    setKey: SettingBoxKey.disableAudioCDN,
    defaultVal: false,
    onChanged: (value) => VideoUtils.disableAudioCDN = value,
  ),
  NormalModel(
    title: '默认画质',
    leading: const Icon(Icons.video_settings_outlined),
    getSubtitle: () =>
        '当前画质：${VideoQuality.fromCode(Pref.defaultVideoQa).desc}',
    onTap: _showVideoQaDialog,
  ),
  NormalModel(
  title: '半屏默认画质',
  leading: const Icon(Icons.picture_in_picture_alt_outlined),
  getSubtitle: () =>
      '当前画质：${VideoQuality.fromCode(Pref.defaultVideoQaHalfScreen).desc}',
  onTap: _showHalfScreenVideoQaDialog,
  ),
  NormalModel(
    title: '蜂窝网络画质',
    leading: const Icon(Icons.video_settings_outlined),
    getSubtitle: () =>
        '当前画质：${VideoQuality.fromCode(Pref.defaultVideoQaCellular).desc}',
    onTap: _showVideoCellularQaDialog,
  ),
  NormalModel(
    title: '默认音质',
    leading: const Icon(Icons.music_video_outlined),
    getSubtitle: () =>
        '当前音质：${AudioQuality.fromCode(Pref.defaultAudioQa).desc}',
    onTap: _showAudioQaDialog,
  ),
  NormalModel(
    title: '蜂窝网络音质',
    leading: const Icon(Icons.music_video_outlined),
    getSubtitle: () =>
        '当前音质：${AudioQuality.fromCode(Pref.defaultAudioQaCellular).desc}',
    onTap: _showAudioCellularQaDialog,
  ),
  NormalModel(
    title: '直播默认画质',
    leading: const Icon(Icons.video_settings_outlined),
    getSubtitle: () => '当前画质：${LiveQuality.fromCode(Pref.liveQuality)?.desc}',
    onTap: _showLiveQaDialog,
  ),
  NormalModel(
    title: '蜂窝网络直播默认画质',
    leading: const Icon(Icons.video_settings_outlined),
    getSubtitle: () =>
        '当前画质：${LiveQuality.fromCode(Pref.liveQualityCellular)?.desc}',
    onTap: _showLiveCellularQaDialog,
  ),
  NormalModel(
    title: '首选解码格式',
    leading: const Icon(Icons.movie_creation_outlined),
    getSubtitle: () =>
        '首选解码格式：${(Pref.preferCodecs.map((i) => i.name).join(","))}，请根据设备支持情况与需求调整',
    onTap: _showCodecsDialog,
  ),
  if (kDebugMode || Platform.isAndroid)
    NormalModel(
      title: '音频输出设备',
      leading: const Icon(Icons.speaker_outlined),
      getSubtitle: () => '当前：${Pref.audioOutput}',
      onTap: _showAudioOutputDialog,
    ),
  NormalModel(
    title: '缓冲大小',
    leading: const Icon(Icons.storage_outlined),
    getSubtitle: () =>
        '当前：${Pref.bufferSize}MB。同时为前向和后向缓冲区大小。对于直播流，无后向缓冲大小，全部转给前向（此选项即mpv的--demuxer-max-bytes，--demuxer-max-back-bytes）',
    onTap: _showBufferSizeDialog,
  ),
  NormalModel(
    title: '缓冲时长',
    leading: const Icon(Icons.av_timer),
    getSubtitle: () =>
        '当前：${Pref.bufferSec}s。实际缓冲为二者最小值。对于直播流，该选项无效（此选项即mpv的--cache-secs）',
    onTap: _showBufferSecDialog,
  ),
  NormalModel(
    title: '自动同步',
    leading: const Icon(Icons.sync_rounded),
    getSubtitle: () => '当前：${Pref.autosync}（此项即mpv的--autosync）',
    onTap: _showAutoSyncDialog,
  ),
  NormalModel(
    title: '视频同步',
    leading: const Icon(Icons.view_timeline_outlined),
    getSubtitle: () => '当前：${Pref.videoSync}（此项即mpv的--video-sync）',
    onTap: _showVideoSyncDialog,
  ),
  NormalModel(
    title: '硬解模式',
    leading: const Icon(Icons.memory_outlined),
    getSubtitle: () => '当前：${Pref.hardwareDecoding}（此项即mpv的--hwdec）',
    onTap: _showHwDecDialog,
  ),
  const SwitchModel(
    title: '使用 mpv 进行分辨率缩放',
    subtitle: '开启后画质更好，但会导致画面尺寸切换时闪烁',
    leading: Icon(Icons.high_quality_outlined),
    setKey: SettingBoxKey.useMpvVideoScaling,
    defaultVal: false,
  ),
  const SwitchModel(
    title: '全屏切换使用黑屏遮罩',
    subtitle: '播放状态切换时，调整 mpv 输出尺寸前盖黑，确认新 Surface 帧后立即移除',
    leading: Icon(Icons.fullscreen_outlined),
    setKey: SettingBoxKey.coverFullscreenTransitionWithBlack,
    defaultVal: false,
  ),
  NormalModel(
    title: '自定义 mpv 启动参数',
    leading: const Icon(Icons.tune),
    getSubtitle: _customMpvOptionsSubtitle,
    onTap: _showCustomMpvOptionsDialog,
  ),
  NormalModel(
    title: 'mpv 日志详细等级',
    leading: const Icon(Icons.manage_search_outlined),
    getSubtitle: () =>
        '当前：${_mpvLogLevelLabel(Pref.mpvLogLevel)}；新建播放器后生效',
    onTap: _showMpvLogLevelDialog,
  ),
  NormalModel(
    title: '显示上次 mpv 播放日志',
    subtitle: '查看最近一次视频、音频或 Live Photo 播放产生的 mpv 后端日志',
    leading: const Icon(Icons.article_outlined),
    onTap: (_, _) => Get.toNamed('/mpvLogs'),
  ),
  const SwitchModel(
    title: '显示播放器主备实例状态',
    subtitle: '在画面中心偏左显示主、备实例的视频源加载状态与切换提示',
    leading: Icon(Icons.swap_horiz_outlined),
    setKey: SettingBoxKey.showPlayerInstanceStatus,
    defaultVal: false,
  ),
];

Future<void> _showCDNDialog(BuildContext context, VoidCallback setState) async {
  final res = await showDialog<List<CDNService>>(
    context: context,
    builder: (context) => const CdnSelectDialog(),
  );
  if (res != null && res.isNotEmpty) {
    VideoUtils.setCdnServices(res);
    await GStorage.setting.putAll({
      SettingBoxKey.CDNServices: res.map((item) => item.name).toList(),
      SettingBoxKey.CDNService: res.first.name,
    });
    setState();
  }
}

Future<void> _showLiveCDNDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  String host = Pref.liveCdnUrl ?? '';
  String? res = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('输入CDN host'),
      content: TextFormField(
        initialValue: host,
        autofocus: true,
        onChanged: (value) => host = value,
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: Text(
            '取消',
            style: TextStyle(color: ColorScheme.of(context).outline),
          ),
        ),
        TextButton(
          onPressed: () => Get.back(result: host),
          child: const Text('确定'),
        ),
      ],
    ),
  );
  if (res != null) {
    if (res.isEmpty) {
      res = null;
      await GStorage.setting.delete(SettingBoxKey.liveCdnUrl);
    } else {
      if (!res.startsWith('http')) {
        res = 'https://$res';
      }
      await GStorage.setting.put(SettingBoxKey.liveCdnUrl, res);
    }
    VideoUtils.liveCdnUrl = res;
    setState();
  }
}

Future<void> _showVideoQaDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<int>(
    context: context,
    builder: (context) => SelectDialog<int>(
      title: '默认画质',
      value: Pref.defaultVideoQa,
      values: VideoQuality.values.map((e) => (e.code, e.desc)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.defaultVideoQa, res);
    setState();
  }
}

Future<void> _showHalfScreenVideoQaDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<int>(
    context: context,
    builder: (context) => SelectDialog<int>(
      title: '半屏默认画质',
      value: Pref.defaultVideoQaHalfScreen,
      values: VideoQuality.values.map((e) => (e.code, e.desc)).toList(),
    ),
  );

  if (res != null) {
    await GStorage.setting.put(
      SettingBoxKey.defaultVideoQaHalfScreen,
      res,
    );
    setState();
  }
}

Future<void> _showVideoCellularQaDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<int>(
    context: context,
    builder: (context) => SelectDialog<int>(
      title: '蜂窝网络画质',
      value: Pref.defaultVideoQaCellular,
      values: VideoQuality.values.map((e) => (e.code, e.desc)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(
      SettingBoxKey.defaultVideoQaCellular,
      res,
    );
    setState();
  }
}

Future<void> _showAudioQaDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<int>(
    context: context,
    builder: (context) => SelectDialog<int>(
      title: '默认音质',
      value: Pref.defaultAudioQa,
      values: AudioQuality.values.map((e) => (e.code, e.desc)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.defaultAudioQa, res);
    setState();
  }
}

Future<void> _showAudioCellularQaDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<int>(
    context: context,
    builder: (context) => SelectDialog<int>(
      title: '蜂窝网络音质',
      value: Pref.defaultAudioQaCellular,
      values: AudioQuality.values.map((e) => (e.code, e.desc)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(
      SettingBoxKey.defaultAudioQaCellular,
      res,
    );
    setState();
  }
}

Future<void> _showLiveQaDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<int>(
    context: context,
    builder: (context) => SelectDialog<int>(
      title: '直播默认画质',
      value: Pref.liveQuality,
      values: LiveQuality.values.map((e) => (e.code, e.desc)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.liveQuality, res);
    setState();
  }
}

Future<void> _showLiveCellularQaDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<int>(
    context: context,
    builder: (context) => SelectDialog<int>(
      title: '蜂窝网络直播默认画质',
      value: Pref.liveQualityCellular,
      values: LiveQuality.values.map((e) => (e.code, e.desc)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.liveQualityCellular, res);
    setState();
  }
}

Future<void> _showCodecsDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<List<VideoDecodeFormatType>>(
    context: context,
    builder: (context) => OrderedMultiSelectDialog<VideoDecodeFormatType>(
      title: '首选解码格式',
      initValues: Pref.preferCodecs,
      values: {for (final e in VideoDecodeFormatType.values) e: e.name},
    ),
  );
  if (res != null && res.isNotEmpty) {
    await GStorage.setting.put(
      SettingBoxKey.preferCodecs,
      res.map((i) => i.name).toList(),
    );
    setState();
  }
}

Future<void> _showAudioOutputDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<List<String>>(
    context: context,
    builder: (context) => OrderedMultiSelectDialog<String>(
      title: '音频输出设备',
      initValues: Pref.audioOutput.split(','),
      values: {
        for (final e in AudioOutput.values) e.name: e.label,
      },
    ),
  );
  if (res != null && res.isNotEmpty) {
    await GStorage.setting.put(
      SettingBoxKey.audioOutput,
      res.join(','),
    );
    setState();
  }
}

Future<void> _showVideoSyncDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<String>(
    context: context,
    builder: (context) => SelectDialog<String>(
      title: '视频同步',
      value: Pref.videoSync,
      values: const [
        'audio',
        'display-resample',
        'display-resample-vdrop',
        'display-resample-desync',
        'display-tempo',
        'display-vdrop',
        'display-adrop',
        'display-desync',
        'desync',
      ].map((e) => (e, e)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.videoSync, res);
    setState();
  }
}

Future<void> _showHwDecDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<List<String>>(
    context: context,
    builder: (context) => OrderedMultiSelectDialog<String>(
      title: '硬解模式',
      initValues: Pref.hardwareDecoding.split(','),
      values: {
        for (final e in HwDecType.values) e.hwdec: '${e.hwdec}\n${e.desc}',
      },
    ),
  );
  if (res != null && res.isNotEmpty) {
    await GStorage.setting.put(
      SettingBoxKey.hardwareDecoding,
      res.join(','),
    );
    setState();
  }
}

Future<void> _showCustomMpvOptionsDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  var value = Pref.customMpvOptions;
  final optionsScrollController = ScrollController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: const Text('自定义 mpv 启动参数'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '每行一个参数，使用 --参数=值；无值开关可写 --参数，'
              '保存时会转换为 yes，--no-参数会转换为 参数=no。'
              '空行和以 # 开头的行会被忽略。\n\n'
              '示例：\n--video-sync=audio\n--cache-secs=30\n--gpu-api=vulkan',
            ),
            const SizedBox(height: 12),
            Scrollbar(
              controller: optionsScrollController,
              thumbVisibility: true,
              child: TextFormField(
                initialValue: value,
                autofocus: true,
                minLines: 6,
                maxLines: 12,
                scrollController: optionsScrollController,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                onChanged: (text) => value = text,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: Text(
            '取消',
            style: TextStyle(color: ColorScheme.of(context).outline),
          ),
        ),
        TextButton(
          onPressed: () {
            try {
              MpvUtils.parseOptions(value);
              Get.back(result: value.trim());
            } on FormatException catch (e) {
              SmartDialog.showToast('${e.message}');
            }
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
  optionsScrollController.dispose();

  if (result == null) return;
  if (result.isEmpty) {
    await GStorage.setting.delete(SettingBoxKey.customMpvOptions);
  } else {
    await GStorage.setting.put(SettingBoxKey.customMpvOptions, result);
  }
  setState();
  SmartDialog.showToast('已保存，新建播放器后生效');
}

Future<void> _showMpvLogLevelDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final result = await showDialog<String>(
    context: context,
    builder: (context) => SelectDialog<String>(
      title: 'mpv 日志详细等级',
      value: Pref.mpvLogLevel,
      values: _mpvLogLevels,
    ),
  );
  if (result != null) {
    await GStorage.setting.put(SettingBoxKey.mpvLogLevel, result);
    setState();
    SmartDialog.showToast('新建播放器后生效');
  }
}

void _showAutoSyncDialog(BuildContext context, VoidCallback setState) {
  String autosync = Pref.autosync.toString();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('自动同步'),
      content: TextFormField(
        autofocus: true,
        initialValue: autosync,
        keyboardType: TextInputType.number,
        onChanged: (value) => autosync = value,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: Text(
            '取消',
            style: TextStyle(color: ColorScheme.of(context).outline),
          ),
        ),
        TextButton(
          onPressed: () async {
            try {
              // validate
              int.parse(autosync);
              Get.back();
              await GStorage.setting.put(SettingBoxKey.autosync, autosync);
              setState();
            } catch (e) {
              SmartDialog.showToast(e.toString());
            }
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
}

void _showDecimalDialog(
  BuildContext context,
  VoidCallback setState, {
  required String key,
  required double defVal,
  required String title,
  required String? suffix,
}) {
  String value = (GStorage.setting.get(key) ?? defVal).toString();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextFormField(
        autofocus: true,
        initialValue: value,
        keyboardType: const .numberWithOptions(decimal: true),
        onChanged: (val) => value = val,
        inputFormatters: FilteringText.decimal,
        decoration: suffix == null ? null : InputDecoration(suffixText: suffix),
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: Text(
            '取消',
            style: TextStyle(color: ColorScheme.of(context).outline),
          ),
        ),
        TextButton(
          onPressed: () async {
            try {
              final val = double.parse(value);
              Get.back();
              await GStorage.setting.put(key, val);
              setState();
            } catch (e) {
              SmartDialog.showToast(e.toString());
            }
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
}

void _showBufferSizeDialog(BuildContext context, VoidCallback setState) =>
    _showDecimalDialog(
      context,
      setState,
      key: SettingBoxKey.bufferSize,
      defVal: Pref.bufferSize,
      title: '缓冲大小',
      suffix: 'MB',
    );

void _showBufferSecDialog(BuildContext context, VoidCallback setState) =>
    _showDecimalDialog(
      context,
      setState,
      key: SettingBoxKey.bufferSec,
      defVal: Pref.bufferSec,
      title: '缓冲时长',
      suffix: 's',
    );
