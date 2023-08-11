BaseClass = class ({})
guardian_of_the_ancients_ficle_ground = BaseClass

LinkLuaModifier( "modifier_slow", "heroes/guardian_of_the_ancients/ficle_ground", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "guardian_of_the_ancients_ficle_ground_thinker", "heroes/guardian_of_the_ancients/ficle_ground", LUA_MODIFIER_MOTION_NONE )
function BaseClass:OnSpellStart()
    
    local caster = self:GetCaster()
	local point = self:GetCursorPosition()

	-- create thinker
	CreateModifierThinker(
		caster, -- player source
		self, -- ability source
		"guardian_of_the_ancients_ficle_ground_thinker", -- modifier name
		{}, -- kv
		point,
		caster:GetTeamNumber(),
		false
	)

end
function BaseClass:GetAOERadius()
    return self:GetSpecialValueFor("aoe_range")
end

guardian_of_the_ancients_ficle_ground_thinker = class({})

--------------------------------------------------------------------------------
-- Classifications
function guardian_of_the_ancients_ficle_ground_thinker:IsHidden()
	return true
end

function guardian_of_the_ancients_ficle_ground_thinker:IsPurgable()
	return false
end

--------------------------------------------------------------------------------
-- Initializations
function guardian_of_the_ancients_ficle_ground_thinker:OnCreated( kv )
	self.caster = self:GetCaster()
    self.interval = self:GetAbility():GetSpecialValueFor( "interval" ) 
    self.range = self:GetAbility():GetSpecialValueFor("aoe_range") 
    self.damage = self:GetAbility():GetSpecialValueFor("damage") 
    self.impuls_max = self:GetAbility():GetSpecialValueFor("impuls_max") 
    self.parent = self:GetParent()
    if not IsServer() then return end
    self.impuls_now = 0
    self:StartIntervalThink(self.interval)
    self:OnIntervalThink()    
end

function guardian_of_the_ancients_ficle_ground_thinker:OnRefresh( kv )
	
end

function guardian_of_the_ancients_ficle_ground_thinker:OnRemoved()
end

function guardian_of_the_ancients_ficle_ground_thinker:OnDestroy()
	if not IsServer() then return end
	UTIL_Remove( self:GetParent() )
end

function guardian_of_the_ancients_ficle_ground_thinker:OnIntervalThink()
    if  self.impuls_now < self.impuls_max then
        local enemies = FindUnitsInRadius(
            self.caster:GetTeamNumber(),	-- int, your team number
            self.parent:GetOrigin(),	-- point, center point
            nil,	-- handle, cacheUnit. (not known)
            self.range,	-- float, radius. or use FIND_UNITS_EVERYWHERE
            DOTA_UNIT_TARGET_TEAM_ENEMY,	-- int, team filter
            DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,	-- int, type filter
            0,	-- int, flag filter
            0,	-- int, order filter
            false	-- bool, can grow cache
        )
        for _,enemy in pairs(enemies) do
            local dmg = self.damage
            if self:GetAbility():GetSpecialValueFor("talant_caster_damage") ~= 0 then 
                self:GetCaster():PerformAttack(enemy, true, true, true, true, false, false, true)
            end
            ApplyDamage({   victim = enemy,
                            attacker = self.caster,
                            damage = dmg,
                            damage_type = self:GetAbility():GetAbilityDamageType(),
                            ability = self})
            enemy:AddNewModifier( self.caster, self:GetAbility(), "modifier_slow", {duration = self:GetAbility():GetSpecialValueFor("duration") } )
        end

        local effect_cast = ParticleManager:CreateParticle(
            "particles/units/heroes/hero_sandking/sandking_epicenter.vpcf",
            PATTACH_ABSORIGIN_FOLLOW,
            self.parent
        )
        ParticleManager:SetParticleControl( effect_cast, 1, Vector( self.range, self.range, self.range ) )
        ParticleManager:ReleaseParticleIndex( effect_cast )
    
        local effect_cast = ParticleManager:CreateParticle(
            "particles/units/heroes/hero_sandking/sandking_epicenter_ring.vpcf",
            PATTACH_ABSORIGIN_FOLLOW,
            self.parent
        )
        ParticleManager:SetParticleControl( effect_cast, 1, Vector( self.range, self.range, self.range ) )
        ParticleManager:ReleaseParticleIndex( effect_cast )
        self.impuls_now = self.impuls_now + 1
    else 
        print('destroy')
        UTIL_Remove( self:GetParent() )
    end
end

modifier_slow = class({
    IsDebuff = function(self) return true end,
    IsHidden = function(self) return false end,
    IsPurgable = function(self) return true end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
    }end,
    GetModifierMoveSpeedBonus_Percentage = function(self) return - self:GetAbility():GetSpecialValueFor("slow_pct") end
})