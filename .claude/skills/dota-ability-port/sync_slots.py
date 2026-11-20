#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Fill hero ability slots that the addon blanked but the live patch fills.

Faceless Void is the symptom: the addon set "Ability6" to generic_hidden and let
the Chronosphere facet grant the ultimate instead. Without facets the hero has
no ultimate at all. In the live patch Ability6 really is
faceless_void_chronosphere, and the Time Zone facet merely replaces it.

So the fix is not to invent a slot layout - it is to adopt Valve's.

Rules:
  * only slots holding generic_hidden or an empty string are filled
  * a slot already holding an ability is never touched, which protects the
    addon's Lua variants (abaddon_aphotic_shield_lua and friends)
  * talent slots (Ability10 and up) are left alone
  * the ability must be defined in the addon or in the patch

usage: python sync_slots.py [--dry-run]
"""
import os, re, sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
HEROES = os.path.join(ROOT, 'scripts', 'npc', 'heroes')
PATCH_HEROES = r"C:\Users\admin\Desktop\Dota 2 7.42\scripts\npc\npc_heroes.txt"
PATCH_ABILS = r"C:\Users\admin\Desktop\Dota 2 7.42\scripts\npc\heroes"

_v = {'__file__': os.path.join(HERE, 'validate.py')}
_src = open(os.path.join(HERE, 'validate.py'), encoding='utf-8').read().split('def check_hero(')[0]
exec(compile(_src, 'validate_part', 'exec'), _v)
parse = _v['parse']
read = _v['read']

SLOT = re.compile(r'^Ability([1-9])$')          # 1..9 only, never talents
EMPTY = ('generic_hidden', '')


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
    pheroes, _ = load_patch_heroes(PATCH_HEROES)

    filled = 0
    for hero in sorted(os.listdir(HEROES)):
        hp = os.path.join(HEROES, hero, 'hero_data.txt')
        ap = os.path.join(HEROES, hero, 'ability_data.txt')
        if not os.path.isfile(hp):
            continue
        hkv, _ = parse(read(hp))
        akv = {}
        if os.path.isfile(ap):
            akv, _ = parse(read(ap))

        raw = read(hp)
        crlf = '\r\n' in open(hp, 'rb').read().decode('utf-8', 'ignore')
        text = raw.replace('\r\n', '\n')
        edits, log = [], []

        for hname, hb in hkv.items():
            if not isinstance(hb, dict):
                continue
            pb = pheroes.get(hname)
            if not isinstance(pb, dict):
                continue
            pabils = {}
            pf = os.path.join(PATCH_ABILS, '%s.txt' % hname)
            if os.path.isfile(pf):
                pabils, _ = parse(read(pf))

            for key, cur in hb.items():
                if not SLOT.match(key) or not isinstance(cur, str):
                    continue
                if cur not in EMPTY:
                    continue
                want = pb.get(key)
                if not isinstance(want, str) or not want or want in EMPTY:
                    continue
                if want not in akv and want not in pabils:
                    log.append('%-20s %s -> %s  SKIPPED, ability not defined'
                               % (hero, key, want))
                    continue
                if want in hb.values():
                    continue                    # already in another slot
                m = re.search(r'("%s"\s*")%s(")' % (re.escape(key), re.escape(cur)), text)
                if not m:
                    continue
                edits.append((m.start(2), m.start(2), want) if cur == '' else
                             (m.start(2) - len(cur), m.start(2), want))
                log.append('%-20s %-10s %-16s -> %s' % (hero, key, cur, want))

        if edits:
            edits.sort(key=lambda e: e[0], reverse=True)
            for a, b, repl in edits:
                text = text[:a] + repl + text[b:]
            if not dry:
                if crlf:
                    text = text.replace('\n', '\r\n')
                with open(hp, 'w', encoding='utf-8', newline='') as f:
                    f.write(text)
            filled += len(edits)
        for l in log:
            print('  ', l)

    print()
    print('TOTAL: %d slot(s) filled from the live patch%s'
          % (filled, '  (dry run)' if dry else ''))


main()
