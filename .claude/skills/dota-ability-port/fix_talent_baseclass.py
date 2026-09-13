#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Give every talent stub the BaseClass that makes it learnable.

A talent the addon redefines needs

    "BaseClass"  "special_bonus_base"

or the engine has no class to instantiate: the talent draws in the tree and
refuses to level. Phantom Assassin showed it - five of her eight stubs lacked
the line, and those five were the ones that would not take a point.

516 stubs in this project already carry it, 206 do not. The line is added to
the ones missing it; nothing else in the block is touched.

usage: python fix_talent_baseclass.py [--dry-run]
"""
import os, re, sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
HEROES = os.path.join(ROOT, 'scripts', 'npc', 'heroes')
EXTRA = [os.path.join(ROOT, 'scripts', 'npc', 'talantes.txt')]

_p = {'__file__': os.path.join(HERE, 'port.py')}
_src = open(os.path.join(HERE, 'port.py'), encoding='utf-8').read().split('def port_hero(')[0]
_src = _src.replace('main()', '')
exec(compile(_src, 'port_part', 'exec'), _p)
parse = _p['parse']
read = _p['read']
find_blocks = _p['find_blocks']


def targets():
    out = []
    for h in sorted(os.listdir(HEROES)):
        p = os.path.join(HEROES, h, 'ability_data.txt')
        if os.path.isfile(p):
            out.append(p)
    out += [p for p in EXTRA if os.path.isfile(p)]
    return out


def main():
    dry = '--dry-run' in sys.argv
    total, files = 0, 0

    for path in targets():
        kv, _ = parse(read(path))
        raw = open(path, 'rb').read()
        crlf = b'\r\n' in raw
        bom = raw[:3] == b'\xef\xbb\xbf'
        text = raw.decode('utf-8-sig', 'replace').replace('\r\n', '\n')

        need = [n for n, b in kv.items()
                if isinstance(b, dict) and n.startswith('special_bonus_')
                and b.get('BaseClass') != 'special_bonus_base']
        if not need:
            continue

        edits, log = [], []

        def walk(start, end):
            for name, _ks, bo, bc in list(find_blocks(text, start, end)):
                if name in ('DOTAAbilities', 'Version'):
                    walk(bo + 1, bc)
                    continue
                if name not in need:
                    continue
                body = kv.get(name)
                if not isinstance(body, dict):
                    continue
                if 'BaseClass' in body:
                    # present but wrong - leave it, that is a deliberate class
                    log.append('%-52s has BaseClass "%s", left alone'
                               % (name, body['BaseClass']))
                    continue
                # insert right after the opening brace, matching indentation
                line_start = text.rfind('\n', 0, bo) + 1
                indent = re.match(r'[ \t]*', text[line_start:bo]).group(0) + '\t'
                nl = text.find('\n', bo)
                nl = bo + 1 if nl == -1 else nl + 1
                edits.append((nl, nl, '%s"BaseClass"\t\t\t\t\t"special_bonus_base"\n' % indent))
                log.append('%-52s + BaseClass' % name)

        walk(0, len(text))
        if not edits:
            for l in log:
                print('   ', l)
            continue

        edits.sort(key=lambda e: e[0], reverse=True)
        for a, b, repl in edits:
            text = text[:a] + repl + text[b:]
        if not dry:
            out = text.replace('\n', '\r\n') if crlf else text
            with open(path, 'w', encoding='utf-8-sig' if bom else 'utf-8',
                      newline='') as f:
                f.write(out)
        print(os.path.relpath(path, ROOT))
        for l in log:
            print('   ', l)
        total += len(edits)
        files += 1

    print()
    print('TOTAL: %d talent stub(s) fixed in %d file(s)%s'
          % (total, files, '  (dry run)' if dry else ''))


main()
