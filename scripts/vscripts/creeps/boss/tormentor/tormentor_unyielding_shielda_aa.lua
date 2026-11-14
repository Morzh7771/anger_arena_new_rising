-- Unyielding Shield торментора. Механика перенесена из 1х6
-- (modifiers/creeps/modifier_tormentor_custom.lua), запас барьера - наш:
-- damage_absorb + absorb_bonus_per_interval за каждую минуту игры, как и было.
--
--  * барьер принимает весь урон, пока не кончится; потом урон идёт в 1 ХП;
--  * на health_1% и health_2% барьера - неуязвимость на invun_duration сек,
--    отражение в это время сильнее в invun_damage раз;
--  * на health_2% - поле: тех, кто был снаружи в момент появления, не пускает
--    внутрь и выталкивает;
--  * урон из-за радиуса (и от мёртвых) не проходит;
--  * если рядом герои двух и больше команд, барьер теряет на damage_reduce%
--    меньше;
--  * пока рядом нет вражеских героев, барьер восстанавливает regen% в секунду;
--  * после смерти лечит героев команды убийцы рядом на death_heal% ХП.
-- Отражение - в tormentor_reflect_aa.lua, зовётся отсюда.

LinkLuaModifier("modifier_tormentor_unyielding_shielda_aa", "creeps/boss/tormentor/tormentor_unyielding_shielda_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_tormentor_aa_invun", "creeps/boss/tormentor/tormentor_unyielding_shielda_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_tormentor_aa_field", "creeps/boss/tormentor/tormentor_unyielding_shielda_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_tormentor_aa_field_cd", "creeps/boss/tormentor/tormentor_unyielding_shielda_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_tormentor_aa_contested", "creeps/boss/tormentor/tormentor_unyielding_shielda_aa", LUA_MODIFIER_MOTION_NONE)

local THINK = 0.1

-- Партиклы по сторонам. Свет - по умолчанию, Тьма - если в имени конфига
-- босса есть "dire" (miniboss_dire).
local FX = {
	radiant = {
		shield  = "particles/neutral_fx/miniboss_shield.vpcf",
		death   = "particles/neutral_fx/miniboss_death.vpcf",
		knock   = "particles/tormentor/stun_target.vpcf",
		wave    = "particles/tormentor/stun_wave.vpcf",
		field   = "particles/tormentor/tormentor_knock_field.vpcf",
		electro = "particles/tormentor/stun_wave_electro.vpcf",
		invun   = "particles/generic/tormentor_invun_field_radiant.vpcf",
	},
	dire = {
		shield  = "particles/neutral_fx/miniboss_shield_dire.vpcf",
		death   = "particles/neutral_fx/miniboss_death_dire.vpcf",
		knock   = "particles/tormentor/stun_target_dire.vpcf",
		wave    = "particles/tormentor/stun_wave_dire.vpcf",
		field   = "particles/tormentor/tormentor_knock_field_dire.vpcf",
		electro = "particles/tormentor/stun_wave_electro_dire.vpcf",
		invun   = "particles/generic/tormentor_invun_field.vpcf",
	},
}
local FX_HEAL     = "particles/legion_commander/lc_odd_proc_.vpcf"
local FX_IMMUNE   = "particles/items_fx/backdoor_protection.vpcf"

-- В 1х6 тут были свои звуки, которых у нас нет; взяты похожие ванильные.
local SND_SPAWN       = "Miniboss.Tormenter.Spawn"
local SND_HIT         = "Miniboss.Tormenter.Target"
local SND_FIELD_START = "Hero_Disruptor.KineticField"
local SND_FIELD_END   = "Hero_Disruptor.KineticField.End"
local SND_KNOCK       = "Hero_Disruptor.KineticField.End"
local SND_INVUN       = "Hero_Zuus.ArcLightning.Target"

tormentor_unyielding_shielda_aa = class({
	GetIntrinsicModifierName = function (self) return "modifier_tormentor_unyielding_shielda_aa" end,
	Spawn = function (self) if IsServer() then return self:SetLevel(1) end end,
})

function tormentor_unyielding_shielda_aa:Precache(context)
	for _, side in pairs(FX) do
		for _, name in pairs(side) do
			PrecacheResource("particle", name, context)
		end
	end
	PrecacheResource("particle", FX_HEAL, context)
	PrecacheResource("particle", FX_IMMUNE, context)
	PrecacheResource("soundfile", "soundevents/game_sounds_creeps.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_disruptor.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_zuus.vsndevts", context)
end

local function SideFx(parent)
	local name = parent.aa_boss_name
	if name and name:find("dire") then return FX.dire end
	return FX.radiant
end

--------------------------------------------------------------------------------

modifier_tormentor_unyielding_shielda_aa = class({})

function modifier_tormentor_unyielding_shielda_aa:IsHidden() return false end
function modifier_tormentor_unyielding_shielda_aa:IsDebuff() return false end
function modifier_tormentor_unyielding_shielda_aa:IsPurgable() return false end
function modifier_tormentor_unyielding_shielda_aa:RemoveOnDeath() return false end

function modifier_tormentor_unyielding_shielda_aa:OnCreated()
	if not IsServer() then return end
	self.parent = self:GetParent()
	self.ability = self:GetAbility()
	local a = self.ability

	self.minArmor      = a:GetSpecialValueFor("min_armor")
	self.radius        = a:GetSpecialValueFor("radius")
	self.regenPct      = a:GetSpecialValueFor("regen") / 100
	self.regenDelay    = a:GetSpecialValueFor("regen_delay")
	self.contestedK    = 1 + a:GetSpecialValueFor("damage_reduce") / 100
	self.invunDuration = a:GetSpecialValueFor("invun_duration")
	self.fieldDuration = a:GetSpecialValueFor("field_duration")
	self.fieldHealth   = a:GetSpecialValueFor("health_2")
	self.deathHeal     = a:GetSpecialValueFor("death_heal") / 100

	-- пороги неуязвимости, по убыванию
	self.phases = {
		{ pct = a:GetSpecialValueFor("health_1"), done = false },
		{ pct = a:GetSpecialValueFor("health_2"), done = false },
	}

	self:UpdateMax()
	self.currentShield = self.maxShield

	-- Позицию берём на первом тике (InitVisuals): OnCreated срабатывает внутри
	-- CreateUnitByName, когда юнит ещё стоит в (0,0,0). SetNeverMoveToClearSpace
	-- здесь не давал движку перенести его на точку спавна - торменторы
	-- появлялись в центре карты.
	self.origin = self.parent:GetAbsOrigin()

	self:SetHasCustomTransmitterData(true)
	self:StartIntervalThink(THINK)
end

-- Запас барьера - здоровье босса из scripts/npc/boss_spawners.kv (как у всех
-- боссов: base_health + health_per_death за каждую смерть). BossSpawner
-- передаёт его сюда сразу после спавна, а ХП юнита ставит в 1.
function modifier_tormentor_unyielding_shielda_aa:SetMaxShield(value)
	self.fileMax = value
	self.maxShield = value
	self.currentShield = value
	self:SendBuffRefreshToClients()
end

-- Запасной вариант, если юнит заспавнили не через BossSpawner:
-- damage_absorb + absorb_bonus_per_interval за минуту.
function modifier_tormentor_unyielding_shielda_aa:UpdateMax()
	if self.fileMax then return end
	local minute = math.floor(GameRules:GetDOTATime(false, false) / 60)
	local a = self.ability
	local newMax = a:GetSpecialValueFor("damage_absorb") + a:GetSpecialValueFor("absorb_bonus_per_interval") * minute
	if self.maxShield and self.currentShield and newMax > self.maxShield then
		-- рост максимума не должен выглядеть как урон: добавляем и к текущему
		self.currentShield = self.currentShield + (newMax - self.maxShield)
	end
	self.maxShield = newMax
	if self.currentShield and self.currentShield > self.maxShield then
		self.currentShield = self.maxShield
	end
end

-- Партиклы и звук появления - на первом тике: к этому моменту BossSpawner
-- уже записал юниту имя конфига, и понятно, какая это сторона.
function modifier_tormentor_unyielding_shielda_aa:InitVisuals()
	self.fx = SideFx(self.parent)
	self.parent.aa_tormentor_fx = self.fx

	self.origin = self.parent:GetAbsOrigin()
	self.parent:SetNeverMoveToClearSpace(true)

	local p = ParticleManager:CreateParticle(self.fx.shield, PATTACH_CUSTOMORIGIN_FOLLOW, self.parent)
	ParticleManager:SetParticleControlEnt(p, 0, self.parent, PATTACH_POINT_FOLLOW, "attach_hitloc", self.parent:GetAbsOrigin(), true)
	self:AddParticle(p, false, false, -1, true, false)

	if self.fx == FX.dire then
		self.parent:SetMaterialGroup("1")
	end

	self.parent:EmitSound(SND_SPAWN)
	self.parent:StartGesture(ACT_DOTA_SPAWN)
end

-- Команды, у которых рядом есть живые герои.
function modifier_tormentor_unyielding_shielda_aa:TeamsNearby()
	local teams, count = {}, 0
	local heroes = FindUnitsInRadius(self.parent:GetTeamNumber(), self.origin, nil, self.radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO,
		DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_INVULNERABLE,
		FIND_ANY_ORDER, false)
	for _, hero in ipairs(heroes) do
		if hero:IsRealHero() and hero:IsAlive() then
			local team = hero:GetTeamNumber()
			if not teams[team] then
				teams[team] = true
				count = count + 1
			end
		end
	end
	return teams, count
end

function modifier_tormentor_unyielding_shielda_aa:OnIntervalThink()
	if not self.fx then self:InitVisuals() end
	if not self.parent:IsAlive() then return end

	self:UpdateMax()

	local teams, count = self:TeamsNearby()

	-- регенерация: рядом нет врагов или его не били regen_delay секунд
	local idle = GameRules:GetGameTime() - (self.lastHitTime or -math.huge) >= self.regenDelay
	if (count == 0 or idle) and self.currentShield < self.maxShield then
		self.currentShield = math.min(self.maxShield, self.currentShield + self.maxShield * self.regenPct * THINK)
	end

	-- оспаривание: рядом две и больше команд
	if count >= 2 then
		if not self.parent:HasModifier("modifier_tormentor_aa_contested") then
			self.parent:AddNewModifier(self.parent, self.ability, "modifier_tormentor_aa_contested", {})
		end
	else
		self.parent:RemoveModifierByName("modifier_tormentor_aa_contested")
	end

	-- поле на втором пороге
	if self.currentShield <= self.maxShield * self.fieldHealth / 100
		and not self.parent:HasModifier("modifier_tormentor_aa_field")
		and not self.parent:HasModifier("modifier_tormentor_aa_field_cd") then
		local field = self.parent:AddNewModifier(self.parent, self.ability, "modifier_tormentor_aa_field", { duration = self.fieldDuration })
		if field then field.teamsInside = teams end
	end

	self:SendBuffRefreshToClients()
end

function modifier_tormentor_unyielding_shielda_aa:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_INCOMING_DAMAGE_CONSTANT,
		MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
		MODIFIER_PROPERTY_TOOLTIP,
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
		MODIFIER_EVENT_ON_DEATH,
	}
end

function modifier_tormentor_unyielding_shielda_aa:CheckState()
	return {
		[MODIFIER_STATE_CANNOT_BE_MOTION_CONTROLLED] = true,
	}
end

function modifier_tormentor_unyielding_shielda_aa:AddCustomTransmitterData()
	return { currentShield = self.currentShield, maxShield = self.maxShield }
end

function modifier_tormentor_unyielding_shielda_aa:HandleCustomTransmitterData(data)
	self.currentShield = data.currentShield
	self.maxShield = data.maxShield
end

function modifier_tormentor_unyielding_shielda_aa:OnTooltip()
	return self.maxShield
end

-- Урон не проходит, если атакующий за радиусом, мёртв или (пока стоит поле)
-- из команды, которой не было внутри.
function modifier_tormentor_unyielding_shielda_aa:IsImmuneTo(attacker)
	if not attacker or attacker:IsNull() or not attacker:IsAlive() then return true end
	if (attacker:GetAbsOrigin() - self.origin):Length2D() > self.radius then return true end
	local field = self.parent:FindModifierByName("modifier_tormentor_aa_field")
	if field and field.teamsInside and not field.teamsInside[attacker:GetTeamNumber()] then return true end
	return false
end

-- Урон от Dispersion: по способности-источнику, а если её нет - по флагу
-- отражения от героя с Dispersion.
function modifier_tormentor_unyielding_shielda_aa:IsDispersion(event)
	local inflictor = event.inflictor
	if inflictor and not inflictor:IsNull() and inflictor.GetAbilityName
		and inflictor:GetAbilityName() == "spectre_dispersion" then
		return true
	end
	local attacker = event.attacker
	if attacker and not attacker:IsNull() and attacker.HasModifier
		and attacker:HasModifier("modifier_spectre_dispersion")
		and bit.band(event.damage_flags or 0, DOTA_DAMAGE_FLAG_REFLECTION) ~= 0 then
		return true
	end
	return false
end

-- Второй заслон для Dispersion: -100% входящего урона, если какой-то путь
-- урона обходит INCOMING_DAMAGE_CONSTANT.
function modifier_tormentor_unyielding_shielda_aa:GetModifierIncomingDamage_Percentage(event)
	if not IsServer() then return 0 end
	if self:IsDispersion(event) then return -100 end
	return 0
end

function modifier_tormentor_unyielding_shielda_aa:ShowImmune()
	local p = ParticleManager:CreateParticle(FX_IMMUNE, PATTACH_ABSORIGIN, self.parent)
	ParticleManager:SetParticleControl(p, 0, self.parent:GetAbsOrigin())
	ParticleManager:SetParticleControl(p, 1, Vector(300, 0, 0))
	ParticleManager:ReleaseParticleIndex(p)
end

function modifier_tormentor_unyielding_shielda_aa:GetModifierIncomingDamageConstant(event)
	if IsClient() then
		if event.report_max then return self.maxShield end
		return self.currentShield
	end

	local damage = event.damage
	if damage <= 0 then return 0 end

	-- Dispersion спектры щит не замечает: урон не проходит, не тратит
	-- прочность, не сбрасывает восстановление и не отражается. Проверка
	-- первая: раньше урон Dispersion уходил мимо щита по ветке HPLOSS и
	-- ваншотал торментора в его 1 ХП.
	if self:IsDispersion(event) then
		return -damage
	end

	-- Урон с HPLOSS (у торментора всего 1 ХП) тоже идёт в щит, а не мимо.

	local attacker = event.attacker
	if self:IsImmuneTo(attacker) then
		self:ShowImmune()
		return -damage
	end

	self.lastHitTime = GameRules:GetGameTime()

	local invun = self.parent:HasModifier("modifier_tormentor_aa_invun")
	local k = self.parent:HasModifier("modifier_tormentor_aa_contested") and self.contestedK or 1

	local block = damage
	if not invun then
		-- сколько урона уйдёт в барьер с учётом ослабления
		local loss = math.min(damage * k, self.currentShield)
		block = loss / k

		-- порог неуязвимости: барьер не опускается ниже него за один удар
		for _, phase in ipairs(self.phases) do
			if not phase.done then
				local floor = self.maxShield * phase.pct / 100
				if self.currentShield - loss < floor then
					loss = math.max(0, self.currentShield - floor)
					block = damage
					phase.done = true
					self.parent:AddNewModifier(self.parent, self.ability, "modifier_tormentor_aa_invun", { duration = self.invunDuration })
				end
				break
			end
		end

		self.currentShield = self.currentShield - loss
		self:SendBuffRefreshToClients()
	end

	self.parent:StartGesture(ACT_DOTA_FLINCH)
	attacker:EmitSound(SND_HIT)

	local reflect = self.parent:FindAbilityByName("tormentor_reflect_aa")
	if reflect and reflect.Reflect then
		reflect:Reflect(attacker, event.original_damage, event.damage_flags, invun)
	end

	return -block
end

function modifier_tormentor_unyielding_shielda_aa:GetModifierPhysicalArmorBonus()
	if not IsServer() then return end
	if self.checkArmor then return 0 end
	self.checkArmor = true
	local current = self.parent:GetPhysicalArmorValue(false)
	self.checkArmor = false
	if current < self.minArmor then
		return self.minArmor - current
	end
	return 0
end

function modifier_tormentor_unyielding_shielda_aa:OnDeath(keys)
	if not IsServer() then return end
	if keys.unit ~= self.parent then return end

	local fx = self.fx or SideFx(self.parent)
	local p = ParticleManager:CreateParticle(fx.death, PATTACH_ABSORIGIN_FOLLOW, self.parent)
	ParticleManager:SetParticleControl(p, 0, self.parent:GetAbsOrigin())
	ParticleManager:ReleaseParticleIndex(p)

	local killer = keys.attacker
	if not killer or killer:IsNull() then return end
	local team = killer:GetTeamNumber()

	local heroes = FindUnitsInRadius(team, self.origin, nil, self.radius,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_INVULNERABLE,
		FIND_ANY_ORDER, false)
	for _, hero in ipairs(heroes) do
		if hero:IsRealHero() and hero:IsAlive() then
			local heal = hero:GetMaxHealth() * self.deathHeal
			hero:Heal(heal, self.ability)
			SendOverheadEventMessage(nil, OVERHEAD_ALERT_HEAL, hero, heal, nil)
			local h = ParticleManager:CreateParticle(FX_HEAL, PATTACH_ABSORIGIN_FOLLOW, hero)
			ParticleManager:ReleaseParticleIndex(h)
		end
	end
end

--------------------------------------------------------------------------------
-- Неуязвимость на пороге.

modifier_tormentor_aa_invun = class({})

function modifier_tormentor_aa_invun:IsHidden() return true end
function modifier_tormentor_aa_invun:IsPurgable() return false end

function modifier_tormentor_aa_invun:OnCreated()
	if not IsServer() then return end
	local parent = self:GetParent()
	local fx = parent.aa_tormentor_fx or FX.radiant

	parent:EmitSound(SND_INVUN)

	local e = ParticleManager:CreateParticle(fx.electro, PATTACH_ABSORIGIN_FOLLOW, parent)
	ParticleManager:ReleaseParticleIndex(e)

	local p = ParticleManager:CreateParticle(fx.invun, PATTACH_ABSORIGIN_FOLLOW, parent)
	ParticleManager:SetParticleControl(p, 0, parent:GetAbsOrigin())
	ParticleManager:SetParticleControl(p, 1, Vector(300, 1, 1))
	self:AddParticle(p, false, false, -1, false, false)
end

--------------------------------------------------------------------------------
-- Ослабление урона по барьеру, когда рядом несколько команд.

modifier_tormentor_aa_contested = class({})

function modifier_tormentor_aa_contested:IsHidden() return true end
function modifier_tormentor_aa_contested:IsPurgable() return false end

function modifier_tormentor_aa_contested:OnCreated()
	if not IsServer() then return end
	local parent = self:GetParent()
	local fx = parent.aa_tormentor_fx or FX.radiant
	local p = ParticleManager:CreateParticle(fx.invun, PATTACH_ABSORIGIN_FOLLOW, parent)
	ParticleManager:SetParticleControl(p, 0, parent:GetAbsOrigin())
	ParticleManager:SetParticleControl(p, 1, Vector(300, 1, 1))
	self:AddParticle(p, false, false, -1, false, false)
end

--------------------------------------------------------------------------------
-- Поле: выталкивает тех, кого не было внутри при появлении.

modifier_tormentor_aa_field = class({})

function modifier_tormentor_aa_field:IsHidden() return true end
function modifier_tormentor_aa_field:IsPurgable() return false end

function modifier_tormentor_aa_field:OnCreated()
	if not IsServer() then return end
	local parent = self:GetParent()
	local ability = self:GetAbility()
	self.radius = ability:GetSpecialValueFor("radius")
	self.cd = ability:GetSpecialValueFor("field_cd")
	self.center = parent:GetAbsOrigin()
	self.fx = parent.aa_tormentor_fx or FX.radiant

	parent:EmitSound(SND_FIELD_START)

	local w = ParticleManager:CreateParticle(self.fx.wave, PATTACH_ABSORIGIN_FOLLOW, parent)
	ParticleManager:ReleaseParticleIndex(w)

	local p = ParticleManager:CreateParticle(self.fx.field, PATTACH_ABSORIGIN_FOLLOW, parent)
	ParticleManager:SetParticleControl(p, 0, self.center)
	ParticleManager:SetParticleControl(p, 1, Vector(self.radius, 1, 1))
	self:AddParticle(p, false, false, -1, false, false)

	self.knocked = {}
	self:StartIntervalThink(THINK)
end

function modifier_tormentor_aa_field:OnIntervalThink()
	local inside = self.teamsInside or {}
	local parent = self:GetParent()
	local now = GameRules:GetGameTime()

	local units = FindUnitsInRadius(parent:GetTeamNumber(), self.center, nil, self.radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES, FIND_CLOSEST, false)

	for _, unit in ipairs(units) do
		local id = unit:entindex()
		if not inside[unit:GetTeamNumber()] and (self.knocked[id] or 0) < now then
			self.knocked[id] = now + 0.25

			local dist = (unit:GetAbsOrigin() - self.center):Length2D()
			local push = self.radius * 1.1 - dist

			local p = ParticleManager:CreateParticle(self.fx.knock, PATTACH_ABSORIGIN_FOLLOW, parent)
			ParticleManager:SetParticleControl(p, 0, parent:GetAbsOrigin())
			ParticleManager:SetParticleControlEnt(p, 1, unit, PATTACH_POINT_FOLLOW, "attach_hitloc", unit:GetAbsOrigin(), true)
			ParticleManager:ReleaseParticleIndex(p)
			unit:EmitSound(SND_KNOCK)

			unit:InterruptMotionControllers(false)
			unit:AddNewModifier(parent, self:GetAbility(), "modifier_knockback", {
				center_x = self.center.x,
				center_y = self.center.y,
				center_z = self.center.z,
				knockback_distance = push,
				knockback_height = 0,
				knockback_duration = 0.2,
				duration = 0.2,
				should_stun = 1,
			})
		end
	end
end

function modifier_tormentor_aa_field:OnDestroy()
	if not IsServer() then return end
	local parent = self:GetParent()
	parent:EmitSound(SND_FIELD_END)
	if parent:IsAlive() then
		parent:AddNewModifier(parent, self:GetAbility(), "modifier_tormentor_aa_field_cd", { duration = self.cd })
	end
end

--------------------------------------------------------------------------------

modifier_tormentor_aa_field_cd = class({})

function modifier_tormentor_aa_field_cd:IsHidden() return false end
function modifier_tormentor_aa_field_cd:IsDebuff() return true end
function modifier_tormentor_aa_field_cd:IsPurgable() return false end
