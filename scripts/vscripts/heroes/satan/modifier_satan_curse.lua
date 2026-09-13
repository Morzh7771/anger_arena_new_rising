modifier_satan_curse = class({})

function modifier_satan_curse:IsPurgable( ... )
	return false
end

function modifier_satan_curse:IsDebuff( ... )
	return true
end

function modifier_satan_curse:GetEffectName( ... )
	return "particles/units/heroes/hero_shadow_demon/shadow_demon_demonic_purge_debuff.vpcf"
end

function modifier_satan_curse:CheckState( ... )
	local states = {
		[MODIFIER_STATE_DISARMED] = true,
		[MODIFIER_STATE_SILENCED] = true,
		[MODIFIER_STATE_PASSIVES_DISABLED] = true,
		[MODIFIER_STATE_MUTED] = true,
		[MODIFIER_STATE_BLIND] = true,
	}
	return states
end

function modifier_satan_curse:OnCreated( ... )
	self.slow = self:GetAbility():GetSpecialValueFor("slow")
	self.scepter_enabled = self:GetAbility():GetSpecialValueFor("scepter_enabled")
	self.scepter_jump_radius = self:GetAbility():GetSpecialValueFor("scepter_jump_radius")
	self.scepter_jump_duration = self:GetAbility():GetSpecialValueFor("scepter_jump_duration")
end

function modifier_satan_curse:DeclareFunctions( ... )
	local funcs = {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
	}
	if IsServer() and self.scepter_enabled == 1 then
		table.insert(funcs, MODIFIER_EVENT_ON_DEATH)
	end
	return funcs
end

function modifier_satan_curse:GetModifierMoveSpeedBonus_Percentage( ... )
	return self.slow
end

if IsServer() then
	function modifier_satan_curse:OnDeath(params)
		if params.unit ~= self:GetParent() then return end
		if self.scepter_enabled ~= 1 then return end

		local target = self:GetParent()
		local caster = self:GetCaster()
		local ability = self:GetAbility()

		if not target or not caster or not ability then return end

		local remaining_duration = self:GetRemainingTime()
		if remaining_duration <= 0 then remaining_duration = self.scepter_jump_duration end

		-- Ищем врагов в радиусе для перепрыгивания
		local radius = self.scepter_jump_radius
		if radius <= 0 then return end

		local enemies = FindUnitsInRadius(
			caster:GetTeamNumber(),
			target:GetOrigin(),
			nil,
			radius,
			DOTA_UNIT_TARGET_TEAM_ENEMY,
			DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
			DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
			FIND_ANY_ORDER,
			false
		)

		for _, enemy in ipairs(enemies) do
			if enemy ~= target and not enemy:HasModifier("modifier_satan_curse") then
				enemy:AddNewModifier(caster, ability, "modifier_satan_curse", {duration = remaining_duration})
			end
		end
	end
end