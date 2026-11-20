-- Voodoo Restoration на Lua: ванильное поведение (тоггл, мана в секунду, лечение союзников в радиусе)
-- плюс лечение в % от макс. ХП самого Witch Doctor и магический урон врагам в том же радиусе
-- с тем же интервалом. Все значения "в секунду", за тик берётся доля heal_interval.

LinkLuaModifier("modifier_witch_doctor_voodoo_restoration_lua", "heroes/witch_doctor/witch_doctor_voodoo_restoration", LUA_MODIFIER_MOTION_NONE)

witch_doctor_voodoo_restoration = class({})

function witch_doctor_voodoo_restoration:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_witchdoctor/witchdoctor_voodoo_restoration.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_witchdoctor/witchdoctor_voodoo_restoration_heal.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_witchdoctor.vsndevts", context)
end

function witch_doctor_voodoo_restoration:GetAOERadius()
	return self:GetSpecialValueFor("radius")
end

function witch_doctor_voodoo_restoration:ResetToggleOnRespawn()
	return true
end

function witch_doctor_voodoo_restoration:OnToggle()
	local caster = self:GetCaster()

	if self:GetToggleState() then
		caster:AddNewModifier(caster, self, "modifier_witch_doctor_voodoo_restoration_lua", {})
		caster:EmitSound("Hero_WitchDoctor.Voodoo_Restoration")
		caster:EmitSound("Hero_WitchDoctor.Voodoo_Restoration.Loop")
	else
		caster:RemoveModifierByName("modifier_witch_doctor_voodoo_restoration_lua")
	end
end

--------------------------------------------------------------------------------
modifier_witch_doctor_voodoo_restoration_lua = class({
	IsHidden = function() return false end,
	IsDebuff = function() return false end,
	IsPurgable = function() return false end,
})

function modifier_witch_doctor_voodoo_restoration_lua:OnCreated()
	if not IsServer() then return end

	local parent = self:GetParent()
	local ability = self:GetAbility()

	self.ally_fx = {}
	self.fx = ParticleManager:CreateParticle("particles/units/heroes/hero_witchdoctor/witchdoctor_voodoo_restoration.vpcf", PATTACH_ABSORIGIN_FOLLOW, parent)
	ParticleManager:SetParticleControl(self.fx, 1, Vector(ability:GetSpecialValueFor("radius"), 0, 0))
	ParticleManager:SetParticleControlEnt(self.fx, 2, parent, PATTACH_POINT_FOLLOW, "attach_staff", parent:GetAbsOrigin(), true)

	self:StartIntervalThink(ability:GetSpecialValueFor("heal_interval"))
end

function modifier_witch_doctor_voodoo_restoration_lua:OnIntervalThink()
	local parent = self:GetParent()
	local ability = self:GetAbility()

	if not ability or ability:IsNull() then self:Destroy() return end

	local interval = ability:GetSpecialValueFor("heal_interval")
	local mana = ability:GetSpecialValueFor("mana_per_second") * interval

	if parent:GetMana() < mana then
		if ability:GetToggleState() then ability:ToggleAbility() end
		return
	end

	parent:SpendMana(mana, ability)

	local radius = ability:GetSpecialValueFor("radius")
	local caster_hp = parent:GetMaxHealth()
	local heal_flat = ability:GetSpecialValueFor("heal")
	local heal_caster_pct = ability:GetSpecialValueFor("heal_caster_hp_pct") / 100
	local damage_caster_pct = ability:GetSpecialValueFor("damage_caster_hp_pct") / 100
	-- урон врагам: база (heal) + процент от макс. ХП кастера (damage_caster_hp_pct)
	local damage = (heal_flat + caster_hp * damage_caster_pct) * interval
	local origin = parent:GetAbsOrigin()

	local allies = FindUnitsInRadius(parent:GetTeamNumber(), origin, nil, radius,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES, FIND_ANY_ORDER, false)

	-- партикл лечения зацикленный: один на союзника, пока он в ауре
	local inside = {}

	for _, ally in pairs(allies) do
		local idx = ally:entindex()
		inside[idx] = true

		if not self.ally_fx[idx] then
			self.ally_fx[idx] = ParticleManager:CreateParticle("particles/units/heroes/hero_witchdoctor/witchdoctor_voodoo_restoration_heal.vpcf", PATTACH_ABSORIGIN_FOLLOW, ally)
		end

		local heal = (heal_flat + caster_hp * heal_caster_pct) * interval

		if heal > 0 and ally:GetHealth() < ally:GetMaxHealth() then
			ally:Heal(heal, ability)
		end
	end

	for idx, fx in pairs(self.ally_fx) do
		if not inside[idx] then
			ParticleManager:DestroyParticle(fx, false)
			ParticleManager:ReleaseParticleIndex(fx)
			self.ally_fx[idx] = nil
		end
	end

	if damage <= 0 then return end

	local enemies = FindUnitsInRadius(parent:GetTeamNumber(), origin, nil, radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

	for _, enemy in pairs(enemies) do
		ApplyDamage({
			victim = enemy,
			attacker = parent,
			damage = damage,
			damage_type = DAMAGE_TYPE_MAGICAL,
			ability = ability,
		})
	end
end

function modifier_witch_doctor_voodoo_restoration_lua:OnDestroy()
	if not IsServer() then return end

	local parent = self:GetParent()

	if self.fx then
		ParticleManager:DestroyParticle(self.fx, false)
		ParticleManager:ReleaseParticleIndex(self.fx)
	end

	for _, fx in pairs(self.ally_fx or {}) do
		ParticleManager:DestroyParticle(fx, false)
		ParticleManager:ReleaseParticleIndex(fx)
	end
	self.ally_fx = {}

	parent:StopSound("Hero_WitchDoctor.Voodoo_Restoration.Loop")
	parent:EmitSound("Hero_WitchDoctor.Voodoo_Restoration.Off")

	-- смерть или снятие модификатора извне: тоггл тоже выключаем
	local ability = self:GetAbility()
	if ability and not ability:IsNull() and ability:GetToggleState() then ability:ToggleAbility() end
end
