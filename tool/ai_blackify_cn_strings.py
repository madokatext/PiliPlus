from __future__ import annotations

import hashlib
import json
import re
from collections import defaultdict
from pathlib import Path

SCAN_PATH = Path('scan_bundle/scan.json')
REPORT_PATH = Path('scan_bundle/blackify_report.json')

EXACT = {
    '取消': '不整了，撤！',
    '确定': '包的，就这么整',
    '确认': '拍板，启动！',
    '账号未登录': '赛博户口没上号',
    '搜索': '全站搜刮',
    '关闭': '啪一下封印',
    '删除成功': '已成功物理超度',
    '提示': '赛博小喇叭',
    '评论': '赛博锐评',
    '举报': '赛博递状纸',
    '删除': '一键物理超度',
    '稍后再看': '先吃灰，回头再炫',
    '分享': '到处扩散',
    '点赞': '赛博大拇哥',
    '设置成功': '调参焊死，包成的',
    '充电专属': '氪金充电特供',
    '番剧': '纸片人连续剧',
    '清空': '一键扬了',
    '重置': '恢复出厂人格',
    '复制链接': '薅走这串门牌号',
    '收藏': '塞进电子小被窝',
    '视频': '电子榨菜',
    '其他': '剩下那坨',
    '其它': '剩下那坨',
    '动态': '互联网近况',
    '复制': '赛博复刻',
    '裁剪': '咔嚓修边',
    '请先登录': '先上号再整活',
    '请求中': '正在敲机房大爹家门',
    '转发': '二次扩散',
    '返回': '润回去',
    '专栏': '赛博小作文',
    '保存': '焊死这个配置',
    '分享至动态': '丢到互联网近况',
    '分享至消息': '塞进赛博小纸条',
    '加载中...': '疯狂搬数据中，CPU已冒烟...',
    '取消赞': '大拇哥收回',
    '合作': '梦幻联动',
    '完成': '收工，包成的',
    '排序': '重新排座次',
    '直播': '赛博围观现场',
    '移除': '踢出群聊',
    '编辑': '重新盘它',
    '请退出账号后重新登录': '先把赛博户口润出去，再重新上号',
    '课堂': '知识灌脑区',
    '重启生效': '重开一把才算数',
    ' 已保存 ': ' 已焊死，包的 ',
    '全部': '我全都要',
    '关注': '赛博蹲点',
    '刷新': '重新投胎',
    '发送': '发射',
    '发送成功': '已成功发射',
    '已关注': '已赛博蹲点',
    '已看完': '已炫完',
    '影视': '大屏电子榨菜',
    '播放': '开炫',
    '更新失败': '版本投胎寄了',
    '更新成功': '版本投胎成功，包的',
    '正在播放：': '正在开炫：',
    '没有更多了': '真没了，别扒拉了',
    '点赞成功': '大拇哥已送达，功德+1',
    '点踩': '赛博倒拇指',
    '电影': '两小时电子榨菜',
    '观看': '开炫',
    '评论详情': '锐评案发现场',
    '追番': '电子追番',
    '默认': '祖传默认',
    '主题模式': '皮肤人格模式',
    '仅自己可见': '仅本鼠可见',
    '全选': '我全都要',
    '再看': '二刷启动',
    '动画': '纸片人运动会',
    '取消收藏': '踢出电子小被窝',
    '合集': '电子大礼包',
    '国创': '国创专区·启动',
    '垃圾广告': '赛博牛皮癣',
    '多选': '批量抓壮丁',
    '大会员': '尊贵氪佬通行证',
    '定时关闭': '定点熄火',
    '展开': '摊开讲',
    '弹幕设置': '满屏飘字调参室',
    '投币': '上贡硬币',
    '推荐': '算法喂饭',
    '播放信息': '开炫参数',
    '播放全部': '一锅端开炫',
    '收起': '卷起来',
    '时间': '时间线',
    '更多': '再扒拉点',
    '正在提交': '正在往机房大爹桌上拍',
    '没有数据': '空得能跑马',
    '添加': '塞一个进去',
    '用户': '赛博居民',
    '登录': '上号',
    '禁用': '当场封印',
    '移动': '挪个窝',
    '综艺': '电子乐子场',
    '超分辨率': '赛博开眼',
    'CDN 设置': 'CDN 炼丹房',
    '三连成功': '一键功德三连，功德+3',
    '从剪贴板导入': '从剪贴板往里灌',
    '保存图片': '把赛博小画片薅到本地',
    '修改成功': '重新盘它成功，包的',
    '倒序': '反着排',
    '入站必刷': '镇站电子榨菜',
    '其它app打开': '甩给别的 App',
    '分享视频': '扩散这盘电子榨菜',
    '发布': '发射到互联网',
    '发弹幕': '往屏幕上扔字',
    '取消保存': '不焊了，撤',
    '取消踩': '撤回倒拇指',
    '回复我的': '来找我对线的',
    '图片': '赛博小画片',
    '在看': '正在炫',
    '密码': '芝麻开门口令',
    '导入失败：$e': '往里灌寄了：$e',
    '导入成功': '往里灌成功，包的',
    '导出文件至本地': '薅成赛博卷宗落地',
    '导出至剪贴板': '薅到剪贴板',
    '已保存': '已焊死，包的',
    '已删除': '已物理超度',
    '已取消收藏': '已踢出电子小被窝',
    '忘记密码': '芝麻口令失忆了',
    '想看': '塞进赛博愿望单',
    '投币失败': '硬币上贡失败，寄',
    '投稿': '赛博投递',
    '排序完成': '座次排明白了，包的',
    '排行榜': '神仙打架榜',
    '播放器音量': '开炫机器喇叭声压',
    '收到的赞': '收到的大拇哥',
    '收藏夹': '电子小被窝',
    '新建分组': '再开个小圈子',
    '更新': '版本投胎',
    '最多播放': '炫得最多',
    '最新': '刚出锅',
    '最新发布': '刚出锅',
    '查看全部': '一锅端看完',
    '查看更多': '再扒拉亿点',
    '正在保存': '正在往硬盘焊',
    '浏览器打开': '扔浏览器里开',
    '游戏': '赛博游乐场',
    '点踩成功': '倒拇指已送达',
    '点错了': '手滑了，撤',
    '登录成功': '上号成功，启动！',
    '画质': '眼睛待遇',
    '硬解模式': 'GPU 硬啃模式',
    '系统通知': '系统催命符',
    '验证码': '人类认证咒语',
    '置顶': '焊死在天灵盖',
    '筛选': '拿筛子过一遍',
    '公开': '全网裸奔',
    '私密': '关起门来',
    '订阅': '赛博追更',
    '取消订阅': '撤销赛博追更',
    '预告': '先画个饼',
    '限免': '白嫖窗口期',
    '简介': '赛博说明书',
    '上一个': '往前翻一页人生',
    '下一个': '往后翻一页人生',
    '顶部': '天灵盖',
    '底部': '脚底板',
    '本地': '自家硬盘',
    '网络': '网线宇宙',
    '离线视频': '拔网线电子榨菜',
    '网页打开': '扔浏览器里开',
    '输入': '往里塞字',
    '选择': '抓一个',
}

PHRASES = [
    ('默认收藏夹', '祖传电子小被窝'),
    ('收藏夹', '电子小被窝'),
    ('稍后再看', '先吃灰回头再炫'),
    ('超分辨率', '赛博开眼'),
    ('重新登录', '重新上号'),
    ('退出账号', '把赛博户口润出去'),
    ('账号', '赛博户口'),
    ('登录', '上号'),
    ('播放器', '开炫机器'),
    ('播放', '开炫'),
    ('暂停', '按住别动'),
    ('停止', '熄火'),
    ('视频', '电子榨菜'),
    ('音频', '电子响'),
    ('弹幕', '满屏飘字'),
    ('评论', '赛博锐评'),
    ('回复', '对线回合'),
    ('点赞', '赛博大拇哥'),
    ('点踩', '赛博倒拇指'),
    ('投币', '上贡硬币'),
    ('收藏', '塞进电子小被窝'),
    ('关注', '赛博蹲点'),
    ('分享', '到处扩散'),
    ('转发', '二次扩散'),
    ('举报', '赛博递状纸'),
    ('搜索', '全站搜刮'),
    ('推荐', '算法喂饭'),
    ('历史', '电子案底'),
    ('记录', '电子脚印'),
    ('归档', '赛博入土'),
    ('存档', '赛博存档'),
    ('设置', '赛博调参'),
    ('配置', '赛博配方'),
    ('主题', '皮肤人格'),
    ('颜色', '赛博染料'),
    ('字体', '赛博字骨'),
    ('字号', '字有多大'),
    ('进度条', '时间轨道'),
    ('快进', '时间猛冲'),
    ('快退', '时间倒车'),
    ('全屏', '铺满屏'),
    ('竖屏', '竖着炫'),
    ('横屏', '横着炫'),
    ('亮度', '屏幕发光量'),
    ('音量', '喇叭声压'),
    ('手势', '搓玻璃'),
    ('阈值', '触发红线'),
    ('识别', '认出来'),
    ('圆角', '边角磨圆'),
    ('边距', '留白距离'),
    ('间隔', '缝隙'),
    ('高度', '竖向身高'),
    ('宽度', '横向体宽'),
    ('速度', '油门'),
    ('刷新', '重新投胎'),
    ('加载', '疯狂搬数据'),
    ('缓冲', '疯狂囤帧'),
    ('缓存', '电子囤货'),
    ('下载', '薅到本地'),
    ('上传', '往云上扔'),
    ('导入', '往里灌'),
    ('导出', '往外薅'),
    ('保存', '焊死'),
    ('复制', '赛博复刻'),
    ('粘贴', '啪地贴上'),
    ('删除', '物理超度'),
    ('移除', '踢出群聊'),
    ('清空', '一键扬了'),
    ('重置', '恢复出厂人格'),
    ('编辑', '重新盘'),
    ('修改', '重新盘'),
    ('新建', '凭空捏一个'),
    ('创建', '凭空捏一个'),
    ('添加', '塞一个'),
    ('发布', '发射到互联网'),
    ('本地', '自家硬盘'),
    ('网络', '网线宇宙'),
    ('请求', '敲机房大爹家门'),
    ('服务器', '机房大爹'),
    ('错误', '翻车'),
    ('失败', '寄了'),
    ('成功', '成了，包的'),
    ('异常', '抽风'),
    ('数据', '赛博粮'),
    ('文件夹', '电子抽屉'),
    ('文件', '赛博卷宗'),
    ('目录', '电子抽屉'),
    ('分辨率', '像素军备'),
    ('清晰度', '眼睛分辨率'),
    ('画质', '眼睛待遇'),
    ('硬解', 'GPU 硬啃'),
    ('软解', 'CPU 硬扛'),
    ('解码', '赛博拆包'),
    ('内存', '脑容量'),
    ('重启', '重开一把'),
    ('应用', '这坨 App'),
    ('系统', '系统大爹'),
    ('通知', '系统催命符'),
    ('消息', '赛博小纸条'),
    ('验证码', '人类认证咒语'),
    ('密码', '芝麻开门口令'),
    ('输入', '往里塞'),
    ('选择', '抓一个'),
    ('取消', '撤了'),
    ('确定', '拍板'),
    ('确认', '拍板'),
    ('完成', '收工'),
    ('返回', '润回去'),
    ('关闭', '啪一下封印'),
    ('打开', '掀开'),
    ('查看', '扒拉看看'),
    ('显示', '亮出来'),
    ('隐藏', '藏起来'),
    ('展开', '摊开讲'),
    ('收起', '卷起来'),
    ('启用', '解封'),
    ('禁用', '封印'),
    ('开启', '启动'),
    ('恢复', '复活'),
    ('重试', '再赌一把'),
    ('等待', '蹲一会'),
    ('稍后', '回头'),
    ('立即', '现在立刻马上'),
    ('定时', '定点爆破'),
    ('自动', '全自动赛博'),
    ('手动', '亲自下场'),
    ('默认', '祖传默认'),
    ('永久', '焊死到天荒地老'),
    ('临时', '先凑合'),
    ('在线', '联网活着'),
    ('离线', '拔网线'),
    ('用户', '赛博居民'),
    ('审核', '赛博判官'),
    ('违规', '踩红线'),
    ('广告', '牛皮癣'),
    ('屏蔽', '眼不见为净'),
    ('隐私', '赛博隐身'),
    ('公开', '全网裸奔'),
    ('私密', '关起门来'),
    ('当前', '眼下这坨'),
    ('更多', '再扒拉点'),
    ('全部', '我全都要'),
    ('其他', '剩下那坨'),
    ('其它', '剩下那坨'),
    ('番剧', '纸片人连续剧'),
    ('影视', '大屏电子榨菜'),
    ('电影', '两小时电子榨菜'),
    ('动画', '纸片人运动会'),
    ('专栏', '赛博小作文'),
    ('动态', '互联网近况'),
    ('直播间', '赛博围观房'),
    ('直播', '赛博围观'),
    ('图片', '赛博小画片'),
]

MEME_SUFFIXES = (
    '，包的',
    '，启动！',
    '，这把高端局',
    '，属实绷不住',
    '，鼠鼠我啊',
    '，CPU 都看沉默了',
    '，曼波',
    '，优势在我',
    '，已老实',
    '，不是哥们',
    '，功德+1',
    '，我嘞个豆',
)

COUNTRY_SUFFIXES = (
    '·赛博区号站', '·电话传送门', '·跨洋摇人区', '·信号召唤阵',
    '·号码宇宙', '·国际摇人服', '·拨号副本', '·通讯传送点',
    '·运营商异世界', '·电话曼波',
)

PROTECTED_MODEL_ASSIGN = re.compile(r'\b(?:badge|tagName)\s*=\s*$')


def stable_index(text: str, n: int) -> int:
    return int(hashlib.sha256(text.encode('utf-8')).hexdigest()[:8], 16) % n


def protection_reason(rec: dict, source: str) -> str | None:
    if rec['kind'] != 'string_literal':
        return None
    start, end = rec['start'], rec['end']
    prefix = source[max(0, start - 220):start]
    suffix = source[end:min(len(source), end + 220)]
    ps = prefix.rstrip()
    ss = suffix.lstrip()
    ctx = rec.get('context', '')
    path = rec['path']
    original = rec['inner_raw']

    if (path, original) in {
        ('lib/pages/member_profile/view.dart', '头像'),
        ('lib/pages/video/view.dart', '简介'),
        ('lib/pages/video/view.dart', '相关视频'),
        ('lib/pages/video/view.dart', '评论'),
    }:
        return None

    if (path, original) in {
        ('lib/http/fav.dart', '账号未登录'),
        ('lib/pages/live_room/view.dart', '直播'),
    }:
        return '保留：跨文件内部协议/状态值，必须保持原字面量'

    if re.search(r'(?:==|!=)\s*$', ps) or re.match(r'^(?:==|!=)', ss):
        if path == 'lib/models/common/setting_type.dart':
            return None
        return '保留：参与字符串相等判断，疑似服务端/运行时判据'
    if re.search(r'\bcase\s*$', ps):
        return '保留：switch/case 匹配常量'
    if re.search(r'\.(?:contains|startsWith|endsWith|replaceAll|replaceFirst)\s*\(\s*$', ps):
        return '保留：参与字符串匹配/解析逻辑'
    if re.search(r'\bRegExp\s*\(\s*$', ps):
        return '保留：正则表达式/解析规则'
    if re.match(r'^=>', ss):
        return '保留：switch 模式匹配常量'
    if (('}.contains(' in ctx or '].contains(' in ctx) and path != 'lib/models/common/setting_type.dart'):
        return '保留：集合成员匹配常量'
    if path.startswith(('lib/models/', 'lib/models_new/')) and PROTECTED_MODEL_ASSIGN.search(ps):
        return '保留：模型字段内部标记，改动可能破坏后续判断'
    if path == 'lib/utils/num_utils.dart':
        return '保留：数字格式化解析常量'
    return None


def blackify_theme(text: str) -> str:
    repl = [
        ('中性色与表面色系', '人畜无害背景色系'),
        ('错误色系', '翻车警报色系'),
        ('第三色系', '三号工具色系'),
        ('次色系', '二当家色系'),
        ('主色系', 'C 位主色系'),
        ('错误色', '翻车警报色'),
        ('第三色', '三号工具色'),
        ('次色', '二当家色'),
        ('主色', 'C 位主色'),
        ('页面表面', '页面地板漆'),
        ('表面', '界面地板'),
        ('容器', '盒子'),
        ('轮廓', '描边骨架'),
        ('阴影', '赛博投影'),
        ('遮罩', '赛博黑布'),
        ('背景', '底漆'),
        ('文字', '字儿'),
        ('图标', '小图标'),
        ('按钮', '赛博按钮'),
        ('选中项', '被点名的那位'),
        ('强调', '抢镜'),
        ('弱化', '低调'),
        ('固定', '焊死'),
        ('反色', '反骨色'),
        ('明暗主题', '白天黑夜皮肤'),
        ('弹窗', '蹦出来的框'),
        ('顶部栏', '天灵盖栏'),
        ('底部', '脚底板'),
        ('页面', '这页'),
    ]
    out = text
    for old, new in repl:
        out = out.replace(old, new)
    if out == text:
        out = text + '·赛博调色盘'
    elif len(out) <= 18:
        out += '·曼波版'
    elif stable_index(text, 3) == 0:
        out += '，设计师看了直呼高端'
    return out


def blackify(text: str, path: str) -> str:
    if text in EXACT:
        return EXACT[text]
    if path == 'lib/common/dial_prefix.dart':
        return text + COUNTRY_SUFFIXES[stable_index(text, len(COUNTRY_SUFFIXES))]
    if path == 'lib/models/common/theme/theme_color_type.dart':
        return blackify_theme(text)

    out = text
    for old, new in PHRASES:
        out = out.replace(old, new)

    if out == text:
        out = text + MEME_SUFFIXES[stable_index(text, len(MEME_SUFFIXES))]
    elif len(out) >= 8 and stable_index(text, 5) in (0, 1):
        suffix = MEME_SUFFIXES[stable_index(text + path, len(MEME_SUFFIXES))]
        if suffix.strip('，') not in out:
            out += suffix

    return out


def run(root: Path = Path('.')) -> dict:
    records = json.loads((root / SCAN_PATH).read_text(encoding='utf-8'))
    by_path: dict[str, list[dict]] = defaultdict(list)
    report = []

    for rec in records:
        by_path[rec['path']].append(rec)

    changed_files = 0
    changed_occurrences = 0
    protected_occurrences = 0

    for rel, items in sorted(by_path.items()):
        path = root / rel
        source = path.read_text(encoding='utf-8')
        original_source = source
        decisions = []
        for rec in items:
            reason = protection_reason(rec, original_source)
            old_inner = rec['inner_raw']
            if reason:
                new_inner = old_inner
                status = '保留'
                protected_occurrences += 1
            else:
                new_inner = blackify(old_inner, rel)
                status = '已替换'
                if new_inner == old_inner:
                    raise RuntimeError(f'安全字符串未发生变化: {rel}:{rec["line"]}: {old_inner!r}')
                changed_occurrences += 1
            decisions.append((rec, status, reason or '', new_inner))

        for rec, status, reason, new_inner in sorted(decisions, key=lambda t: t[0]['start'], reverse=True):
            if status != '已替换':
                continue
            start, end = rec['start'], rec['end']
            if rec['kind'] == 'string_literal':
                delim = rec['delimiter']
                old_literal = original_source[start:end]
                expected = delim + rec['inner_raw'] + delim
                if old_literal != expected:
                    raise RuntimeError(
                        f'字面量定位不一致: {rel}:{rec["line"]}: {old_literal!r} != {expected!r}'
                    )
                replacement = delim + new_inner + delim
            else:
                old_literal = original_source[start:end]
                if old_literal != rec['inner_raw']:
                    raise RuntimeError(f'文本节点定位不一致: {rel}:{rec["line"]}')
                replacement = new_inner
            source = source[:start] + replacement + source[end:]

        if source != original_source:
            path.write_text(source, encoding='utf-8')
            changed_files += 1

        for rec, status, reason, new_inner in decisions:
            report.append({
                'path': rel,
                'line': rec['line'],
                'kind': rec['kind'],
                'original': rec['inner_raw'],
                'replacement': new_inner,
                'status': status,
                'reason': reason,
                'context': rec.get('context', ''),
            })

    summary = {
        'scan_occurrences': len(records),
        'changed_occurrences': changed_occurrences,
        'protected_occurrences': protected_occurrences,
        'changed_files': changed_files,
        'excluded_quote_collection': 'assets/data/hitokoto.txt',
        'report': report,
    }
    (root / REPORT_PATH).write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k, v in summary.items() if k != 'report'}, ensure_ascii=False))
    return summary


if __name__ == '__main__':
    run()
