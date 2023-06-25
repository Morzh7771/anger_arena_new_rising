PercentDamage = PercentDamage or class({})

function PercentDamage:_init()
	_G.skill_callback = {}
	PercentDamage:ListenAbilityCallback("item_radiance", 						Radiance )
	PercentDamage:ListenAbilityCallback("item_radiance_2", 						Radiance )
	PercentDamage:ListenAbilityCallback("item_radiance_3", 						Radiance )
	local MagicalDamageFromStr = {
		"ogre_magi_fireblast", "ogre_magi_unrefined_fireblast", "ogre_magi_ignite", "omniknight_purification", "pudge_meat_hook", "pudge_rot", "sandking_epicenter", "sandking_sand_storm",
		"rattletrap_battery_assault", "rattletrap_rocket_flare", "rattletrap_hookshot", "bristleback_quill_spray"
	}
	local MagicalDamageFromAgi = {
		"luna_lucent_beam"
	}
	local MagicalDamageFromInt = {
		"lich_chain_frost", "lina_dragon_slave", "lina_light_strike_array", "lina_laguna_blade", "lion_finger_of_death", "lion_impale", "necrolyte_death_pulse", "nyx_assassin_impale", "nyx_assassin_vendetta",
		"oracle_fortunes_end", "oracle_purifying_flames", "oracle_rain_of_destiny", "phoenix_icarus_dive", "phoenix_fire_spirits", "phoenix_sun_ray", "phoenix_supernova", "phoenix_launch_fire_spirit",
		"pugna_nether_blast", "pugna_life_drain", "queenofpain_shadow_strike", "queenofpain_scream_of_pain", "crystal_maiden_crystal_nova", "crystal_maiden_frostbite", "crystal_maiden_freezing_field"
	}
	local MagicalDamageFromAll = {
		"mirana_arrow", "mirana_starfall", "pangolier_swashbuckle", "pangolier_gyroshell", "razor_plasma_field", "razor_unstable_current", "doom_bringer_scorched_earth", "dragon_knight_fireball",
		"bane_brain_sap", "batrider_flamebreak", "batrider_firefly"
	}

	for _, skillname in pairs(MagicalDamageFromStr) do 
		PercentDamage:ListenAbilityCallback(skillname, DamageFromStr)
	end 
	
	for _, skillname in pairs(MagicalDamageFromAgi) do 
		PercentDamage:ListenAbilityCallback(skillname, DamageFromAgi)
	end 

	for _, skillname in pairs(MagicalDamageFromInt) do 
		PercentDamage:ListenAbilityCallback(skillname, DamageFromInt)
	end 

	for _, skillname in pairs(MagicalDamageFromAll) do 
		PercentDamage:ListenAbilityCallback(skillname, DamageFromAll)
	end 
end	
function DamageFromAll(keys)
	local ability 			= keys.ability
	local caster 			= keys.caster
	local target 			= keys.target
	local damage 			= keys.damage

	if not ability then return end
	
	local percent_damage = ability:GetSpecialValueFor("damage_pct") / 100
	
	return (percent_damage * caster:GetAgility()) + (percent_damage * caster:GetStrength()) + (percent_damage * caster:GetIntellect())
end
function DamageFromAgi(keys)
	local ability 			= keys.ability
	local caster 			= keys.caster
	local target 			= keys.target
	local damage 			= keys.damage

	if not ability then return end
	
	local percent_damage = ability:GetSpecialValueFor("damage_pct") / 100
	
	return percent_damage * caster:GetAgility()
end 

function DamageFromStr(keys)
	local ability 			= keys.ability
	local caster 			= keys.caster
	local target 			= keys.target
	local damage 			= keys.damage

	if not ability then return end
	
	local percent_damage = ability:GetSpecialValueFor("damage_pct") / 100
	
	return percent_damage * caster:GetStrength()
end 

function DamageFromInt(keys)
	local ability 			= keys.ability
	local caster 			= keys.caster
	local target 			= keys.target
	local damage 			= keys.damage

	if not ability then return end
	
	local percent_damage = ability:GetSpecialValueFor("damage_pct") / 100
	
	return percent_damage * caster:GetIntellect()
end 

function Radiance( keys )
	local ability 			= keys.ability
	local caster 			= keys.caster
	local target 			= keys.target
	local damage 			= keys.damage

	if not ability then 
		print("null ability for radiance ")
		return 
	end
	
	local pct 				= ability:GetSpecialValueFor("aura_damage_stats")

	print("radiance damage 1")

	if not ability or not caster or not target or not damage or not pct then return end

	if not caster:IsRealHero() and not caster:IsIllusion() then
		caster = caster:GetPlayerOwner()
		if not IsValidEntity(caster) then return end
		caster = caster:GetAssignedHero() 
	end

	print("radiance damage 2")

	Util:DealDamageFromStats(target, caster, DAMAGE_TYPE_MAGICAL, pct, pct, pct, false)
end

function PercentDamage:ListenAbilityCallback(ability_name, func) -- return callback id
	if type(ability_name) ~= "string" or type(func) ~= "function" then 
		print("Failure to attach function! skill name or function have wrong type.")
		print("Ability Name = ", ability_name)
		return
	end
	_G.skill_callback[ability_name] = _G.skill_callback[ability_name] or {}

	table.insert(_G.skill_callback[ability_name], func)

	return #_G.skill_callback[ability_name];
end

PercentDamage:_init();
