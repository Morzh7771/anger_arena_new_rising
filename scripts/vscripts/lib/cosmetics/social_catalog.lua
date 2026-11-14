-- Социальная косметика: колесо фраз, наборы смайликов, спреи, хай-файвы.
--
-- Глобальная таблица SOCIAL_CATALOG[slot] - контракт с lib/cosmetics/core.lua:
-- core подмешивает эти записи в свой каталог (PublishCatalog) и отдаёт меню.
-- Каждая запись: { id, name_ru, rarity, premium = true, ...поля слота }.
--
-- Слоты:
--   wheel      - набор из 8 фраз. scope = "team" (только своим) или "all".
--                phrases[i] = { id, text, sound } - sound необязателен
--                (имя ванильного soundboard-события, см. ниже).
--   emote_set  - набор смайликов, emotes[i] = { id, name_ru, image }.
--                image - имя файла ванильного смайлика без пути и
--                расширения: panorama/images/emoticons/<image>.vtex
--   spray      - particle - ванильный спрей на земле (particles/sprays/*).
--   high_five  - overhead / travel / impact - ванильные партиклы хай-файва.
--
-- Всё в наборе премиум-только, пока что: поле premium = true читает меню.
-- Ассеты только ванильные (проверены по vpk_files.txt, пути без _c).
-- Звуки - ванильные soundboard-события "soundboard.<имя>", имена совпадают
-- с файлами sounds/misc/soundboard/<имя>.vsnd_c; без звука phrase.sound = nil.

SOCIAL_CATALOG = SOCIAL_CATALOG or {}

-- ------------------------------------------------------------------ колесо фраз

SOCIAL_CATALOG.wheel = {
	{
		id = "wheel_tactics", name_ru = "Тактика", rarity = "common", premium = true,
		scope = "team",
		phrases = {
			{ id = "help",    text = "Нужна помощь!" },
			{ id = "retreat", text = "Отступаем!" },
			{ id = "boss",    text = "Иду на босса" },
			{ id = "farm",    text = "Фармим" },
			{ id = "duel",    text = "Дуэль скоро!" },
			{ id = "ward",    text = "Нужен вард" },
			{ id = "gank",    text = "Иду на ганк" },
			{ id = "push",    text = "Пушим!" },
		},
	},
	{
		id = "wheel_chat", name_ru = "Общение", rarity = "common", premium = true,
		scope = "all",
		phrases = {
			{ id = "gg",     text = "GG" },
			{ id = "wp",     text = "Хорошо сыграно!" },
			{ id = "luck",   text = "Удачи!" },
			{ id = "thanks", text = "Спасибо!" },
			{ id = "sorry",  text = "Извини" },
			{ id = "wow",    text = "Ну вы даёте" },
			{ id = "haha",   text = "Ха-ха" },
			{ id = "what",   text = "Как так?" },
		},
	},
	{
		id = "wheel_sounds", name_ru = "Звуки", rarity = "rare", premium = true,
		scope = "all",
		phrases = {
			{ id = "kiss",     text = "Поцелуй",          sound = "soundboard.kiss" },
			{ id = "ow",       text = "Ой!",              sound = "soundboard.ow" },
			{ id = "snore",    text = "Храп",             sound = "soundboard.snore" },
			{ id = "bockbock", text = "Бок-бок",          sound = "soundboard.bockbock" },
			{ id = "yahoo",    text = "Ура!",             sound = "soundboard.yahoo" },
			{ id = "sadbone",  text = "Грустный тромбон", sound = "soundboard.sad_bone" },
			{ id = "rimshot",  text = "Ба-дум-тсс",       sound = "soundboard.rimshot" },
			{ id = "frog",     text = "Ква",              sound = "soundboard.frog" },
		},
	},
	{
		id = "wheel_fun", name_ru = "Веселье", rarity = "rare", premium = true,
		scope = "all",
		phrases = {
			{ id = "gong",    text = "Гонг!",             sound = "soundboard.gong" },
			{ id = "bells",   text = "Колокольчики",      sound = "soundboard.sleighbells" },
			{ id = "tada",    text = "Тадам!",            sound = "soundboard.ta_daaaa" },
			{ id = "oy",      text = "Ой-ой-ой",          sound = "soundboard.oy_oy_oy" },
			{ id = "quiet",   text = "Тишина...",         sound = "soundboard.cricket" },
			{ id = "drums",   text = "Барабанная дробь",  sound = "soundboard.drum_roll" },
			{ id = "horn",    text = "Фанфары!",          sound = "soundboard.party_horn" },
			{ id = "charge",  text = "В атаку!",          sound = "soundboard.charge" },
		},
	},
	{
		id = "wheel_ru_casters", name_ru = "Русские кастеры", rarity = "rare", premium = true,
		scope = "all",
		phrases = {
			{ id = "a_net_net_da", text = "А, нет-нет-нет... да!", sound = "soundboard.a_net_net_da" },
			{ id = "a_nu_ka_idi_suda", text = "А ну-ка иди сюда!", sound = "soundboard.a_nu_ka_idi_suda" },
			{ id = "aaah_aaah_chto", text = "А-а-а... что?!", sound = "soundboard.aaah_aaah_chto" },
			{ id = "bozhe_kak_eto_bolno", text = "Боже, как это больно", sound = "soundboard.bozhe_kak_eto_bolno" },
			{ id = "bozhe_ti_posmotri", text = "Боже, ты посмотри!", sound = "soundboard.bozhe_ti_posmotri" },
			{ id = "chto_eto_kakaya_zhest", text = "Что это? Какая жесть!", sound = "soundboard.chto_eto_kakaya_zhest" },
			{ id = "da_da_da_nyet", text = "Да-да-да... нет", sound = "soundboard.da_da_da_nyet" },
			{ id = "ehto_g_g", text = "Это ГГ", sound = "soundboard.ehto_g_g" },
			{ id = "eto_ge_popayx_feeda", text = "Это же попахивает фидом", sound = "soundboard.eto_ge_popayx_feeda" },
			{ id = "eto_nenormalno", text = "Это ненормально", sound = "soundboard.eto_nenormalno" },
			{ id = "eto_prosto_netchto", text = "Это просто нечто", sound = "soundboard.eto_prosto_netchto" },
			{ id = "eto_sochno", text = "Это сочно", sound = "soundboard.eto_sochno" },
			{ id = "eto_takaya_dushka", text = "Это такая душка", sound = "soundboard.eto_takaya_dushka" },
			{ id = "krasavchik", text = "Красавчик!", sound = "soundboard.krasavchik" },
			{ id = "kreasa_kreasa", text = "Краса, краса!", sound = "soundboard.kreasa_kreasa" },
			{ id = "oy_oy_bezhat", text = "Ой-ой, бежать!", sound = "soundboard.oy_oy_bezhat" },
			{ id = "takaya_haliava", text = "Такая халява", sound = "soundboard.takaya_haliava" },
			{ id = "casperrr_laugh_ru", text = "Смех Касперра", sound = "soundboard.casperrr_laugh_ru" },
			{ id = "guys_ive_got_this_ru", text = "Пацаны, я разберусь", sound = "soundboard.guys_ive_got_this_ru" },
			{ id = "hit_just_hit_destroy_ru", text = "Бей, просто бей, уничтожай!", sound = "soundboard.hit_just_hit_destroy_ru" },
			{ id = "hit_more_ru", text = "Бей ещё!", sound = "soundboard.hit_more_ru" },
			{ id = "i_saw_everything_its_his_fault_ru", text = "Я всё видел, это он виноват", sound = "soundboard.i_saw_everything_its_his_fault_ru" },
			{ id = "ok_lets_see_whats_next_ru", text = "Ладно, посмотрим, что дальше", sound = "soundboard.ok_lets_see_whats_next_ru" },
			{ id = "chut_chut_ne_hvatilo", text = "Чуть-чуть не хватило", sound = "soundboard.chut_chut_ne_hvatilo" },
			{ id = "kak_dela", text = "Как дела?", sound = "soundboard.kak_dela" },
			{ id = "prosto_mwuah", text = "Просто чмок", sound = "soundboard.prosto_mwuah" },
			{ id = "v_kakoy_zone", text = "В какой зоне?", sound = "soundboard.v_kakoy_zone" },
			{ id = "vot_eto_da", text = "Вот это да!", sound = "soundboard.vot_eto_da" },
		},
	},
	{
		id = "wheel_en_casters", name_ru = "Английские кастеры", rarity = "rare", premium = true,
		scope = "all",
		phrases = {
			{ id = "absolutely_perfect", text = "Просто идеально!", sound = "soundboard.absolutely_perfect" },
			{ id = "brutal", text = "Жестоко. Беспощадно. Разнесли.", sound = "soundboard.brutal" },
			{ id = "easiest_money", text = "Самые лёгкие деньги", sound = "soundboard.easiest_money" },
			{ id = "echo_slama_jama", text = "Эхо слэма-джама!", sound = "soundboard.echo_slama_jama" },
			{ id = "next_level", text = "Игра нового уровня!", sound = "soundboard.next_level" },
			{ id = "no_chill", text = "Никакой пощады", sound = "soundboard.no_chill" },
			{ id = "nothing_that_can_stop_this_man", text = "Этого парня не остановить", sound = "soundboard.nothing_that_can_stop_this_man" },
			{ id = "playing_to_win", text = "Играем на победу", sound = "soundboard.playing_to_win" },
			{ id = "that_was_questionable", text = "Это было сомнительно", sound = "soundboard.that_was_questionable" },
			{ id = "what_just_happened", text = "Что сейчас произошло?", sound = "soundboard.what_just_happened" },
			{ id = "whats_cooking", text = "Что тут готовится?", sound = "soundboard.whats_cooking" },
			{ id = "youre_a_hero", text = "Ты герой!", sound = "soundboard.youre_a_hero" },
			{ id = "see_you_later_nerds", text = "Пока, ботаники", sound = "soundboard.see_you_later_nerds" },
			{ id = "lets_play", text = "Поиграем!", sound = "soundboard.lets_play" },
			{ id = "looking_spicy", text = "Выглядит остро", sound = "soundboard.looking_spicy" },
			{ id = "patience", text = "Терпение...", sound = "soundboard.patience" },
			{ id = "holy_moly", text = "Ничего себе!", sound = "soundboard.holy_moly" },
			{ id = "goodness_gracious", text = "Батюшки!", sound = "soundboard.goodness_gracious" },
			{ id = "rrrrrampage", text = "Ра-а-ампага!", sound = "soundboard.rrrrrampage" },
			{ id = "fight_fight_fight", text = "Драка! Драка! Драка!", sound = "soundboard.fight_fight_fight" },
			{ id = "i_love_dota_so_much", text = "Как же я люблю доту", sound = "soundboard.i_love_dota_so_much" },
			{ id = "his_brain_is_so_big", text = "Какой у него большой мозг", sound = "soundboard.his_brain_is_so_big" },
			{ id = "stupidest_way_to_die", text = "Самая глупая смерть", sound = "soundboard.stupidest_way_to_die" },
			{ id = "keyboard_not_working", text = "У меня клавиатура не работает", sound = "soundboard.keyboard_not_working" },
			{ id = "did_we_actually_win", text = "Мы что, правда выиграли?", sound = "soundboard.did_we_actually_win" },
			{ id = "321_lets_go", text = "Три, два, один, поехали!", sound = "soundboard.321_lets_go" },
		},
	},
	{
		id = "wheel_memes", name_ru = "Мемы", rarity = "common", premium = true,
		scope = "all",
		phrases = {
			{ id = "wow", text = "Вау!", sound = "soundboard.wow" },
			{ id = "oops", text = "Упс", sound = "soundboard.oops" },
			{ id = "uh_oh", text = "Ой-ой", sound = "soundboard.uh_oh" },
			{ id = "crybaby", text = "Плакса", sound = "soundboard.crybaby" },
			{ id = "headshake", text = "Ну-ну-ну", sound = "soundboard.headshake" },
			{ id = "ding_ding_ding", text = "Дзынь-дзынь-дзынь", sound = "soundboard.ding_ding_ding" },
			{ id = "tick_tock", text = "Тик-так", sound = "soundboard.tick-tock" },
			{ id = "woopwoo", text = "Вуп-вуп", sound = "soundboard.woopwoo" },
			{ id = "crash_burn", text = "Разбился и сгорел", sound = "soundboard.crash_burn" },
			{ id = "ti9_record_scratch", text = "Стоп, что?", sound = "soundboard.ti9_record_scratch" },
			{ id = "all_dead", text = "Все мертвы", sound = "soundboard.all_dead" },
			{ id = "boing", text = "Бойнь!", sound = "soundboard.boing" },
			{ id = "chicken", text = "Цыплёнок", sound = "soundboard.chicken" },
		},
	},
}

-- свои звуки владельца (sounds/aa_wheel, генерируется build_wheel_sounds.js): отдельный набор
local okCustom, custom = pcall(require, "lib/cosmetics/wheel_custom_phrases")

if okCustom and type(custom) == "table" and #custom > 0 then
	table.insert(SOCIAL_CATALOG.wheel, {
		id = "wheel_custom", name_ru = "Свои звуки", rarity = "mythical", premium = true,
		scope = "all",
		phrases = custom,
	})
end

-- фразы 1x6 (wheel_x6_phrases.lua, gen_wheel_x6.js): три набора - русские, английские, разное
local okX6, x6 = pcall(require, "lib/cosmetics/wheel_x6_phrases")

if okX6 and type(x6) == "table" then
	for _, set in ipairs(x6) do
		table.insert(SOCIAL_CATALOG.wheel, {
			id = set.id, name_ru = set.name_ru, rarity = "mythical", premium = true,
			scope = "all",
			phrases = set.phrases,
		})
	end
end

-- ------------------------------------------------------------------ смайлики

SOCIAL_CATALOG.emote_set = {
	{
		id = "emote_praise", name_ru = "Похвала", rarity = "common", premium = true,
		emotes = {
			{ id = "cool",        name_ru = "Круто",         image = "cool_png" },
			{ id = "big_brain",   name_ru = "Умница",        image = "big_brain_png" },
			{ id = "blush",       name_ru = "Смущение",      image = "blush_png" },
			{ id = "dealwithit",  name_ru = "Ну-ну",         image = "dealwithit_png" },
			{ id = "cry",         name_ru = "Слёзы",         image = "cry_png" },
			{ id = "dunno",       name_ru = "Не знаю",       image = "dunno_png" },
			{ id = "eh",          name_ru = "Эх",            image = "eh_png" },
			{ id = "exclamation", name_ru = "Внимание",      image = "exclamation_png" },
			{ id = "doot",        name_ru = "Ду-ду",         image = "doot_png" },
			{ id = "cocky",       name_ru = "Уверенность",   image = "cocky_png" },
			{ id = "chew",        name_ru = "Жуёт",          image = "chew_png" },
			{ id = "confounded",  name_ru = "Растерянность", image = "confounded_png" },
		},
	},
	{
		id = "emote_fun", name_ru = "Веселье", rarity = "rare", premium = true,
		emotes = {
			{ id = "crazy",        name_ru = "Безумие",       image = "crazy_png" },
			{ id = "bloodthirsty", name_ru = "Кровожадность", image = "bloodthirsty_png" },
			{ id = "cheeky",       name_ru = "Хитрость",      image = "cheeky_png" },
			{ id = "big_slap",     name_ru = "Пощёчина",      image = "big_slap_png" },
			{ id = "closecall",    name_ru = "Чудом",         image = "closecall_png" },
			{ id = "come_here",    name_ru = "Иди сюда",      image = "come_here_png" },
			{ id = "donkey",       name_ru = "Осёл",          image = "donkey_png" },
			{ id = "dead_eyes",    name_ru = "Мёртвый взгляд", image = "dead_eyes_png" },
			{ id = "aaaah",        name_ru = "Ааа",           image = "aaaah_png" },
			{ id = "angel",        name_ru = "Ангел",         image = "angel_png" },
		},
	},
	{
		id = "emote_carnival", name_ru = "Карнавал", rarity = "mythical", premium = true,
		emotes = {
			{ id = "c_loser",   name_ru = "Проигравший",    image = "dark_carnival_loser_png" },
			{ id = "c_winner",  name_ru = "Победитель",     image = "dark_carnival_winner_png" },
			{ id = "c_rage",    name_ru = "Ярость",         image = "dark_carnival_rage_png" },
			{ id = "c_jam",     name_ru = "Качаюсь",        image = "dark_carnival_jam_out_png" },
			{ id = "c_snappy",  name_ru = "Щёлк",           image = "dark_carnival_snappy_png" },
			{ id = "c_old",     name_ru = "Слишком стар",   image = "dark_carnival_too_old_png" },
			{ id = "c_watch",   name_ru = "Осторожно",      image = "dark_carnival_watchout_png" },
			{ id = "c_shout",   name_ru = "Крик",           image = "dark_carnival_shout_png" },
			{ id = "c_hypno",   name_ru = "Гипноз",         image = "dark_carnival_hypnosis_png" },
		},
	},
}

-- ------------------------------------------------------------------ похвала

-- Картинки похвалы из 1x6 (panorama/images/custom_game/tips/tip_N.png).
-- tip_0 (палец вверх) - у всех по умолчанию, остальные выбирают премиум-игроки в хабе.
-- Сервер (lib/tip_manager.lua) кладёт картинку отправителя в тост player_tipped.

SOCIAL_CATALOG.tip = {
	{ id = "tip_0", name_ru = "Лайк", rarity = "common", premium = true, image = "tip_0", icon = "file://{images}/custom_game/tips/tip_0.png" },
	{ id = "tip_1", name_ru = "Мудрое дерево", rarity = "rare", premium = true, image = "tip_1", icon = "file://{images}/custom_game/tips/tip_1.png" },
	{ id = "tip_2", name_ru = "Рофлан", rarity = "rare", premium = true, image = "tip_2", icon = "file://{images}/custom_game/tips/tip_2.png" },
	{ id = "tip_3", name_ru = "Рофлан поминки", rarity = "rare", premium = true, image = "tip_3", icon = "file://{images}/custom_game/tips/tip_3.png" },
	{ id = "tip_4", name_ru = "База", rarity = "rare", premium = true, image = "tip_4", icon = "file://{images}/custom_game/tips/tip_4.png" },
	{ id = "tip_5", name_ru = "Крип", rarity = "rare", premium = true, image = "tip_5", icon = "file://{images}/custom_game/tips/tip_5.png" },
	{ id = "tip_6", name_ru = "Кот с розой", rarity = "rare", premium = true, image = "tip_6", icon = "file://{images}/custom_game/tips/tip_6.png" },
	{ id = "tip_7", name_ru = "Кот", rarity = "rare", premium = true, image = "tip_7", icon = "file://{images}/custom_game/tips/tip_7.png" },
	{ id = "tip_8", name_ru = "Пепе-клоун", rarity = "rare", premium = true, image = "tip_8", icon = "file://{images}/custom_game/tips/tip_8.png" },
	{ id = "tip_9", name_ru = "Фейспалм", rarity = "rare", premium = true, image = "tip_9", icon = "file://{images}/custom_game/tips/tip_9.png" },
	{ id = "tip_10", name_ru = "KEKW", rarity = "mythical", premium = true, image = "tip_10", icon = "file://{images}/custom_game/tips/tip_10.png" },
	{ id = "tip_11", name_ru = "Гигачад", rarity = "mythical", premium = true, image = "tip_11", icon = "file://{images}/custom_game/tips/tip_11.png" },
	{ id = "tip_12", name_ru = "Грустный кот", rarity = "mythical", premium = true, image = "tip_12", icon = "file://{images}/custom_game/tips/tip_12.png" },
	{ id = "tip_13", name_ru = "Пепе смотрит", rarity = "mythical", premium = true, image = "tip_13", icon = "file://{images}/custom_game/tips/tip_13.png" },
	{ id = "tip_14", name_ru = "xdd", rarity = "mythical", premium = true, image = "tip_14", icon = "file://{images}/custom_game/tips/tip_14.png" },
	{ id = "tip_15", name_ru = "WHAT", rarity = "mythical", premium = true, image = "tip_15", icon = "file://{images}/custom_game/tips/tip_15.png" },
	{ id = "tip_16", name_ru = "Сигма", rarity = "mythical", premium = true, image = "tip_16", icon = "file://{images}/custom_game/tips/tip_16.png" },
	{ id = "tip_17", name_ru = "Джокер", rarity = "mythical", premium = true, image = "tip_17", icon = "file://{images}/custom_game/tips/tip_17.png" },
	{ id = "tip_18", name_ru = "oh", rarity = "mythical", premium = true, image = "tip_18", icon = "file://{images}/custom_game/tips/tip_18.png" },
	{ id = "tip_19", name_ru = "окак", rarity = "mythical", premium = true, image = "tip_19", icon = "file://{images}/custom_game/tips/tip_19.png" },
	{ id = "tip_20", name_ru = "Череп", rarity = "mythical", premium = true, image = "tip_20", icon = "file://{images}/custom_game/tips/tip_20.png" },
	{ id = "tip_21", name_ru = "Сова", rarity = "mythical", premium = true, image = "tip_21", icon = "file://{images}/custom_game/tips/tip_21.png" },
	{ id = "tip_22", name_ru = "Кортизол", rarity = "mythical", premium = true, image = "tip_22", icon = "file://{images}/custom_game/tips/tip_22.png" },
	{ id = "tip_23", name_ru = "67", rarity = "mythical", premium = true, image = "tip_23", icon = "file://{images}/custom_game/tips/tip_23.png" },
	{ id = "tip_24", name_ru = "MOGGED", rarity = "mythical", premium = true, image = "tip_24", icon = "file://{images}/custom_game/tips/tip_24.png" },
}

-- ------------------------------------------------------------------ спреи

SOCIAL_CATALOG.spray = {
	{ id = "spray_lina_angry",  name_ru = "Злость",     rarity = "common", premium = true, particle = "particles/sprays/lina_angry_spray.vpcf" },
	{ id = "spray_lion_xd",     name_ru = "XD",         rarity = "common", premium = true, particle = "particles/sprays/lion_xd_spray.vpcf" },
	{ id = "spray_mirana_shh",  name_ru = "Тсс",        rarity = "common", premium = true, particle = "particles/sprays/mirana_shhh_spray.vpcf" },
	{ id = "spray_monkey_zen",  name_ru = "Дзен",       rarity = "rare",   premium = true, particle = "particles/sprays/monkey_zen_spray.vpcf" },
	{ id = "spray_sf_shrug",    name_ru = "Не знаю",    rarity = "rare",   premium = true, particle = "particles/sprays/sf_shrug_spray.vpcf" },
	{ id = "spray_pudge",       name_ru = "Точно!",     rarity = "rare",   premium = true, particle = "particles/sprays/pudge_just_right_spray.vpcf" },
	{ id = "spray_prophet",     name_ru = "Нервничаю",  rarity = "mythical", premium = true, particle = "particles/sprays/prophet_nervous_spray.vpcf" },
	{ id = "spray_es_question", name_ru = "Вопрос",     rarity = "mythical", premium = true, particle = "particles/sprays/es_question_spray.vpcf" },
}

-- ------------------------------------------------------------------ хай-файвы

SOCIAL_CATALOG.high_five = {
	{
		id = "hf_diretide", name_ru = "Diretide", rarity = "common", premium = true,
		overhead = "particles/econ/events/diretide_2020/high_five/high_five_lvl1_overhead.vpcf",
		travel   = "particles/econ/events/diretide_2020/high_five/high_five_lvl1_travel.vpcf",
		impact   = "particles/econ/events/diretide_2020/high_five/high_five_impact.vpcf",
	},
	{
		id = "hf_crownfall", name_ru = "Crownfall", rarity = "rare", premium = true,
		overhead = "particles/econ/events/crownfall/high_five_crownfall_overhead.vpcf",
		travel   = "particles/econ/events/crownfall/high_five_crownfall_travel.vpcf",
		impact   = "particles/econ/events/crownfall/high_five_crownfall_impact.vpcf",
	},
	{
		id = "hf_carnival", name_ru = "Карнавал", rarity = "mythical", premium = true,
		overhead = "particles/econ/events/dark_carnival/high_five/high_five_dark_carnival_overhead.vpcf",
		travel   = "particles/econ/events/dark_carnival/high_five/high_five_dark_carnival_travel.vpcf",
		impact   = "particles/econ/events/dark_carnival/high_five/high_five_dark_carnival_impact.vpcf",
	},
}

-- ------------------------------------------------------------------ контент aaf и 1x6
-- Генерированный каталог дописывает и COSMETICS_CATALOG (ауры, петы, эффекты), и SOCIAL_CATALOG.
-- core.lua грузится раньше social.lua, поэтому COSMETICS_CATALOG тут уже есть.
if COSMETICS_CATALOG ~= nil then
	local okExtra, errExtra = pcall(require, "lib/cosmetics/catalog_extra")

	if not okExtra then print("[Cosmetics] catalog_extra: " .. tostring(errExtra)) end
end

return SOCIAL_CATALOG
