item_explosive_mantle_of_intelligence = class({})
LinkLuaModifier("modifier_explosive_mantle_of_intelligence", 'items/item_explosive_mantle_of_intelligence', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_explosive_mantle_of_intelligence_active_channel", 'items/item_explosive_mantle_of_intelligence', LUA_MODIFIER_MOTION_NONE)

function item_explosive_mantle_of_intelligence:GetIntrinsicModifierName()
    return "modifier_explosive_mantle_of_intelligence"
end

function item_explosive_mantle_of_intelligence:OnSpellStart()
	local pre_explode_duration = self:GetSpecialValueFor("pre_explode_duration")

	self:GetCaster():AddNewModifier(caster, self, "modifier_explosive_mantle_of_intelligence_active_channel", { duration = pre_explode_duration })
end

modifier_explosive_mantle_of_intelligence = class({
    IsHidden = function() return true end,
    IsPurgable = function() return false end,
    DestroyOnExpire = function() return false end,
    GetAttributes = function(self) return MODIFIER_ATTRIBUTE_PERMANENT end,

    DeclareFunctions = function(self)
        local funcs = {
            MODIFIER_PROPERTY_STATS_INTELLECT_BONUS
        }
        return funcs
    end,

    GetModifierBonusStats_Intellect = function(self) return self:GetAbility():GetSpecialValueFor("bonus_int") end
})

modifier_explosive_mantle_of_intelligence_active_channel = class({
	IsBuff = function (self) return true end,
	IsPurgable = function (self) return false end,

	CheckState = function (self)
        return {
            [MODIFIER_STATE_DISARMED] = true,
            [MODIFIER_STATE_SILENCED] = true,
            [MODIFIER_STATE_STUNNED] = true,
        }
    end,
    OnCreated = function(self)
		self:StartIntervalThink(0)
	end
})

function modifier_explosive_mantle_of_intelligence_active_channel:OnIntervalThink()
    local radius = self:GetAbility():GetSpecialValueFor("radius")
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

        local damage_per_tick = caster:GetMaxHealth() / 100 * self:GetAbility():GetSpecialValueFor("burn_damage_per_hp")
	    local enemies = FindUnitsInRadius(caster:GetTeamNumber(), caster:GetAbsOrigin(), nil, radius, DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC + DOTA_TEAM_NEUTRALS, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
	    for _, enemy in pairs(enemies) do
            ApplyDamage({
                victim = enemy,
                attacker = caster,
                damage_type = DAMAGE_TYPE_MAGICAL ,
                damage_flags = DOTA_DAMAGE_FLAG_NONE, --Optional.
                ability = self:GetAbility(), --Optional.
                damage = damage_per_tick
            })
        end
        ApplyDamage({
            victim = caster,
            attacker = caster,
            damage_type = DAMAGE_TYPE_MAGICAL ,
            damage_flags = DOTA_DAMAGE_FLAG_NONE, --Optional.
            ability = self:GetAbility(), --Optional.
            damage = damage_per_tick
        })
    end

    print (damage_per_tick)
    self:StartIntervalThink(1)
end
