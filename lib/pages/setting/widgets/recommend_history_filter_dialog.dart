import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/models/common/recommend_history_filter_settings.dart';
import 'package:PiliPlus/utils/recommend_history.dart';
import 'package:flutter/material.dart';

class RecommendHistoryFilterDialog extends StatefulWidget {
  final RecommendHistoryFilterSettings initialValue;

  const RecommendHistoryFilterDialog({super.key, required this.initialValue});

  @override
  State<RecommendHistoryFilterDialog> createState() =>
      _RecommendHistoryFilterDialogState();
}

class _RecommendHistoryFilterDialogState
    extends State<RecommendHistoryFilterDialog> {
  late bool _enabled;
  late int _days;
  late int _hours;
  late int _minutes;
  late int _exposureThreshold;
  late int _watchThreshold;
  late int _watchMinutes;
  late int _watchSeconds;

  @override
  void initState() {
    super.initState();
    final value = widget.initialValue;
    _enabled = value.enabled;
    _days = value.lookbackMinutes ~/ (24 * 60);
    final remaining = value.lookbackMinutes % (24 * 60);
    _hours = remaining ~/ 60;
    _minutes = remaining % 60;
    _exposureThreshold = value.exposureThreshold;
    _watchThreshold = value.watchThreshold;
    _watchMinutes = value.minWatchSeconds ~/ 60;
    _watchSeconds = value.minWatchSeconds % 60;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      constraints: Style.dialogFixedConstraints,
      title: const Text('近期推荐历史过滤'),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('过滤近期已推荐或看过的视频'),
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
              const Divider(),
              const Text('过去时间'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _numberSelect(
                    value: _days,
                    values: List.generate(31, (index) => index),
                    suffix: '天',
                    onChanged: (value) {
                      setState(() {
                        _days = value;
                        if (_days == 30) {
                          _hours = 0;
                          _minutes = 0;
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _numberSelect(
                    value: _days == 30 ? 0 : _hours,
                    values: _days == 30
                        ? const [0]
                        : List.generate(24, (index) => index),
                    suffix: '小时',
                    onChanged: _days == 30
                        ? null
                        : (value) => setState(() => _hours = value),
                  ),
                  const SizedBox(width: 8),
                  _numberSelect(
                    value: _days == 30 ? 0 : _minutes,
                    values: _days == 30
                        ? const [0]
                        : List.generate(60, (index) => index),
                    suffix: '分',
                    onChanged: _days == 30
                        ? null
                        : (value) => setState(() => _minutes = value),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _thresholdRow(
                label: '推荐次数',
                value: _exposureThreshold,
                onChanged: (value) =>
                    setState(() => _exposureThreshold = value),
              ),
              const SizedBox(height: 12),
              _thresholdRow(
                label: '观看次数',
                value: _watchThreshold,
                onChanged: (value) => setState(() => _watchThreshold = value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: Text('每次至少观看')),
                  SizedBox(
                    width: 92,
                    child: _plainSelect(
                      value: _watchMinutes,
                      values: List.generate(6, (index) => index),
                      suffix: '分',
                      onChanged: (value) {
                        setState(() {
                          _watchMinutes = value;
                          if (_watchMinutes == 5) {
                            _watchSeconds = 0;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 92,
                    child: _plainSelect(
                      value: _watchMinutes == 5 ? 0 : _watchSeconds,
                      values: _watchMinutes == 5
                          ? const [0]
                          : List.generate(60, (index) => index),
                      suffix: '秒',
                      onChanged: _watchMinutes == 5
                          ? null
                          : (value) => setState(() => _watchSeconds = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.query_stats_outlined),
                title: const Text('统计'),
                subtitle: const Text('查看已记录的推荐与观看历史数据'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showStatistics,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }

  Widget _thresholdRow({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        Expanded(child: Text('同一视频$label达到')),
        SizedBox(
          width: 92,
          child: _plainSelect(
            value: value,
            values: List.generate(6, (index) => index),
            suffix: '次',
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _numberSelect({
    required int value,
    required List<int> values,
    required String suffix,
    required ValueChanged<int>? onChanged,
  }) {
    return Expanded(
      child: _plainSelect(
        value: value,
        values: values,
        suffix: suffix,
        onChanged: onChanged,
      ),
    );
  }

  Widget _plainSelect({
    required int value,
    required List<int> values,
    required String suffix,
    required ValueChanged<int>? onChanged,
  }) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      items: values
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text('$item $suffix', maxLines: 1),
            ),
          )
          .toList(),
      onChanged: onChanged == null
          ? null
          : (value) {
              if (value != null) {
                onChanged(value);
              }
            },
    );
  }

  void _showStatistics() {
    showDialog<void>(
      context: context,
      builder: (_) => const _RecommendHistoryStatisticsDialog(),
    );
  }

  void _save() {
    final lookbackMinutes = (_days * 24 * 60 + _hours * 60 + _minutes)
        .clamp(1, RecommendHistoryFilterSettings.maxLookbackMinutes)
        .toInt();
    final minWatchSeconds = (_watchMinutes * 60 + _watchSeconds)
        .clamp(0, 300)
        .toInt();
    Navigator.pop(
      context,
      RecommendHistoryFilterSettings(
        enabled: _enabled,
        lookbackMinutes: lookbackMinutes,
        exposureThreshold: _exposureThreshold,
        watchThreshold: _watchThreshold,
        minWatchSeconds: minWatchSeconds,
      ),
    );
  }
}

class _RecommendHistoryStatisticsDialog extends StatefulWidget {
  const _RecommendHistoryStatisticsDialog();

  @override
  State<_RecommendHistoryStatisticsDialog> createState() =>
      _RecommendHistoryStatisticsDialogState();
}

class _RecommendHistoryStatisticsDialogState
    extends State<_RecommendHistoryStatisticsDialog> {
  late Future<RecommendHistoryStatistics> _statistics;

  @override
  void initState() {
    super.initState();
    _statistics = _loadStatistics();
  }

  Future<RecommendHistoryStatistics> _loadStatistics() =>
      RecommendHistoryRepository.instance.loadStatistics(
        scopeId: currentRecommendHistoryScope(),
      );

  void _reload() {
    setState(() => _statistics = _loadStatistics());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      constraints: Style.dialogFixedConstraints,
      title: Row(
        children: [
          const Expanded(child: Text('历史数据统计')),
          IconButton(
            tooltip: '刷新统计',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      content: SizedBox(
        width: 430,
        height: (MediaQuery.sizeOf(context).height * 0.62)
            .clamp(280.0, 560.0)
            .toDouble(),
        child: FutureBuilder<RecommendHistoryStatistics>(
          future: _statistics,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: FilledButton.tonalIcon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('统计加载失败，重试'),
                ),
              );
            }
            return _statisticsList(context, snapshot.data!);
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _statisticsList(
    BuildContext context,
    RecommendHistoryStatistics statistics,
  ) {
    return ListView(
      children: [
        _sectionTitle(context, '存储'),
        _statRow(
          context,
          '数据库总大小',
          _formatBytes(statistics.totalDatabaseBytes),
        ),
        _statRow(
          context,
          '推荐数据库大小',
          _formatBytes(statistics.exposureDatabaseBytes),
        ),
        _statRow(
          context,
          '观看数据库大小',
          _formatBytes(statistics.watchDatabaseBytes),
        ),
        _statRow(
          context,
          '推荐数据库键数',
          '${statistics.exposureDatabaseEntryCount}',
        ),
        _statRow(
          context,
          '观看数据库键数',
          '${statistics.watchDatabaseEntryCount}',
        ),
        _statRow(
          context,
          '数据保留期限',
          '${recommendHistoryRetention.inDays} 天',
        ),
        _sectionTitle(context, '保留期总计'),
        _statRow(context, '账号作用域', '${statistics.scopeCount}'),
        _statRow(context, '推荐展示记录', '${statistics.recommendationCount}'),
        _statRow(
          context,
          '推荐视频（去重）',
          '${statistics.recommendedVideoCount}',
        ),
        _statRow(context, '观看会话记录', '${statistics.watchCount}'),
        _statRow(
          context,
          '观看视频（去重）',
          '${statistics.watchedVideoCount}',
        ),
        _statRow(context, '已结束观看会话', '${statistics.completedWatchCount}'),
        _statRow(
          context,
          '累计有效播放时长',
          _formatDuration(statistics.activePlayedMs),
        ),
        _statRow(
          context,
          '平均每次观看时长',
          _formatDuration(statistics.averageActivePlayedMs),
        ),
        _statRow(
          context,
          '推荐 UGC 视频（去重）',
          '${statistics.recommendedUgcVideoCount}',
        ),
        _statRow(
          context,
          '推荐 PGC 视频（去重）',
          '${statistics.recommendedPgcVideoCount}',
        ),
        _statRow(
          context,
          '观看 UGC 视频（去重）',
          '${statistics.watchedUgcVideoCount}',
        ),
        _statRow(
          context,
          '观看 PGC 视频（去重）',
          '${statistics.watchedPgcVideoCount}',
        ),
        _statRow(
          context,
          '最早记录',
          _formatDateTime(statistics.oldestRecordAt),
        ),
        _statRow(
          context,
          '最新记录',
          _formatDateTime(statistics.newestRecordAt),
        ),
        _sectionTitle(context, '当前账号'),
        _statRow(
          context,
          '推荐展示记录',
          '${statistics.currentScopeRecommendationCount}',
        ),
        _statRow(
          context,
          '推荐视频（去重）',
          '${statistics.currentScopeRecommendedVideoCount}',
        ),
        _statRow(
          context,
          '观看会话记录',
          '${statistics.currentScopeWatchCount}',
        ),
        _statRow(
          context,
          '观看视频（去重）',
          '${statistics.currentScopeWatchedVideoCount}',
        ),
        ..._windowRows(context, '近 24 小时', statistics.lastDay),
        ..._windowRows(context, '近 7 天', statistics.lastWeek),
        ..._windowRows(context, '近 30 天', statistics.lastMonth),
      ],
    );
  }

  List<Widget> _windowRows(
    BuildContext context,
    String title,
    RecommendHistoryWindowStatistics statistics,
  ) => [
    _sectionTitle(context, title),
    _statRow(context, '推荐展示记录', '${statistics.recommendationCount}'),
    _statRow(
      context,
      '推荐视频（去重）',
      '${statistics.recommendedVideoCount}',
    ),
    _statRow(context, '观看会话记录', '${statistics.watchCount}'),
    _statRow(
      context,
      '观看视频（去重）',
      '${statistics.watchedVideoCount}',
    ),
    _statRow(
      context,
      '累计有效播放时长',
      _formatDuration(statistics.activePlayedMs),
    ),
  ];

  Widget _sectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _statRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(label)),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  String _formatBytes(int? bytes) {
    if (bytes == null) return '不可用';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return unit == 0
        ? '${value.toInt()} ${units[unit]}'
        : '${value.toStringAsFixed(2)} ${units[unit]}';
  }

  String _formatDuration(int milliseconds) {
    if (milliseconds <= 0) return '0 秒';
    final duration = Duration(milliseconds: milliseconds);
    final parts = <String>[];
    if (duration.inDays > 0) parts.add('${duration.inDays} 天');
    final hours = duration.inHours % 24;
    if (hours > 0) parts.add('$hours 小时');
    final minutes = duration.inMinutes % 60;
    if (minutes > 0) parts.add('$minutes 分');
    final seconds = duration.inSeconds % 60;
    if (seconds > 0 || parts.isEmpty) parts.add('$seconds 秒');
    return parts.join(' ');
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '暂无';
    final local = value.toLocal();
    String twoDigits(int part) => part.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}
