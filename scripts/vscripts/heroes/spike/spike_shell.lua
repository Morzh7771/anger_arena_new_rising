-- Spike: Thorn Shell. Порт из Angel Arena Global (angel_arena_shell).
-- Пассивка: возвращает атакующему return_damage% полученного урона чистым уроном.
-- Таланты: +% к возврату; возвращённый урон лечит Спайка (если удар не смертельный).

spike_shell = class({})

LinkLuaModifier("modifier_spike_shell", "heroes/spike/spike_shell", LUA_MODIFIER_MOTION_NONE)

function spike_shell:GetIntrinsicModifierName()
	return "modifier_spike_shell"
end

--------------------------------------------------------------------------------

modifier_spike_shell = class({})

function modifier_spike_shell:IsHidden() return true end
function modifier_spike_shell:IsPurgable() return false end
function modifier_spike_shell:RemoveOnDeath() return false end

function modifier_spike_shell:DeclareFunctions()
	return { MODIFIER_EVENT_ON_TAKEDAMAGE }
end

function modifier_spike_shell:OnTakeDamage(params)
	if not IsServer() then return end

	local parent = self:GetParent()
	local attacker = params.attacker
	local ability = self:GetAbility()

	if params.unit ~= parent or not ability or parent:PassivesDisabled() then return end
	if not attacker or attacker:IsNull() or attacker == parent or attacker:IsInvulnerable() then return end
	if attacker:GetTeamNumber() == parent:GetTeamNumber() then return end
	if bit.band(params.damage_flags, DOTA_DAMAGE_FLAG_REFLECTION) ~= 0 then return end
	if bit.band(params.damage_flags, DOTA_DAMAGE_FLAG_HPLOSS) ~= 0 then return end

	local returned = params.damage * ability:GetSpecialValueFor("return_damage") / 100
	if returned <= 0 then return end

	if ability:GetSpecialValueFor("heal_returned") > 0 and parent:IsAlive() then
		parent:Heal(returned, ability)
	end

	ApplyDamage({
		victim			= attacker,
		attacker		= parent,
		damage			= returned,
		damage_type		= DAMAGE_TYPE_PURE,
		ability			= ability,
		damage_flags	= DOTA_DAMAGE_FLAG_REFLECTION + DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION,
	})
end
