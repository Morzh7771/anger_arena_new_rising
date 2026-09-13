#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Move generated Precache functions out of class({...}) constructors.

Something generated Precache methods and inserted them inside the table passed
to class(), which Lua cannot parse:

    tormentor_reflect_aa = class({
    function tormentor_reflect_aa:Precache(context)   <- statement in a table
        ...
    end
        GetIntrinsicModifierName = function(self) ... end,
    })

The engine agrees:

    tormentor_reflect_aa.lua:8: '(' expected near 'tormentor_reflect_aa'
    LoadAndCompileScriptFile: Failed to compile script file
    Filename creeps/boss/tormentor/tormentor_reflect_aa of ability ... not found!

The function is lifted above the assignment, where it is a valid statement and
still runs before anything needs it.

usage: python fix_precache.py [--dry-run]
"""
import os, re, sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
VSCRIPTS = os.path.join(ROOT, 'scripts', 'vscripts')

# "<name> = class({"  ... anything ... "})"
CLASS_OPEN = re.compile(r'^([ \t]*)([A-Za-z_][\w.]*)\s*=\s*class\s*\(\s*\{', re.M)


def find_matching(text, i, open_ch='{', close_ch='}'):
    depth = 0
    while i < len(text):
        c = text[i]
        if c == '"' or c == "'":
            q = c
            i += 1
            while i < len(text) and text[i] != q:
                i += 2 if text[i] == '\\' else 1
        elif text.startswith('--[[', i):
            j = text.find(']]', i)
            i = len(text) if j == -1 else j + 1
        elif c == '-' and text.startswith('--', i):
            j = text.find('\n', i)
            i = len(text) if j == -1 else j
            continue
        elif c == open_ch:
            depth += 1
        elif c == close_ch:
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def extract(text):
    """Pull every `function X:Name(...) ... end` out of a class({...}) body."""
    moved = []
    for m in list(CLASS_OPEN.finditer(text)):
        brace = text.index('{', m.end() - 1)
        close = find_matching(text, brace)
        if close == -1:
            continue
        body = text[brace + 1:close]
        fn = re.search(r'(?m)^[ \t]*function\s+[\w.]+:\w+\s*\(', body)
        if not fn:
            continue
        # take the whole function through its matching `end`
        start = fn.start()
        depth, i, n = 0, start, len(body)
        while i < n:
            w = re.match(r'\b(function|if|for|while|do)\b', body[i:])
            e = re.match(r'\bend\b', body[i:])
            if w:
                depth += 1
                i += w.end()
                continue
            if e:
                depth -= 1
                i += e.end()
                if depth == 0:
                    break
                continue
            i += 1
        block = body[start:i]
        # carry a leading comment block with it
        lead = start
        prev = body.rfind('\n', 0, start)
        while prev != -1:
            line_start = body.rfind('\n', 0, prev) + 1
            line = body[line_start:prev]
            if line.strip().startswith('--'):
                lead = line_start
                prev = body.rfind('\n', 0, line_start)
            else:
                break
        full = body[lead:i]
        new_body = body[:lead] + body[i:]
        # The method must land AFTER the assignment: `function X:Precache()`
        # needs X to exist already, so hoisting it above `X = class({...})`
        # would swap a compile error for a nil-index at runtime.
        stmt_end = text.find('\n', close)
        stmt_end = len(text) if stmt_end == -1 else stmt_end + 1
        text = (text[:brace + 1] + new_body + text[close:stmt_end]
                + '\n' + full.strip('\n') + '\n' + text[stmt_end:])
        moved.append(m.group(2))
        # offsets shifted; restart the scan
        return text, moved, True
    return text, moved, False


def main():
    dry = '--dry-run' in sys.argv
    fixed = []
    for dp, _d, fs in os.walk(VSCRIPTS):
        for fn in sorted(fs):
            if not fn.endswith('.lua'):
                continue
            p = os.path.join(dp, fn)
            raw = open(p, 'rb').read()
            crlf = b'\r\n' in raw
            text = raw.decode('utf-8', 'surrogateescape').replace('\r\n', '\n')
            names, changed_any = [], False
            while True:
                text, moved, changed = extract(text)
                if not changed:
                    break
                names += moved
                changed_any = True
            if not changed_any:
                continue
            if not dry:
                out = text.replace('\n', '\r\n') if crlf else text
                with open(p, 'wb') as f:
                    f.write(out.encode('utf-8', 'surrogateescape'))
            fixed.append((os.path.relpath(p, ROOT), names))

    for p, names in fixed:
        print('  %-72s %s' % (p, ','.join(names)))
    print()
    print('TOTAL: %d file(s) repaired%s' % (len(fixed), '  (dry run)' if dry else ''))


main()
