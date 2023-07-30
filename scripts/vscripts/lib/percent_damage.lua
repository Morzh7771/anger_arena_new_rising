PercentDamage = PercentDamage or class({})

function PercentDamage:_init()
	_G.skill_callback = {}
	PercentDamage:ListenAbilityCallback("item_radiance", 						Radiance )
	PercentDamage:ListenAbilityCallback("item_radiance_2", 						Radiance )
	PercentDamage:ListenAbilityCallback("item_radiance_3", 						Radiance )
	PercentDamage:ListenAbilityCallback("pudge_rot", 							PudgeRot)
	PercentDamage:ListenAbilityCallback("bane_brain_sap",						BaneBrainSap)
	PercentDamage:ListenAbilityCallback("pugna_life_drain",						LifeDrain )
	PercentDamage:ListenAbilityCallback("axe_counter_helix",						axe_counter_helix )
	
	local MagicalDamageFromStr = {
		"ogre_magi_fireblast",
		"ogre_magi_unrefined_fireblast",
		"ogre_magi_ignite",
		"omniknight_purification",
		"pudge_meat_hook",
		"sandking_epicenter",
		"sandking_sand_storm",
		"rattletrap_battery_assault",
		"rattletrap_rocket_flare",
		"rattletrap_hookshot",
		"bristleback_quill_spray",
		"centaur_hoof_stomp",
		"undying_decay",
		"earthshaker_fissure",
		"earthshaker_aftershock",
		"earthshaker_echo_slam",
		"tiny_avalanche",
		"tiny_toss",
		"treant_overgrowth", 
		"kunkka_ghostship",
		"tusk_ice_shards",
		"tusk_snowball",
		"earth_spirit_boulder_smash",
		"earth_spirit_geomagnetic_grip",
		"earth_spirit_petrify",
		"spirit_breaker_greater_bash",
		"spirit_breaker_nether_strike"
	}
	local MagicalDamageFromAgi = {
		"luna_lucent_beam",
		"slark_dark_pact",
		"naga_siren_rip_tide",
		"gyrocopter_rocket_barrage",
		"sniper_shrapnel",
		"sniper_assassinate",
		"faceless_void_time_lock",
		"phantom_lancer_spirit_lance",
		"ember_spirit_searing_chains",
		"ember_spirit_flame_guard"
	}
	local MagicalDamageFromInt = {
		"lich_chain_frost",
		"lina_dragon_slave",
		"lina_light_strike_array",
		"lina_laguna_blade",
		"lion_finger_of_death",
		"lion_impale",
		"necrolyte_death_pulse",
		"nyx_assassin_impale",
		"nyx_assassin_vendetta",
		"oracle_fortunes_end",
		"oracle_purifying_flames",
		"oracle_rain_of_destiny",
		"phoenix_icarus_dive",
		"phoenix_fire_spirits",
		"phoenix_sun_ray",
		"phoenix_supernova",
		"phoenix_launch_fire_spirit",
		"pugna_nether_blast",
		"queenofpain_shadow_strike",
		"queenofpain_scream_of_pain",
		"queenofpain_sonic_wave",
		"crystal_maiden_crystal_nova",
		"crystal_maiden_frostbite",
		"crystal_maiden_freezing_field",
		"venomancer_venomous_gale",
		"venomancer_poison_sting",
		"venomancer_latent_poison",
		"shadow_demon_demonic_purge",
		"shadow_demon_shadow_poison",
		"keeper_of_the_light_illuminate",
		"keeper_of_the_light_spirit_form_illuminate",
		"puck_illusory_orb",
		"puck_waning_rift",
		"techies_sticky_bomb",
		"invoker_sun_strike",
		"invoker_chaos_meteor",
		"shadow_shaman_ether_shock",
		"shadow_shaman_shackles"
	}
	local MagicalDamageFromAll = {
		"mirana_arrow",
		"mirana_starfall",
		"pangolier_swashbuckle",
		"pangolier_gyroshell",
		"razor_plasma_field",
		"razor_unstable_current",
		"razor_eye_of_the_storm",
		"doom_bringer_scorched_earth",
		"dragon_knight_fireball",
		"batrider_flamebreak",
		"batrider_firefly",
		"bane_brain_sap",
		"dark_seer_ion_shell",
		"muerta_dead_shot",
		"vengefulspirit_magic_missile",
		"void_spirit_dissimilate",
		"void_spirit_resonant_pulse",
		"snapfire_scatterblast",
		"snapfire_mortimer_kisses",
		"snapfire_firesnap_cookie",
		"windrunner_powershot"
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
function LifeDrain( keys )
	local ability 			= keys.ability
	local caster 			= keys.caster
	local target 			= keys.target
	local damage 			= keys.damage
	if not ability then print("Pugna 4 skill nil ability for percent damage"); return end
	
	local percent_damage 	= ability:GetSpecialValueFor("damage_pct") / 100
	
	if target:IsMagicImmune() then return end 
	
	Util:DealPercentDamageOfMaxHealth(target, caster, DAMAGE_TYPE_MAGICAL, caster:GetIntellect() * percent_damage, 0)

	local heal = caster:GetIntellect() * percent_damage
	
	caster:Heal(heal, caster) 
end
function axe_counter_helix(keys)
	local ability 			= keys.ability
	local caster 			= keys.caster
	local target 			= keys.target
	local damage 			= keys.damage

	if not ability then return end
	
	local percent_damage = ability:GetSpecialValueFor("damage_pct")
	print(caster:GetPhysicalArmorValue(false))
	return (percent_damage * caster:GetPhysicalArmorValue(false))
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
	print(percent_damage * caster:GetAgility())
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

function BaneBrainSap( keys )
	local caster 			= keys.caster
	local target 			= keys.target
	local damage 			= keys.damage
	local ability 			= keys.ability
	local multipler 		= (ability:GetSpecialValueFor("damage_pct") or 0) /100

	local int = caster:GetIntellect() * multipler
	caster:Heal(int, ability)
end
function PudgeRot(keys)
	local ability 			= keys.ability
	local caster 			= keys.caster
	local target 			= keys.target
	local damage 			= keys.damage

	if not ability then return end
	
	local percent_damage 	= ability:GetSpecialValueFor("damage_pct") / 100
	
	local damage = percent_damage * caster:GetPrimaryStatValue() 

	if caster == target then return end
	
	ApplyDamage({ 	victim = target, 
					attacker = caster,
					damage = damage, 
					damage_type = ability:GetAbilityDamageType(),
					damage_flags = DOTA_DAMAGE_FLAG_NON_LETHAL 
				})


end
PercentDamage:_init();
