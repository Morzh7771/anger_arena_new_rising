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

modifier_giant_ring_aa = class({})
function modifier_giant_ring_aa:DeclareFunctions()
    local funcs = {
        MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
        MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
        MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
        MODIFIER_PROPERTY_MOVESPEED_BONUS_UNIQUE,
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
    }
    return funcs
end
function modifier_giant_ring_aa:IsBuff() return true end
function modifier_giant_ring_aa:IsDebuff() return false end
function modifier_giant_ring_aa:IsHidden() return true end
function modifier_giant_ring_aa:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_MULTIPLE end
function modifier_giant_ring_aa:GetModifierBonusStats_Strength() return self:GetAbility():GetSpecialValueFor('bonus_all_stats') end
function modifier_giant_ring_aa:GetModifierBonusStats_Agility() return self:GetAbility():GetSpecialValueFor('bonus_all_stats') end
function modifier_giant_ring_aa:GetModifierBonusStats_Intellect() return self:GetAbility():GetSpecialValueFor('bonus_all_stats') end
function modifier_giant_ring_aa:GetModifierMoveSpeedBonus_Special_Boots() return self:GetAbility():GetSpecialValueFor('movement_speed') end
function modifier_giant_ring_aa:GetModifierAttackSpeedBonus_Constant() return self:GetAbility():GetSpecialValueFor('attack_speed') end


modifier_giant_ring_aa_active = class({})

function modifier_giant_ring_aa_active:OnCreated()
    self.bonus_stats = self:GetAbility():GetSpecialValueFor("bonus_all_stats_pct")
    self.interval = 0.5
    self:StartIntervalThink(self.interval)
end

function modifier_giant_ring_aa_active:IsBuff() return true end
function modifier_giant_ring_aa_active:IsDebuff() return false end
function modifier_giant_ring_aa_active:IsHidden() return false end
function modifier_giant_ring_aa_active:GetTexture()
	return "../items/giant_ring_aa" 
end

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
function modifier_giant_ring_aa_active:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
        MODIFIER_PROPERTY_MODEL_SCALE,
	}
	return funcs
end
function modifier_giant_ring_aa_active:GetModifierBonusStats_Agility()
	if not IsServer() then return end

	if self.bonus_stats then
	if self:GetParent()==self:GetParent() then
		-- use lock mechanism to prevent infinite recursive
		if self.lock1 then return end

		-- calculate bonus
		self.lock1 = true
		local agi = self:GetParent():GetAgility()
		self.lock1 = false

		local bonus = self.bonus_stats*agi/100

		return bonus
	else
		-- this agi includes bonus from this ability, which should be excluded
		local agi = self:GetParent():GetAgility()
		agi = 100/(100+self.bonus_stats)*agi

		local bonus = self.bonus_stats*agi/100

		return bonus
	end
end

end
function modifier_giant_ring_aa_active:GetModifierBonusStats_Strength()
	if not IsServer() then return end

	if self.bonus_stats then
	if self:GetParent()==self:GetParent() then
		-- use lock mechanism to prevent infinite recursive
		if self.lock2 then return end

		-- calculate bonus
		self.lock2 = true
		local str = self:GetParent():GetStrength()
		self.lock2 = false

		local bonus = self.bonus_stats*str/100

		return bonus
	else
		-- this agi includes bonus from this ability, which should be excluded
		local str = self:GetParent():GetStrength()
		str = 100/(100+self.bonus_stats)*str

		local bonus = self.bonus_stats*str/100

		return bonus
	end
	end
end

function modifier_giant_ring_aa_active:GetModifierBonusStats_Intellect()
    if not IsServer() then return end

    if self.bonus_stats then
        if self:GetParent()==self:GetParent() then
            -- use lock mechanism to prevent infinite recursive
            if self.lock3 then return end

            -- calculate bonus
            self.lock3 = true
            local int = self:GetParent():GetIntellect()
            self.lock3 = false

            local bonus = self.bonus_stats*int/100

            return bonus
        else
            -- this agi includes bonus from this ability, which should be excluded
            local int = self:GetParent():GetIntellect()
            int = 100/(100+self.bonus_stats)*int

            local bonus = self.bonus_stats*int/100

            return bonus
        end
    end

end
function modifier_giant_ring_aa_active:CheckState()
	return {
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
	}
end


function modifier_giant_ring_aa_active:GetModifierModelScale()
	return 20
end