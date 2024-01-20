modifier_fervor_aa = class({})

-----------------------------------------------------------------------------
function modifier_fervor_aa:IsHidden()
    return true
end

--------------------------------------------------------------------------------
function modifier_fervor_aa:IsPurgable()
    return false
end

--------------------------------------------------------------------------------
function modifier_fervor_aa:OnCreated(kv)
    self.duration = self:GetAbility():GetSpecialValueFor("duration")
    self.chance = self:GetAbility():GetSpecialValueFor("chance")
    self.chance_per_stack = self:GetAbility():GetSpecialValueFor("chance_per_stack")
    self.bonus_range = self:GetAbility():GetSpecialValueFor("bonus_range")
    self.target = nil
end

-------------------------------------------------------------------------------
function modifier_fervor_aa:OnRefresh(kv)
    self.duration = self:GetAbility():GetSpecialValueFor("duration")
    self.chance = self:GetAbility():GetSpecialValueFor("chance")
    self.chance_per_stack = self:GetAbility():GetSpecialValueFor("chance_per_stack")
    self.bonus_range = self:GetAbility():GetSpecialValueFor("bonus_range")
end

-------------------------------------------------------------------------------
function modifier_fervor_aa:DeclareFunctions()
    local funcs = {
		MODIFIER_PROPERTY_PROCATTACK_FEEDBACK,
    }
    return funcs
end

-------------------------------------------------------------------------------
function modifier_fervor_aa:GetModifierProcAttack_Feedback(params)
	local parent = self:GetParent()
    if not parent or parent:PassivesDisabled() then return end
    if not IsServer() then return end
	if parent:IsIllusion() then return end

	parent:AddNewModifier(parent, self:GetAbility(), "modifier_fervor_aa_effect", { duration = self.duration })
	local stack_count = params.attacker:GetModifierStackCount("modifier_fervor_aa_effect", parent)
	
    local chance = self.chance+self.chance_per_stack*stack_count
    if chance >= 50 then chance = 50 end

    if params.target == self.target then
        self:SetStacksCustom(stack_count + 1)
    else
        self:SetStacksCustom(1)
    end
    if params.no_attack_cooldown then return end
    if self:GetAbility():GetSpecialValueFor("has_shard") == 1 then
        if RollPseudoRandomPercentage(chance,12,parent) then
            local enemies = FindUnitsInRadius(
                parent:GetTeamNumber(),	-- int, your team number
                parent:GetOrigin(),	-- point, center point
                nil,	-- handle, cacheUnit. (not known)
                self.bonus_range+parent:GetBaseAttackRange(),	-- float, radius. or use FIND_UNITS_EVERYWHERE
                DOTA_UNIT_TARGET_TEAM_ENEMY,	-- int, team filter
                DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,	-- int, type filter
                0,	-- int, flag filter
                0,	-- int, order filter
                false	-- bool, can grow cache
            )
            for _,enemy in pairs(enemies) do
                if enemy == params.target then
                    parent:PerformAttack(enemy, true, true, true, false, true, false, false)
                    break
                end
            end
        end
    end
    self.target = params.target
end

-------------------------------------------------------------------------------
function modifier_fervor_aa:SetStacksCustom(value)
    local attacker = self:GetParent()
    attacker:SetModifierStackCount("modifier_fervor_aa_effect", attacker, value)
end
