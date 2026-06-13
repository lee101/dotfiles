#!/usr/bin/env python3
"""Parse Valgrind memcheck output (text or XML) and render as Markdown.

Usage:
    valgrind-to-md.py valgrind-report.log        # text log
    valgrind-to-md.py --xml valgrind-report.xml   # XML report
    valgrind-to-md.py < valgrind-report.log       # stdin
"""
import sys, re, xml.etree.ElementTree as ET
from pathlib import Path


def parse_text(lines):
    errors = []
    cur = None
    summary_lines = []
    in_summary = False
    for line in lines:
        line = line.rstrip()
        stripped = re.sub(r'^==\d+== ', '', line)
        if 'ERROR SUMMARY' in stripped:
            in_summary = True
            summary_lines.append(stripped)
            continue
        if in_summary:
            summary_lines.append(stripped)
            continue
        if 'Invalid' in stripped or 'Conditional' in stripped or 'definitely lost' in stripped or 'indirectly lost' in stripped or 'possibly lost' in stripped:
            if cur:
                errors.append(cur)
            cur = {'title': stripped.strip(), 'frames': []}
            continue
        m = re.match(r'\s+(at|by) 0x[0-9A-Fa-f]+: (.+)', stripped)
        if m and cur:
            cur['frames'].append(m.group(2))
    if cur:
        errors.append(cur)
    return errors, summary_lines


def parse_xml(path):
    tree = ET.parse(path)
    root = tree.getroot()
    errors = []
    for err in root.findall('.//error'):
        kind = err.findtext('kind', '')
        what = err.findtext('what', '') or err.findtext('xwhat/text', '')
        frames = []
        for frame in err.findall('.//frame'):
            fn = frame.findtext('fn', '???')
            f = frame.findtext('file', '')
            line = frame.findtext('line', '')
            loc = f'{f}:{line}' if f else ''
            frames.append(f'{fn} ({loc})' if loc else fn)
        errors.append({'title': f'[{kind}] {what}', 'frames': frames})
    summary = []
    es = root.find('.//errorcounts')
    if es is not None:
        for pair in es.findall('pair'):
            summary.append(f"{pair.findtext('unique', '?')}: {pair.findtext('count', '?')}")
    return errors, summary


def render_md(errors, summary):
    out = ['# Valgrind Memcheck Report\n']
    if not errors:
        out.append('No errors detected.\n')
    else:
        out.append(f'**{len(errors)} issue(s) found**\n')
        for i, e in enumerate(errors, 1):
            out.append(f'## {i}. {e["title"]}\n')
            if e['frames']:
                out.append('```')
                for f in e['frames'][:15]:
                    out.append(f'  {f}')
                out.append('```\n')
    if summary:
        out.append('## Summary\n')
        for s in summary:
            out.append(f'- {s}')
    return '\n'.join(out)


def main():
    use_xml = '--xml' in sys.argv
    args = [a for a in sys.argv[1:] if a != '--xml']
    if args:
        path = Path(args[0])
        if use_xml or path.suffix == '.xml':
            errors, summary = parse_xml(path)
        else:
            errors, summary = parse_text(path.read_text().splitlines())
    else:
        errors, summary = parse_text(sys.stdin.readlines())
    print(render_md(errors, summary))


if __name__ == '__main__':
    main()
