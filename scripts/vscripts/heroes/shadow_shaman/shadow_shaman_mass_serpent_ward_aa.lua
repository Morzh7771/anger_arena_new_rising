--[[
	Mass Serpent Ward Расты на Lua - как в доте, но с любым числом уровней.
	Ванильная способность умеет только 3 уровня (юниты ward_1..3), выше
	змейки не появлялись. Имя способности ванильное, поэтому иконка, тексты
	и таланты остаются дотовские.

	Змейки - наши юниты npc_dota_shadow_shaman_ward_<уровень> (heroes/shadow_shaman/unit.txt),
	класс npc_dota_shadowshaman_serpentward сам считает здоровье ударами.

	Значения из KV:
	  ward_count            - сколько змеек
	  spawn_radius          - радиус кольца вокруг точки
	  duration              - время жизни
	  ward_health           - сколько ударов держит (талант shaman_1)
	  bonus_damage          - доп. урон (талант shaman_4)
	  bonus_attack_range    - доп. дальность (талант shaman_8)
	  bonus_attack_targets  - доп. цели атаки (талант shaman_4)
]]

LinkLuaModifier("modifier_shadow_shaman_serpent_ward_aa", "heroes/shadow_shaman/shadow_shaman_mass_serpent_ward_aa", LUA_MODIFIER_MOTION_NONE)

shadow_shaman_mass_serpent_ward = shadow_shaman_mass_serpent_ward or class({})

function shadow_shaman_mass_serpent_ward:GetAOERadius()
	return self:GetSpecialValueFor("spawn_radius")
end

function shadow_shaman_mass_serpent_ward:OnSpellStart()
	local caster = self:GetCaster()
	local point = self:GetCursorPosition()
	local level = math.max(1, self:GetLevel())

	local unit_name = "npc_dota_shadow_shaman_ward_" .. level
	local count = math.max(1, self:GetSpecialValueFor("ward_count"))
	local radius = self:GetSpecialValueFor("spawn_radius")
	local duration = self:GetSpecialValueFor("duration")
	local health = self:GetSpecialValueFor("ward_health")
	local playerID = caster:GetPlayerOwnerID()

	EmitSoundOnLocationWithCaster(point, "Hero_ShadowShaman.SerpentWard", caster)

	-- кольцо вокруг точки, первая змейка - в направлении от кастера (как в доте)
	local forward = point - caster:GetAbsOrigin()
	forward.z = 0
	if forward:Length2D() < 1 then forward = caster:GetForwardVector() end
	forward = forward:Normalized()

	for i = 0, count - 1 do
		local angle = 360 / count * i
		local pos = point + RotatePosition(Vector(0, 0, 0), QAngle(0, angle, 0), forward) * radius

		local ward = CreateUnitByName(unit_name, pos, false, caster, caster, caster:GetTeamNumber())

		if ward then
			ward:SetForwardVector(forward)
			ward:SetOwner(caster)
			if playerID and playerID >= 0 then
				ward:SetControllableByPlayer(playerID, true)
			end

			if health > 0 then
				ward:SetBaseMaxHealth(health)
				ward:SetMaxHealth(health)
				ward:SetHealth(health)
			end

			-- сплэш суммонов и бафф от статов хозяина выдаём сами: на юнитах,
			-- созданных из Lua, они сами не появлялись
			local cleave = ward:FindAbilityByName("summon_cleave") or ward:AddAbility("summon_cleave")
			if cleave then cleave:SetLevel(1) end

			if not ward:HasModifier("modifier_summon_power") then
				ward:AddNewModifier(caster, nil, "modifier_summon_power", {})
			end

			ward:AddNewModifier(caster, self, "modifier_kill", { duration = duration })
			ward:AddNewModifier(caster, self, "modifier_shadow_shaman_serpent_ward_aa", { duration = duration })
		end
	end

	-- юниты не встают друг в друга и в кастера
	ResolveNPCPositions(point, radius + 64)
end

--------------------------------------------------------------------------------
-- Таланты на змейке: урон, дальность, доп. цели
--------------------------------------------------------------------------------
modifier_shadow_shaman_serpent_ward_aa = class({})

function modifier_shadow_shaman_serpent_ward_aa:IsHidden() return true end
function modifier_shadow_shaman_serpent_ward_aa:IsPurgable() return false end

function modifier_shadow_shaman_serpent_ward_aa:OnCreated()
	local ability = self:GetAbility()

	self.damage = 0
	self.range = 0
	self.targets = 0

	if not ability or ability:IsNull() then return end

	self.damage = ability:GetSpecialValueFor("bonus_damage")
	self.range = ability:GetSpecialValueFor("bonus_attack_range")
	self.targets = ability:GetSpecialValueFor("bonus_attack_targets")
end

function modifier_shadow_shaman_serpent_ward_aa:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_BASEATTACK_BONUSDAMAGE,
		MODIFIER_PROPERTY_ATTACK_RANGE_BONUS,
		MODIFIER_EVENT_ON_ATTACK,
		MODIFIER_PROPERTY_HEALTHBAR_PIPS,
	}
end

function modifier_shadow_shaman_serpent_ward_aa:GetModifierBaseAttack_BonusDamage() return self.damage end
function modifier_shadow_shaman_serpent_ward_aa:GetModifierAttackRangeBonus() return self.range end

-- здоровье змейки = число ударов, показываем делениями
function modifier_shadow_shaman_serpent_ward_aa:GetModifierHealthBarPips() return self:GetParent():GetMaxHealth() end

-- доп. цели: выпускаем ещё атаки по ближайшим врагам в радиусе атаки
function modifier_shadow_shaman_serpent_ward_aa:OnAttack(keys)
	if not IsServer() then return end

	local ward = self:GetParent()

	if keys.attacker ~= ward or (self.targets or 0) <= 0 then return end
	if keys.no_attack_cooldown then return end -- это уже наша доп. атака

	local main = keys.target
	local left = self.targets

	for _, enemy in pairs(FindUnitsInRadius(ward:GetTeamNumber(), ward:GetAbsOrigin(), nil,
		ward:Script_GetAttackRange() + 50, DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NOT_ATTACK_IMMUNE + DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE,
		FIND_CLOSEST, false)) do
		if left <= 0 then break end

		if enemy ~= main then
			ward:PerformAttack(enemy, true, true, true, false, true, false, false)
			left = left - 1
		end
	end
end
