item_guardian_greaves_custom = class({})

item_guardian_greaves_custom_2 = item_guardian_greaves_custom

LinkLuaModifier( "modifier_item_guardian_greaves_custom", "items/item_guardian_greaves_custom", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_guardian_greaves_custom_aura", "items/item_guardian_greaves_custom", LUA_MODIFIER_MOTION_NONE )

function item_guardian_greaves_custom:GetIntrinsicModifierName()
	return "modifier_item_guardian_greaves_custom"
end
function item_guardian_greaves_custom:Precache(context)
    PrecacheResource("particle", "particles/items3_fx/warmage.vpcf", context)
    PrecacheResource("particle", "particles/items3_fx/warmage_recipient.vpcf", context)
end
function item_guardian_greaves_custom:OnSpellStart()
	if not IsServer() then return end
	local heal_amount = self:GetSpecialValueFor("replenish_health")*self:GetCaster():GetMaxHealth()/100 + self:GetSpecialValueFor("base_health")
	local mana_amount = self:GetSpecialValueFor("replenish_mana")*self:GetCaster():GetMaxMana()/100 + self:GetSpecialValueFor("base_mana")
    local radius = self:GetSpecialValueFor("replenish_radius")

	self:GetCaster():EmitSound("Item.GuardianGreaves.Activate")

	local particle_1 = ParticleManager:CreateParticle("particles/items3_fx/warmage.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetCaster())
	ParticleManager:ReleaseParticleIndex(particle_1)

	self:GetCaster():GiveMana(mana_amount)
	SendOverheadEventMessage(nil, OVERHEAD_ALERT_MANA_ADD, self:GetCaster(), mana_amount, nil)
	self:GetCaster():Purge(false, true, false, true, false)
	self:GetCaster():Heal(heal_amount, self:GetCaster())
	SendOverheadEventMessage(nil, OVERHEAD_ALERT_HEAL, self:GetCaster(), heal_amount, nil)
	self:GetCaster():EmitSound("Item.GuardianGreaves.Target")

	local particle_2 = ParticleManager:CreateParticle("particles/items3_fx/warmage_recipient.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetCaster())
	ParticleManager:SetParticleControl(particle_2, 0, self:GetCaster():GetAbsOrigin())

    local nearby_allied_units = FindUnitsInRadius(self:GetCaster():GetTeam(), self:GetCaster():GetAbsOrigin(), 
			nil, radius,DOTA_UNIT_TARGET_TEAM_FRIENDLY, 
			DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
			DOTA_UNIT_TARGET_FLAG_NONE + DOTA_UNIT_TARGET_FLAG_OUT_OF_WORLD + DOTA_UNIT_TARGET_FLAG_INVULNERABLE,
			FIND_ANY_ORDER, false)
	
	for _,nearby_ally in ipairs(nearby_allied_units) do 
        if self:GetCaster() ~= nearby_ally then
            local heal_amount = self:GetSpecialValueFor("replenish_health")*nearby_ally:GetMaxHealth()/100 + self:GetSpecialValueFor("base_health")
            local mana_amount = self:GetSpecialValueFor("replenish_mana")*nearby_ally:GetMaxMana()/100 + self:GetSpecialValueFor("base_mana")
            
            nearby_ally:GiveMana(mana_amount)
            SendOverheadEventMessage(nil, OVERHEAD_ALERT_MANA_ADD, nearby_ally, mana_amount, nil)
            nearby_ally:Purge(false, true, false, false, false)
            nearby_ally:Heal(heal_amount, self:GetCaster())
            SendOverheadEventMessage(nil, OVERHEAD_ALERT_HEAL, nearby_ally, heal_amount, nil)
            nearby_ally:EmitSound("Item.GuardianGreaves.Target")

            local particle_2 = ParticleManager:CreateParticle("particles/items3_fx/warmage_recipient.vpcf", PATTACH_ABSORIGIN_FOLLOW, nearby_ally)
            ParticleManager:SetParticleControl(particle_2, 0, nearby_ally:GetAbsOrigin())
        end
	end
end

modifier_guardian_greaves_custom_aura = class({
    IsHidden = function (self) return false end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
        MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
        MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
        MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
    } end,
    GetTexture = function (self) return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "") end,
})

function modifier_guardian_greaves_custom_aura:GetModifierConstantHealthRegen()
    if self:GetParent():GetHealthPercent() < self:GetAbility():GetSpecialValueFor("aura_bonus_threshold") then
        return self:GetAbility():GetSpecialValueFor("aura_health_regen_active")
    else
        return self:GetAbility():GetSpecialValueFor("aura_health_regen")
    end
end

function modifier_guardian_greaves_custom_aura:GetModifierConstantManaRegen()
    if self:GetParent():GetHealthPercent() < self:GetAbility():GetSpecialValueFor("aura_bonus_threshold") then
        return self:GetAbility():GetSpecialValueFor("aura_mana_regen_active")
    else
        return self:GetAbility():GetSpecialValueFor("aura_mana_regen")
    end
end

function modifier_guardian_greaves_custom_aura:GetModifierPhysicalArmorBonus()
    if self:GetParent():GetHealthPercent() < self:GetAbility():GetSpecialValueFor("aura_bonus_threshold") then
        return self:GetAbility():GetSpecialValueFor("aura_armor_active")
    else
        return self:GetAbility():GetSpecialValueFor("aura_armor")
    end
end

function modifier_guardian_greaves_custom_aura:GetModifierIncomingDamage_Percentage()
    if self:GetParent():GetHealthPercent() < self:GetAbility():GetSpecialValueFor("aura_bonus_threshold") then
        return self:GetAbility():GetSpecialValueFor("aura_reduction")
    else
        return 0
    end
end

modifier_item_guardian_greaves_custom = class({
    IsHidden = function (self) return true end,
    IsAura = function (self) return true end,
    GetModifierAura = function (self) return "modifier_guardian_greaves_custom_aura" end,
    GetAuraRadius = function (self) return self:GetAbility():GetSpecialValueFor("replenish_radius") end,
    GetAuraSearchTeam = function (self) return DOTA_UNIT_TARGET_TEAM_FRIENDLY end,
    GetAuraSearchType = function (self) return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC end,
    GetAuraSearchFlags = function (self) return DOTA_UNIT_TARGET_FLAG_INVULNERABLE end,
    IsPurgable = function (self) return false end,
    RemoveOnDeath = function (self) return false end,
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
		MODIFIER_PROPERTY_MOVESPEED_BONUS_UNIQUE,
		MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
		MODIFIER_EVENT_ON_TAKEDAMAGE,
    } end,
    GetModifierMoveSpeedBonus_Special_Boots = function (self) return self:GetAbility():GetSpecialValueFor("bonus_movement") end,
    GetModifierConstantManaRegen = function (self) return self:GetAbility():GetSpecialValueFor("bonus_mana_regen") end,
    GetModifierPhysicalArmorBonus = function (self) return self:GetAbility():GetSpecialValueFor("bonus_armor") end,
})

function modifier_item_guardian_greaves_custom:OnTakeDamage(params)
    if not IsServer() then return end
    if self:GetParent() ~= params.unit then return end
    if not self:GetParent():IsRealHero() then return end
    if self:GetParent():GetHealthPercent() > self:GetAbility():GetSpecialValueFor("aura_bonus_threshold") then return end
    if self:GetAbility():GetCooldownTimeRemaining() > 0 then return end
    if self:GetParent():HasModifier("modifier_death") then return end

    self:GetAbility():UseResources(false, false, false, true)
    self:GetAbility():OnSpellStart()
end


