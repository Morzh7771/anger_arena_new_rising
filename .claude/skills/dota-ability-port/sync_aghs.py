#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Bring Aghanim's Scepter / Shard data in line with the live patch.

Per hero, for every NATIVE ability present in both the addon and the patch:
  * HasScepterUpgrade / HasShardUpgrade / IsGrantedByScepter / IsGrantedByShard
    are set exactly as in the patch (an extra "1" is removed, a missing one added);
  * every AbilityValues key the patch ties to the scepter or shard
    (special_bonus_scepter/shard[_N], RequiresScepter/Shard, or "scepter"/"shard"
    in the key name) exists in the addon with the same bonus kind:
      - the addon wrote the bonus under the other kind -> renamed, addon's number kept
      - the addon has no bonus                         -> patch's number, rescaled
      - the addon has a bonus the patch does not       -> removed
      - RequiresScepter / RequiresShard                -> as in the patch
  * scepter/shard bonuses on addon keys the patch no longer has are removed,
    unless some Lua reads that key (then only reported).

For LUA abilities and abilities with no patch counterpart (custom heroes):
  * special_bonus_X numbers without HasXUpgrade -> the flag is added
    (the engine does not apply the bonus without it);
  * HasXUpgrade with no trace of X anywhere     -> reported only.

Numbers the addon already has are never changed: they are balance-tuned.
The engine merges addon KV with vanilla key by key, so "has the flag" below
always means "in the addon or inherited from the vanilla ability of that name".

usage: python sync_aghs.py --all [--dry-run]
       python sync_aghs.py <hero> [<hero> ...] [--dry-run]
"""
import os, re, sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HERE = os.path.dirname(os.path.abspath(__file__))

# helpers from port.py - it runs main() on import, so take the source up to main
_p = {'__file__': os.path.join(HERE, 'port.py')}
_src = open(os.path.join(HERE, 'port.py'), encoding='utf-8').read().split('\ndef main():')[0]
exec(compile(_src, 'port_part', 'exec'), _p)
parse = _p['parse']
read = _p['read']
is_lua = _p['is_lua']
rescale = _p['rescale']
find_blocks = _p['find_blocks']
render_entry = _p['render_entry']
ADDON = _p['ADDON']
PATCH = _p['PATCH']
LUA_KEYS = _p['LUA_KEYS']

FLAGS = ('HasScepterUpgrade', 'HasShardUpgrade', 'IsGrantedByScepter', 'IsGrantedByShard')
KIND_FLAG = {'scepter': 'HasScepterUpgrade', 'shard': 'HasShardUpgrade'}
REQS = ('RequiresScepter', 'RequiresShard')
BONUS = re.compile(r'^special_bonus_(scepter|shard)(_\d+)?$')
SCALAR = re.compile(r'^([ \t]*)"([^"]+)"[ \t]+"([^"]*)"[^\n]*\n?', re.M)


# ------------------------------------------------------------------ helpers
def swap_kind(sub):
    if 'scepter' in sub:
        return sub.replace('scepter', 'shard')
    return sub.replace('shard', 'scepter')


def bonuses(entry):
    return {s: v for s, v in entry.items() if BONUS.match(s)} if isinstance(entry, dict) else {}


def reqs(entry):
    if not isinstance(entry, dict):
        return set()
    return {r for r in REQS if str(entry.get(r)) == '1'}


def is_aghs_key(key, entry):
    if bonuses(entry) or reqs(entry):
        return True
    return re.search(r'scepter|shard', key, re.I) is not None


def bonus_value(v, ml):
    """Patch bonus rescaled to the addon's MaxLevel, keeping a leading '+'."""
    parts = v.split()
    plus = all(p.startswith('+') for p in parts)
    core = ' '.join(p.lstrip('+') for p in parts)
    r = rescale(core, ml) if ml > 1 else None
    if r is None:
        return v
    return ' '.join(('+' + x) if plus and not x.startswith('-') else x for x in r.split())


def nums_of(v):
    """Numbers of a KV value ("+10 +20", "=5", "0.3") or None."""
    if not isinstance(v, str) or not v.strip():
        return None
    try:
        return [float(p.lstrip('+=')) for p in v.split()]
    except ValueError:
        return None


def is_zero(v):
    n = nums_of(v)
    return n is not None and all(x == 0 for x in n)


def apply_bonus(value, bonus):
    """value with the bonus applied: "0.2" + "-0.1" -> "0.1", "5" + "=12" -> "12"."""
    if bonus.lstrip().startswith('='):
        return ' '.join(p.lstrip('=') for p in bonus.split())
    v, b = nums_of(value), nums_of(bonus)
    if not v or not b:
        return None
    if len(b) == 1:
        b = b * len(v)
    if len(v) == 1 and len(b) > 1:
        v = v * len(b)
    if len(v) != len(b):
        return None
    as_int = all('.' not in p for p in (value + ' ' + bonus).replace('+', '').split())
    out = [x + y for x, y in zip(v, b)]
    return ' '.join(str(int(round(x))) if as_int else ('%.2f' % x).rstrip('0').rstrip('.') for x in out)


def styled_like(patch_bonus, number):
    """The addon's number written the way the patch writes this bonus ('+' or not)."""
    if all(p.startswith('+') for p in patch_bonus.split()):
        return ' '.join(p if p.startswith(('-', '+')) else '+' + p for p in number.split())
    return number


# Что не растягиваем под кастомку: время, счётчики, проценты, замедления - их
# умножение ломает баланс, а не подтягивает его.
NO_SCALE = re.compile(r'duration|cooldown|delay|interval|time|count|stack|charge|instance|target'
                      r'|projectile|illusion|bounce|pct|percent|chance|jump|split|wave|number'
                      r'|cast_point|slow|linger|max_|min_|cost', re.I)
# Что тянем по всей способности, если у самого ключа в доте ноль.
POWER = re.compile(r'damage|dmg|heal|shield|health|hp|mana|armor|regen|absorb', re.I)
SCALE_MIN, SCALE_MAX = 1.0, 2.0


def ability_ratio(pav, aav):
    """How much the addon buffed this ability: median of addon/patch at max level
    over keys that grow with level in both files."""
    rs = []
    for k, pe in pav.items():
        if k not in aav:
            continue
        pv = nums_of(pe.get('value') if isinstance(pe, dict) else pe)
        av = nums_of(aav[k].get('value') if isinstance(aav[k], dict) else aav[k])
        if not pv or not av or len(pv) < 2:
            continue
        if pv[0] <= 0 or pv[-1] <= pv[0] or av[-1] <= 0:
            continue
        rs.append(av[-1] / pv[-1])
    if not rs:
        return 1.0
    rs.sort()
    return rs[len(rs) // 2]


def scale_bonus(key, v, p_val, a_val, ratio):
    """A patch bonus the addon has no number for, lifted to the addon's power level.
    Returns (value, why)."""
    nums = nums_of(v)
    if not nums or v.lstrip().startswith('=') or any(x < 0 for x in nums) \
            or max(nums) <= 1 or NO_SCALE.search(key):
        return v, 'из патча'
    pv, av = nums_of(p_val), nums_of(a_val)
    if pv and av and pv[-1] > 0 and av[-1] > 0:
        r, src = av[-1] / pv[-1], 'ключ в аддоне %g против %g в доте' % (av[-1], pv[-1])
    elif POWER.search(key) and (not pv or pv[-1] == 0):
        r, src = ratio, 'по способности'
    else:
        return v, 'из патча'
    r = max(SCALE_MIN, min(SCALE_MAX, r))
    if r < 1.05:
        return v, 'из патча'
    as_int = all('.' not in p for p in v.split())
    out = []
    for p in v.split():
        x = float(p.lstrip('+=')) * r
        s = str(int(round(x))) if as_int else ('%.2f' % x).rstrip('0').rstrip('.')
        out.append(('+' if p.startswith('+') else '') + s)
    return ' '.join(out), 'из патча x%.2f под кастомку: %s' % (r, src)


def scalar_lines(text, start, end, exclude):
    """`"key" "value"` lines in [start,end) that lie outside the given sub-blocks."""
    out = {}
    for m in SCALAR.finditer(text, start, end):
        if any(o < m.start() < c for o, c in exclude):
            continue
        out.setdefault(m.group(2), (m.start(), m.end(), m.group(3), m.group(1)))
    return out


def patch_file(hero):
    p = os.path.join(PATCH, 'npc_dota_hero_%s.txt' % hero)
    if os.path.isfile(p):
        return p
    hpath = os.path.join(ADDON, hero, 'hero_data.txt')
    if os.path.isfile(hpath):
        hkv, _ = parse(read(hpath))
        for k in hkv:
            cand = os.path.join(PATCH, '%s.txt' % k)
            if os.path.isfile(cand):
                return cand
    return None


def allowed_bonuses(hero):
    allowed = {'special_bonus_scepter', 'special_bonus_shard'}
    hpath = os.path.join(ADDON, hero, 'hero_data.txt')
    if os.path.isfile(hpath):
        hkv, _ = parse(read(hpath))
        for hb in hkv.values():
            if not isinstance(hb, dict):
                continue
            for k, v in hb.items():
                if re.fullmatch(r'Ability\d+', k) and isinstance(v, str) and v.startswith('special_bonus_'):
                    allowed.add(v)
    return allowed


# every vanilla ability, for flags the engine inherits by ability name
PATCH_ALL = {}
for fn in os.listdir(PATCH):
    if fn.endswith('.txt'):
        kv, _ = parse(read(os.path.join(PATCH, fn)))
        for k, v in kv.items():
            if isinstance(v, dict):
                PATCH_ALL.setdefault(k, v)


# ------------------------------------------------------------------ planning
def plan_ability(text, name, bopen, bclose, ab, pb, allowed, rep):
    edits = []
    try:
        ml = int(ab.get('MaxLevel', '0'))
    except ValueError:
        ml = 0

    children = list(find_blocks(text, bopen + 1, bclose))
    tops = scalar_lines(text, bopen + 1, bclose, [(bo, bc) for _k, _s, bo, bc in children])
    top_indent = next(iter(tops.values()))[3] if tops else '\t\t'
    av_blk = next(((ks, bo, bc) for k, ks, bo, bc in children if k == 'AbilityValues'), None)
    aav = ab.get('AbilityValues') if isinstance(ab.get('AbilityValues'), dict) else None

    def insert_top(key, val):
        anchor = av_blk[0] if av_blk else bclose
        pos = text.rfind('\n', 0, anchor) + 1
        edits.append((pos, pos, '%s"%s"\t\t\t"%s"\n' % (top_indent, key, val)))

    def top_flag(F):
        cur = tops.get(F)
        return cur is not None and cur[2] == '1'

    if pb is not None and not is_lua(ab):
        # ---------------------------------------------------- native: as in the patch
        # IsGrantedBy* только сверяем: снять его - значит превратить выданную
        # аганимом способность в обычную, а это уже смена кита (sync_kit), не цифр
        for F in ('IsGrantedByScepter', 'IsGrantedByShard'):
            want = str(pb.get(F, '')) == '1'
            if top_flag(F) != want:
                rep.append('%s: ?? %s в аддоне %s, в патче %s - кит не трогаю'
                           % (name, F, '"1"' if top_flag(F) else 'нет', '"1"' if want else 'нет'))
        for F in KIND_FLAG.values():
            want = str(pb.get(F, '')) == '1'
            cur = tops.get(F)
            have = cur is not None and cur[2] == '1'
            if have and not want:
                edits.append((cur[0], cur[1], ''))
                rep.append('%s: убран %s (в патче нет)' % (name, F))
            elif want and not have:
                if cur is not None:
                    line = text[cur[0]:cur[1]]
                    edits.append((cur[0], cur[1], re.sub(r'("%s"[ \t]+)"[^"]*"' % F, r'\1"1"', line, 1)))
                    rep.append('%s: %s "%s" -> "1" как в патче' % (name, F, cur[2]))
                else:
                    insert_top(F, '1')
                    rep.append('%s: добавлен %s, как в патче' % (name, F))

        pav = pb.get('AbilityValues') if isinstance(pb.get('AbilityValues'), dict) else {}
        want_flags = {k for k, F in KIND_FLAG.items() if str(pb.get(F, '')) == '1'}

        if aav is None or av_blk is None:
            if any(is_aghs_key(k, v) for k, v in pav.items()):
                rep.append('%s: !! в аддоне нет AbilityValues - аганим/шард не сверены' % name)
            return edits

        _ks, av_open, av_close = av_blk
        entries = {k: (ks, bo, bc) for k, ks, bo, bc in find_blocks(text, av_open + 1, av_close)}
        scal = scalar_lines(text, av_open + 1, av_close, [(bo, bc) for _s, bo, bc in entries.values()])
        close_line = text.rfind('\n', 0, av_close) + 1
        ent_indent = re.match(r'[ \t]*', text[close_line:av_close]).group(0) + '\t'

        ratio = ability_ratio(pav, aav)
        new_entries = ''
        for k, pe in pav.items():
            if not is_aghs_key(k, pe):
                continue
            if k not in aav:
                piece = render_entry(k, pe, ent_indent, ml, allowed | set(bonuses(pe)))
                if piece:
                    new_entries += piece
                    rep.append('%s / %s: ключа не было - взят из патча' % (name, k))
                continue
            edits += sync_entry(text, name, k, pe, aav[k], entries.get(k), scal.get(k), ml, want_flags,
                                ratio, rep)
        if new_entries:
            edits.append((close_line, close_line, new_entries))

        # addon keys the patch no longer has: the engine never reads them
        for k, ae in aav.items():
            if k in pav or not bonuses(ae) or k not in entries:
                continue
            subs = sorted(bonuses(ae))
            if k in LUA_KEYS:
                rep.append('%s / %s: ключа нет в патче, но его читает Lua - %s оставлены' % (name, k, subs))
                continue
            _s, bo, bc = entries[k]
            lines = scalar_lines(text, bo + 1, bc, [])
            for s in subs:
                edits.append((lines[s][0], lines[s][1], ''))
            rep.append('%s / %s: ключа нет в патче - убраны %s' % (name, k, subs))
        return edits

    # -------------------------------------------------------- lua / custom: additive
    inherited = PATCH_ALL.get(name, {})
    kinds = set()
    for v in (aav or {}).values():
        for s in bonuses(v):
            kinds.add(BONUS.match(s).group(1))

    for kind in sorted(kinds):
        F = KIND_FLAG[kind]
        cur = tops.get(F)
        if top_flag(F) or str(inherited.get(F, '')) == '1':
            continue
        if cur is not None:
            rep.append('%s: [lua] есть special_bonus_%s, но %s "%s" стоит явно - не трогаю' % (name, kind, F, cur[2]))
            continue
        insert_top(F, '1')
        rep.append('%s: [lua] числа special_bonus_%s были без %s - флаг добавлен' % (name, kind, F))

    for kind, F in KIND_FLAG.items():
        if kind in kinds or not top_flag(F):
            continue
        trace = any(('Requires' + kind.capitalize()) in reqs(v) or kind in k.lower()
                    for k, v in (aav or {}).items())
        if not trace:
            rep.append('%s: [lua] %s стоит, а значений %s нет - смотреть Lua' % (name, F, kind))
    return edits


def sync_entry(text, name, k, pe, ae, block, scalar, ml, want_flags, ratio, rep):
    edits = []
    p_b, a_b = bonuses(pe), bonuses(ae)
    p_r, a_r = reqs(pe), reqs(ae)
    p_val = pe.get('value') if isinstance(pe, dict) else pe
    a_val = ae.get('value') if isinstance(ae, dict) else ae
    if isinstance(pe, dict) and p_val is None and p_b:
        # Современный формат доты: value нет вовсе, число только в бонусе
        # ("cooldown_scepter" { "special_bonus_scepter" "7" }) - это value 0.
        # Без этого старый формат аддона ("value" "7" + RequiresScepter) не
        # опознавался, и бонус ложился поверх - с аганимом выходило 14.
        p_val = '0'

    rename, add, remove, notes = {}, {}, [], {}
    new_value = None    # value вместо аддоновского - при переносе старого формата
    for s, v in p_b.items():
        if s in a_b:
            continue
        other = swap_kind(s)
        if other in a_b and other not in p_b and other not in rename:
            rename[other] = s
        elif k == 'AbilityCharges' and nums_of(a_val) and nums_of(p_val) and nums_of(v):
            # Заряды с базы 0 не восстанавливаются (грабли KV из памяти проекта),
            # поэтому в аддоне база 1. Бонус - столько, чтобы с аганимом зарядов
            # стало как в доте: Rupture 0 + 2 в доте -> у нас 1 + 1.
            want = nums_of(p_val)[-1] + nums_of(v)[-1]
            extra = want - nums_of(a_val)[-1]
            if extra > 0:
                add[s] = '+%g' % extra
                notes[s] = 'заряды: база аддона %s, с %s станет %g, как в доте' % (
                    a_val, s.replace('special_bonus_', ''), want)
            else:
                rep.append('%s / %s: у аддона уже %s зарядов, в доте с бонусом %g - бонус не нужен'
                           % (name, k, a_val, want))
        elif is_zero(p_val) and nums_of(a_val) and len(set(nums_of(a_val))) > 1:
            # В доте ключ только для аганима/шарда, а у аддона он по уровням -
            # кастомка сделала его частью базового кита (Kez: крит от парирования
            # 25..100). Перенос в бонус урезал бы его до шарда - не трогаем.
            rep.append('%s / %s: в доте только с %s, у аддона по уровням "%s" - оставлено как есть'
                       % (name, k, s.replace('special_bonus_', ''), a_val))
        elif is_zero(p_val) and a_val is not None and nums_of(a_val) and not is_zero(a_val) \
                and len(p_b) == 1:
            # Старый формат: число аганима лежит прямо в value. Оно так работает и
            # без аганима (RequiresScepter гейтит только подпись), а если просто
            # добавить бонус - удвоится. Как у Абаддона в эталоне: value - как в
            # патче ("0"), наше число - в бонус.
            new_value = p_val
            add[s] = styled_like(v, a_val)
            notes[s] = 'наше число из value "%s", value -> "%s"' % (a_val, p_val)
        else:
            add[s], notes[s] = scale_bonus(k, bonus_value(v, ml), p_val, a_val, ratio)
    for s in a_b:
        if s not in p_b and s not in rename:
            remove.append(s)
            # Ключ и так только для аганима/шарда (shard_cast_point), а в доте у
            # него просто value без бонуса: сворачиваем наше число в value, иначе
            # эффект с шардом станет другим. Dawnbreaker: 0.2 + -0.1 -> 0.1.
            kind = BONUS.match(s).group(1)
            if kind in k.lower() and new_value is None:
                folded = apply_bonus(a_val, a_b[s])
                if folded is not None:
                    new_value = folded
                    notes[s] = 'свёрнут в value: "%s" + "%s" -> "%s"' % (a_val, a_b[s], folded)
    req_add = sorted(p_r - a_r)
    req_del = sorted(a_r - p_r)

    if not (rename or add or remove or req_add or req_del):
        return edits

    for old, new in rename.items():
        rep.append('%s / %s: %s -> %s (число аддона %s, в патче %s)' % (name, k, old, new, a_b[old], p_b[new]))
    for s, v in add.items():
        rep.append('%s / %s: добавлен %s "%s" (%s)' % (name, k, s, v, notes[s]))
    for s in remove:
        live = BONUS.match(s).group(1) in want_flags
        if s in notes:
            rep.append('%s / %s: убран %s, %s' % (name, k, s, notes[s]))
        else:
            rep.append('%s / %s: убран %s "%s"%s' % (name, k, s, a_b[s],
                       ' (работал - у способности есть этот флаг)' if live else ''))
    for r in req_add:
        rep.append('%s / %s: добавлен %s' % (name, k, r))
    for r in req_del:
        rep.append('%s / %s: убран %s' % (name, k, r))

    if block is None:
        # scalar `"k" "v"` -> block with value + bonuses
        if scalar is None:
            rep.append('%s / %s: !! не нашёл строку ключа, пропущено' % (name, k))
            return edits
        s_start, s_end, value, indent = scalar
        inner = indent + '\t'
        body = '%s"value"\t\t\t\t"%s"\n' % (inner, new_value if new_value is not None else value)
        for s, v in add.items():
            body += '%s"%s"\t\t\t"%s"\n' % (inner, s, v)
        for r in req_add:
            body += '%s"%s"\t\t\t"1"\n' % (inner, r)
        edits.append((s_start, s_end, '%s"%s"\n%s{\n%s%s}\n' % (indent, k, indent, body, indent)))
        return edits

    _ks, bo, bc = block
    lines = scalar_lines(text, bo + 1, bc, [])
    if new_value is not None and 'value' in lines:
        st, en = lines['value'][0], lines['value'][1]
        edits.append((st, en, re.sub(r'("value"[ \t]+)"[^"]*"', lambda m: m.group(1) + '"%s"' % new_value,
                                     text[st:en], 1)))
    for old, new in rename.items():
        st, en = lines[old][0], lines[old][1]
        edits.append((st, en, text[st:en].replace('"%s"' % old, '"%s"' % new, 1)))
    for s in remove + req_del:
        edits.append((lines[s][0], lines[s][1], ''))
    if add or req_add:
        inner = next(iter(lines.values()))[3] if lines else re.match(
            r'[ \t]*', text[text.rfind('\n', 0, bc) + 1:bc]).group(0) + '\t'
        chunk = ''.join('%s"%s"\t\t\t"%s"\n' % (inner, s, v) for s, v in add.items())
        chunk += ''.join('%s"%s"\t\t\t"1"\n' % (inner, r) for r in req_add)
        pos = text.rfind('\n', 0, bc) + 1
        edits.append((pos, pos, chunk))
    return edits


# ------------------------------------------------------------------ per hero
def sync_hero(hero, dry):
    apath = os.path.join(ADDON, hero, 'ability_data.txt')
    if not os.path.isfile(apath):
        return None
    raw = open(apath, 'rb').read()
    bom = raw.startswith(b'\xef\xbb\xbf')
    text = read(apath)
    crlf = '\r\n' in text
    text = text.replace('\r\n', '\n')

    addon_kv, _ = parse(text)
    ppath = patch_file(hero)
    patch_kv = parse(read(ppath))[0] if ppath else {}
    allowed = allowed_bonuses(hero)
    rep = [] if ppath else ['(кастомный герой: только проверка флагов)']

    edits = []
    for name, _ks, bopen, bclose in list(find_blocks(text, 0, len(text))):
        if name in ('DOTAAbilities', 'Version'):
            for n2, _ks2, bo2, bc2 in list(find_blocks(text, bopen + 1, bclose)):
                ab = addon_kv.get(n2)
                if isinstance(ab, dict):
                    pb = patch_kv.get(n2) if isinstance(patch_kv.get(n2), dict) else None
                    edits += plan_ability(text, n2, bo2, bc2, ab, pb, allowed, rep)
            continue
        ab = addon_kv.get(name)
        if isinstance(ab, dict):
            pb = patch_kv.get(name) if isinstance(patch_kv.get(name), dict) else None
            edits += plan_ability(text, name, bopen, bclose, ab, pb, allowed, rep)

    # abilities the patch grants with the scepter/shard that the addon has no block for
    for pname, pb in patch_kv.items():
        if isinstance(pb, dict) and pname not in addon_kv and \
                (str(pb.get('IsGrantedByScepter')) == '1' or str(pb.get('IsGrantedByShard')) == '1'):
            rep.append('%s: ?? в патче выдаётся аганимом/шардом, в аддоне блока нет (ваниль сработает сама, проверить слоты hero_data)' % pname)

    if edits and not dry:
        edits.sort(key=lambda e: (e[0], e[1]), reverse=True)
        for pos, pos_end, repl in edits:
            text = text[:pos] + repl + text[pos_end:]
        if crlf:
            text = text.replace('\n', '\r\n')
        with open(apath, 'w', encoding='utf-8-sig' if bom else 'utf-8', newline='') as f:
            f.write(text)
    return {'hero': hero, 'edits': len(edits), 'report': rep}


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    dry = '--dry-run' in sys.argv
    if '--all' in sys.argv:
        heroes = sorted(d for d in os.listdir(ADDON) if os.path.isdir(os.path.join(ADDON, d)))
    elif args:
        heroes = args
    else:
        print(__doc__); sys.exit(2)

    total = 0
    for h in heroes:
        r = sync_hero(h, dry)
        if not r or not r['report']:
            continue
        total += r['edits']
        print('== %s  (%d правок)' % (h, r['edits']))
        for line in r['report']:
            print('   ' + line)
    print()
    print('ИТОГО правок: %d%s' % (total, '  (dry run)' if dry else ''))


main()
