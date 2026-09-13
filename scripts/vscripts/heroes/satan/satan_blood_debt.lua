
BaseClass = class({})
satan_blood_debt = BaseClass
LinkLuaModifier("satan_blood_debt_counter", "heroes/satan/satan_blood_debt", LUA_MODIFIER_MOTION_NONE)

function BaseClass:GetIntrinsicModifierName()
	return "satan_blood_debt_counter"
end


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

function satan_blood_debt_counter:CacheValues()
	local ability = self:GetAbility()

	if not ability then return end

	self.debt_pct         = ability:GetSpecialValueFor("debt_pct")
	self.debt_per_damage  = ability:GetSpecialValueFor("debt_per_damage")
	self.max_bonus_damage = ability:GetSpecialValueFor("max_bonus_damage")
	self.decay_per_second = ability:GetSpecialValueFor("decay_per_second")
	self.decay_delay      = ability:GetSpecialValueFor("decay_delay")
end

function satan_blood_debt_counter:OnCreated()
	self:CacheValues()

	if IsServer() then
		self:SetStackCount(0)
		self.last_damage_time = GameRules:GetGameTime()
		self:StartIntervalThink(0.1)  -- Проверяем затухание каждые 0.1 сек
	end
end

function satan_blood_debt_counter:OnRefresh()
	self:CacheValues()
end

function satan_blood_debt_counter:OnUpgrade()
	self:CacheValues()
end

if IsServer() then
	function satan_blood_debt_counter:OnIntervalThink()
		local caster = self:GetCaster()
		local current_stack = self:GetStackCount()

		if not self.debt_pct then self:CacheValues() end
		if not self.decay_per_second then return end

		if caster:PassivesDisabled() or not caster:IsAlive() then
			return
		end

		local time_since_damage = GameRules:GetGameTime() - (self.last_damage_time or GameRules:GetGameTime())

		if time_since_damage >= self.decay_delay then
			-- Долг тает
			local decay_amount = self.decay_per_second * 0.1  -- 0.1 сек интервал
			local new_stack = math.max(0, current_stack - decay_amount)

			if math.floor(new_stack) ~= current_stack then
				self:SetStackCount(math.floor(new_stack))
			end
		end
	end

	function satan_blood_debt_counter:OnTakeDamage(params)
		if params.unit ~= self:GetParent() then return end

		local damage = params.damage
		local current_time = GameRules:GetGameTime()
		self.last_damage_time = current_time

		if not self.debt_pct then self:CacheValues() end
		if not self.debt_pct then return end

		local debt_add = damage * self.debt_pct / 100
		local new_stack = self:GetStackCount() + debt_add

		self:SetStackCount(math.floor(new_stack))
	end
end

function satan_blood_debt_counter:GetModifierPreAttack_BonusDamage()
	local caster = self:GetCaster()

	if caster:PassivesDisabled() then return 0 end
	if not self.debt_per_damage or not self.max_bonus_damage then return 0 end

	local debt = self:GetStackCount()
	local bonus = (debt / self.debt_per_damage)
	bonus = math.min(bonus, self.max_bonus_damage)

	return bonus
end
