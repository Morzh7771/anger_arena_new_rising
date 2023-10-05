LinkLuaModifier('modifier_drum_of_endurance', 'items/drum_and_base/item_drum_of_endurance', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_drum_of_endurance_aura', 'items/drum_and_base/item_drum_of_endurance', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_drum_of_endurance_active', 'items/drum_and_base/item_drum_of_endurance', LUA_MODIFIER_MOTION_NONE)

item_drum_of_endurance = class({
    GetIntrinsicModifierName = function (self) return 'modifier_drum_of_endurance' end
})

function item_drum_of_endurance:OnSpellStart()
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
		if not ally:HasModifier("modifier_boots_of_bearing_aa_active") and not ally:HasModifier("modifier_boots_of_bearing_aa_2_active")then
		    ally:AddNewModifier(self:GetCaster(), self, "modifier_drum_of_endurance_active", {duration = self:GetSpecialValueFor("active_duration")})
        end
        self:GetCaster():AddNewModifier(self:GetCaster(), self, "modifier_drum_of_endurance_active", {duration = self:GetSpecialValueFor("active_duration")})
       
	end
end



-----------------------------------------------------------------------

modifier_drum_of_endurance = class({
    IsHidden = function (self) return true end,
    IsPurgable = function (self) return true end,
    DeclareFunctions = function (self)
        return {
            MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
            MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
            MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
            MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
        }
    end,
    GetModifierAura = function (self)return "modifier_drum_of_endurance_aura" end,
    IsAura = function (self) return true end,
    GetAuraSearchTeam = function (self) return DOTA_UNIT_TARGET_TEAM_FRIENDLY end,
    GetAuraSearchType = function (self) return  DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_CREEP end,
    GetAuraRadius  = function (self) return self:GetAbility():GetSpecialValueFor("active_radius") end,
    GetModifierBonusStats_Strength = function (self) return self:GetAbility():GetSpecialValueFor("bonus_str") end,
    GetModifierBonusStats_Agility = function (self) return self:GetAbility():GetSpecialValueFor("bonus_agi")end,
    GetModifierBonusStats_Intellect = function (self) return self:GetAbility():GetSpecialValueFor("bonus_int")end,
    GetModifierPhysicalArmorBonus = function (self) return self:GetAbility():GetSpecialValueFor("bonus_armor")end,
})
function modifier_drum_of_endurance:GetAuraEntityReject(target)
	if target:HasModifier("modifier_boots_of_bearing_aa_aura") or target:HasModifier("modifier_boots_of_bearing_aa_2_aura")then
		return true
	end
end


modifier_drum_of_endurance_aura = class({
    IsHidden = function (self) return false end,
    DeclareFunctions = function (self)
        return {
            MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
            MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT
        }
    end,
    GetModifierAttackSpeedBonus_Constant = function (self) return self:GetAbility():GetSpecialValueFor("aura_attack_speed") end,
    GetModifierMoveSpeedBonus_Constant = function (self) return self:GetAbility():GetSpecialValueFor("aura_movement_speed") end,
})


modifier_drum_of_endurance_active = class({
    IsHidden = function (self) return false end,
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
})
function modifier_drum_of_endurance_active:OnCreated()
    self:Particle()
end
function modifier_drum_of_endurance_active:OnRefresh()
    self:Particle()
end

function modifier_drum_of_endurance_active:Particle()
    self.particle_buff = "particles/items_fx/drum_of_endurance_buff.vpcf"
    local particle_buff_fx = ParticleManager:CreateParticle(self.particle_buff, PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
	ParticleManager:SetParticleControl(particle_buff_fx, 0, self:GetParent():GetAbsOrigin())
	ParticleManager:SetParticleControl(particle_buff_fx, 1, Vector(0,0,0))
	self:AddParticle(particle_buff_fx, false, false, -1, false, false)
end
