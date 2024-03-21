item_explosive_mantle_of_intelligence = class({})
LinkLuaModifier("modifier_explosive_mantle_of_intelligence", 'items/explosive_mantle_of_intelligence/modifier_explosive_mantle_of_intelligence', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_explosive_mantle_of_intelligence_active_channel", 'items/explosive_mantle_of_intelligence/modifier_explosive_mantle_of_intelligence_active_channel', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_explosive_mantle_of_intelligence_active_finish'", 'items/explosive_mantle_of_intelligence/modifier_explosive_mantle_of_intelligence_active_finish', LUA_MODIFIER_MOTION_NONE)

function item_explosive_mantle_of_intelligence:GetIntrinsicModifierName()
    return "modifier_explosive_mantle_of_intelligence"
end

function item_explosive_mantle_of_intelligence:OnSpellStart()
	local pre_explode_duration = self:GetSpecialValueFor("pre_explode_duration")

	self:GetCaster():AddNewModifier(caster, self, "modifier_explosive_mantle_of_intelligence_active_channel", { duration = pre_explode_duration })

end
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
		self:StartIntervalThink(1)
	end
})

function modifier_explosive_mantle_of_intelligence_active_channel:OnIntervalThink()
	print("123")
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

	local enemies = FindUnitsInRadius(caster:GetTeamNumber(), caster:GetAbsOrigin(), nil, radius, DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC + DOTA_TEAM_NEUTRALS, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
	    for _, enemy in pairs(enemies) do
	    	local damage_per_tick = caster:GetMaxHealth() / 100 * self:GetSpecialValueFor("burn_hp_to_damage")
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
end
