#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Trade plain stat talents for the ability talents Dota has added.

A talent that changes how an ability behaves is worth more than one that adds a
flat number, so where a hero is missing a current Dota ability talent and is
spending a slot on raw stats, the stat talent gives way.

Never displaced:
  * special_bonus_unique_*     - ability talents, addon's or Valve's
  * special_bonus_base_aa_*    - the addon's scripted talent system

Displaced:
  * plain stat talents, Valve's (+5 strength) and the addon's (+20) alike

Placement prefers the same tier the talent occupies in Dota, so the power level
lands where Valve put it:
    Ability10/11 = level 10,  12/13 = 15,  14/15 = 20,  16/17 = 25

usage: python promote_talents.py [--dry-run] [--limit N]
"""
import os, re, sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
HEROES = os.path.join(ROOT, 'scripts', 'npc', 'heroes')
PATCH = r"C:\Users\admin\Desktop\Dota 2 7.42\scripts\npc"

_v = {'__file__': os.path.join(HERE, 'validate.py')}
_src = open(os.path.join(HERE, 'validate.py'), encoding='utf-8').read().split('def check_hero(')[0]
exec(compile(_src, 'validate_part', 'exec'), _v)
parse = _v['parse']
read = _v['read']

SLOT = re.compile(r'^Ability(1[0-7])$')
NUMBERED = re.compile(r'^special_bonus_unique_[a-z_]+_\d+$')
SCRIPTED = 'special_bonus_base_aa_'
TIER = {10: (10, 11), 11: (10, 11), 12: (12, 13), 13: (12, 13),
        14: (14, 15), 15: (14, 15), 16: (16, 17), 17: (16, 17)}


def build_referenced():
    """Talents some ability names as a bonus - those modify an ability."""
    out = set()
    for hero in sorted(os.listdir(HEROES)):
        ap = os.path.join(HEROES, hero, 'ability_data.txt')
        if not os.path.isfile(ap):
            continue
        kv, _ = parse(read(ap))
        for _n, b in kv.items():
            if not isinstance(b, dict):
                continue
            av = b.get('AbilityValues')
            if isinstance(av, dict):
                for _k, v in av.items():
                    if isinstance(v, dict):
                        for s in v:
                            if s.startswith('special_bonus_'):
                                out.add(s)
    return out


REFERENCED = build_referenced()


def is_stat(name):
    """A plain numeric talent - not an ability talent, not the addon's system.

    Membership in REFERENCED decides it, not the name: medusa carries a talent
    called special_bonus_special_bonus_unique_... whose doubled prefix would
    otherwise read as a stat talent, while an ability really does reference it.
    """
    return (name.startswith('special_bonus_')
            and not name.startswith('special_bonus_unique_')
            and not name.startswith(SCRIPTED)
            and name not in REFERENCED)



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
    pher, _ = load_patch_heroes(os.path.join(PATCH, 'npc_heroes.txt'))

    total = 0
    for hero in sorted(os.listdir(HEROES)):
        hp = os.path.join(HEROES, hero, 'hero_data.txt')
        if not os.path.isfile(hp):
            continue
        hkv, _ = parse(read(hp))
        raw = open(hp, 'rb').read()
        crlf = b'\r\n' in raw
        bom = raw[:3] == b'\xef\xbb\xbf'
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
            aslots = {int(SLOT.match(k).group(1)): v for k, v in hb.items()
                      if SLOT.match(k) and isinstance(v, str) and v}
            if not pslots or not aslots:
                continue
            used = set(aslots.values())

            # Dota ability talents this hero is missing, newest naming first
            wanted = [(s, t) for s, t in sorted(pslots.items())
                      if t.startswith('special_bonus_unique_')
                      and not NUMBERED.match(t) and t not in used]
            if not wanted:
                continue

            free_stat = {s: v for s, v in aslots.items() if is_stat(v)}
            if not free_stat:
                continue

            for dota_slot, talent in wanted:
                # prefer a stat slot in the same tier, then any stat slot
                pick = None
                for cand in TIER[dota_slot]:
                    if cand in free_stat:
                        pick = cand
                        break
                if pick is None and free_stat:
                    pick = sorted(free_stat)[0]
                if pick is None:
                    break
                old = free_stat.pop(pick)
                key = 'Ability%d' % pick
                m = re.search(r'("%s"\s*")%s(")' % (re.escape(key), re.escape(old)), text)
                if not m:
                    continue
                start = m.start(2) - len(old)
                edits.append((start, m.start(2), talent))
                used.add(talent)
                log.append('%-20s %-10s %-34s -> %s' % (hero, key, old, talent))

        if edits:
            edits.sort(key=lambda e: e[0], reverse=True)
            for a, b, repl in edits:
                text = text[:a] + repl + text[b:]
            if not dry:
                out = text.replace('\n', '\r\n') if crlf else text
                with open(hp, 'w', encoding='utf-8-sig' if bom else 'utf-8',
                          newline='') as f:
                    f.write(out)
            total += len(edits)
        for l in log:
            print('  ', l)

    print()
    print('TOTAL: %d stat talent(s) traded for ability talents%s'
          % (total, '  (dry run)' if dry else ''))


main()
