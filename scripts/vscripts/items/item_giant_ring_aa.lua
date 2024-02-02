item_giant_ring_aa = class({})

LinkLuaModifier( "modifier_giant_ring_aa", "items/item_giant_ring_aa", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_giant_ring_aa_active", "items/item_giant_ring_aa", LUA_MODIFIER_MOTION_NONE )
function item_giant_ring_aa:GetIntrinsicModifierName()
    return "modifier_giant_ring_aa"
end
function item_giant_ring_aa:OnSpellStart()
    local caster = self:GetCaster()
    caster:AddNewModifier( caster, self, "modifier_giant_ring_aa_active", {duration = self:GetSpecialValueFor("duration")} )
end

modifier_giant_ring_aa = class({ 
	IsBuff = function(self)return true end,
	IsDebuff = function(self) return false end,
	IsHidden = function(self) return true end,
	GetAttributes = function(self) return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_MULTIPLE end,
	DeclareFunctions = function(self) 
		return {
			MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
			MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
			MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
			MODIFIER_PROPERTY_MOVESPEED_BONUS_UNIQUE,
			MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
		}
	end,
	GetModifierBonusStats_Strength = function(self) return self:GetAbility():GetSpecialValueFor('bonus_all_stats') end,
	GetModifierBonusStats_Agility = function(self) return self:GetAbility():GetSpecialValueFor('bonus_all_stats') end,
	GetModifierBonusStats_Intellect = function(self) return self:GetAbility():GetSpecialValueFor('bonus_all_stats') end,
	GetModifierMoveSpeedBonus_Special_Boots = function(self) return self:GetAbility():GetSpecialValueFor('movement_speed') end,
	GetModifierAttackSpeedBonus_Constant = function(self) return self:GetAbility():GetSpecialValueFor('attack_speed') end,
})

modifier_giant_ring_aa_active = class({
	IsBuff = function(self) return true end,
	IsDebuff = function(self) return false end,
	IsHidden = function(self) return false end,
	GetTexture = function(self) return "../items/giant_ring_aa" end,
	OnCreated = function(self)
		self.bonus_stats = self:GetAbility():GetSpecialValueFor("bonus_all_stats_pct")
		self.interval = 0.5
		self:StartIntervalThink(self.interval) 
		self.bonus_str = self:GetParent():GetStrength() * self:GetAbility():GetSpecialValueFor("bonus_all_stats_pct")/100
		self.bonus_agi = self:GetParent():GetAgility() * self:GetAbility():GetSpecialValueFor("bonus_all_stats_pct")/100
		self.bonus_int = self:GetParent():GetIntellect() * self:GetAbility():GetSpecialValueFor("bonus_all_stats_pct")/100
	end,
	DeclareFunctions = function(self) 
		return {
			MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
			MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
			MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
			MODIFIER_PROPERTY_MODEL_SCALE,
		}
	end,
	GetModifierBonusStats_Strength = function(self) return self.bonus_str end,
	GetModifierBonusStats_Agility = function(self) return self.bonus_agi end,
	GetModifierBonusStats_Intellect = function(self) return self.bonus_int end,
	CheckState = function(self) return {[MODIFIER_STATE_NO_UNIT_COLLISION] = true,} end,
	GetModifierModelScale = function(self) return 20 end,
})
function modifier_giant_ring_aa_active:OnIntervalThink()
    local radius = self:GetAbility():GetSpecialValueFor('radius')
    local caster = self:GetParent()
    if IsServer() and caster:IsAlive() then

        local effect_cast = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_sandking/sandking_epicenter.vpcf",
		PATTACH_ABSORIGIN_FOLLOW,
		self:GetParent()
	)
	ParticleManager:SetParticleControl( effect_cast, 1, Vector( radius, radius, radius ) )
	ParticleManager:ReleaseParticleIndex( effect_cast )

	local effect_cast = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_sandking/sandking_epicenter_ring.vpcf",
		PATTACH_ABSORIGIN_FOLLOW,
		self:GetParent()
	)
	ParticleManager:SetParticleControl( effect_cast, 1, Vector( radius, radius, radius ) )
	ParticleManager:ReleaseParticleIndex( effect_cast )

	local enemies = FindUnitsInRadius(caster:GetTeamNumber(), caster:GetAbsOrigin(), nil, radius, DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC + DOTA_TEAM_NEUTRALS, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
	    for _, enemy in pairs(enemies) do
            local damageTable = {
                victim = enemy,
                attacker = caster,
                damage_type = DAMAGE_TYPE_MAGICAL ,
                damage_flags = DOTA_DAMAGE_FLAG_NONE, --Optional.
                ability = self:GetAbility(), --Optional.
            }
            if IsServer() then
                local damage_stat = self:GetAbility():GetSpecialValueFor('stat_damage_per_sec') / 100 * self.interval
                damageTable.damage = (caster:GetStrength() + caster:GetAgility() + caster:GetIntellect()) * damage_stat
                ApplyDamage(damageTable)
            end
            
        end
        
    end
end
