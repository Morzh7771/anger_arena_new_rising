
LinkLuaModifier('modifier_boots_of_bearing_aa_3', 'items/drum_and_base/item_boots_of_bearing_aa_3', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_boots_of_bearing_aa_3_aura', 'items/drum_and_base/item_boots_of_bearing_aa_3', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_boots_of_bearing_aa_3_active', 'items/drum_and_base/item_boots_of_bearing_aa_3', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_boots_of_bearing_aa_unslowable', 'items/drum_and_base/item_boots_of_bearing_aa', LUA_MODIFIER_MOTION_NONE)

item_boots_of_bearing_aa_3 = class({
    GetIntrinsicModifierName = function (self) return 'modifier_boots_of_bearing_aa_3' end
})
function item_boots_of_bearing_aa_3:OnSpellStart()
    EmitSoundOn("DOTA_Item.DoE.Activate", self:GetCaster())

	-- Find all nearby allies
	local allies = FindUnitsInRadius(self:GetCaster():GetTeamNumber(),
		self:GetCaster():GetAbsOrigin(),
		nil,
		self:GetSpecialValueFor("active_radius"),
		DOTA_UNIT_TARGET_TEAM_FRIENDLY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_INVULNERABLE + DOTA_UNIT_TARGET_FLAG_OUT_OF_WORLD,
		FIND_ANY_ORDER,
		false)
	for _,ally in pairs(allies) do

		if ally:HasModifier("modifier_drum_of_endurance_active") then
			ally:RemoveModifierByName("modifier_drum_of_endurance_active")
		end
        if ally:HasModifier("modifier_boots_of_bearing_aa_active") then
			ally:RemoveModifierByName("modifier_boots_of_bearing_aa_active")
		end
        if not ally:HasModifier("modifier_boots_of_bearing_aa_2_active") then
            ally:AddNewModifier(self:GetCaster(), self, "modifier_boots_of_bearing_aa_2_active", {duration = self:GetSpecialValueFor("active_duration")})
		end
        self:GetCaster():AddNewModifier(self:GetCaster(), self, "modifier_boots_of_bearing_aa_2_active", {duration = self:GetSpecialValueFor("active_duration")})
        ally:AddNewModifier(self:GetCaster(), self, "modifier_boots_of_bearing_aa_unslowable", {duration = self:GetSpecialValueFor("active_non_slow")})
	end
end



-----------------------------------------------------------------------

modifier_boots_of_bearing_aa_3 = class({
    IsHidden = function (self) return true end,
    DeclareFunctions = function (self)
        return {
            MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
            MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
            MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
            MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
            MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
            MODIFIER_PROPERTY_MOVESPEED_BONUS_UNIQUE,
        }
    end,
    GetModifierAura = function (self)return "modifier_boots_of_bearing_aa_3_aura" end,
    IsAura = function (self) return true end,
    GetAuraSearchTeam = function (self) return DOTA_UNIT_TARGET_TEAM_FRIENDLY end,
    GetAuraSearchType = function (self) return  DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_CREEP end,
    GetAuraRadius  = function (self) return  self:GetAbility():GetSpecialValueFor("active_radius") end,
    GetModifierBonusStats_Strength = function (self) return self:GetAbility():GetSpecialValueFor("bonus_str") end,
    GetModifierBonusStats_Agility = function (self) return self:GetAbility():GetSpecialValueFor("bonus_agi")end,
    GetModifierBonusStats_Intellect = function (self) return self:GetAbility():GetSpecialValueFor("bonus_int")end,
    GetModifierPhysicalArmorBonus = function (self) return self:GetAbility():GetSpecialValueFor("bonus_armor")end,

    GetModifierConstantHealthRegen = function (self) return self:GetAbility():GetSpecialValueFor("bonus_health_regen")end,
    GetModifierMoveSpeedBonus_Special_Boots = function (self) return self:GetAbility():GetSpecialValueFor("bonus_movement_speed") end,
})

modifier_boots_of_bearing_aa_3_aura = class({
    IsHidden = function (self) return false end,
    DeclareFunctions = function (self)
        return {
            MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
            MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT
        }
    end,
    GetModifierAttackSpeedBonus_Constant = function (self) return self:GetAbility():GetSpecialValueFor("aura_attack_speed") end,
    GetModifierMoveSpeedBonus_Constant = function (self) return self:GetAbility():GetSpecialValueFor("aura_movement_speed") end,
    GetTexture = function (self) return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "") end
})

modifier_boots_of_bearing_aa_3_active = class({
    IsHidden = function (self) return false end,
    IsPurgable = function (self) return true end,
    DeclareFunctions = function (self)
        return {
            MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
            MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
            MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
        }
    end,

    GetModifierAttackSpeedBonus_Constant = function (self) return self:GetAbility():GetSpecialValueFor("active_bonus_attack_speed") end,
    GetModifierMoveSpeedBonus_Percentage = function (self) return self:GetAbility():GetSpecialValueFor("aura_movement_speed") end,
    GetModifierPreAttack_BonusDamage = function (self) return self:GetAbility():GetSpecialValueFor("active_bonus_damage_from_agi") / 100 * self:GetCaster():GetAgility() end,
    GetTexture = function (self) return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "") end
})
function modifier_boots_of_bearing_aa_3_active:OnCreated()
    self:Particle()
end
function modifier_boots_of_bearing_aa_3_active:OnRefresh()
    self:Particle()
end

function modifier_boots_of_bearing_aa_3_active:Particle()
    self.particle_buff = "particles/items_fx/drum_of_endurance_buff.vpcf"
    local particle_buff_fx = ParticleManager:CreateParticle(self.particle_buff, PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
	ParticleManager:SetParticleControl(particle_buff_fx, 0, self:GetParent():GetAbsOrigin())
	ParticleManager:SetParticleControl(particle_buff_fx, 1, Vector(0,0,0))
	self:AddParticle(particle_buff_fx, false, false, -1, false, false)
end

modifier_boots_of_bearing_aa_3_unslowable = class({
    IsHidden = function (self) return false end,
    IsDebuff = function (self) return false end,
    IsPurgable = function (self) return true end,
    GetPriority = function (self) return MODIFIER_PRIORITY_SUPER_ULTRA + 10000 end,
    CheckState = function (self) return {[MODIFIER_STATE_UNSLOWABLE] = true,} end,
    GetTexture = function (self) return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "") end
})
