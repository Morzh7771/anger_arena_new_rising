#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Replace dead talent slots with the hero's current Dota talent.

A talent slot is dead when the name it holds is defined nowhere - not by Dota,
not by the addon - and no ability's AbilityValues carries a bonus under it. The
slot still shows in the talent UI and grants nothing. Monkey King has eight such
slots, Tinker seven.

A dead slot is filled from the same tier of Valve's talent tree, so the power
level of the choice stays where it belongs:
    Ability10/11 = level 10,  12/13 = level 15,  14/15 = level 20,  16/17 = 25

Working talents are never touched, which keeps both the addon's inventions and
its rebalanced generic talents (special_bonus_strength_15 where Dota says 10).

usage: python fix_talents.py [--dry-run]
"""
import os, re, sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
HEROES = os.path.join(ROOT, 'scripts', 'npc', 'heroes')
PATCH = r"C:\Users\admin\Desktop\Dota 2 7.42\scripts\npc"
PATCH_HERO_DIR = os.path.join(PATCH, 'heroes')

_v = {'__file__': os.path.join(HERE, 'validate.py')}
_src = open(os.path.join(HERE, 'validate.py'), encoding='utf-8').read().split('def check_hero(')[0]
exec(compile(_src, 'validate_part', 'exec'), _v)
parse = _v['parse']
read = _v['read']

SLOT = re.compile(r'^Ability(1[0-7])$')
TIER = {10: (10, 11), 11: (10, 11), 12: (12, 13), 13: (12, 13),
        14: (14, 15), 15: (14, 15), 16: (16, 17), 17: (16, 17)}


def build_known():
    known, referenced = set(), set()
    pab, _ = parse(read(os.path.join(PATCH, 'npc_abilities.txt')))
    known |= {k for k, v in pab.items() if isinstance(v, dict)}
    for f in os.listdir(PATCH_HERO_DIR):
        if f.endswith('.txt'):
            d, _ = parse(read(os.path.join(PATCH_HERO_DIR, f)))
            known |= {k for k, v in d.items() if isinstance(v, dict)}

    def scan(kv):
        for n, b in kv.items():
            if not isinstance(b, dict):
                continue
            known.add(n)
            av = b.get('AbilityValues')
            if isinstance(av, dict):
                for _k, v in av.items():
                    if isinstance(v, dict):
                        for s in v:
                            if s.startswith('special_bonus_'):
                                referenced.add(s)

    for extra in ('talantes.txt', 'neutral_creeps_skill.txt'):
        p = os.path.join(ROOT, 'scripts', 'npc', extra)
        if os.path.isfile(p):
            scan(parse(read(p))[0])
    for h in sorted(os.listdir(HEROES)):
        ap = os.path.join(HEROES, h, 'ability_data.txt')
        if os.path.isfile(ap):
            scan(parse(read(ap))[0])
    return known, referenced



def load_patch_heroes(path):
    """npc_heroes.txt now only #base-includes heroes/npc_dota_hero_*.txt - merge them."""
    base = os.path.dirname(path)
    txt = read(path)
    out = {}
    files = re.findall(r'#base\s+"([^"]+)"', txt)
    for f in files:
        p = os.path.join(base, f.replace('/', os.sep))
        if os.path.isfile(p):
            kv, _ = parse(read(p))
            out.update({k: v for k, v in kv.items() if isinstance(v, dict)})
    if not files:
        out, _ = parse(txt)
    return out, None


def main():
    dry = '--dry-run' in sys.argv
    known, referenced = build_known()
    pher, _ = load_patch_heroes(os.path.join(PATCH, 'npc_heroes.txt'))

    total, unresolved = 0, []
    for hero in sorted(os.listdir(HEROES)):
        hp = os.path.join(HEROES, hero, 'hero_data.txt')
        if not os.path.isfile(hp):
            continue
        hkv, _ = parse(read(hp))
        raw = open(hp, 'rb').read()
        crlf = b'\r\n' in raw
        text = raw.decode('utf-8-sig', 'replace').replace('\r\n', '\n')
        edits, log = [], []

        for hname, hb in hkv.items():
            if not isinstance(hb, dict):
                continue
            pb = pher.get(hname)
            if not isinstance(pb, dict):
                continue
            pslots = {int(SLOT.match(k).group(1)): v for k, v in pb.items()
                      if SLOT.match(k) and isinstance(v, str) and v}
            if not pslots:
                continue
            used = {v for k, v in hb.items()
                    if SLOT.match(k) and isinstance(v, str) and v}

            for k, cur in sorted(hb.items()):
                m = SLOT.match(k)
                if not m or not isinstance(cur, str) or not cur:
                    continue
                if cur in known or cur in referenced or cur == 'generic_hidden':
                    continue
                n = int(m.group(1))
                pick = None
                for cand_slot in (n,) + TIER[n]:
                    cand = pslots.get(cand_slot)
                    if cand and cand not in used:
                        pick = cand
                        break
                if not pick:
                    unresolved.append('%s %s = %s' % (hero, k, cur))
                    continue
                mm = re.search(r'("%s"\s*")%s(")' % (re.escape(k), re.escape(cur)), text)
                if not mm:
                    unresolved.append('%s %s = %s (not found in text)' % (hero, k, cur))
                    continue
                start = mm.start(2) - len(cur)
                edits.append((start, mm.start(2), pick))
                used.discard(cur)
                used.add(pick)
                log.append('%-20s %-10s %-46s -> %s' % (hero, k, cur, pick))

        if edits:
            edits.sort(key=lambda e: e[0], reverse=True)
            for a, b, repl in edits:
                text = text[:a] + repl + text[b:]
            if not dry:
                out = text.replace('\n', '\r\n') if crlf else text
                with open(hp, 'w', encoding='utf-8-sig' if raw[:3] == b'\xef\xbb\xbf'
                          else 'utf-8', newline='') as f:
                    f.write(out)
            total += len(edits)
        for l in log:
            print('  ', l)

    if unresolved:
        print()
        print('could not resolve (no free Dota talent in that tier):')
        for u in unresolved:
            print('   ', u)
    print()
    print('TOTAL: %d dead talent slot(s) replaced%s' % (total, '  (dry run)' if dry else ''))


main()
