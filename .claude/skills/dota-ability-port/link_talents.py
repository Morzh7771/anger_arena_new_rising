#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Wire hero talents back to the abilities they are supposed to modify.

A Dota talent is not a standalone thing. It works because some ability lists it
inside AbilityValues:

    "damage"
    {
        "value"                             "100 200 300"
        "special_bonus_unique_monkey_king_9"    "+40"
    }

Remove that line and the talent still appears in the UI and grants nothing. The
addon is in exactly that state for several heroes - Monkey King and Tinker carry
eight and seven talent slots with no reference anywhere in their abilities.

This script copies the missing references from the live patch, for talents the
hero actually has in a slot. Bonus amounts come from the patch; existing
references are never modified, so the addon's own tuning survives.

usage: python link_talents.py [--dry-run]
"""
import os, re, sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
HEROES = os.path.join(ROOT, 'scripts', 'npc', 'heroes')
PATCH_HEROES = r"C:\Users\admin\Desktop\Dota 2 7.42\scripts\npc\heroes"

_p = {'__file__': os.path.join(HERE, 'port.py')}
_src = open(os.path.join(HERE, 'port.py'), encoding='utf-8').read().split('def port_hero(')[0]
_src = _src.replace('main()', '')
exec(compile(_src, 'port_part', 'exec'), _p)
parse = _p['parse']
read = _p['read']
find_blocks = _p['find_blocks']
find_scalar = _p['find_scalar']
is_lua = _p['is_lua']

SLOT = re.compile(r'^Ability(1[0-9]|[2-9][0-9])$')


def main():
    dry = '--dry-run' in sys.argv
    total = 0

    for hero in sorted(os.listdir(HEROES)):
        hdir = os.path.join(HEROES, hero)
        ap = os.path.join(hdir, 'ability_data.txt')
        hp = os.path.join(hdir, 'hero_data.txt')
        if not os.path.isfile(ap) or not os.path.isfile(hp):
            continue

        pf = os.path.join(PATCH_HEROES, 'npc_dota_hero_%s.txt' % hero)
        if not os.path.isfile(pf):
            hkv0, _ = parse(read(hp))
            pf = None
            for k in hkv0:
                cand = os.path.join(PATCH_HEROES, '%s.txt' % k)
                if os.path.isfile(cand):
                    pf = cand
                    break
        if not pf:
            continue

        hkv, _ = parse(read(hp))
        akv, _ = parse(read(ap))
        pkv, _ = parse(read(pf))

        talents = set()
        for hb in hkv.values():
            if isinstance(hb, dict):
                for k, v in hb.items():
                    if SLOT.match(k) and isinstance(v, str) and v.startswith('special_bonus_'):
                        talents.add(v)
        if not talents:
            continue

        raw = open(ap, 'rb').read()
        crlf = b'\r\n' in raw
        bom = raw[:3] == b'\xef\xbb\xbf'
        text = raw.decode('utf-8-sig', 'replace').replace('\r\n', '\n')
        edits, log = [], []

        def walk(start, end):
            for name, _ks, bo, bc in list(find_blocks(text, start, end)):
                if name in ('DOTAAbilities', 'Version'):
                    walk(bo + 1, bc)
                    continue
                ab = akv.get(name)
                pb = pkv.get(name)
                if not isinstance(ab, dict) or not isinstance(pb, dict):
                    continue
                if is_lua(ab):
                    continue
                pav = pb.get('AbilityValues')
                aav = ab.get('AbilityValues')
                if not isinstance(pav, dict) or not isinstance(aav, dict):
                    continue

                av_open = av_close = None
                for k2, _k, bo2, bc2 in find_blocks(text, bo + 1, bc):
                    if k2 == 'AbilityValues':
                        av_open, av_close = bo2, bc2
                        break
                if av_open is None:
                    continue

                for key, pval in pav.items():
                    if not isinstance(pval, dict):
                        continue
                    wanted = {s: v for s, v in pval.items()
                              if s.startswith('special_bonus_') and s in talents
                              and isinstance(v, str)}
                    if not wanted:
                        continue
                    cur = aav.get(key)
                    have = set(cur) if isinstance(cur, dict) else set()
                    add = {s: v for s, v in wanted.items() if s not in have}
                    if not add:
                        continue

                    # find this key's block inside the addon's AbilityValues
                    kb = None
                    for k3, ks3, bo3, bc3 in find_blocks(text, av_open + 1, av_close):
                        if k3 == key:
                            kb = (ks3, bo3, bc3)
                            break
                    if kb is None:
                        # scalar form - promote it to a block carrying the bonus
                        f = find_scalar(text, av_open, av_close, key)
                        if not f:
                            continue
                        line_start = text.rfind('\n', 0, f[0]) + 1
                        line_end = text.find('\n', f[1])
                        line_end = len(text) if line_end == -1 else line_end + 1
                        indent = re.match(r'[ \t]*', text[line_start:]).group(0)
                        body = '%s\t"value"\t\t\t\t"%s"\n' % (indent, f[2])
                        for s, v in add.items():
                            body += '%s\t"%s"\t\t\t\t"%s"\n' % (indent, s, v)
                        block = '%s"%s"\n%s{\n%s%s}\n' % (indent, key, indent, body, indent)
                        edits.append((line_start, line_end, block))
                    else:
                        _ks3, bo3, bc3 = kb
                        line_start = text.rfind('\n', 0, bc3) + 1
                        indent = re.match(r'[ \t]*', text[line_start:bc3]).group(0) + '\t'
                        chunk = ''.join('%s"%s"\t\t\t\t"%s"\n' % (indent, s, v)
                                        for s, v in add.items())
                        edits.append((line_start, line_start, chunk))
                    for s in add:
                        log.append('%-20s %-34s %-22s %s' % (hero, name, key, s))

        walk(0, len(text))
        if edits:
            edits.sort(key=lambda e: e[0], reverse=True)
            for a, b, repl in edits:
                text = text[:a] + repl + text[b:]
            if not dry:
                out = text.replace('\n', '\r\n') if crlf else text
                with open(ap, 'w', encoding='utf-8-sig' if bom else 'utf-8',
                          newline='') as f:
                    f.write(out)
            total += len(log)
        for l in log:
            print('  ', l)

    print()
    print('TOTAL: %d talent reference(s) restored%s' % (total, '  (dry run)' if dry else ''))


main()
