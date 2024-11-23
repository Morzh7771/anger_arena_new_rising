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
	PercentDamage:ListenAbilityCallback("snapfire_scatterblast",						snapfire_scatterblast )
	PercentDamage:ListenAbilityCallback("axe_culling_blade",						axe_culling_blade )
	PercentDamage:ListenAbilityCallback("lion_mana_drain",						lion_mana_drain )
	PercentDamage:ListenAbilityCallback("beastmaster_drums_of_slom",						beastmaster_drums_of_slom )
	PercentDamage:ListenAbilityCallback("ancient_apparition_death_rime",						ancient_apparition_death_rime )
	PercentDamage:ListenAbilityCallback("shadow_shaman_shackles",					shadow_shaman_shackles )


	local MagicalDamageFromStr = {
		"ogre_magi_fireblast",
		"ogre_magi_unrefined_fireblast",
		"ogre_magi_ignite",
		"omniknight_purification",
		"pudge_meat_hook",
		"sandking_epicenter",
		"dark_seer_ion_shell",
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
		"earth_spirit_magnetize",
		"spirit_breaker_greater_bash",
		"spirit_breaker_nether_strike",
		"legion_commander_overwhelming_odds",
		"mars_spear",
		"primal_beast_uproar",
		"kunkka_torrent",
		"satan_breath",
		"primal_beast_rock_throw",
		"primal_beast_pulverize",
		"primal_beast_onslaught",
		"slardar_slithereen_crush",
		"tidehunter_ravage",
		"tidehunter_gush",
	}
	local MagicalDamageFromAgi = {
		"luna_lucent_beam",
		"slark_dark_pact",
		"naga_siren_rip_tide",
		"naga_siren_deluge",
		"gyrocopter_rocket_barrage",
		"sniper_shrapnel",
		"sniper_assassinate",
		"faceless_void_time_lock",
		"phantom_lancer_spirit_lance",
		"ember_spirit_searing_chains",
		"ember_spirit_flame_guard",
		"nevermore_shadowraze1",
		"nevermore_shadowraze2",
		"nevermore_shadowraze3",
		"juggernaut_blade_fury",
		"spectre_desolate",
		"spectre_spectral_dagger",
		"sniper_assassinate",
		"broodmother_silken_bola",
		"nevermore_requiem",
		"bloodseeker_blood_bath",
		"riki_blink_strike",
		"hoodwink_bushwhack",
		"hoodwink_sharpshooter",
		"meepo_poof",
		"meepo_ransack",
	}
	local MagicalDamageFromInt = {
		"lich_chain_frost",
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
		"zuus_heavenly_jump",
		"zuus_lightning_bolt",
		"witch_doctor_voodoo_restoration",
		"storm_spirit_overload",
		"storm_spirit_static_remnant",
		"leshrac_split_earth",
		"leshrac_diabolic_edict",
		"leshrac_lightning_storm",
		"leshrac_pulse_nova",
		"jakiro_liquid_fire",
		"jakiro_dual_breath",
		"jakiro_macropyre",
		"grimstroke_ink_creature",
		"grimstroke_spirit_walk",
		"grimstroke_dark_artistry",
		"disruptor_thunder_strike",
		"disruptor_static_storm",
		"skywrath_mage_concussive_shot",
		"skywrath_mage_mystic_flare",
		"enchantress_enchant",
		"witch_doctor_maledict",
		"lich_frost_nova",
		"silencer_last_word",
		"silencer_curse_of_the_silent",
	}
	--"ancient_apparition_chilling_touch",
	--"ancient_apparition_ice_vortex",
	--"ancient_apparition_cold_feet",

	local MagicalDamageFromAll = {
		"mirana_arrow",
		"mirana_starfall",
		"pangolier_swashbuckle",
		"pangolier_gyroshell",
		"razor_plasma_field",
		"razor_unstable_current",
		"razor_eye_of_the_storm",
		"doom_bringer_scorched_earth",
		"dragon_knight_breathe_fire",
		"dragon_knight_fireball",
		"dragon_knight_dragon_tail",
		"batrider_flamebreak",
		"batrider_firefly",
		"bane_brain_sap",
		"muerta_dead_shot",
		"vengefulspirit_magic_missile",
		"void_spirit_dissimilate",
		"void_spirit_resonant_pulse",
		"snapfire_scatterblast",
		"snapfire_mortimer_kisses",
		"snapfire_firesnap_cookie",
		"windrunner_powershot",
		"bounty_hunter_shuriken_toss",
		"viper_viper_strike",
		"viper_corrosive_skin",
		"viper_nethertoxin",
		"viper_poison_attack",
		"death_prophet_carrion_swarm",
		"death_prophet_exorcism",
		"shredder_flamethrower",
		"shredder_whirling_death",
		"shredder_timber_chain",
		"shredder_chakram",
		"shredder_chakram_2",
		"shredder_twisted_chakram",
		"night_stalker_crippling_fear",
		"night_stalker_void",
		"beastmaster_primal_roar",
		"bane_enfeeble",
		"brewmaster_cinder_brew",
		"brewmaster_thunder_clap",
		"furion_sprout",
		"furion_wrath_of_nature",
		"lina_dragon_slave",
		"lina_light_strike_array",
		"lina_laguna_blade",
		"magnataur_shockwave",
		"abaddon_frostmourne"
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

function shadow_shaman_shackles( keys )
	local ability 			= keys.ability
	local caster 			= keys.caster
	local target 			= keys.target
	local damage 			= keys.damage

	local percent_damage 	= ability:GetSpecialValueFor("damage_pct") / 100

	Util:DealPercentDamageOfMaxHealth(target, caster, DAMAGE_TYPE_MAGICAL, caster:GetIntellect(false) * percent_damage, 0)

	local heal = caster:GetIntellect(false) * percent_damage

	caster:Heal(heal, caster)
end

function LifeDrain( keys )
	local ability 			= keys.ability
	local caster 			= keys.caster
	local target 			= keys.target
	local damage 			= keys.damage
	if not ability then print("Pugna 4 skill nil ability for percent damage"); return end
	
	local percent_damage 	= ability:GetSpecialValueFor("damage_pct") / 100
	
	if target:IsMagicImmune() then return end 
	
	Util:DealPercentDamageOfMaxHealth(target, caster, DAMAGE_TYPE_MAGICAL, caster:GetIntellect(false) * percent_damage, 0)

	local heal = caster:GetIntellect(false) * percent_damage
	
	caster:Heal(heal, caster) 
end
function ancient_apparition_death_rime( keys )
	local ability 			= keys.ability
	local caster 			= keys.caster
	local target 			= keys.target
	local damage 			= keys.damage

	local percent_damage = ability:GetSpecialValueFor("damage_pct") / 100 * target:FindModifierByName("modifier_ancient_apparition_death_rime"):GetStackCount()
	if target:IsMagicImmune() then return end 

	Util:DealPercentDamage(target, caster, DAMAGE_TYPE_MAGICAL, caster:GetIntellect(false) * percent_damage, 0)

	--local modifier_count = target:GetModifierCount()
	--for i = 0, modifier_count - 1 do
        --local modifier_name = target:GetModifierNameByIndex(i)
        --print("Modifier " .. i .. ": " .. modifier_name)
    --end 

  
end
function beastmaster_drums_of_slom( keys )
	local ability 			= keys.ability
	local caster 			= keys.caster
	local target 			= keys.target
	local damage 			= keys.damage
	
	local percent_damage = ability:GetSpecialValueFor("damage_pct") / 100
	
	if target:IsMagicImmune() then return end 

	Util:DealPercentDamage(target, caster, DAMAGE_TYPE_MAGICAL,(caster:GetStrength()+caster:GetAgility()+caster:GetIntellect(false)) * percent_damage, 0)

	local heal = (caster:GetStrength()+caster:GetAgility()+caster:GetIntellect(false)) * percent_damage * (ability:GetSpecialValueFor("heal_pct")/100)

	SendOverheadEventMessage(caster, OVERHEAD_ALERT_HEAL , caster, heal,nil)
	caster:Heal(heal, caster) 
end
function lion_mana_drain( keys )
	local ability 			= keys.ability
	local caster 			= keys.caster
	local target 			= keys.target
	local damage 			= keys.damage

	if target:IsMagicImmune() then return end 
	
	local percent_damage = ability:GetSpecialValueFor("mana_damage_pct")/100
	return (percent_damage * caster:GetMana()/7.5)
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
function axe_culling_blade(keys)
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
	
	return (percent_damage * caster:GetAgility()) + (percent_damage * caster:GetStrength()) + (percent_damage * caster:GetIntellect(false))
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
	
	return percent_damage * caster:GetIntellect(false)
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

	local int = caster:GetIntellect(false) * multipler
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

	--if caster == target then return end

	ApplyDamage({ 	victim = target,
					attacker = caster,
					damage = damage,
					damage_type = ability:GetAbilityDamageType(),
					damage_flags = DOTA_DAMAGE_FLAG_NON_LETHAL,
					ability = keys.inflictor
				})


end
function snapfire_scatterblast(keys)
	local ability 			= keys.ability
	local caster 			= keys.caster
	local target 			= keys.target
	local damage 			= keys.damage

	if not ability then return end
	
	local percent_damage = ability:GetSpecialValueFor("damage_pct_stat") / 100
	
	return (percent_damage * caster:GetAgility()) + (percent_damage * caster:GetStrength()) + (percent_damage * caster:GetIntellect(false))
end
PercentDamage:_init();

