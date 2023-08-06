
itemBaseClass = class ({})
item_vision = itemBaseClass
LinkLuaModifier( "modifier_vision_item", "items/item_vision", LUA_MODIFIER_MOTION_NONE )
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
        print(enemies)
    for _,enemy in pairs(enemies) do
        if enemy:HasModifier("modifier_vision_item") then 
            return
        end
    end
    for _,enemy in pairs(enemies) do
        if enemy:IsRealHero() then
            enemy:AddNewModifier(self.caster, self, "modifier_vision_item", {duration = self:GetSpecialValueFor("duration")})
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
        print(self:GetParent():GetUnitName())
	end
end
function modifier_vision_item:OnIntervalThink()
	if not IsServer() then return end
    local hero = self:GetParent()
	AddFOWViewer(hero:GetOpposingTeamNumber(), hero:GetAbsOrigin(), 200, FrameTime(), false)
end
function modifier_vision_item:OnDestroy()
    self:StartIntervalThink(-1)
end