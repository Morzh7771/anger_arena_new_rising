
BaseClass = class({})
shadowsong_shadow_echo = BaseClass

LinkLuaModifier("shadowsong_shadow_echo_modifier", "heroes/shadowsong/shadowsong_shadow_echo", LUA_MODIFIER_MOTION_NONE)

function BaseClass:GetIntrinsicModifierName()
	return "shadowsong_shadow_echo_modifier"
end


shadowsong_shadow_echo_modifier = class({
	IsHidden = function(self) return false end,
	IsPurgable = function(self) return false end,
	IsDebuff = function(self) return false end,
	IsBuff = function(self) return true end,
	RemoveOnDeath = function(self) return true end,
	DeclareFunctions = function(self) return {
		MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
		MODIFIER_EVENT_ON_TAKEDAMAGE,
	}end,
})

function shadowsong_shadow_echo_modifier:CacheValues()
	local ability = self:GetAbility()

	if not ability then return end

	self.heal_per_mana = ability:GetSpecialValueFor("heal_per_mana")
	self.spell_lifesteal_pct = ability:GetSpecialValueFor("spell_lifesteal_pct")
end

function shadowsong_shadow_echo_modifier:OnCreated()
	self:CacheValues()
end

function shadowsong_shadow_echo_modifier:OnRefresh()
	self:CacheValues()
end

function shadowsong_shadow_echo_modifier:OnUpgrade()
	self:CacheValues()
end

if IsServer() then
	function shadowsong_shadow_echo_modifier:OnTakeDamage(params)
		if params.attacker ~= self:GetParent() then return end
		if params.damage_type ~= DAMAGE_TYPE_MAGICAL then return end

		local parent = self:GetParent()
		local heal_amount = params.original_damage * self.spell_lifesteal_pct / 100

		if heal_amount > 0 then
			parent:Heal(heal_amount, parent)
			SendOverheadEventMessage(parent, OVERHEAD_ALERT_HEAL, parent, heal_amount, nil)
		end
	end
end
