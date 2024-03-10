LinkLuaModifier("modifier_item_wraith_band_custom", "items/item_wraith_band_custom", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_wraith_band_custom_speed", "items/item_wraith_band_custom", LUA_MODIFIER_MOTION_NONE)

item_wraith_band_custom = class({})

function item_wraith_band_custom:GetIntrinsicModifierName()
	return "modifier_item_wraith_band_custom"
end

function item_wraith_band_custom:OnSpellStart()
if not IsServer() then return end

if test then 
    --my_game:WinTeam(self:GetCaster())
end

self:GetParent():EmitSound("DOTA_Item.Butterfly")
self:GetParent():AddNewModifier(self:GetParent(), self, "modifier_item_wraith_band_custom_speed", {duration = self:GetSpecialValueFor("duration")})
end


modifier_item_wraith_band_custom = class({})

function modifier_item_wraith_band_custom:IsHidden() return true end
function modifier_item_wraith_band_custom:IsPurgable() return false end
function modifier_item_wraith_band_custom:GetAttributes() return MODIFIER_ATTRIBUTE_MULTIPLE end
function modifier_item_wraith_band_custom:DeclareFunctions()
    local funcs = {
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
        MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
        MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
        MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT
    }

    return funcs
end


function modifier_item_wraith_band_custom:GetModifierBonusStats_Strength()
    if self:GetAbility() then return self:GetAbility():GetSpecialValueFor("str") *  (math.floor(GameRules:GetDOTATime(false,false) / 600) + 1) end
end
function modifier_item_wraith_band_custom:GetModifierBonusStats_Agility()
    if self:GetAbility() then return self:GetAbility():GetSpecialValueFor("agi") *  (math.floor(GameRules:GetDOTATime(false,false) / 600) + 1) end
end
function modifier_item_wraith_band_custom:GetModifierBonusStats_Intellect()
    if self:GetAbility() then return self:GetAbility():GetSpecialValueFor("int") *  (math.floor(GameRules:GetDOTATime(false,false) / 600) + 1) end
end
function modifier_item_wraith_band_custom:GetModifierPhysicalArmorBonus()
    if self:GetAbility() then return self:GetAbility():GetSpecialValueFor("armor") *  (math.floor(GameRules:GetDOTATime(false,false) / 600) + 1) end
end


function modifier_item_wraith_band_custom:GetModifierAttackSpeedBonus_Constant()
    if self:GetAbility() then return self:GetAbility():GetSpecialValueFor("speed") *  (math.floor(GameRules:GetDOTATime(false,false) / 600) + 1) end
end

modifier_item_wraith_band_custom_speed = class({})
function modifier_item_wraith_band_custom_speed:IsHidden() return false end
function modifier_item_wraith_band_custom_speed:IsPurgable() return true end

function modifier_item_wraith_band_custom_speed:OnCreated(table)
self.speed = self:GetAbility():GetSpecialValueFor("speed_buf") *  (math.floor(GameRules:GetDOTATime(false,false) / 600) + 1)
if not IsServer() then return end

local particle = ParticleManager:CreateParticle("particles/wb_bif.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
ParticleManager:SetParticleControl(particle, 0, self:GetParent():GetAbsOrigin())
self:AddParticle(particle, false, false, -1, false, false)   


for _,mod in pairs(self:GetParent():FindAllModifiers()) do 
    if mod:GetName() == "modifier_item_wraith_band_custom" then 
        self:IncrementStackCount()
    end
end

end

function modifier_item_wraith_band_custom_speed:DeclareFunctions()
return
{
    MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT
}

end

function modifier_item_wraith_band_custom_speed:GetModifierAttackSpeedBonus_Constant()
return self.speed*self:GetStackCount()
end

