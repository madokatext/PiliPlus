import 'dart:async';
import 'dart:convert';

import 'package:PiliPlus/common/assets.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/flutter/list_tile.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/route_aware_mixin.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:PiliPlus/models_new/fav/fav_folder/list.dart';
import 'package:PiliPlus/pages/common/common_page.dart';
import 'package:PiliPlus/pages/home/view.dart';
import 'package:PiliPlus/pages/login/controller.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/pages/mine/widgets/item.dart';
import 'package:PiliPlus/utils/bili_utils.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/material.dart' hide ListTile;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class MinePage extends StatefulWidget {
  const MinePage({super.key, this.showBackBtn = false});

  final bool showBackBtn;

  @override
  State<MinePage> createState() => _MediaPageState();
}

class _MediaPageState extends CommonPageState<MinePage>
    with AutomaticKeepAliveClientMixin, RouteAware, RouteAwareMixin {
  static const _quoteAsset = 'assets/data/hitokoto.txt';
  static const _quoteBreakPunctuation = <String>{
    '，',
    ',',
    '。',
    '.',
    '！',
    '!',
    '？',
    '?',
    '；',
    ';',
    '：',
    ':',
    '、',
    '…',
    '—',
    '～',
    '~',
  };
  static const _quoteClosingPunctuation = <String>{
    '”',
    '’',
    '"',
    "'",
    '）',
    ')',
    '】',
    ']',
    '〕',
    '}',
    '》',
    '〉',
    '」',
    '』',
  };
  static Future<List<String>>? _quotesFuture;
  static int? _nextQuoteIndex;

  final MineController controller = Get.putOrFind(MineController.new);
  late final MainController _mainController = Get.find<MainController>();
  Worker? _selectedIndexWorker;
  bool _wasCurrentMinePage = false;
  int _quoteRequest = 0;
  String? _quote;

  @override
  bool get wantKeepAlive => true;

  bool get _isCurrentMinePage {
    final index = _mainController.selectedIndex.value;
    return index >= 0 &&
        index < _mainController.navigationBars.length &&
        _mainController.navigationBars[index] == NavigationBarType.mine;
  }

  @override
  void initState() {
    super.initState();
    _wasCurrentMinePage = widget.showBackBtn || _isCurrentMinePage;
    if (!widget.showBackBtn) {
      _selectedIndexWorker = ever<int>(
        _mainController.selectedIndex,
        (_) => _handlePageSelection(),
      );
    }
    if (_wasCurrentMinePage) {
      _refreshQuote();
    }
  }

  void _handlePageSelection() {
    final isCurrentMinePage = _isCurrentMinePage;
    if (isCurrentMinePage && !_wasCurrentMinePage) {
      _refreshQuote();
    }
    _wasCurrentMinePage = isCurrentMinePage;
  }

  @override
  void didPopNext() {
    if (widget.showBackBtn || _isCurrentMinePage) {
      _refreshQuote();
    }
    super.didPopNext();
  }

  void _refreshQuote() {
    if (Pref.showMineQuote) {
      unawaited(_rotateQuote());
      return;
    }

    _quoteRequest++;
    if (_quote != null && mounted) {
      setState(() => _quote = null);
    }
  }

  static Future<List<String>> _loadQuotes() async {
    final content = await rootBundle.loadString(_quoteAsset);
    return const LineSplitter()
        .convert(content)
        .map((quote) => quote.trim())
        .where((quote) => quote.isNotEmpty)
        .toList(growable: false);
  }

  static List<({String text, bool leadingSpace})> _splitQuoteClauses(
    String quote,
  ) {
    final clauses = <({String text, bool leadingSpace})>[];
    var buffer = StringBuffer();
    var leadingSpace = false;
    var canBreak = false;
    var hasBoundaryWhitespace = false;

    void flush() {
      if (buffer.isNotEmpty) {
        clauses.add((text: buffer.toString(), leadingSpace: leadingSpace));
        buffer = StringBuffer();
      }
    }

    for (final rune in quote.runes) {
      final char = String.fromCharCode(rune);
      if (canBreak && char.trim().isEmpty) {
        hasBoundaryWhitespace = true;
        continue;
      }

      if (canBreak &&
          !_quoteBreakPunctuation.contains(char) &&
          !_quoteClosingPunctuation.contains(char)) {
        flush();
        leadingSpace = hasBoundaryWhitespace;
        canBreak = false;
        hasBoundaryWhitespace = false;
      }

      buffer.write(char);
      if (_quoteBreakPunctuation.contains(char)) {
        canBreak = true;
      }
    }
    flush();
    return clauses;
  }

  static String _wrapQuote({
    required String quote,
    required double maxWidth,
    required TextStyle? style,
    required TextScaler textScaler,
    required TextDirection textDirection,
    required Locale? locale,
  }) {
    if (quote.isEmpty || maxWidth <= 0 || !maxWidth.isFinite) {
      return quote;
    }

    final clauses = _splitQuoteClauses(quote);
    if (clauses.length <= 1) {
      return quote;
    }

    final painter = TextPainter(
      textDirection: textDirection,
      textScaler: textScaler,
      locale: locale,
    );

    int lineCount(String text) {
      painter
        ..text = TextSpan(text: text, style: style)
        ..layout(maxWidth: maxWidth);
      return painter.computeLineMetrics().length;
    }

    final lines = <String>[];
    var current = '';
    var currentLineCount = 0;
    try {
      for (final clause in clauses) {
        if (current.isEmpty) {
          current = clause.text;
          currentLineCount = lineCount(current);
          continue;
        }

        final separator = clause.leadingSpace ? ' ' : '';
        final candidate = '$current$separator${clause.text}';
        final candidateLineCount = lineCount(candidate);

        // 能独占一行的短句必须整体移到下一行；只有单句本身过长时，
        // 才保留 Flutter 的句内自动折行，并继续利用其最后一行的余量。
        if (candidateLineCount > currentLineCount &&
            lineCount(clause.text) == 1) {
          lines.add(current);
          current = clause.text;
          currentLineCount = 1;
        } else {
          current = candidate;
          currentLineCount = candidateLineCount;
        }
      }
    } finally {
      painter.dispose();
    }

    if (current.isNotEmpty) {
      lines.add(current);
    }
    return lines.join('\n');
  }

  Future<void> _rotateQuote() async {
    final request = ++_quoteRequest;
    try {
      final quotes = await (_quotesFuture ??= _loadQuotes());
      if (quotes.isEmpty ||
          !mounted ||
          request != _quoteRequest ||
          !Pref.showMineQuote) {
        return;
      }

      _nextQuoteIndex ??=
          (GStorage.localCache.get(LocalCacheKey.mineQuoteIndex) as int? ?? 0) %
          quotes.length;
      final index = _nextQuoteIndex!;
      _nextQuoteIndex = (index + 1) % quotes.length;
      unawaited(
        GStorage.localCache.put(LocalCacheKey.mineQuoteIndex, _nextQuoteIndex),
      );

      setState(() => _quote = quotes[index]);
    } catch (_) {
      // The bundled quote file is optional UI content; keep the page usable if
      // the asset cannot be loaded.
    }
  }

  @override
  void dispose() {
    _selectedIndexWorker?.dispose();
    super.dispose();
  }

@override
bool onNotificationType1(UserScrollNotification notification) {
  if (_isCurrentMinePage) {
    // instant 模式：始终保持底栏显示
    _mainController.showBottomBar?.value = true;
  }
  return false;
}

@override
bool onNotificationType2(ScrollNotification notification) {
  if (_isCurrentMinePage) {
    // sync 模式：始终把底栏恢复到完整显示位置
    _mainController.barOffset?.value = 0.0;
  }
  return false;
}

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;
    return Column(
      children: [
        Padding(
          padding: const .symmetric(vertical: 10),
          child: _buildHeaderActions,
        ),
        Expanded(
          child: Material(
            type: .transparency,
            child: refreshIndicator(
              onRefresh: controller.onRefresh,
              requireInitialDownwardDrag: true,
              child: onBuild(
                CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _buildUserInfo(theme, secondary),
                          _buildActions(secondary),
                          Obx(
                            () => controller.loadingState.value is Loading
                                ? const SizedBox.shrink()
                                : _buildFav(theme, secondary),
                          ),
                        ],
                      ),
                    ),
                    SliverLayoutBuilder(
                      builder: (context, constraints) {
                        const bottomPadding = 100.0;
                        final availableHeight =
                            constraints.viewportMainAxisExtent -
                            constraints.precedingScrollExtent -
                            bottomPadding;
                        return SliverToBoxAdapter(
                          child: SizedBox(
                            height: availableHeight > 0 ? availableHeight : 0,
                            child: _buildQuote(theme),
                          ),
                        );
                      },
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuote(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final style = theme.textTheme.bodyMedium?.copyWith(height: 1.6);
          final quote = _wrapQuote(
            quote: _quote ?? '',
            maxWidth: constraints.maxWidth,
            style: style,
            textScaler: MediaQuery.textScalerOf(context),
            textDirection: Directionality.of(context),
            locale: Localizations.maybeLocaleOf(context),
          );
          return Center(
            child: Text(
              quote,
              textAlign: TextAlign.center,
              overflow: TextOverflow.fade,
              style: style,
            ),
          );
        },
      ),
    );
  }

  Widget _buildActions(Color primary) {
    return Row(
      mainAxisAlignment: .spaceEvenly,
      children: controller.list
          .map(
            (e) => Flexible(
              child: InkWell(
                onTap: e.onTap,
                borderRadius: Style.mdRadius,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 80),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Column(
                      spacing: 6,
                      mainAxisSize: .min,
                      mainAxisAlignment: .center,
                      children: [
                        Icon(e.icon, color: primary),
                        Text(
                          e.title,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget get _buildHeaderActions {
    const iconSize = 22.0;
    const padding = EdgeInsets.all(8);
    const style = ButtonStyle(tapTargetSize: .shrinkWrap);
    return Row(
      spacing: 5,
      mainAxisAlignment: .end,
      children: [
        if (widget.showBackBtn)
          const Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 8),
                child: BackButton(),
              ),
            ),
          ),
        if (!_mainController.hasHome) ...[
          IconButton(
            iconSize: iconSize,
            padding: padding,
            style: style,
            tooltip: '搜索',
            onPressed: () => Get.toNamed('/search'),
            icon: const Icon(Icons.search),
          ),
          msgBadge(_mainController),
        ],
        if (GStorage.reply != null)
          IconButton(
            iconSize: iconSize,
            padding: padding,
            style: style,
            tooltip: '评论记录',
            onPressed: () => Get.toNamed('/myReply'),
            icon: const Icon(Icons.message_outlined),
          ),
        Obx(
          () {
            final anonymity = MineController.anonymity.value;
            return IconButton(
              iconSize: iconSize,
              padding: padding,
              style: style,
              tooltip: "${anonymity ? '退出' : '进入'}无痕模式",
              onPressed: MineController.onChangeAnonymity,
              icon: anonymity
                  ? const Icon(MdiIcons.incognito)
                  : const Icon(MdiIcons.incognitoOff),
            );
          },
        ),
        IconButton(
          iconSize: iconSize,
          padding: padding,
          style: style,
          tooltip: '切换账号',
          onPressed: () => LoginPageController.switchAccountDialog(context),
          icon: const Icon(Icons.switch_account_outlined),
        ),
        Obx(
          () {
            return IconButton(
              iconSize: iconSize,
              padding: padding,
              style: style,
              tooltip: '切换至${controller.nextThemeType.desc}主题',
              onPressed: controller.onChangeTheme,
              icon: controller.themeType.value.icon,
            );
          },
        ),
        IconButton(
          iconSize: iconSize,
          padding: padding,
          style: style,
          tooltip: '设置',
          onPressed: () => Get.toNamed('/setting', preventDuplicates: false),
          icon: const Icon(Icons.settings_outlined),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildUserInfo(ThemeData theme, Color secondary) {
    final style = TextStyle(
      fontSize: theme.textTheme.titleMedium!.fontSize,
      fontWeight: FontWeight.bold,
    );
    final labelStyle = theme.textTheme.labelMedium!.copyWith(
      color: theme.colorScheme.outline,
    );
    final coinLabelStyle = TextStyle(
      fontSize: theme.textTheme.labelMedium!.fontSize,
      color: theme.colorScheme.outline,
    );
    final coinValStyle = TextStyle(
      fontSize: theme.textTheme.labelMedium!.fontSize,
      fontWeight: FontWeight.bold,
      color: secondary,
    );
    return Obx(() {
      final userInfo = controller.userInfo.value;
      final levelInfo = userInfo.levelInfo;
      final hasLevel = levelInfo != null;
      final isVip = userInfo.vipStatus != null && userInfo.vipStatus! > 0;
      final userStat = controller.userStat.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: .opaque,
            onTap: controller.onLogin,
            onLongPress: () {
              Feedback.forLongPress(context);
              controller.onLogin(true);
            },
            onSecondaryTap: PlatformUtils.isMobile
                ? null
                : () => controller.onLogin(true),
            child: Row(
              mainAxisSize: .min,
              children: [
                const SizedBox(width: 20),
                userInfo.face != null
                    ? Stack(
                        clipBehavior: .none,
                        children: [
                          NetworkImgLayer(
                            src: userInfo.face,
                            type: .avatar,
                            width: 55,
                            height: 55,
                          ),
                          if (isVip)
                            Positioned(
                              right: -1,
                              bottom: -2,
                              child: SvgPicture.asset(
                                Assets.vipIcon,
                                height: 19,
                                semanticsLabel: "大会员",
                              ),
                            ),
                        ],
                      )
                    : ClipOval(
                        child: Image.asset(
                          width: 55,
                          height: 55,
                          cacheHeight: 55.cacheSize(context),
                          Assets.avatarPlaceHolder,
                          semanticLabel: "默认头像",
                        ),
                      ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: .min,
                    mainAxisAlignment: .center,
                    crossAxisAlignment: .start,
                    children: [
                      Row(
                        spacing: 6,
                        children: [
                          Flexible(
                            child: Text(
                              userInfo.uname ?? '点击登录',
                              style: theme.textTheme.titleMedium!.copyWith(
                                height: 1,
                                color: isVip && userInfo.vipType == 2
                                    ? theme.colorScheme.vipColor
                                    : null,
                              ),
                              maxLines: 1,
                              overflow: .ellipsis,
                            ),
                          ),
                          BiliUtils.levelPicture(
                            levelInfo?.currentLevel ?? 0,
                            isSeniorMember: userInfo.isSeniorMember == 1,
                            height: 10,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '硬币 ',
                              style: coinLabelStyle,
                            ),
                            TextSpan(
                              text: userInfo.money?.toString() ?? '-',
                              style: coinValStyle,
                            ),
                            TextSpan(
                              text: "      经验 ",
                              style: coinLabelStyle,
                            ),
                            TextSpan(
                              text: levelInfo?.currentExp?.toString() ?? '-',
                              style: coinValStyle,
                            ),
                            TextSpan(
                              text: "/${levelInfo?.nextExp ?? '-'}",
                              style: coinLabelStyle,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 225),
                        child: LinearProgressIndicator(
                          minHeight: 2.25,
                          value: hasLevel
                              ? levelInfo.currentExp! / levelInfo.nextExp!
                              : 0,
                          backgroundColor: theme.colorScheme.outline.withValues(
                            alpha: 0.4,
                          ),
                          valueColor: AlwaysStoppedAnimation<Color>(secondary),
                          stopIndicatorColor: Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: .spaceEvenly,
            children: [
              _btn(
                count: userStat.dynamicCount,
                countStyle: style,
                name: '动态',
                labelStyle: labelStyle,
                onTap: () => controller.push('memberDynamics'),
              ),
              _btn(
                count: userStat.following,
                countStyle: style,
                name: '关注',
                labelStyle: labelStyle,
                onTap: () => controller.push('follow'),
              ),
              _btn(
                count: userStat.follower,
                countStyle: style,
                name: '粉丝',
                labelStyle: labelStyle,
                onTap: () => controller.push('fan'),
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _btn({
    required int? count,
    required TextStyle countStyle,
    required String name,
    required TextStyle? labelStyle,
    required VoidCallback onTap,
  }) {
    return Flexible(
      child: InkWell(
        onTap: onTap,
        borderRadius: Style.mdRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 80),
          child: AspectRatio(
            aspectRatio: 1,
            child: Column(
              spacing: 4,
              mainAxisSize: .min,
              mainAxisAlignment: .center,
              children: [
                Text(
                  count?.toString() ?? '-',
                  style: countStyle,
                ),
                Text(
                  name,
                  style: labelStyle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _autoRefresh() => Future.delayed(
    const Duration(milliseconds: 150),
    () => controller.onRefresh(isManual: false),
  );

  Widget _buildFav(ThemeData theme, Color secondary) {
    return Column(
      children: [
        Divider(
          height: 20,
          color: theme.dividerColor.withValues(alpha: 0.1),
        ),
        ListTile(
          onTap: () => Get.toNamed('/fav')?.whenComplete(_autoRefresh),
          dense: true,
          title: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '我的收藏  ',
                    style: TextStyle(
                      fontSize: theme.textTheme.titleMedium!.fontSize,
                      fontWeight: .bold,
                    ),
                  ),
                  if (controller.favFolderCount != null)
                    TextSpan(
                      text: "${controller.favFolderCount}  ",
                      style: TextStyle(
                        fontSize: theme.textTheme.titleSmall!.fontSize,
                        color: secondary,
                      ),
                    ),
                  WidgetSpan(
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          trailing: IconButton(
            tooltip: '刷新',
            onPressed: controller.onRefresh,
            icon: const Icon(Icons.refresh, size: 20),
          ),
        ),
        _buildFavBody(theme, secondary, controller.loadingState.value),
      ],
    );
  }

  Widget _buildFavBody(
    ThemeData theme,
    Color secondary,
    LoadingState loadingState,
  ) {
    return switch (loadingState) {
      Loading() => const SizedBox.shrink(),
      Success(:final response) => Builder(
        builder: (context) {
          List<FavFolderInfo>? favFolderList = response.list;
          if (favFolderList == null || favFolderList.isEmpty) {
            return const SizedBox.shrink();
          }
          bool flag = (controller.favFolderCount ?? 0) > favFolderList.length;
          return SizedBox(
            height: 200,
            child: ListView.separated(
              controller: controller.scrollController,
              padding: const .only(left: 20, top: 10, right: 20),
              itemCount: response.list.length + (flag ? 1 : 0),
              itemBuilder: (context, index) {
                if (flag && index == favFolderList.length) {
                  return Padding(
                    padding: const .only(bottom: 35),
                    child: Center(
                      child: IconButton(
                        tooltip: '查看更多',
                        style: ButtonStyle(
                          padding: const WidgetStatePropertyAll(.zero),
                          backgroundColor: WidgetStatePropertyAll(
                            theme.colorScheme.secondaryContainer.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        onPressed: () =>
                            Get.toNamed('/fav')?.whenComplete(_autoRefresh),
                        icon: Icon(
                          Icons.arrow_forward_ios,
                          size: 18,
                          color: secondary,
                        ),
                      ),
                    ),
                  );
                } else {
                  return FavFolderItem(
                    heroTag: Utils.generateRandomString(8),
                    item: response.list[index],
                    onPop: _autoRefresh,
                  );
                }
              },
              scrollDirection: .horizontal,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
            ),
          );
        },
      ),
      Error(:final errMsg) => SizedBox(
        height: 160,
        child: Center(
          child: Text(
            errMsg ?? '',
            textAlign: .center,
          ),
        ),
      ),
    };
  }
}
