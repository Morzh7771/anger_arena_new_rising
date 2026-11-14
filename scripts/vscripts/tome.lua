local Constants = require('consts') -- XP TABLE

-- Книги съедаются всем стаком за одно нажатие: берём число зарядов, оставляем
-- один - его тратит SpendCharge из KV, и предмет исчезает
local function TakeWholeStack(ability)
	if not ability or ability:IsNull() then return 1 end
	local n = ability:GetCurrentCharges()
	if not n or n < 1 then return 1 end
	if n > 1 then ability:SetCurrentCharges(1) end
	return n
end

function UpgradeStats(keys)
	local caster = keys.caster
	local cost = keys.ability:GetCost() 
	local str = keys.Str
	local agi = keys.Agi
	local int = keys.Int

	if not caster or not caster:IsRealHero() then return end
	if caster:HasModifier("modifier_arc_warden_tempest_double") then return end
	local n = TakeWholeStack(keys.ability)
	if str then str = str * n end
	if agi then agi = agi * n end
	if int then int = int * n end
	if str then 
		caster:FindModifierByName('bonus_str_tome'):SetStackCount(caster:FindModifierByName('bonus_str_tome'):GetStackCount() + str/2)
		caster:ModifyStrength(str/2)
	end
	if agi then
		caster:FindModifierByName('bonus_agi_tome'):SetStackCount(caster:FindModifierByName('bonus_agi_tome'):GetStackCount() + agi/2)
		caster:ModifyAgility(agi/2)
	end
	if int then
		caster:FindModifierByName('bonus_int_tome'):SetStackCount(caster:FindModifierByName('bonus_int_tome'):GetStackCount() + int/2)
		caster:ModifyIntellect(int/2)
	end

	-- телеметрия: событие "tome" и накопленное в heartbeat (lib/match_telemetry.lua)
	if MatchTelemetry and MatchTelemetry.OnTome then
		local ok, err = pcall(MatchTelemetry.OnTome, caster, keys.ability:GetAbilityName(), { str = str, agi = agi, int = int })
		if not ok then print("[tome] telemetry: " .. tostring(err)) end
	end
end


function tome_levelup(keys)
	local caster = keys.caster
	if not caster or not caster:IsRealHero() then return end
	if caster:HasModifier("modifier_arc_warden_tempest_double") then return end
	local n = TakeWholeStack(keys.ability)

	for _ = 1, n do
		local level = caster:GetLevel()
		local need_exp = Constants.XP_PER_LEVEL_TABLE[level+1]
		local old_exp = Constants.XP_PER_LEVEL_TABLE[level]
		if not need_exp then need_exp = 0 end
		if not old_exp then old_exp = 0 end

		caster:AddExperience(need_exp - old_exp, 0, true, true)

		if EndGameStats then EndGameStats:OnLevelTome(caster) end
	end
end

function MedicalTractat(keys)
	local caster = keys.caster
	if not caster then return end
	
	if not(caster.medical_tractates) then
		caster.medical_tractates = 0
	end
	local cost = keys.ability:GetCost() 

	local n = TakeWholeStack(keys.ability)
	caster.medical_tractates = caster.medical_tractates + n

	if MatchTelemetry and MatchTelemetry.OnTome then
		local ok, err = pcall(MatchTelemetry.OnTome, caster, keys.ability:GetAbilityName(), { tractate = n })
		if not ok then print("[tome] telemetry: " .. tostring(err)) end
	end
	
	caster:RemoveModifierByName("modifier_medical_tractate") 
	while (caster:HasModifier("modifier_medical_tractate")) do
		caster:RemoveModifierByName("modifier_medical_tractate") 
	end
	caster:AddNewModifier(caster, nil, "modifier_medical_tractate", null)

end
function MedicalTractat2(keys)
	local caster = keys.caster
	if not caster then return end
	
	if not(caster.medical_tractates2) then
		caster.medical_tractates2 = 0
	end
	local cost = keys.ability:GetCost() 

	caster.medical_tractates2 = caster.medical_tractates2 + TakeWholeStack(keys.ability)
	
	caster:RemoveModifierByName("modifier_medical_tractate_2") 
	while (caster:HasModifier("modifier_medical_tractate_2")) do
		caster:RemoveModifierByName("modifier_medical_tractate_2") 
	end
	caster:AddNewModifier(caster, nil, "modifier_medical_tractate_2", null)

end