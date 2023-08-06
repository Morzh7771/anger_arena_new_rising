local target = nil
itemBaseClass = class ({})
item_vision = itemBaseClass

LinkLuaModifier( "modifier_vision_item", "items/item_vision", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_vision_item_caster", "items/item_vision", LUA_MODIFIER_MOTION_NONE )

function itemBaseClass:GetIntrinsicModifierName()
    return "modifier_vision_item_caster"
end
function itemBaseClass:OnDestroy()
    
end
function itemBaseClass:OnSpellStart()
    self.caster = self:GetCaster()

    local enemies = FindUnitsInRadius(
			self.caster:GetTeamNumber(),	-- int, your team number
			self.caster:GetAbsOrigin(),	-- point, center point
			nil,	-- handle, cacheUnit. (not known)
			999999,	-- float, radius. or use FIND_UNITS_EVERYWHERE
			DOTA_UNIT_TARGET_TEAM_ENEMY,	-- int, team filter
			DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,	-- int, type filter
			DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,	-- int, flag filter
			0,	-- int, order filter
			false	-- bool, can grow cache
	    )
    for _,enemy in pairs(enemies) do
        if enemy:HasModifier("modifier_vision_item") then
            enemy:RemoveModifierByName("modifier_vision_item")
            enemy:AddNewModifier(self.caster, self, "modifier_vision_item", {duration = self:GetSpecialValueFor("duration")})
            return
        end
    end
    for _,enemy in pairs(enemies) do
        if enemy:IsRealHero() then
            enemy:AddNewModifier(self.caster, self, "modifier_vision_item", {duration = self:GetSpecialValueFor("duration")})
            target = enemy
            break
        end
    end
end

modifier_vision_item = class({
    IsDebuff = function(self) return true end,
    IsHidden = function(self) return false end,
    IsPurgable = function(self) return false end,
    RemoveOnDeath = function(self) return true end,
})

function modifier_vision_item:OnCreated()
    if IsServer() then
		self:StartIntervalThink(FrameTime())
	end
end
function modifier_vision_item:OnIntervalThink()
	if not IsServer() then return end
    local hero = self:GetParent()
    AddFOWViewer(hero:GetOpposingTeamNumber(), hero:GetAbsOrigin(), hero:GetCurrentVisionRange(), FrameTime(), false)
end
function modifier_vision_item:OnDestroy()
    self:StartIntervalThink(-1)
end
modifier_vision_item_caster = class({
    IsDebuff = function(self) return false end,
    IsHidden = function(self) return true end,
    IsPurgable = function(self) return false end,
    DeclareFunctions = function(self) return {
        MODIFIER_PROPERTY_BONUS_DAY_VISION,
        MODIFIER_PROPERTY_BONUS_NIGHT_VISION,
        MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
        MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
    }end,
    GetBonusDayVision = function(self) return self:GetAbility():GetSpecialValueFor("day_vision") end,
    GetBonusNightVision = function(self) return self:GetAbility():GetSpecialValueFor("night_vision")  end,
    GetModifierBonusStats_Strength = function(self) return self:GetAbility():GetSpecialValueFor("bonus_str") end,
    GetModifierBonusStats_Intellect = function(self) return self:GetAbility():GetSpecialValueFor("bonus_int")  end,
})
function modifier_vision_item_caster:OnDestroy()
    target:RemoveModifierByNameAndCaster("modifier_vision_item",self:GetParent())
end