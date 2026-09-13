LinkLuaModifier("modifier_slark_essence_shift_aa", "heroes/slark/slark_essence_shift_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_slark_essence_shift_aa_tinker", "heroes/slark/slark_essence_shift_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_slark_essence_shift_aa_enemy", "heroes/slark/slark_essence_shift_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_slark_essence_shift_aa_tinker_enemy", "heroes/slark/slark_essence_shift_aa", LUA_MODIFIER_MOTION_NONE)


slark_essence_shift_aa = class({

    Precache = function(self, context)
        PrecacheResource("particle", "particles/units/heroes/hero_slark/slark_essence_shift.vpcf", context)
        PrecacheResource("particle", "particles/units/heroes/hero_pudge/pudge_fleshheap_count.vpcf", context)
    end,
    GetIntrinsicModifierName = function() return "modifier_slark_essence_shift_aa" end,
})

-- Сгенерировано: ресурсы, на которые ссылается этот скрипт.
-- Движок зовёт этот метод при прекеше юнита со способностью, поэтому
-- партиклы приезжают вместе с героем (пик/репик), а не на старте карты.
function slark_essence_shift_aa:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_pudge/pudge_fleshheap_count.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_slark/slark_essence_shift.vpcf", context)
end

modifier_slark_essence_shift_aa = class({
    IsHidden = function() return false end,
    IsDebuff = function() return false end,
    IsPurgable = function() return false end,
    DeclareFunctions = function() return {
        MODIFIER_PROPERTY_PROCATTACK_FEEDBACK,
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
        MODIFIER_EVENT_ON_DEATH,
    } end,
    -- геттер вызывается на каждом пересчёте статов, KV читаем один раз
    OnCreated = function(self) self:CacheValues() end,
    OnRefresh = function(self) self:CacheValues() end,
    CacheValues = function(self)
        local ability = self:GetAbility()

        if ability then self.agi_gain = ability:GetSpecialValueFor("agi_gain") end
    end,
    GetModifierBonusStats_Agility = function(self) return self:GetStackCount() * (self.agi_gain or 0) end,
})
function modifier_slark_essence_shift_aa:AddStackSelf(duration)
    local mod = self:GetParent():AddNewModifier(
        self:GetParent(),
        self:GetAbility(),
        "modifier_slark_essence_shift_aa_tinker",
        {
            duration = duration,
        }
    )
    mod.modifier = self
    self:IncrementStackCount()
end
function modifier_slark_essence_shift_aa:AddStackEnemy(target,duration)
    target:AddNewModifier(
        self:GetParent(),
        self:GetAbility(),
        "modifier_slark_essence_shift_aa_tinker_enemy",
        {
            duration = duration,
        }
    )
    target:AddNewModifier(
        self:GetParent(),
        self:GetAbility(),
        "modifier_slark_essence_shift_aa_enemy",
        {
            duration = duration,
        }
    )
end
function modifier_slark_essence_shift_aa:GetModifierProcAttack_Feedback( params )
	if IsServer() and (not self:GetParent():PassivesDisabled()) then
        if self:GetParent():PassivesDisabled() then return end
		if params.target:IsIllusion() then return end
        if params.attacker ~= self:GetParent() then return end
        local duration = 1
        if params.target:IsRealHero() then
            duration = self:GetAbility():GetSpecialValueFor("duration")
        else
            duration = self:GetAbility():GetSpecialValueFor("duration_creeps")
        end
        self:AddStackSelf(duration)
        self:AddStackEnemy(params.target,duration)
		self:PlayEffects( params.target )
	end
end
function modifier_slark_essence_shift_aa:OnDeath(params)
    local hVictim = params.unit
    local hKiller = params.attacker
	if hVictim == nil or hKiller == nil then return	end
	if hVictim:IsIllusion() then return end
    if hVictim:IsCreep() then return end

	if hVictim:GetTeamNumber() ~= self:GetParent():GetTeamNumber() and self:GetParent():IsAlive() then
		local vToCaster = self:GetParent():GetOrigin() - hVictim:GetOrigin()
		local flDistance = vToCaster:Length2D()
		if hKiller == self:GetParent() or self:GetAbility():GetSpecialValueFor( "steal_radius" ) >= flDistance then
            self:AddStackSelf(-1)
			local nFXIndex = ParticleManager:CreateParticle( "particles/units/heroes/hero_pudge/pudge_fleshheap_count.vpcf", PATTACH_OVERHEAD_FOLLOW, self:GetCaster() )
			ParticleManager:SetParticleControl( nFXIndex, 1, Vector( 1, 0, 0 ) )
			ParticleManager:ReleaseParticleIndex( nFXIndex )
		end
	end
end
function modifier_slark_essence_shift_aa:PlayEffects( target )
	local particle_cast = "particles/units/heroes/hero_slark/slark_essence_shift.vpcf"
	local effect_cast = ParticleManager:CreateParticle( particle_cast, PATTACH_ABSORIGIN_FOLLOW, target )
	ParticleManager:SetParticleControl( effect_cast, 1, self:GetParent():GetOrigin() + Vector( 0, 0, 64 ) )
	ParticleManager:ReleaseParticleIndex( effect_cast )
end

function modifier_slark_essence_shift_aa:RemoveStack()
	self:DecrementStackCount()
end

modifier_slark_essence_shift_aa_tinker = class({
    IsHidden = function() return true end,
    IsPurgable = function() return false end,
    GetAttributes = function() return MODIFIER_ATTRIBUTE_MULTIPLE end,
    OnRemoved = function(self)
        if IsServer() then
		    self.modifier:RemoveStack()
	    end
    end,
})

modifier_slark_essence_shift_aa_tinker_enemy = class({
    IsHidden = function() return true end,
    IsPurgable = function() return false end,
    GetAttributes = function() return MODIFIER_ATTRIBUTE_MULTIPLE end,
})

modifier_slark_essence_shift_aa_enemy = class({
    IsHidden = function() return false end,
    IsPurgable = function() return false end,
    IsDebuff = function() return true end,
    OnTooltip = function(self) return self:GetStackCount() * (self.stat_loss or 0) end,
    DeclareFunctions = function() return {
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
        MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
        MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
        MODIFIER_PROPERTY_TOOLTIP,
    } end,
    OnCreated = function(self)
        self:CacheValues()
        self:StartIntervalThink(0.25)
    end,
    OnRefresh = function(self) self:CacheValues() end,
    CacheValues = function(self)
        local ability = self:GetAbility()

        if ability then self.stat_loss = ability:GetSpecialValueFor("stat_loss") end
    end,
    OnIntervalThink = function (self)
        if not IsServer() then return end

        -- SetStackCount рассылается клиентам, поэтому только при изменении
        local count = #self:GetParent():FindAllModifiersByName("modifier_slark_essence_shift_aa_tinker_enemy")

        if self:GetStackCount() ~= count then self:SetStackCount(count) end
    end,
    GetModifierBonusStats_Strength = function(self) return self:GetStackCount() * -(self.stat_loss or 0) end,
    GetModifierBonusStats_Agility = function(self) return self:GetStackCount() * -(self.stat_loss or 0) end,
    GetModifierBonusStats_Intellect = function(self) return self:GetStackCount() * -(self.stat_loss or 0) end,
})





