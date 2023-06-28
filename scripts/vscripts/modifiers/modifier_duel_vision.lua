if modifier_duel_vision == nil then
	modifier_duel_vision = class({})
end
LinkLuaModifier( "modifier_edible_gem", 'modifiers/modifier_duel_vision', LUA_MODIFIER_MOTION_NONE )
function modifier_duel_vision:IsPurgable()
	return false
end
function modifier_duel_vision:OnCreated(params)
    self.radius = 900 
    self.team = params.team
    print("visionMod")
	if IsServer() then
		self:StartIntervalThink(FrameTime())
	end
end
function modifier_duel_vision:OnIntervalThink()
	if not IsServer() then return end
	if not self:GetParent():IsAlive() then return end
    local hero = self:GetParent()

	AddFOWViewer(hero:GetOpposingTeamNumber(), hero:GetAbsOrigin(), 10, FrameTime(), false)
end

function modifier_duel_vision:IsAura()
	return true
end

function modifier_duel_vision:RemoveOnDeath()
	return true
end

function modifier_duel_vision:AllowIllusionDuplicate()
	return true
end

function modifier_duel_vision:GetAuraRadius()
	return self.radius
end

function modifier_duel_vision:DeclareFunctions()
	return { MODIFIER_EVENT_ON_DEATH }
end

function modifier_duel_vision:GetAuraSearchTeam()
	return DOTA_UNIT_TARGET_TEAM_ENEMY
end

function modifier_duel_vision:GetAuraSearchType()
	return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC + DOTA_UNIT_TARGET_OTHER
end

function modifier_duel_vision:GetAuraSearchFlags()
	return DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES
end

function modifier_duel_vision:GetModifierAura()
	return "modifier_edible_gem"
end

function modifier_duel_vision:GetTexture()
	return "item_gem"
end

function modifier_duel_vision:OnDeath( keys )
	if IsServer() then
		local dead_hero = keys.unit 

		if dead_hero ~= self:GetParent() then return end
		if dead_hero.IsReincarnating and dead_hero:IsReincarnating() then return end 

		self:Destroy()
	end
end

if modifier_edible_gem == nil then modifier_edible_gem = class({}) end

function modifier_edible_gem:CheckState()
	if self:GetParent():GetUnitName() == "npc_dota_techies_land_mine" then
		return {}
	else 
		return { [MODIFIER_STATE_INVISIBLE] = false }
	end 
end

function modifier_edible_gem:IsHidden()
	return true
end

function modifier_edible_gem:IsPurgable()
	return false
end

function modifier_edible_gem:GetPriority()
	return MODIFIER_PRIORITY_HIGH
end
