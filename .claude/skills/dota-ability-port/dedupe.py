#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Remove duplicate keys inside a block, keeping the first occurrence.

Valve KeyValues resolves a lookup to the FIRST matching key, so every later
duplicate is already dead weight - deleting it cannot change in-game behaviour.

Repeated keys are legitimate inside precache / AbilityPreview /
MovementSpeedActivityModifiers, so those containers are left alone.
Duplicate keys whose value is a BLOCK are reported, never deleted.

usage: python dedupe.py <hero> [...]        (hero folder name)
       python dedupe.py --all [--dry-run]
"""
import os, re, sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
ADDON = os.path.join(ROOT, 'scripts', 'npc', 'heroes')

SKIP_CONTAINERS = ('precache', 'AbilityPreview', 'MovementSpeedActivityModifiers')

_v = {'__file__': os.path.join(HERE, 'validate.py')}
_src = open(os.path.join(HERE, 'validate.py'), encoding='utf-8').read().split('def check_hero(')[0]
exec(compile(_src, 'validate_part', 'exec'), _v)
read = _v['read']


def scan(text):
    """Walk raw text; yield (key, is_block, key_start, stmt_end, path)."""
    i, n = 0, len(text)
    path = []
    counts = [{}]
    while i < n:
        c = text[i]
        if c == '/' and i + 1 < n and text[i + 1] == '/':
            while i < n and text[i] != '\n':
                i += 1
            continue
        if c == '{':
            counts.append({})
            i += 1
            continue
        if c == '}':
            if len(counts) > 1:
                counts.pop()
            if path:
                path.pop()
            i += 1
            continue
        if c == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == '\\' else 1
            key = text[i + 1:j]
            k = j + 1
            while k < n:
                if text[k] in ' \t\r\n':
                    k += 1
                elif text[k] == '/' and k + 1 < n and text[k + 1] == '/':
                    while k < n and text[k] != '\n':
                        k += 1
                else:
                    break
            if k < n and text[k] == '{':
                yield key, True, i, k, list(path)
                path.append(key)
                i = k          # let the '{' branch push a fresh scope
                continue
            if k < n and text[k] == '"':
                m = k + 1
                while m < n and text[m] != '"':
                    m += 2 if text[m] == '\\' else 1
                yield key, False, i, m + 1, list(path)
                i = m + 1
                continue
            i = j + 1
            continue
        i += 1


def dedupe_text(text):
    """Return (new_text, removed, block_dups)."""
    removed, block_dups = [], []
    seen_stack = [{}]
    depth_of = []
    cuts = []

    # re-walk maintaining a per-scope seen-map
    i, n = 0, len(text)
    scopes = [{}]
    path = []
    while i < n:
        c = text[i]
        if c == '/' and i + 1 < n and text[i + 1] == '/':
            while i < n and text[i] != '\n':
                i += 1
            continue
        if c == '{':
            scopes.append({})
            i += 1
            continue
        if c == '}':
            if len(scopes) > 1:
                scopes.pop()
            if path:
                path.pop()
            i += 1
            continue
        if c == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == '\\' else 1
            key = text[i + 1:j]
            k = j + 1
            while k < n:
                if text[k] in ' \t\r\n':
                    k += 1
                elif text[k] == '/' and k + 1 < n and text[k + 1] == '/':
                    while k < n and text[k] != '\n':
                        k += 1
                else:
                    break
            protected = any(p in SKIP_CONTAINERS for p in path)
            if k < n and text[k] == '{':
                if not protected and key in scopes[-1]:
                    block_dups.append('/'.join(path + [key]))
                scopes[-1][key] = None
                path.append(key)
                i = k
                continue
            if k < n and text[k] == '"':
                m = k + 1
                while m < n and text[m] != '"':
                    m += 2 if text[m] == '\\' else 1
                val = text[k + 1:m]
                if not protected:
                    if key in scopes[-1]:
                        line_start = text.rfind('\n', 0, i) + 1
                        line_end = text.find('\n', m)
                        line_end = n if line_end == -1 else line_end + 1
                        # only cut when the line holds nothing but this pair
                        seg = text[line_start:line_end]
                        if seg.strip().startswith('"%s"' % key) and \
                                seg.count('"') == 4:
                            cuts.append((line_start, line_end))
                            removed.append('%s = "%s"  (kept first: "%s")'
                                           % ('/'.join(path + [key]), val,
                                              scopes[-1][key]))
                    else:
                        scopes[-1][key] = val
                i = m + 1
                continue
            i = j + 1
            continue
        i += 1

    for a, b in sorted(cuts, reverse=True):
        text = text[:a] + text[b:]
    return text, removed, block_dups


def run(path, dry):
    raw = read(path)
    crlf = '\r\n' in raw
    body = raw.replace('\r\n', '\n')
    new, removed, block_dups = dedupe_text(body)
    if removed and not dry:
        if crlf:
            new = new.replace('\n', '\r\n')
        with open(path, 'w', encoding='utf-8', newline='') as f:
            f.write(new)
    return removed, block_dups


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    dry = '--dry-run' in sys.argv
    if '--all' in sys.argv:
        heroes = sorted(d for d in os.listdir(ADDON)
                        if os.path.isdir(os.path.join(ADDON, d)))
    elif args:
        heroes = args
    else:
        print(__doc__); sys.exit(2)

    tot = 0
    blocks = []
    for h in heroes:
        for fn in ('ability_data.txt', 'hero_data.txt'):
            p = os.path.join(ADDON, h, fn)
            if not os.path.isfile(p):
                continue
            removed, bd = run(p, dry)
            if removed:
                tot += len(removed)
                print('%s/%s' % (h, fn))
                for r in removed:
                    print('   - %s' % r)
            for b in bd:
                blocks.append('%s/%s: %s' % (h, fn, b))
    if blocks:
        print('\nDuplicate BLOCKS (not touched, review by hand):')
        for b in blocks:
            print('   ! %s' % b)
    print('\n%d duplicate line(s) removed%s' % (tot, '  (dry run)' if dry else ''))


main()
