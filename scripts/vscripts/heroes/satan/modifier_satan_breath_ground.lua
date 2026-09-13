modifier_satan_breath_ground = class({})

function modifier_satan_breath_ground:IsHidden()
	return true
end

function modifier_satan_breath_ground:IsPurgable()
	return false
end

function modifier_satan_breath_ground:IsDebuff()
	return true
end

function modifier_satan_breath_ground:OnCreated()
	self.damage = 0
	if self:GetAbility() then
		self.damage = self:GetAbility():GetSpecialValueFor("shard_ground_damage")
	end

	if IsServer() then
		self:StartIntervalThink(1.0)
	end
end

if IsServer() then
	function modifier_satan_breath_ground:OnIntervalThink()
		local parent = self:GetParent()
		local caster = self:GetCaster()
		local ability = self:GetAbility()

		if not parent or not caster or not ability then
			self:Destroy()
			return
		end

		if self.damage <= 0 then return end

		local enemies = FindUnitsInRadius(
			caster:GetTeamNumber(),
			parent:GetOrigin(),
			nil,
			200,
			DOTA_UNIT_TARGET_TEAM_ENEMY,
			DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
			DOTA_UNIT_TARGET_FLAG_NONE,
			FIND_ANY_ORDER,
			false
		)

		for _, enemy in ipairs(enemies) do
			local damage_table = {
				victim = enemy,
				attacker = caster,
				damage = self.damage,
				damage_type = DAMAGE_TYPE_MAGICAL,
				ability = ability
			}
			ApplyDamage(damage_table)
		end
	end
end
