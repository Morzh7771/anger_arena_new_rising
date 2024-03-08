
tower_ability = class{}

function tower_ability:GetIntrinsicModifierName()
	return 'tower_controller'
end
LinkLuaModifier( "tower_controller", "lib/tower/tower_base", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "attack_slow", "lib/tower/tower_base", LUA_MODIFIER_MOTION_NONE )

attack_slow = class{
	DeclareFunctions = function(self)return {
		MODIFIER_PROPERTY_FIXED_ATTACK_RATE,
	}end,
    GetModifierFixedAttackRate = function(self) return 1.5 end,
}

tower_controller = class{
	IsDebuff = function (self) return false end,
	DeclareFunctions = function(self) return {
		MODIFIER_PROPERTY_MIN_HEALTH,
		MODIFIER_EVENT_ON_ATTACK,
		MODIFIER_EVENT_ON_ATTACKED,
		MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
		MODIFIER_EVENT_ON_ATTACK_LANDED ,
		MODIFIER_PROPERTY_HEALTH_REGEN_PERCENTAGE,
    } end,
	GetMinHealth = function (self) return 1 end,
}
function tower_controller:GetModifierIncomingDamage_Percentage()
	return -100
end

function tower_controller:OnCreated()
	self.damage = 0
end
function tower_controller:OnAttack(e)
	if e.target ~= self:GetParent() then return end 
	e.attacker:AddNewModifier(self:GetParent(),self:GetAbility(),'attack_slow',{duration = 1})
end
function tower_controller:OnAttackLanded(e)
	if e.attacker == self:GetParent() then 
		if BossSpawner:IsBoss(e.target) ~= nil then return end
		if not e.target:IsRealHero() then 
			self.damage = e.target:GetMaxHealth() * 10000
		else
			self.damage = e.target:GetMaxHealth() * 0.025
		end
		ApplyDamage{
			victim = e.target,
			attacker = self:GetParent(),
			ability = self:GetAbility(),
			damage = self.damage,
			damage_flags = DOTA_DAMAGE_FLAG_IGNORES_PHYSICAL_ARMOR+DOTA_DAMAGE_FLAG_IGNORES_MAGIC_ARMOR,
			damage_type = DAMAGE_TYPE_PHYSICAL,
		}
	end
end
function tower_controller:OnAttacked(e)
	if e.target == self:GetParent() then  
		if (e.attacker:GetOrigin() - e.target:GetOrigin()):Length2D() < e.target:Script_GetAttackRange() + e.attacker:GetHullRadius() + e.target:GetHullRadius() and e.attacker:IsRealHero() then
			if e.target:GetHealth() <= e.target:GetMaxHealth() * 0.05 + 10 then
				e.target:SetTeam(e.target:GetOpposingTeamNumber())
				TeamHelper:ApplyForHeroes(e.attacker:GetTeamNumber(), function(playerid, hero)
					PlayerResource:ModifyGold(playerid, 300+(GameRules:GetDOTATime(false,false) / 60) * 100, false, DOTA_ModifyGold_RoshanKill)
					hero:HeroLevelUp(true)
				end)
				e.target:SetHealth(e.target:GetMaxHealth())
			else
				e.target:SetHealth( (e.target:GetHealth() - e.target:GetMaxHealth() * 0.025 ))
				self.CanRegen = false
				self.timeLastDamage = GameRules:GetDOTATime( false, false )
				local timeLastDamage = GameRules:GetDOTATime( false, false )
				self.timer = Timers:CreateTimer( 10, function()
					if (self.timeLastDamage == timeLastDamage) then
						self.CanRegen = true
					end
				end )
			end
		end
	end
end

function tower_controller:GetModifierHealthRegenPercentage(tData)
	if self.CanRegen then 
		return 0.8
	end
end
