
mid_teleport = class ({})

LinkLuaModifier("modifier_mid_teleport_cd", "abilities/mid_teleport", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_mid_teleport_cast", "abilities/mid_teleport", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_mid_teleport_speed", "abilities/mid_teleport", LUA_MODIFIER_MOTION_NONE)

function mid_teleport:GetChannelTime() return 3 end
function mid_teleport:OnSpellStart()
	local hero = self:GetCaster()
	self.portal = nil
	self.portals = {}
	self.portalsName = {
		"teleport_radiant_top",
		"teleport_radiant_bot",
		"teleport_dire_top",
		"teleport_dire_bot",
	}
	for _,unit in pairs(self.portalsName)do
		local portalTarget = Entities:FindByName( nil, unit )
		if portalTarget ~= nil then
			table.insert(self.portals,portalTarget)
		end
	end
	for _,unit in pairs(self.portals)do
		if 550 >= ( hero:GetOrigin() - unit:GetOrigin() ):Length2D() then 
			self.portal = unit
		end
	end
	hero:AddNewModifier(hero, self, "modifier_mid_teleport_cast", {target = self.portal:entindex()})
end
function mid_teleport:OnChannelFinish(bInterrupted)

	self:GetCaster():RemoveModifierByName("modifier_mid_teleport_cast")
    
	local hero = self:GetCaster()

	local ability_name = self:GetAbilityName()
	for i = 0,23 do
		local ability_search = hero:GetAbilityByIndex(i)
		if ability_search ~= nil then
		if ability_search:GetAbilityName() == ability_name then hero:RemoveAbility(ability_name)	
		end
	end

	end

	if bInterrupted then 
        return 
    end   
	hero:AddNewModifier(hero, nil, "modifier_mid_teleport_speed", {duration = 15} )
	hero:AddNewModifier(hero, nil, "modifier_mid_teleport_cd", {duration = 10} )

	local targets = {
		"teleport_radiant_top_target",
		"teleport_dire_top_target",
		"teleport_radiant_bot_target",
		"teleport_dire_bot_target",
	}
	local teleports = {
		"teleport_dire_top",
		"teleport_radiant_top",
		"teleport_dire_bot",
		"teleport_radiant_bot",
	}
	local teleporttarget
	for i,teleport in pairs(teleports) do
		if teleport == self.portal:GetName() then
			teleporttarget = Entities:FindByName( nil, targets[i] )
		end
	end

	hero:SetAbsOrigin(teleporttarget:GetAbsOrigin())
	FindClearSpaceForUnit(hero, teleporttarget:GetAbsOrigin(), true)
	hero:Stop()
	hero:Interrupt()
end

modifier_mid_teleport_cd = class({})

function modifier_mid_teleport_cd:IsDebuff() return true end
function modifier_mid_teleport_cd:IsPurgable() return false end
function modifier_mid_teleport_cd:RemoveOnDeath() return false end
function modifier_mid_teleport_cd:GetTexture() return "item_tpscroll" end

function modifier_mid_teleport_cd:OnCreated(table)
	if not IsServer() then return end	
	--	if teleports[self:GetParent():GetTeamNumber()].ray then
	 --  	  ParticleManager:DestroyParticle(teleports[self:GetParent():GetTeamNumber()].ray, false)
		--end
	end
	
	
modifier_mid_teleport_cast = class({})

function modifier_mid_teleport_cast:IsHidden() return true end
function modifier_mid_teleport_cast:IsPurgable() return false end
function modifier_mid_teleport_cast:DeclareFunctions()
	return
	{
		MODIFIER_PROPERTY_OVERRIDE_ANIMATION
	}
	end
	
function modifier_mid_teleport_cast:GetOverrideAnimation()
	return ACT_DOTA_TELEPORT
end
	
	
function modifier_mid_teleport_cast:OnCreated(table)
	if not IsServer() then return end
	local portal = EntIndexToHScript(table.target)

	self:GetParent():SetForwardVector((portal:GetAbsOrigin() - self:GetParent():GetAbsOrigin()):Normalized())
	self:GetParent():FaceTowards(portal:GetAbsOrigin())
	
end

modifier_mid_teleport_speed = class({})

function modifier_mid_teleport_speed:IsHidden() return false end
function modifier_mid_teleport_speed:IsPurgable() return false end
function modifier_mid_teleport_speed:GetTexture() return "rune_haste" end
function modifier_mid_teleport_speed:OnCreated(table)
	self.move_speed = 25
	if not IsServer() then return end
end

function modifier_mid_teleport_speed:GetEffectName()
	return "particles/generic_gameplay/rune_haste_owner.vpcf"
end

function modifier_mid_teleport_speed:DeclareFunctions()
return
{
  MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
  MODIFIER_EVENT_ON_TAKEDAMAGE
}
end


function modifier_mid_teleport_speed:GetModifierMoveSpeedBonus_Percentage()
	return self.move_speed
end


function modifier_mid_teleport_speed:OnTakeDamage(params)
	if not IsServer() then return end
	if self:GetParent() ~= params.unit then return end
	if self:GetParent() == params.atttacker then return end

	self:Destroy()
end