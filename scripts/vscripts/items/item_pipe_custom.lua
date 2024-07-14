item_pipe_custom = item_pipe_custom or class({})
item_pipe_custom_2 = item_pipe_custom or class({})
item_pipe_custom_3 = item_pipe_custom or class({})

LinkLuaModifier("modifier_item_pipe_custom", "items/item_pipe_custom", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_pipe_custom_aura", "items/item_pipe_custom", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_pipe_custom_shield", "items/item_pipe_custom", LUA_MODIFIER_MOTION_NONE)

function item_pipe_custom:GetIntrinsicModifierName()
	return "modifier_item_pipe_custom"
end

function item_pipe_custom:OnSpellStart()
    local radius = self:GetSpecialValueFor("barrier_radius")

    local units = FindUnitsInRadius(self:GetCaster():GetTeamNumber(), self:GetCaster():GetAbsOrigin(), nil, radius, DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_INVULNERABLE, FIND_ANY_ORDER, false)
		
	for _, unit in pairs(units) do
		unit:RemoveModifierByName("modifier_item_pipe_custom_shield")
		unit:AddNewModifier(self:GetCaster(), self, "modifier_item_pipe_custom_shield", {duration = self:GetSpecialValueFor("barrier_duration"),bonus = self:GetCaster():GetIntellect(false)})
	end
end

modifier_item_pipe_custom = class({})
function modifier_item_pipe_custom:IsHidden()
	return true
end

function modifier_item_pipe_custom:DeclareFunctions()
	local funcs = {
        MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
        MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
	}
	return funcs
end

function modifier_item_pipe_custom:GetModifierMagicalResistanceBonus( kv )
	return self:GetAbility():GetSpecialValueFor( "magic_resistance_aura" )
end
function modifier_item_pipe_custom:GetModifierConstantHealthRegen( kv )
	return self:GetAbility():GetSpecialValueFor( "aura_health_regen" )
end


function modifier_item_pipe_custom:IsAura()
	return true
end

function modifier_item_pipe_custom:GetModifierAura()
	return "modifier_item_pipe_custom_aura"
end

function modifier_item_pipe_custom:GetAuraRadius()
	return self:GetAbility():GetSpecialValueFor("aura_radius")
end

function modifier_item_pipe_custom:GetAuraSearchTeam()
	return DOTA_UNIT_TARGET_TEAM_FRIENDLY
end

function modifier_item_pipe_custom:GetAuraSearchType()
	return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC
end

function modifier_item_pipe_custom:GetAuraSearchFlags()
	return DOTA_UNIT_TARGET_FLAG_INVULNERABLE
end

modifier_item_pipe_custom_aura = class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_item_pipe_custom_aura:IsHidden()
	return false
end

function modifier_item_pipe_custom_aura:IsDebuff()
	return false
end

function modifier_item_pipe_custom_aura:GetTexture()
	return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "")
end
--------------------------------------------------------------------------------
-- Initializations
function modifier_item_pipe_custom_aura:OnCreated( kv )
	self.aura_regen = self:GetAbility():GetSpecialValueFor( "aura_health_regen" )
    self.aura_resist = self:GetAbility():GetSpecialValueFor( "magic_resistance_aura" )
end

function modifier_item_pipe_custom_aura:OnRefresh( kv )
	self.aura_regen = self:GetAbility():GetSpecialValueFor( "aura_health_regen" )
    self.aura_resist = self:GetAbility():GetSpecialValueFor( "magic_resistance_aura" )
end

--------------------------------------------------------------------------------
-- Modifier Effects
function modifier_item_pipe_custom_aura:DeclareFunctions()
	local funcs = {
        MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
        MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
	}
	return funcs
end

function modifier_item_pipe_custom_aura:GetModifierMagicalResistanceBonus( kv )
	return self.aura_resist
end
function modifier_item_pipe_custom_aura:GetModifierConstantHealthRegen( kv )
	return self.aura_resist
end


modifier_item_pipe_custom_shield = class({})
function modifier_item_pipe_custom_shield:IsHidden() return false end
function modifier_item_pipe_custom_shield:IsPurgable() return false end
function modifier_item_pipe_custom_shield:IsDebuff() return false end
function modifier_item_pipe_custom_shield:GetTexture() return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "") end



function modifier_item_pipe_custom_shield:OnCreated(table)
    if not IsServer() then return end
    self.shield = self:GetAbility():GetSpecialValueFor("barrier_block")+table.bonus*self:GetAbility():GetSpecialValueFor("bonus_block_per_int")

    self:SetStackCount(self.shield)

    self:GetParent():EmitSound("DOTA_Item.Pipe.Activate")
        

    self.particle = ParticleManager:CreateParticle("particles/items2_fx/pipe_of_insight_v2.vpcf", PATTACH_OVERHEAD_FOLLOW, self:GetParent())
    ParticleManager:SetParticleControl(self.particle, 0, self:GetParent():GetAbsOrigin())
    ParticleManager:SetParticleControlEnt(self.particle, 1, self:GetParent(), PATTACH_POINT_FOLLOW, "attach_origin", self:GetParent():GetAbsOrigin(), true)
    ParticleManager:SetParticleControl(self.particle, 2, Vector(125, 0, 0))

    self:AddParticle(self.particle,false, false, -1, false, false)

end



function modifier_item_pipe_custom_shield:DeclareFunctions()
    return 
    {
    MODIFIER_PROPERTY_INCOMING_SPELL_DAMAGE_CONSTANT,
    MODIFIER_PROPERTY_TOOLTIP,
    }
end

function modifier_item_pipe_custom_shield:OnTooltip() return self:GetStackCount() end



function modifier_item_pipe_custom_shield:GetModifierIncomingSpellDamageConstant(params)

    if IsClient() then 
    return self:GetStackCount()
    end

    if not IsServer() then return end

    if self:GetParent() == params.attacker then return end


    if self:GetStackCount() > params.damage then
        self:SetStackCount(self:GetStackCount() - params.damage)
        local i = params.damage
        return -i
    else
        
        local i = self:GetStackCount()
        self:SetStackCount(0)
        self:Destroy()
        return -i
    end

end

