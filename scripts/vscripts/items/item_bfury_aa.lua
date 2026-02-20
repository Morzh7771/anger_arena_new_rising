require("items.funcs.cleave")
DOTA_DAMAGE_FLAG_TRISULA = 524288

local forbidden_modifiers = {
	--"modifier_pangolier_swashbuckle_stunned",
	--"modifier_pangolier_swashbuckle",
	--"modifier_pangolier_swashbuckle_attack",
	--"modifier_monkey_king_boundless_strike_crit",
}

LinkLuaModifier("modifier_item_bfury_aa", "items/item_bfury_aa", LUA_MODIFIER_MOTION_NONE)

item_bfury_aa = class({})
item_bfury_aa_2 = item_bfury_aa

function item_bfury_aa:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_magnataur/magnataur_empower_cleave_effect.vpcf", context)
end

function item_bfury_aa:GetIntrinsicModifierName()
	return "modifier_item_bfury_aa"
end

function item_bfury_aa:OnSpellStart()
local target = self:GetCursorTarget()

--if target.CutDown then
	--target:CutDown(self:GetCaster():GetTeamNumber())
GridNav:DestroyTreesAroundPoint(target:GetAbsOrigin(), 10, true)
--end 

end

modifier_item_bfury_aa	= class({})

function modifier_item_bfury_aa:AllowIllusionDuplicate()	return false end
function modifier_item_bfury_aa:IsPurgable()		return false end
function modifier_item_bfury_aa:RemoveOnDeath()	return false end
function modifier_item_bfury_aa:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT end
function modifier_item_bfury_aa:IsHidden()	return true end

function modifier_item_bfury_aa:OnCreated()
	self.damage_bonus							= self:GetAbility():GetSpecialValueFor("bonus_damage")
	self.hp_regen								= self:GetAbility():GetSpecialValueFor("bonus_health_regen")
	self.mp_regen								= self:GetAbility():GetSpecialValueFor("bonus_mana_regen")
	self.bonus_str 								= self:GetAbility():GetSpecialValueFor("bonus_str")
	self.bonus_agi 								= self:GetAbility():GetSpecialValueFor("bonus_agi")

	self.cleave_damage_creep 					= self:GetAbility():GetSpecialValueFor("cleave_damage_creep")
	self.cleave_damage_hero 					= self:GetAbility():GetSpecialValueFor("cleave_damage_hero")
	self.cleave_range 							= self:GetAbility():GetSpecialValueFor("cleave_range")
	self.cleave_damage_illusion 				= self:GetAbility():GetSpecialValueFor("cleave_damage_illusion")
	self.cleave_illusion_pure 					= self:GetAbility():GetSpecialValueFor("cleave_illusion_pure")

	self.quelling_bonus_const					= self:GetAbility():GetSpecialValueFor("quelling_bonus")
	self.quelling_bonus_ranged_coef				= self:GetAbility():GetSpecialValueFor("quelling_bonus_ranged_coef") / 100
	self.quelling_bonus_pct						= self:GetCaster():GetAverageTrueAttackDamage(self:GetParent()) * self:GetAbility():GetSpecialValueFor("quelling_bonus_pct") / 100
	self.quelling_bonus_summ					= self.quelling_bonus_const + self.quelling_bonus_pct

	if IsServer() then
	end
end
function modifier_item_bfury_aa:OnRefresh(params)
	if IsServer() then
	end
end
function modifier_item_bfury_aa:OnDestroy()
	if IsServer() then
	end
end



function modifier_item_bfury_aa:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
		MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
		MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
		MODIFIER_PROPERTY_PROCATTACK_BONUS_DAMAGE_PHYSICAL,
		MODIFIER_EVENT_ON_ATTACK_LANDED,
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
	}
	return funcs
end

function modifier_item_bfury_aa:GetModifierPreAttack_BonusDamage(keys)
	return self.damage_bonus
end

function modifier_item_bfury_aa:GetModifierProcAttack_BonusDamage_Physical( keys )
	if not IsServer() then return end
	if keys.target and not keys.target:IsHero() and not keys.target:IsOther() and not keys.target:IsBuilding() and keys.target:GetTeamNumber() ~= self:GetParent():GetTeamNumber() then
		
		if self:GetParent():IsRangedAttacker() then 
			return self.quelling_bonus_summ * self.quelling_bonus_ranged_coef
		else 
			return self.quelling_bonus_summ
		end
	end
end
function modifier_item_bfury_aa:GetModifierConstantManaRegen()
	return self.mp_regen
end
function modifier_item_bfury_aa:GetModifierConstantHealthRegen()
	return self.hp_regen
end
function modifier_item_bfury_aa:GetModifierBonusStats_Strength()
	return	self.bonus_str
end
function modifier_item_bfury_aa:GetModifierBonusStats_Agility()
	return	self.bonus_agi
end

function modifier_item_bfury_aa:OnAttackLanded( params )
	if params.attacker ~= self:GetParent() then return end
	if self:GetParent():IsRangedAttacker() then	return end
	if not IsServer() then return end
	if params.damage_flags and Util:testflag(params.damage_flags, DOTA_DAMAGE_FLAG_TRISULA) then return end

	local caster = params.attacker
	local target = params.target
	local radius = self.cleave_range

	if not caster or not target then return end
	if not params.ranged_attack and caster:IsRangedAttacker() then return end
	if caster and caster:IsIllusion() then return end

	if not IsValidEntity(caster) or not IsValidEntity(target) then return end
	if not target:IsCreep() and not target:IsHero() then return end

	for _, modifier_name in pairs(forbidden_modifiers) do
		if caster:HasModifier(modifier_name) then return end
	end

	local team = caster:GetTeamNumber()
	local position = target:GetAbsOrigin()

	local units_in_radius = FindUnitsInRadius(
			team,
			position,
			nil,
			radius,
			DOTA_UNIT_TARGET_TEAM_ENEMY,
			DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_CREEP,
			DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
			0,
			false)

	if not units_in_radius then return end

	CreateParticleForCleave("particles/units/heroes/hero_magnataur/magnataur_empower_cleave_effect.vpcf", radius, target)


	for _,x in pairs(units_in_radius) do
		if x ~= params.target or x:IsIllusion() then
		    local dmg = 0
		    local cleave_physical_pierce = self:GetAbility():GetSpecialValueFor("cleave_physical_pierce")
		    local result_armor = x:GetPhysicalArmorValue(false) / 100 * (100 - cleave_physical_pierce)
		    local dmg_ref = params.original_damage * Util:ArmorDamageReductionByNumber(result_armor)

			if x:IsCreep() then
				dmg = dmg_ref / 100 * self.cleave_damage_creep
			end
			if x:IsIllusion() then
				dmg = dmg_ref / 100 * self.cleave_damage_illusion -- / 100 * self.cleave_illusion_pure

				ApplyDamage({ victim = x,
							  attacker = caster,
							  damage = dmg,
							  damage_type = DAMAGE_TYPE_PHYSICAL,
							  damage_flags = DOTA_DAMAGE_FLAG_IGNORES_PHYSICAL_ARMOR + DOTA_DAMAGE_FLAG_TRISULA,
							  ability = params.ability}) --deal damage

				dmg = dmg_ref / 100 * self.cleave_damage_illusion -- / 100 * (100 - self.cleave_illusion_pure)
			end
			if x:IsHero() then
				dmg = dmg_ref / 100 * self.cleave_damage_hero
			end
			if x:GetUnitName() == "npc_tree_thinker" then
				return
			end
			ApplyDamage({ victim = x,
						  attacker = caster,
						  damage = dmg,
						  damage_type = DAMAGE_TYPE_PHYSICAL,
						  damage_flags = DOTA_DAMAGE_FLAG_IGNORES_PHYSICAL_ARMOR + DOTA_DAMAGE_FLAG_TRISULA,
						  ability = params.ability}) --deal damage
		end
	end
end

--if not IsServer() then return end
--if self:GetParent() ~= params.attacker then return end
--if self:GetParent():IsRangedAttacker() then return end
--if not params.target:IsHero() and not params.target:IsCreep() then return end
--
--local k = self:GetAbility():GetSpecialValueFor("cleave_damage_percent")
--if params.target:IsCreep() then 
--	k = self.cleave_damage_percent_creep + self.splash_bonus_pct
--end
--
--params.target:EmitSound("DOTA_Item.BattleFury")
--
--DoCleaveAttack(self:GetParent(), params.target, self:GetAbility(), params.damage*k/100, self.start_width, self.end_width, self.cleave_distance, "particles/items_fx/battlefury_cleave.vpcf")
