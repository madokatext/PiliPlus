from __future__ import annotations

import json
import re
import shutil
from pathlib import Path

ROOT = Path('.')
OUT = Path('scan_bundle')
FILES_OUT = OUT / 'files'
ZH_RE = re.compile(r'[\u3400-\u4dbf\u4e00-\u9fff]')

ALLOWED_EXT = {
    '.dart', '.java', '.kt', '.kts', '.gradle', '.xml', '.json', '.arb',
    '.yaml', '.yml', '.plist', '.swift', '.m', '.mm', '.cpp', '.cc', '.c',
    '.h', '.hpp', '.js', '.ts', '.html', '.htm', '.css', '.cmake', '.toml',
    '.ini', '.conf', '.txt', '.csv',
}
ALLOWED_NAMES = {
    'CMakeLists.txt', 'pubspec.yaml', 'analysis_options.yaml',
    'distribute_options.yaml',
}
EXCLUDED_PARTS = {
    '.git', '.dart_tool', 'build', '.idea', '.vscode', '.github',
}
EXCLUDED_FILES = {
    'assets/data/hitokoto.txt',
}


def line_no(text: str, pos: int) -> int:
    return text.count('\n', 0, pos) + 1


def one_line_context(text: str, pos: int) -> str:
    a = text.rfind('\n', 0, pos) + 1
    b = text.find('\n', pos)
    if b < 0:
        b = len(text)
    return text[a:b].strip()[:700]


def quote_info(text: str, i: int):
    if i >= len(text) or text[i] not in "'\"":
        return None
    q = text[i]
    triple = text.startswith(q * 3, i)
    delim = q * (3 if triple else 1)
    raw = (
        i > 0
        and text[i - 1] in 'rR'
        and (i < 2 or not (text[i - 2].isalnum() or text[i - 2] == '_'))
    )
    return delim, raw


def iter_code_strings(text: str, *, dart: bool):
    n = len(text)

    def skip_block_comment(i: int) -> int:
        depth = 1
        j = i + 2
        while j < n and depth:
            if text.startswith('/*', j):
                depth += 1
                j += 2
            elif text.startswith('*/', j):
                depth -= 1
                j += 2
            else:
                j += 1
        return j

    def skip_interp(i: int) -> int:
        depth = 1
        j = i
        while j < n:
            if text.startswith('//', j):
                k = text.find('\n', j + 2)
                return n if k < 0 else skip_interp(k + 1) if False else _resume(k + 1, depth)
            if text.startswith('/*', j):
                j = skip_block_comment(j)
                continue
            if text[j] in "'\"":
                j = skip_string(j)
                continue
            if text[j] == '{':
                depth += 1
            elif text[j] == '}':
                depth -= 1
                if depth == 0:
                    return j + 1
            j += 1
        return n

    def _resume(j: int, depth: int) -> int:
        while j < n:
            if text.startswith('//', j):
                k = text.find('\n', j + 2)
                if k < 0:
                    return n
                j = k + 1
                continue
            if text.startswith('/*', j):
                j = skip_block_comment(j)
                continue
            if text[j] in "'\"":
                j = skip_string(j)
                continue
            if text[j] == '{':
                depth += 1
            elif text[j] == '}':
                depth -= 1
                if depth == 0:
                    return j + 1
            j += 1
        return n

    def skip_string(i: int) -> int:
        info = quote_info(text, i)
        if info is None:
            return i + 1
        delim, raw = info
        j = i + len(delim)
        while j < n:
            if text.startswith(delim, j):
                return j + len(delim)
            if not raw and text[j] == '\\':
                j = min(n, j + 2)
                continue
            if dart and not raw and text[j] == '$' and j + 1 < n and text[j + 1] == '{':
                j = skip_interp(j + 2)
                continue
            j += 1
        return i + 1

    def scan_string(i: int):
        info = quote_info(text, i)
        if info is None:
            return i + 1, None
        delim, raw = info
        start = i
        j = i + len(delim)
        while j < n:
            if text.startswith(delim, j):
                end = j + len(delim)
                return end, (start, end, delim, raw, text[i + len(delim):j])
            if not raw and text[j] == '\\':
                j = min(n, j + 2)
                continue
            if dart and not raw and text[j] == '$' and j + 1 < n and text[j + 1] == '{':
                j = skip_interp(j + 2)
                continue
            j += 1
        return start + 1, None

    i = 0
    while i < n:
        if text.startswith('//', i):
            j = text.find('\n', i + 2)
            i = n if j < 0 else j + 1
            continue
        if text.startswith('/*', i):
            i = skip_block_comment(i)
            continue
        if text[i] in "'\"":
            i, rec = scan_string(i)
            if rec is not None:
                yield rec
            continue
        i += 1


def xml_comment_ranges(text: str):
    ranges = []
    for m in re.finditer(r'<!--.*?-->', text, re.S):
        ranges.append((m.start(), m.end()))
    return ranges


def inside_any(pos: int, ranges) -> bool:
    return any(a <= pos < b for a, b in ranges)


def strip_yaml_comment(line: str) -> str:
    single = False
    double = False
    escaped = False
    for i, ch in enumerate(line):
        if double and escaped:
            escaped = False
            continue
        if double and ch == '\\':
            escaped = True
            continue
        if ch == "'" and not double:
            single = not single
        elif ch == '"' and not single:
            double = not double
        elif ch == '#' and not single and not double:
            return line[:i]
    return line


def main() -> None:
    OUT.mkdir(exist_ok=True)
    FILES_OUT.mkdir(parents=True, exist_ok=True)
    records = []
    candidate_paths = set()

    for path in ROOT.rglob('*'):
        if not path.is_file():
            continue
        rel = path.as_posix()
        if rel in EXCLUDED_FILES:
            continue
        if any(part in EXCLUDED_PARTS for part in path.parts):
            continue
        if path.suffix.lower() not in ALLOWED_EXT and path.name not in ALLOWED_NAMES:
            continue
        if path.suffix.lower() in {'.txt', '.csv'} and not rel.startswith('assets/'):
            continue
        try:
            text = path.read_text(encoding='utf-8')
        except Exception:
            continue

        ext = path.suffix.lower()
        seen_ranges = []
        comments = xml_comment_ranges(text) if ext in {'.xml', '.html', '.htm', '.plist'} else []

        if ext not in {'.txt', '.csv'}:
            for start, end, delim, raw, inner in iter_code_strings(text, dart=ext == '.dart'):
                if inside_any(start, comments) or not ZH_RE.search(inner):
                    continue
                records.append({
                    'path': rel,
                    'line': line_no(text, start),
                    'start': start,
                    'end': end,
                    'kind': 'string_literal',
                    'delimiter': delim,
                    'raw': raw,
                    'literal_raw': text[start:end],
                    'inner_raw': inner,
                    'context': one_line_context(text, start),
                })
                candidate_paths.add(rel)
                seen_ranges.append((start, end))

        if ext in {'.xml', '.html', '.htm', '.plist'}:
            for m in re.finditer(r'>([^<>]+)<', text, re.S):
                s, e = m.start(1), m.end(1)
                val = m.group(1)
                if inside_any(s, comments) or not ZH_RE.search(val):
                    continue
                records.append({
                    'path': rel,
                    'line': line_no(text, s),
                    'start': s,
                    'end': e,
                    'kind': 'text_node',
                    'delimiter': '',
                    'raw': False,
                    'literal_raw': val,
                    'inner_raw': val,
                    'context': one_line_context(text, s),
                })
                candidate_paths.add(rel)
                seen_ranges.append((s, e))

        if ext in {'.yaml', '.yml'}:
            offset = 0
            for ln in text.splitlines(True):
                body = ln.rstrip('\r\n')
                content = strip_yaml_comment(body)
                stripped = content.strip()
                if stripped and ZH_RE.search(stripped):
                    s = offset + content.find(stripped)
                    if not any(a <= s < b for a, b in seen_ranges):
                        records.append({
                            'path': rel,
                            'line': line_no(text, s),
                            'start': s,
                            'end': s + len(stripped),
                            'kind': 'yaml_scalar_line',
                            'delimiter': '',
                            'raw': False,
                            'literal_raw': stripped,
                            'inner_raw': stripped,
                            'context': stripped[:700],
                        })
                        candidate_paths.add(rel)
                offset += len(ln)

        if ext in {'.txt', '.csv'}:
            offset = 0
            for ln in text.splitlines(True):
                body = ln.rstrip('\r\n')
                if ZH_RE.search(body):
                    s = offset
                    records.append({
                        'path': rel,
                        'line': line_no(text, s),
                        'start': s,
                        'end': s + len(body),
                        'kind': 'resource_line',
                        'delimiter': '',
                        'raw': False,
                        'literal_raw': body,
                        'inner_raw': body,
                        'context': body[:700],
                    })
                    candidate_paths.add(rel)
                offset += len(ln)

    records.sort(key=lambda x: (x['path'], x['start'], x['end'], x['kind']))
    for rel in sorted(candidate_paths):
        dst = FILES_OUT / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(rel, dst)

    (OUT / 'scan.json').write_text(
        json.dumps(records, ensure_ascii=False, indent=2), encoding='utf-8'
    )
    (OUT / 'candidate_files.txt').write_text(
        '\n'.join(sorted(candidate_paths)) + '\n', encoding='utf-8'
    )
    summary = {
        'occurrences': len(records),
        'candidate_files': len(candidate_paths),
        'unique_inner_raw': len({r['inner_raw'] for r in records}),
        'excluded_quote_collection': 'assets/data/hitokoto.txt',
    }
    (OUT / 'summary.json').write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8'
    )
    print(json.dumps(summary, ensure_ascii=False))
    print('Candidate files:')
    print('\n'.join(sorted(candidate_paths)))


if __name__ == '__main__':
    main()
