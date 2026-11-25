-- Gun Joe: Rapid (врождённая). Порт из Angel Arena Global, переделано во врождённую со скейлом от уровня.
-- Пока Джо cooldown секунд не получает урона от вражеских героев, у него бонус к скорости атаки
-- и скорости передвижения. Урон от героя сбивает бонус (способность уходит в перезарядку).
-- Бонус = база + за уровень героя. Талант: меньше время без урона.

gun_joe_rapid = class({})

LinkLuaModifier("modifier_gun_joe_rapid", "heroes/gun_joe/gun_joe_rapid", LUA_MODIFIER_MOTION_NONE)

function gun_joe_rapid:GetIntrinsicModifierName()
	return "modifier_gun_joe_rapid"
end

function gun_joe_rapid:GetCooldown(level)
	return self:GetSpecialValueFor("cooldown")
end

--------------------------------------------------------------------------------

modifier_gun_joe_rapid = class({})

-- IsCooldownReady есть только на сервере, а IsHidden и бонусы считает и клиент:
-- там сыпались ошибки. Остаток перезарядки есть на обеих сторонах.
local function Ready(ability)
	return ability:GetCooldownTimeRemaining() <= 0
end

function modifier_gun_joe_rapid:IsHidden()
	local ability = self:GetAbility()
	return not ability or not Ready(ability)
end

function modifier_gun_joe_rapid:IsPurgable() return false end
function modifier_gun_joe_rapid:RemoveOnDeath() return false end

function modifier_gun_joe_rapid:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
		MODIFIER_EVENT_ON_TAKEDAMAGE,
	}
end

function modifier_gun_joe_rapid:IsActive()
	local ability = self:GetAbility()
	return ability and Ready(ability) and not self:GetParent():PassivesDisabled()
end

function modifier_gun_joe_rapid:Value(base_key, level_key)
	local ability = self:GetAbility()
	return ability:GetSpecialValueFor(base_key) + ability:GetSpecialValueFor(level_key) * self:GetParent():GetLevel()
end

function modifier_gun_joe_rapid:GetModifierMoveSpeedBonus_Percentage()
	if self:IsActive() then return self:Value("bonus_movespeed", "movespeed_per_level") end
end

function modifier_gun_joe_rapid:GetModifierAttackSpeedBonus_Constant()
	if self:IsActive() then return self:Value("bonus_attackspeed", "attackspeed_per_level") end
end

function modifier_gun_joe_rapid:OnTakeDamage(params)
	if not IsServer() then return end
	if params.unit ~= self:GetParent() then return end

	local attacker = params.attacker
	if not attacker or attacker:IsNull() or not attacker:IsHero() then return end
	if attacker:GetTeamNumber() == self:GetParent():GetTeamNumber() then return end

	local ability = self:GetAbility()
	if ability then
		ability:StartCooldown(ability:GetEffectiveCooldown(ability:GetLevel() - 1))
	end
end
