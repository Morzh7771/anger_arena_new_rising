# Меню репика: способности, аганим, таланты

Разбор долгой попытки показать в меню репика то же, что дота показывает на
стадии пика. Записано, чтобы не ходить по второму кругу.

Файлы:

- `content/.../panorama/layout/custom_game/repick_menu.xml`
- `content/.../panorama/scripts/custom_game/repick_menu.js`
- `content/.../panorama/styles/custom_game/repick_menu.css`
- `scripts/vscripts/lib/repick_menu.lua`

---

## Что в итоге осталось

Ряд иконок в правой панели, в одну строку:

1. **значок врождёнки** — одна ванильная эмблема на всех врождённых героя;
2. **способности героя** — обычные иконки;
3. **новые способности от аганима и шарда** — если герой их получает.

Подсказки — только ванильные `DOTAShowAbilityTooltip`. Своя карточка осталась
одна: список врождённых, когда их у героя больше одной.

Убрано намеренно: плашка аганима с шардом и значок дерева талантов. Почему —
ниже.

---

## Ванильные виджеты доты в кастомке не работают

Из `client.dll` вытащены имена всего, что рисует нужные нам вещи:

| событие / панель | что рисует |
|---|---|
| `DOTAHUDShowHeroStatBranchTooltip` | дерево талантов по id героя |
| `DOTAShowAghsStatusDisplayTooltip` | карточка аганима и шарда |
| `DOTAShowInnateDisplayTooltip` | подсказка врождённой |
| `DOTAAbilityDraftShowHeroTooltip` | карточка героя из ability draft: врождёнка + `DOTAUIStatBranch` |
| `DOTAUIStatBranch`, `DOTAAghsStatusDisplay`, `DOTAInnateIcon` | сами виджеты |

Как валва их зовёт (из распакованной панорамы):

```xml
<!-- layout/leaf_pages/dashboard_page_debut_hoodwink.xml -->
<Panel class="StatBranch" onmouseover="DOTAHUDShowHeroStatBranchTooltip( 123 )" onmouseout="DOTAHUDHideStatBranchTooltip()" />

<!-- layout/hud/dota_hud_aghs_status_display.xml -->
<DOTAAghsStatusDisplay onmouseover="DOTAShowAghsStatusDisplayTooltip()" onmouseout="DOTAHideAghsStatusDisplayTooltip()">
```

```js
// scripts/hud/dota_hud_abilitydraft.js:262
$.DispatchEvent('DOTAAbilityDraftShowHeroTooltip', heroPanel.GetParent(), unHeroID);
```

Пробовали все три способа: строкой в `onmouseover`, через `$.DispatchEvent` с
настоящими значениями, и созданием панели `$.CreatePanel('DOTAAghsStatusDisplay', ...)`.

**Ни один не отвечает.** Ни тултипа, ни ошибки, ни строки в консоли. Панель
`DOTAAghsStatusDisplay` при этом создаётся, `IsValid()` возвращает true, но она
пустая и на мышь не реагирует.

Сверено с официальным дампом панорама-событий (ModDota/API,
`dump/dump_panorama_events.md`). Кастомным играм отданы только эти тултипы:

```
DOTAShowAbilityTooltip(string abilityName)
DOTAShowAbilityTooltipForEntityIndex(string abilityName, int32 entityIndex)
DOTAShowAbilityTooltipForLevel(string abilityName, int32 level)
DOTAShowAbilityInventoryItemTooltip(int32 entityIndex, int32 inventorySlot)
DOTAShowBuffTooltip / DOTAShowEconItemTooltip / DOTAShowProfileCard*
DOTAShowTextTooltip(string text)
DOTAShowTextTooltipStyled(string text, string style)
DOTAShowTitleTextTooltip(string title, string text)
DOTAShowTitleImageTextTooltip(string title, string imagePath, string text)
```

Всех наших в списке нет. Это внутренняя кухня ванильного HUD.

### Грабля с разбором аргументов

`onmouseover` разбирает **свой** мини-парсер, а не JS. Он тянет только простую
форму с одним аргументом. Запись

```js
onmouseover: `DOTAShowAbilityTooltipForHero(${ability}, ${heroId}, false)`
```

молча не делает **ничего** — и ломает ховер целиком, без ошибки. Если нужны
несколько аргументов, только `$.DispatchEvent`.

---

## Почему не вышло нарисовать своё

Своя карточка и своё дерево рисовались нормально, но текст в них был неполным.
Уткнулись в две вещи.

### 1. `{s:value}` не подставляется на панели, созданной из JS

Строки талантов у доты выглядят так:

```
"DOTA_Tooltip_ability_special_bonus_unique_juggernaut_omnislash_duration"  "+{s:value}s Omnislash Duration"
```

Что пробовали и что вышло:

| способ | результат |
|---|---|
| `label.text = $.Localize(token)` | переменную выбрасывает: «+s Omnislash Duration» |
| `label.text = '#TOKEN'` | не локализует вовсе, на панель лезет сырой `#DOTA_Tooltip_...` |
| `$.CreatePanel('Label', p, '', { text: token })`, потом `SetDialogVariable` | текст резолвится один раз, до переменной дело не доходит |
| то же, но переменные переданы атрибутами при создании | не помогло |
| `$.Localize(token, panelСПеременными)` | не помогло |

При этом **из XML тот же механизм работает**: в этом же меню подписи статов
объявлены как `<Label text="#DOTA_HeroLoadout_StrengthAttribute"/>`, а
`SetDialogVariable('base_str', ...)` из JS их обновляет, и цифры на месте.

В 226 скриптах распакованной панорамы **нет ни одного случая**, где токен
присваивается из кода: везде токен стоит в разметке, а из JS зовётся только
`SetDialogVariable*`. Похоже, движок пересобирает строку лишь для панелей,
созданных парсером XML.

Непроверенная идея на будущее: объявить строку снипетом в XML
(`<Label text="{s:talent}"/>`), создавать его через `BLoadLayoutSnippet` и
наполнять `SetDialogVariableLocString('talent', token)`.

### 2. Имена ключей в KV и в переводе разошлись

Описания способностей у доты идут с `%ключ%`. Тултип доты их разворачивает сам,
у нас его нет, поэтому значения собирались на сервере и подставлялись вручную.

Проблема в том, что описания ванильные, а KV наши. Пример: перевод просит
`%scepter_move_speed%`, а в KV лежит `scepter_movespeed`. Сделали сравнение без
учёта подчёркиваний и регистра, плюс с приставкой `bonus_` и без неё — стало
лучше, но совпадает не всё. Там, где значения нет, в тексте оставался `?`.

---

## Что удалось починить по дороге

### Аганим и шард не находились ни у кого

Проверялся ключ `AbilityHasScepterUpgrade`, которого в аддоне **нет ни разу**.
Реально используются:

| ключ | вхождений |
|---|---|
| `AbilityHasScepterUpgrade` | 0 |
| `HasScepterUpgrade` | 178 |
| `HasShardUpgrade` | 119 |
| `RequiresScepter` / `RequiresShard` | 140 / 140 |
| `special_bonus_scepter` / `special_bonus_shard` | 282 / 266 |

Функция `HasUpgrade(kv, kind)` в `repick_menu.lua` проверяет все формы.

### Нули вместо чисел в описаниях улучшений

У значений, которые даёт аганим или шард, база нулевая, а число лежит рядом:

```
"cooldown_reduction_on_hero_hit"
{
    "value"                 "0"
    "special_bonus_shard"   "+2.0"
}
```

Брали `value` — выходило «уменьшается на 0 сек.». Теперь при нулевой базе берётся
бонус, знак из числа срезается.

### Способности от фасетов лезли в ряд

У Медузы показывался `medusa_venomed_volley`. Такие помечены
`DOTA_ABILITY_BEHAVIOR_HIDDEN` — дота их в выборе героя не рисует. Добавлена
`IsHiddenAbility(kv)`, проверка стоит **после** врождёнки и аганима: те тоже
часто скрытые.

### Крестик закрытия был серым квадратом

`<Label text="✕"/>` — такого глифа в шрифте панорамы нет. Заменён на две
повёрнутые полоски (`CloseCrossBar`), тем же приёмом, что и крестик забаненного
героя.

### Ряд переносился на вторую строку

Размер ячейки считает `AbilityCellSize(count)` от числа иконок, 40px максимум,
26 минимум. Панель шириной по содержимому и по центру.

---

## Падение игры на 00:00

```
CMemoryStack CKeyValuesSystem::m_Strings ran out of reserved memory (128/128kb)
```

Таблица имён ключей KeyValues — **128 КБ на весь аддон**, и она была уже забита:
135 файлов через `#base`.

Что переполняло:

1. **`LoadKeyValues('scripts/npc/herolist.txt')` внутри цикла по героям** — файл
   грузился заново 127 раз за старт, каждый раз регистрируя все имена. Вынесено
   из цикла.
2. **`GetAbilityKeyValuesByName()` в разборе способностей** — тысячи вызовов на
   127 героев. Каждый вызов тоже регистрирует имена.
3. Отдельный KV-файл со значениями талантов, который добавляли для цифр, — от
   него отказались, значения переехали в Lua-таблицу `MANUAL_TALENT_VALUES`.

**Вывод на будущее: любой новый `#base` роняет игру.** Запас исчерпан. Всё, что
можно держать в Lua, надо держать в Lua. Если понадобится KV — сначала чем-то
ужаться.

### Ленивая загрузка

`RepickMenu:init()` больше не разбирает способности вообще. Собирает только
дешёвое: статы, атрибуты, занят/забанен, id.

Способности считаются **по одному герою, когда игрок его выбрал**:

```
клиент → aa_repick_menu_retrive_hero { hero_name }
сервер → RepickMenu:BuildHeroInfo(hero_name), кэш
сервер → aa_repick_menu_set_hero_info { abilities, innate, scepter, shard, talents, values }
```

Кэш с обеих сторон: повторный выбор того же героя ничего не считает. Работа
размазана по кликам вместо одного тика на старте.

---

## Про таланты: где лежат значения

Числа таланта нет в самом таланте. Оно внутри `AbilityValues` той способности,
которую талант улучшает:

```
"duration"
{
    "value"                                              "1.5 1.7 1.9"
    "special_bonus_unique_juggernaut_omnislash_duration" "+0.7"
}
```

Покрытие по всем героям на момент разбора:

| источник | талантов |
|---|---|
| всего в слотах `Ability10..17` | 1045 |
| лежит в KV, внутри улучшаемой способности | 952 |
| число берётся из имени (`special_bonus_hp_300`) | 93 |
| нет нигде — вписаны руками в `MANUAL_TALENT_VALUES` | 8 |

То есть **переносить таланты доты в наши KV не нужно** — значения уже есть.
Не работала подстановка в текст, а не источник данных.

Ванильные строки талантов пишут переменную с приставкой: `{s:bonus_duration}`,
`{s:bonus_AbilityChannelTime}`. Сервер отдаёт алиас `bonus_<ключ>` к каждому
значению.

---

## Что можно попробовать, если вернёмся

1. **Снипет в XML + `BLoadLayoutSnippet`** — единственный непроверенный путь к
   `{s:value}`. Если сработает, дерево талантов со своими цифрами станет
   возможным.
2. **Спросить на форуме**, как привязать `DOTAUIStatBranch` к произвольному
   герою. Текст вопроса с разбором всех попыток уже составлен.
3. **Свести имена ключей** в KV аддона к ванильным — тогда `%ключ%` в описаниях
   будет находиться всегда. Работа большая и ручная, но разовая.

---

## Чего делать не надо

- Звать `DOTAHUDShowHeroStatBranchTooltip`, `DOTAShowAghsStatusDisplayTooltip`,
  `DOTAShowInnateDisplayTooltip`, `DOTAShowAbilityTooltipForHero` — кастомке они
  не отданы.
- Создавать `DOTAAghsStatusDisplay`, `DOTAUIStatBranch`, `DOTAInnateIcon` —
  создаются пустыми, привязать к своему герою нечем.
- Писать в `onmouseover` вызов с несколькими аргументами.
- Присваивать `label.text = '#TOKEN'` — не локализуется.
- Добавлять `#base` в `npc_abilities_custom.txt` — переполнит таблицу строк.
- Звать `LoadKeyValues` или `GetAbilityKeyValuesByName` в циклах по героям.

---

## Попытка через сущность: `DOTAShowAbilityTooltipForEntityIndex` (не вышло)

Замысел был хороший. `DOTAShowAbilityTooltip(имя)` знает только имя и потому
пишет «Нет улучшений»: блоки аганима и шарда в ванильном тултипе — это
`{s:scepter_description}` / `{s:shard_description}` из
`layout/ability_details_v2.xml`, а заполняет их движок **по живой сущности
способности**.

В списке доступных кастомкам событий есть подходящее:

```
DOTAShowAbilityTooltipForEntityIndex(string abilityName, int32 entityIndex)
```

Сделали так: на выбор героя сервер создавал скрытого `npc_tree_thinker` рядом с
героем игрока, вешал на него способности выбранного, аганим и шард, и слал
клиенту `entindex`. Юнит прятался лua-модификатором (невидимость, неуязвимость,
не выделяется, не на миникарте), удалялся при закрытии меню и при смене выбора.

**Данные доходили правильно** — в логе видно `"entindex":1235` и полный набор
значений. Но при наведении на иконку клиент падал:

```
CLocalize::CompileString failed to localize: '#DOTA_Tooltip_CurrentStats_Header'
CLocalize::ConstructString failed to localize: '#DOTA_Tooltip_Ability_juggernaut_blade_dance_lua_SummaryDescription'
Disconnected From 'Localhost:29000'
```

Причина: по сущности дота строит **полный** тултип, а тому нужны токены, которых
у кастомных способностей аддона нет — `_SummaryDescription` на каждую
способность плюс общий `#DOTA_Tooltip_CurrentStats_Header`. Локализация не
собирается и рвёт соединение.

Дописать их нельзя: это по токену на каждую кастомную способность, и любая новая
способность снова уронит клиент. Всё откачено, тултипы снова по имени.

Если когда-нибудь захочется вернуться — сначала завести
`_SummaryDescription` для всех кастомных способностей и
`#DOTA_Tooltip_CurrentStats_Header`, и только потом пробовать.

---

## Разбор чужого ability draft (ветка `repick-menu-redesign`)

Смотрели https://github.com/unco999/dota2-UI---ability-draft — как там показаны
таланты, аганим и врождённая.

**Итог: ничего нового, чего нет у нас, там не работает.** Это React
(x-template), который рендерится прямо в ванильную панель `PreGame` и
копирует снипет `Player` из ванильного `layout/hud/dota_hud_abilitydraft.xml`:

```xml
<Panel id="StatIcon" class="StatBranch" />
<DOTAInnateIcon id="InnateIcon" show-tooltips="true" hittest="true" />
<DOTAUIHeroFacetDropdown id="ADFacetPicker" />
```

- `StatIcon` — просто круглая панель с картинкой из `dota_hud_abilitydraft.css`.
  Ховер на ней в ванили вешает C++ режима ability draft; в репозитории к ней не
  привязано ничего, так что дерево талантов там не показывается.
- `DOTAInnateIcon` — то же самое: героя в него никто не передаёт.
- Единственное, что там привязано по-настоящему, — выбор фасета через
  недокументированный `panel.Init(heroId, facetId)`. Фасетов в аддоне нет, так
  что нам это не нужно; полезен сам факт: у ванильных панелей бывают методы,
  которых нет в panorama-types. Имеет смысл перебрать методы у
  `DOTAUIStatBranch` и `DOTAInnateIcon` (см. ниже), вдруг там есть свой `Init`.

Что взяли:

1. **Метки аганима и шарда на иконках.** В ванильном снипете
   `DraftedAbilityContainer` внутри `DOTAAbilityImage` лежат
   `<Panel class="ScepterMarker"/>` и `<Panel class="ShardMarker"/>`, видимые при
   классах `HasScepterUpgrade` / `HasShardUpgrade` (текстуры
   `hud/reborn/aghsstatus_scepter_marker_psd.vtex` и `..._shard_marker_psd.vtex`).
   Классы там ставит C++, у нас — JS по спискам `scepter` / `shard` с сервера.
2. **Раскладка дерева талантов** — из `layout/ui_stat_branch.xml`: 25 сверху,
   10 снизу; `Upgrade1` (наш `Ability10`) — правая колонка, `Upgrade2` — левая.
3. **Иконка дерева** — `hud/reborn/stat_branch_large_png.vtex` (класс
   `.StatBranch` в `dotastyles.css`).

### `{s:value}` в талантах: попытка через `SetLocString`

В таблице неудачных способов выше нет `LabelPanel.SetLocString(token)`, а
ванильные скрипты им пользуются (`post_game_mvp.js`,
`dashboard_background_seasonal_reward_line_*.js`). Он привязывает к подписи
сам токен, как `text="#..."` в XML, и должен разворачивать его с диалоговыми
переменными этой подписи. В меню теперь так:

```js
for (const key in vals) label.SetDialogVariable(key, String(vals[key]))
label.SetLocString('#DOTA_Tooltip_ability_' + talent)
```

Подписи при этом созданы из XML-снипета `TalentRow` (`BLoadLayoutSnippet`) —
заодно проверяется и гипотеза «пересобираются только панели из XML».
**Проверить в игре:** у Джаггернаута талант `+{s:value}s Omnislash Duration`
должен показать число. Если опять `+s` — путь закрыт, дописать в таблицу выше.

### Грабли раскладки, на которых споткнулись при переделке

- **`style.backgroundImage` из JS ломает `background-size`.** Эмблема
  врождённой ставилась инлайном, а `background-size: contain` и
  `background-position: center` лежали в классе — и не действовали: картинка
  рисовалась в родном размере от левого верхнего угла, в ячейку влезал кусок
  серого кольца. Картинку ставить классом (`.InnateGlyph`), не из JS.
- **Проценты ширины, дающие ровно 100%, переносятся.** Группы героев стояли
  `49% + 2% + 49%`, и вторая уезжала на новую строку — сетка вставала в один
  столбец с прокруткой. Делить место — `fill-parent-flow(1.0)`.
- **Размер портретов считает JS** (`FitPortraits`): клетка группы зависит от
  разрешения, а портрет надо вписать и по ширине, и по высоте — CSS так не
  умеет. Берёт `actuallayoutwidth/height` клетки, делит на `actualuiscale_x/y`
  и перебирает число портретов в ряд. Сразу после показа меню лейаут ещё не
  посчитан — функция ждёт кадр.

### Как посмотреть методы ванильного виджета

В консоли панорамы (или временно в `repick_menu.js`):

```js
const p = $.CreatePanel('DOTAUIStatBranch', $.GetContextPanel(), '')
for (const k in p) $.Msg(k)
p.DeleteAsync(0)
```
