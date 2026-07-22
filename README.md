> **PiliPlus-max 是 [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus) 经过深度自定义和细节优化的分支版本。**

<div align="center">
    <img width="200" height="200" src="assets/images/logo/logo.png">
</div>

<div align="center">
    <h1>PiliPlus-max</h1>

![GitHub repo size](https://img.shields.io/github/repo-size/madokatext/PiliPlus-Max)
![GitHub Repo stars](https://img.shields.io/github/stars/madokatext/PiliPlus-Max)
![GitHub all releases](https://img.shields.io/github/downloads/madokatext/PiliPlus-Max/total)

<p>使用 Flutter 开发的 BiliBili 第三方客户端</p>

<img src="assets/screenshots/510shots_so.png" width="32%" alt="home" />
<img src="assets/screenshots/174shots_so.png" width="32%" alt="home" />
<img src="assets/screenshots/850shots_so.png" width="32%" alt="home" />
<br/>
<img src="assets/screenshots/main_screen.png" width="96%" alt="home" />
</div>

## 与 main 分支的区别

以下按当前 [`main...mod2`](https://github.com/madokatext/PiliPlus-Max/compare/main...mod2) 的最终代码差异整理，已排除后来完全回滚的中间方案。

### 项目与设置

- 应用改名为 `PiliPlus-max`，包名改为 `com.max.piliplus`，版本标识改为 `2.1a`。
- 源码、更新、Release、问题反馈和构建链接均指向本仓库。
- 关闭 Android 主题色图标，固定使用默认绿色图标和白色背景。
- 内置一套深度调校的首次启动默认配置，仅填充尚不存在的设置。
- 新增所有设置 JSON 导入导出，文件保存到公共 Download 目录并带导出时间。
- 登录信息导入导出移至设置首页，关于页不再重复显示导入导出入口。

### 主题、首页与交互

- 新增动态取色、预设单种子和自定义三种子三种配色模式。
- 支持分别设置主、次、第三种子色及透明度。
- 支持分别调整亮色和暗色主题各语义区域的 HCT 明暗层级。
- 首页卡片左右间隔、上下间隔、左右边距和全局卡片圆角均可调。
- 首页顶部分类栏高度和传统底栏底部留白均可调。
- 首页手动刷新卡片数量可调，App 推荐模式会自动合并多个请求批次。
- 推荐卡片时长可与统计信息同行，播放量与弹幕数间距可调。
- 推荐卡片新增与标题对齐的 `UP` 标识，并统一作者信息间距。
- 优化“上次看到这里”和“上次观看”的文字间距与排版。
- 横向标签页可分别设置快滑速度阈值和慢滑翻页距离。
- 页面纵向滚动的惯性倍率和减速度可调，顶底栏可跟随惯性滚动。
- 设置搜索支持完整结果、搜索历史、快捷重搜和历史清空。
- 评论正文大小、行距和折叠回复字号比例均可调。
- 评论操作区改为左对齐，并优化点赞、点踩、回复、翻译等项目的顺序与间距。
- 评论点赞数为零时隐藏数字但保留布局宽度。

### 播放器与字幕

- 新增半屏独立默认画质，首次进入全屏后再切换到原有画质策略。
- 新增自定义 mpv 启动参数，用户参数覆盖内置重复项并应用于视频、音频和 Live Photo。
- 新增 mpv 日志等级设置和最近一次播放日志查看页面。
- AI 入口优先显示网页版 AI 小助手字幕；仅有总结时回退播放器字幕并优先中文。
- AI 字幕显示时间戳并支持点击跳转，新增复制全部且扩大入口触摸范围。
- 播放控件显示时间和长按倍速触发延迟均可调。
- 新增 B 站官方式进度时间布局，将当前时间和总时长放到进度条两侧。
- 进度条手柄大小和垂直触摸范围可调，并修正扩展区域点击跳转偏移。
- 播放器按钮横向边距、上下栏厚度和渐变弥散范围均可调。
- 竖屏全屏底栏可选择避让系统导航栏，并可单独设置避让高度。
- 全屏倍速和画面比例入口移至顶栏，弹幕开关移至底栏，并移除控制栏超分辨率入口。
- 拖动进度条与横滑快进可分别控制预览浮窗显示及是否跟随手柄。
- 预览浮窗大小、与进度条间距及非全屏显示均可调，位置跟随当前可见进度条。
- 预览雪碧图按视频比例校正并用黑边补齐；竖屏视频保持原始雪碧图比例。
- 优化预览图缓存、加载任务复用和视频切换清理，减少长时间转圈与旧图残留。
- 当前时间可集成到预览浮窗，进度与长按倍速浮窗的字号和垂直位置可分别设置。
- 音量、亮度手势的识别角度和调节速度可分别设置，并可改用主题色图形进度条。
- 横滑快进的识别角度与触发距离可调，双指缩放也可设置识别角度。
- 优先识别双指播放器手势，减少竖向缩放被页面滚动抢占的问题。
- 新增弹幕字体选择，并统一应用到普通弹幕与高级弹幕渲染。
- 重构章节、屏蔽段和弹幕趋势层级，避免遮挡播放进度条触摸。
- 章节文字固定字号并按章节范围截断，当前章节变化时自动更新显示。
- 修复同一 UP 视频切换后进入全屏仍显示上一视频的问题。

## 适配平台

- [x] Android
- [x] iOS
- [x] Pad
- [x] Windows
- [x] Linux

[![Packaging status](https://repology.org/badge/vertical-allrepos/piliplus.svg)](https://repology.org/project/piliplus/versions)

## 原项目功能

本分支完整继承 PiliPlus 的基础功能。原 README 中的 `refactor`、`feat`、`opt`、`fix` 与“功能”清单不再重复，详见 [PiliPlus 原项目](https://github.com/bggRGjQaUbCoE/PiliPlus#readme)。

## 下载

可以通过右侧 Release 下载，或拉取代码到本地编译。

## 声明

此项目（PiliPlus-max）是个人为了兴趣而开发，仅用于学习和测试，请于下载后 24 小时内删除。

所用 API 皆从官方网站收集，不提供任何破解内容。

本项目基于 [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus) 进行深度自定义，感谢 PiliPlus 的长期维护与开源贡献。

在此致敬原作者：[guozhigq/pilipala](https://github.com/guozhigq/pilipala)

在此致敬上游作者：[orz12/PiliPalaX](https://github.com/orz12/PiliPalaX)

本仓库做了更激进的修改，感谢各上游项目与贡献者的开源精神。

感谢使用。

## 致谢

- [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)
- [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect)
- [flutter_meedu_videoplayer](https://github.com/zezo357/flutter_meedu_videoplayer)
- [media-kit](https://github.com/media-kit/media-kit)
- [dio](https://pub.dev/packages/dio)
- 等等
