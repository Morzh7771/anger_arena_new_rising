
BaseClass = class({})
satan_blood_debt = BaseClass
LinkLuaModifier("satan_blood_debt_counter", "heroes/satan/satan_blood_debt", LUA_MODIFIER_MOTION_NONE)

function BaseClass:GetIntrinsicModifierName()
	return "satan_blood_debt_counter"
end


-- Стаки = бонус к урону атаки. Дробные части копятся в self.debt,
-- в стаки уходит только целая часть, чтобы мелкие удары не терялись.
satan_blood_debt_counter = class({
	IsHidden                = function(self) return false end,
	IsPurgable              = function(self) return false end,
	IsDebuff                = function(self) return false end,
	IsBuff                  = function(self) return true end,
	RemoveOnDeath           = function(self) return false end,
	DeclareFunctions        = function(self) return {
		MODIFIER_EVENT_ON_TAKEDAMAGE,
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
	}end,
})

local THINK_INTERVAL = 0.1

function satan_blood_debt_counter:CacheValues()
	local ability = self:GetAbility()

	if not ability then return end

	self.debt_pct         = ability:GetSpecialValueFor("debt_pct")
	self.max_bonus_damage = ability:GetSpecialValueFor("max_bonus_damage")
	self.decay_per_second = ability:GetSpecialValueFor("decay_per_second")
	self.decay_delay      = ability:GetSpecialValueFor("decay_delay")
end

function satan_blood_debt_counter:OnCreated()
	self:CacheValues()

	if IsServer() then
		self.debt = 0
		self:SetStackCount(0)
		self.last_damage_time = GameRules:GetGameTime()
		self:StartIntervalThink(THINK_INTERVAL)
	end
end

function satan_blood_debt_counter:OnRefresh()
	self:CacheValues()
end

function satan_blood_debt_counter:OnUpgrade()
	self:CacheValues()
end

if IsServer() then
	-- потолок долга растёт с уровнем героя
	function satan_blood_debt_counter:MaxDebt()
		local ability = self:GetAbility()
		return self.max_bonus_damage + (ability and ability:GetSpecialValueFor("max_damage_per_level") or 0) * self:GetParent():GetLevel()
	end

	function satan_blood_debt_counter:SetDebt(value)
		self.debt = math.max(0, math.min(value, self:MaxDebt()))

		local stacks = math.floor(self.debt)
		if stacks ~= self:GetStackCount() then
			self:SetStackCount(stacks)
		end
	end

	function satan_blood_debt_counter:OnIntervalThink()
		if not self.decay_per_second then self:CacheValues() end
		if not self.decay_per_second or self.debt <= 0 then return end

		if GameRules:GetGameTime() - self.last_damage_time >= self.decay_delay then
			-- тает на decay_per_second% от потолка в секунду
			self:SetDebt(self.debt - self:MaxDebt() * self.decay_per_second / 100 * THINK_INTERVAL)
		end
	end

	function satan_blood_debt_counter:OnTakeDamage(params)
		local parent = self:GetParent()
		if params.unit ~= parent then return end
		if parent:PassivesDisabled() or parent:IsIllusion() then return end
		if params.damage <= 0 then return end

		if not self.debt_pct then self:CacheValues() end
		if not self.debt_pct then return end

		self.last_damage_time = GameRules:GetGameTime()
		self:SetDebt(self.debt + params.damage * self.debt_pct / 100)
	end
end

function satan_blood_debt_counter:GetModifierPreAttack_BonusDamage()
	if self:GetParent():PassivesDisabled() then return 0 end

	return self:GetStackCount()
end
