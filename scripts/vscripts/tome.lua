local Constants = require('consts') -- XP TABLE

function UpgradeStats(keys)
	local caster = keys.caster
	local cost = keys.ability:GetCost() 
	local str = keys.Str
	local agi = keys.Agi
	local int = keys.Int

	if not caster or not caster:IsRealHero() then return end
	if caster:HasModifier("modifier_arc_warden_tempest_double") then return end
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
end


function tome_levelup(keys)
	local caster = keys.caster
	if not caster or not caster:IsRealHero() then return end
	if caster:HasModifier("modifier_arc_warden_tempest_double") then return end
	local level = caster:GetLevel()
	local need_exp = Constants.XP_PER_LEVEL_TABLE[level+1]
	local old_exp = Constants.XP_PER_LEVEL_TABLE[level]
	if not need_exp then need_exp = 0 end
	if not old_exp then old_exp = 0 end
	local cost = keys.ability:GetCost() 

	caster:AddExperience(need_exp - old_exp, 0, true, true)
end

function MedicalTractat(keys)
	local caster = keys.caster
	if not caster then return end
	
	if not(caster.medical_tractates) then
		caster.medical_tractates = 0
	end
	local cost = keys.ability:GetCost() 

	caster.medical_tractates = caster.medical_tractates + 1
	
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

	caster.medical_tractates2 = caster.medical_tractates2 + 1
	
	caster:RemoveModifierByName("modifier_medical_tractate_2") 
	while (caster:HasModifier("modifier_medical_tractate_2")) do
		caster:RemoveModifierByName("modifier_medical_tractate_2") 
	end
	caster:AddNewModifier(caster, nil, "modifier_medical_tractate_2", null)

end