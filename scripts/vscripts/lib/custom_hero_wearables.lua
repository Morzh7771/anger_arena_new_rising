-- Предметы (сеты) на своих героях, у которых модель - ванильный герой доты.
--
-- У своего героя (BaseClass npc_dota_hero) движок не надевает косметику, ванильная модель
-- без предметов голая. Поэтому на спавне героя и его иллюзий вешаем модели сета через
-- prop_dynamic + FollowEntity (кости совпадают, анимации идут за героем).
-- Пока герой невидим - предметы прячем, иначе на месте невидимки висит броня.
--
-- Модель самого героя - в hero_data.txt ("Model"), сеты - здесь.

if not IsServer() then return end

CustomHeroWearables = CustomHeroWearables or {}

local W = CustomHeroWearables

W.SETS = {
	-- Monkey King, сет Sins of the Simian Sovereign
	npc_dota_hero_forgotten_hero = {
		"models/items/monkey_king/accursed_king_staff/accursed_king_staff.vmdl",
		"models/items/monkey_king/accursed_king_armor/accursed_king_armor.vmdl",
		"models/items/monkey_king/accursed_king_inverted_crown/accursed_king_inverted_crown.vmdl",
		"models/items/monkey_king/accursed_king_shoulder/accursed_king_shoulder.vmdl",
	},
	-- Sniper, сет The Silver Fox
	npc_dota_hero_gun_joe = {
		"models/items/sniper/the_silverfox_hunter_weapon/the_silverfox_hunter_weapon.vmdl",
		"models/items/sniper/the_silverfox_hunter_arms/the_silverfox_hunter_arms.vmdl",
		"models/items/sniper/the_silverfox_hunter_back/the_silverfox_hunter_back.vmdl",
		"models/items/sniper/the_silverfox_hunter_head/the_silverfox_hunter_head.vmdl",
		"models/items/sniper/the_silverfox_hunter_shoulder/the_silverfox_hunter_shoulder.vmdl",
	},
	-- Omniknight, сет Blinding Bastion
	npc_dota_hero_hola = {
		"models/items/omniknight/the_fist_of_frenzied_sun_flail/the_fist_of_frenzied_sun_flail.vmdl",
		"models/items/omniknight/the_fist_of_frenzied_sun_arms/the_fist_of_frenzied_sun_arms.vmdl",
		"models/items/omniknight/the_fist_of_frenzied_sun_alternate_back/the_fist_of_frenzied_sun_alternate_back.vmdl",
		"models/heroes/omniknight/head.vmdl",
		"models/items/omniknight/the_fist_of_frenzied_sun_head/the_fist_of_frenzied_sun_head.vmdl",
		"models/items/omniknight/the_fist_of_frenzied_sun_shoulders/the_fist_of_frenzied_sun_shoulders.vmdl",
	},
	-- Necrophos, сет Rot-Iron Ripper
	npc_dota_hero_joe_black = {
		"models/items/necrolyte/necro_plague_doctor/necro_plague_doctor_weapon.vmdl",
		"models/items/necrolyte/necro_plague_doctor/necro_plague_doctor_beard.vmdl",
		"models/items/necrolyte/necro_plague_doctor/necro_plague_doctor_head.vmdl",
		"models/items/necrolyte/necro_plague_doctor/necro_plague_doctor_legs.vmdl",
		"models/items/necrolyte/necro_plague_doctor/necro_plague_doctor_robe.vmdl",
	},
	-- Terrorblade, сет Rictus Ripper
	npc_dota_hero_reaver_lord = {
		"models/items/terrorblade/dreadhunt_weapon/dreadhunt_weapon.vmdl",
		"models/items/terrorblade/dreadhunt_armor/dreadhunt_armor.vmdl",
		"models/items/terrorblade/dreadhunt_back/dreadhunt_back.vmdl",
		"models/items/terrorblade/dreadhunt_head/dreadhunt_head.vmdl",
	},
	-- Bristleback, сет Heavy Barbed Armor
	npc_dota_hero_spike = {
		"models/items/bristleback/heavy_barbed_morning_star/heavy_barbed_morning_star.vmdl",
		"models/items/bristleback/heavy_barbed_arms/heavy_barbed_arms.vmdl",
		"models/items/bristleback/heavy_barbed_back/heavy_barbed_back.vmdl",
		"models/items/bristleback/heavy_barbed_head/heavy_barbed_head.vmdl",
		"models/items/bristleback/heavy_barbed_neck/heavy_barbed_neck.vmdl",
	},
	-- Visage, сет Grimfeather the Grotesque
	npc_dota_hero_charon = {
		"models/items/visage/visage_vulture_wraith_armor/visage_vulture_wraith_armor.vmdl",
		"models/items/visage/visage_vulture_wraith_head/visage_vulture_wraith_head.vmdl",
	},
	-- Anti-Mage, сет Shadows of the Forgotten Plane
	npc_dota_hero_shadowsong = {
		"models/items/antimage/am_shinobi_armor/am_shinobi_armor.vmdl",
		"models/items/antimage/am_shinobi_arms/am_shinobi_arms.vmdl",
		"models/items/antimage/am_shinobi_belt/am_shinobi_belt.vmdl",
		"models/items/antimage/am_shinobi_head/am_shinobi_head.vmdl",
		"models/items/antimage/am_shinobi_off_hand/am_shinobi_off_hand.vmdl",
		"models/items/antimage/am_shinobi_shoulder/am_shinobi_shoulder.vmdl",
		"models/items/antimage/am_shinobi_weapon/am_shinobi_weapon.vmdl",
	},
	-- Ember Spirit, сет Champion of the Phoenix Clan
	npc_dota_hero_fireblade = {
		"models/items/ember_spirit/dplus_firebirds_awakening_arms/dplus_firebirds_awakening_arms.vmdl",
		"models/items/ember_spirit/dplus_firebirds_awakening_belt/dplus_firebirds_awakening_belt.vmdl",
		"models/items/ember_spirit/dplus_firebirds_awakening_head/dplus_firebirds_awakening_head.vmdl",
		"models/items/ember_spirit/dplus_firebirds_awakening_offhand/dplus_firebirds_awakening_offhand.vmdl",
		"models/items/ember_spirit/dplus_firebirds_awakening_shoulder/dplus_firebirds_awakening_shoulder.vmdl",
		"models/items/ember_spirit/dplus_firebirds_awakening_weapon/dplus_firebirds_awakening_weapon.vmdl",
	},
	-- Mirana, сет Spirit of the Sacred Grove
	npc_dota_hero_huntress = {
		"models/items/mirana/mirana_spirit_of_the_sacred_grove_arms/mirana_spirit_of_the_sacred_grove_arms.vmdl",
		"models/items/mirana/mirana_spirit_of_the_sacred_grove_back/mirana_spirit_of_the_sacred_grove_back.vmdl",
		"models/items/mirana/mirana_spirit_of_the_sacred_grove_head/mirana_spirit_of_the_sacred_grove_head.vmdl",
		"models/items/mirana/mirana_spirit_of_the_sacred_grove_misc/mirana_spirit_of_the_sacred_grove_misc.vmdl",
		"models/items/mirana/mirana_spirit_of_the_sacred_grove_mount/mirana_spirit_of_the_sacred_grove_mount.vmdl",
		"models/items/mirana/mirana_spirit_of_the_sacred_grove_shoulder/mirana_spirit_of_the_sacred_grove_shoulder.vmdl",
		"models/items/mirana/mirana_spirit_of_the_sacred_grove_weapon/mirana_spirit_of_the_sacred_grove_weapon.vmdl",
	},
	-- Doom, сет Dawn of a Darkness Foretold
	npc_dota_hero_satan = {
		"models/items/doom/doom_cthulhu_arms/doom_cthulhu_arms.vmdl",
		"models/items/doom/doom_cthulhu_back/doom_cthulhu_back.vmdl",
		"models/items/doom/doom_cthulhu_belt/doom_cthulhu_belt.vmdl",
		"models/items/doom/doom_cthulhu_head/doom_cthulhu_head.vmdl",
		"models/items/doom/doom_cthulhu_shoulder/doom_cthulhu_shoulder.vmdl",
		"models/items/doom/doom_cthulhu_tail/doom_cthulhu_tail.vmdl",
		"models/items/doom/doom_cthulhu_weapon/doom_cthulhu_weapon.vmdl",
	},
}

local THINK = 0.1

-- Прекеш моделей сета: зовётся из Precache способностей героя нельзя (рекурсия),
-- поэтому грузим асинхронно при первом появлении героя - до этого модели уже в
-- прекеше игры через addon_game_mode (см. W.Precache).
function W.Precache(context)
	for _, models in pairs(W.SETS) do
		for _, m in ipairs(models) do
			PrecacheResource("model", m, context)
		end
	end
end

function W:Attach(unit)
	local models = self.SETS[unit:GetUnitName()]
	if not models or unit.aa_wearables then return end

	unit.aa_wearables = {}

	for _, m in ipairs(models) do
		local prop = SpawnEntityFromTableSynchronous("prop_dynamic", { model = m })
		if prop then
			prop:FollowEntity(unit, true)
			table.insert(unit.aa_wearables, prop)
		end
	end

	local hidden = false

	Timers:CreateTimer(THINK, function()
		if unit:IsNull() then
			for _, p in ipairs(unit.aa_wearables or {}) do
				if not p:IsNull() then UTIL_Remove(p) end
			end
			return nil
		end

		local hide = unit:IsInvisible() or unit:HasModifier("modifier_forgotten_hero_breach")

		if hide ~= hidden then
			hidden = hide
			for _, p in ipairs(unit.aa_wearables) do
				if not p:IsNull() then
					if hide then p:AddEffects(EF_NODRAW) else p:RemoveEffects(EF_NODRAW) end
				end
			end
		end

		return THINK
	end)
end

ListenToGameEvent("npc_spawned", function(event)
	local ok, err = pcall(function()
		local unit = event.entindex and EntIndexToHScript(event.entindex)
		if not unit or not unit.GetUnitName or not W.SETS[unit:GetUnitName()] then return end
		if not unit:IsHero() then return end

		-- модель и иллюзии готовы на следующем тике
		Timers:CreateTimer(FrameTime(), function()
			if not unit:IsNull() then W:Attach(unit) end
		end)
	end)

	if not ok then print("[CustomHeroWearables] npc_spawned: " .. tostring(err)) end
end, nil)
