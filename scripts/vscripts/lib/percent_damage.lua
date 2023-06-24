PercentDamage = PercentDamage or class({})

function PercentDamage:_init()
	_G.skill_callback = {}

	local MagicalDamageFromStr = {
	}
	local MagicalDamageFromAgi = {
	}
	local MagicalDamageFromInt = {
		"lich_chain_frost"
	}
	local MagicalDamageFromAll = {
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
