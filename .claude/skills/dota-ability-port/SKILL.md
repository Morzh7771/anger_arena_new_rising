---
name: dota-ability-port
description: Port one hero's ability KV from the live Dota 2 patch into this addon — sync ability structure and new AbilityValues keys, rescale every level array to the addon's MaxLevel (usually 7), convert legacy AbilitySpecial to AbilityValues, and wire new abilities into hero_data.txt. Use when asked to update, port, or sync a hero's abilities against the reference patch.
---

# Porting a hero's abilities from the live patch

You update **one hero** per run. Do not touch other heroes.

## Files

| Role | Path |
|---|---|
| Target (edit this) | `scripts/npc/heroes/<hero>/ability_data.txt` |
| Target (edit this) | `scripts/npc/heroes/<hero>/hero_data.txt` |
| Reference (read only, never edit) | `C:\Users\admin\Desktop\dota 2 patch\scripts\npc\heroes\npc_dota_hero_<hero>.txt` |

`<hero>` is the addon folder name. If no reference file matches the folder name, look up the
`npc_dota_hero_*` key inside `hero_data.txt` and use that name instead. If there is still no
reference file, the hero is fully custom — **stop and report "custom hero, skipped"**.

Read **both files completely** before editing.

## Step 0 — classify every ability in the addon file

For each top-level ability block in `ability_data.txt`:

- **LUA ability** — it has a `ScriptFile` key, or `BaseClass` is `ability_lua` / `ability_datadriven`.
- **NATIVE ability** — everything else (including `BaseClass` equal to the ability's own name).

The distinction decides everything below. In a native ability the engine only reads the keys that
the *current* patch defines, so any addon key the patch dropped is dead code. In a Lua ability the
addon's own Lua reads the keys, so removing one breaks the hero.

## Rules for LUA abilities

Additive only:

- **Never** rename, remove, or restructure a key.
- **Never** import patch keys into it.
- The only permitted change: fix level-array lengths per §Rescale.

## Rules for NATIVE abilities that exist in both files

Rebuild the block using the patch block as the structural template.

**Keep from the addon, verbatim:**
- `MaxLevel` (the addon's value — usually `7`)
- `BaseClass`, `AbilityTextureName`, `AbilitySound`, `FightRecapLevel`
- any top-level key the patch does not have

**`AbilityBehavior`** — emit the **union** of the addon's flags and the patch's flags. The addon
sometimes adds `DOTA_ABILITY_BEHAVIOR_HIDDEN` or `_NOT_LEARNABLE` deliberately; never drop those.

One exception to the union: do **not** import `DOTA_ABILITY_BEHAVIOR_HIDDEN` or
`DOTA_ABILITY_BEHAVIOR_FORCE_NO_INNATE_UI` from the patch onto an ability that occupies a visible
`AbilityN` slot in the addon's `hero_data.txt`. Valve hides some abilities because their own facet
UI surfaces them elsewhere; copying that flag here would make the ability vanish from the player's
HUD. If the addon already has the flag, keep it.

**Other top-level props** — take the patch's value for: `AbilityUnitTargetTeam`, `AbilityUnitTargetType`,
`AbilityUnitTargetFlags`, `SpellImmunityType`, `SpellDispellableType`, `AbilityUnitDamageType`,
`AbilityType`, `IsBreakable`, `Innate`, `HasScepterUpgrade`, `HasShardUpgrade`,
`AbilityCastAnimation`, `AbilityCastGestureSlot`, `AbilityChannelTime`.

**`AbilityCastRange`, `AbilityCastPoint`, `AbilityManaCost`, `AbilityCooldown`** — keep the
**addon's** numbers (they are balance-tuned), only fix array length per §Rescale. If the addon lacks
the key entirely, take the patch's and rescale.

**`AbilityValues`** — the result must contain every key the patch block has. For each patch key:

1. **Addon has the same key** → keep the addon's numbers and its `special_bonus_*` /
   `LinkedSpecialBonus*` sub-entries. Only fix array length.
2. **Addon has a renamed / merged equivalent** → migrate the addon's numbers into the new key name.
   Judge by meaning. Examples seen in this codebase:
   - `target_damage` + `heal_amount` → `damage_heal` (Abaddon; carry the shared array over once)
   - `num_wall_elements` / `wall_element_spacing` → `wall_total_length` / `wall_width` (Invoker)
   When two old keys merge into one and their arrays differ, use the larger of the two.
3. **No addon counterpart** → take the patch's numbers and rescale to the addon's `MaxLevel`.
   This is the "прописать примерно" case — patch-accurate values stretched to 7 levels.

**Removing dead addon keys.** An `AbilityValues` key present in the addon but absent from the patch
is dead *unless something else reads it*. Before deleting, grep for the key name:

```bash
grep -rn "<key_name>" scripts/vscripts panorama
```

Found → keep it. Not found → delete it. When you are unsure, keep it and note it in your report.

## Rules for abilities the addon does not have

Copy the whole block from the patch, then:

- Set `MaxLevel` to match sibling abilities in the same addon file — `7` for a learnable ability,
  `1` for one marked `Innate` or `DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE`.
- Rescale every level array to that `MaxLevel` (§Rescale).
- Wire it into `hero_data.txt` per §Wiring.

## §Wiring — hero_data.txt

- **Innate ability** (`"Innate" "1"`) → add to the next free `AbilityN` slot.
- **Facet-granted ability** → add under `Facets/<facet>/Abilities/AbilityN/AbilityName`, but **only
  if that facet already exists** in the addon's `hero_data.txt`. Never invent a facet.
- **Sub-ability** — spawned by another ability or by a summoned unit rather than occupying a hero
  slot (`invoker_*_ad`, `*_self_cast`, sub-spell forms, summon abilities, `*_recall`, `*_cancel`)
  → **do not wire**. It is referenced by its parent, not by the hero.
- Never renumber, displace, or remove an existing `AbilityN` entry.
- No free slot, or you are unsure which category applies → leave it unwired and say so in the report.

## §Talents

- Do **not** copy `special_bonus_*` stub definitions from the patch. Base Dota already defines them.
- Keep the addon's `special_bonus_*` sub-entries and their numbers.
- If a patch key carries a `special_bonus_X` that the addon's `hero_data.txt` does not list, drop
  that sub-entry and keep only `value`. Exceptions always kept: `special_bonus_scepter`,
  `special_bonus_shard`.
- `special_bonus_facet_X` → keep only if the addon's `hero_data.txt` declares facet `X`.

## §Rescale — level arrays

Let `ML` be the ability's `MaxLevel` in the addon file. Given a source array `v[0..n-1]`:

| Case | Output |
|---|---|
| `n == ML` | unchanged |
| `n == 1`, or all values equal | a single scalar, no array — Dota applies it to every level |
| series **increasing** | `v[0] + i*step` for `i = 0..ML-1`, where `step = (v[n-1] - v[0]) / (n-1)` — *preserve the step, extend the range* |
| series **decreasing** | `v[0] + i*step` for `i = 0..ML-1`, where `step = (v[n-1] - v[0]) / (ML-1)` — *preserve the range, soften the step* |

The decreasing branch exists because cooldowns and mana costs must not run into zero or negative
numbers. `"12 10 8 6"` at `ML=7` becomes `"12 11 10 9 8 7 6"`, not `"12 10 8 6 4 2 0"`.

Rounding: all source values integer → round to integer. Otherwise round to 2 decimals and trim
trailing zeros. Never emit a negative number, and never emit `0` for a cooldown or mana cost.

Worked examples:

```
patch  "95 170 245 320"  ML 7  increasing  step 75   ->  "95 170 245 320 395 470 545"
addon  "15 20 25 30"     ML 7  increasing  step 5    ->  "15 20 25 30 35 40 45"
patch  "12 10 8 6"       ML 7  decreasing  step -1   ->  "12 11 10 9 8 7 6"
patch  "7 6 5 4"         ML 7  decreasing  step -0.5 ->  "7 6.5 6 5.5 5 4.5 4"
any    "900 900 900 900" ML 7  constant              ->  "900"
```

## §AbilitySpecial → AbilityValues

Legacy blocks must become `AbilityValues`. Drop the `"01"` / `"02"` index wrappers and every
`var_type` line. **Keep** `LinkedSpecialBonus`, `LinkedSpecialBonusField`, and
`LinkedSpecialBonusOperation` exactly as they are — they are valid inside `AbilityValues`.

```
"AbilitySpecial"                          "AbilityValues"
{                                         {
    "01"                                      "movespeed_bonus"  "15 20 25 30 35 40 45"
    {                            ->           "damage"
        "var_type" "FIELD_INTEGER"            {
        "movespeed_bonus" "15 20 25 30"           "value"              "100 200 300 400 500 600 700"
    }                                             "LinkedSpecialBonus" "special_bonus_unique_x"
    "02"                                      }
    {                                     }
        "var_type" "FIELD_INTEGER"
        "damage" "100 200 300 400"
        "LinkedSpecialBonus" "special_bonus_unique_x"
    }
}
```

If an ability already has both an `AbilitySpecial` and an `AbilityValues` block, merge into
`AbilityValues`; on a key collision the existing `AbilityValues` entry wins.

## Worked reference

`scripts/npc/heroes/abaddon/ability_data.txt` is already ported and validates clean. Read it
alongside `npc_dota_hero_abaddon.txt` when a rule here is ambiguous. It demonstrates:

- two dead keys merged into the patch's replacement — `target_damage` + `heal_amount` → `damage_heal`,
  keeping the addon's 7-level array and its talent
- a new sibling key given the addon's number rather than the patch's — `self_damage_enemy_target`
  set to `50` to match the addon's `self_damage`, not the patch's `40`
- a root `AbilityCooldown` moved into `AbilityValues` because the patch moved it there, carrying the
  addon's `"11.0 10.5 10.0 9.5 9.0 8.5 8.0"` unchanged
- new shard keys imported wholesale — `absorb_to_damage`, `absorb_damage_aoe`
- `duration_scepter` / `ally_threshold_scepter` / `redirect_range_scepter` rewritten into the patch's
  `special_bonus_scepter` form, preserving the addon's magnitudes (the scepter bonus was `+1.0`
  because the addon's scepter array sat exactly 1.0s above its base array)
- a duplicate `HasScepterUpgrade` removed

## Style

Match the surrounding file: tabs for indentation, the existing `//---` separator comments, key and
value aligned in the same column style as neighbouring entries. Preserve existing comments. Do not
reorder abilities. Do not reformat blocks you did not otherwise change.

## Finish — validate, then report

Run the validator and fix everything it reports:

```bash
"C:/Users/admin/AppData/Local/Programs/Python/Python314/python.exe" .claude/skills/dota-ability-port/validate.py <hero>
```

Then report, briefly:
- keys renamed / merged, with old → new
- keys deleted, and the grep result that justified each
- new abilities added, and whether each was wired into `hero_data.txt` or intentionally left unwired
- anything you could not resolve

Never claim the validator passed without running it.
