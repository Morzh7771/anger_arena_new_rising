-- Король-Мертвец (npc_aa_leoric). Ключ: убить - половина дела, пока лежит -
-- разбить надгробия. Все скиллы видны заранее: замах, круг, кольцо.

require("creeps/boss/boss_kit")

LinkLuaModifier("modifier_leoric_skull_anchor",  "creeps/boss/leoric/leoric_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_leoric_skeleton",      "creeps/boss/leoric/leoric_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_leoric_bone_slow",     "creeps/boss/leoric/leoric_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_leoric_reincarnation", "creeps/boss/leoric/leoric_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_leoric_fallen",        "creeps/boss/leoric/leoric_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_leoric_mortal_strike", "creeps/boss/leoric/leoric_abilities", LUA_MODIFIER_MOTION_NONE)

local SKULL_FX   = "particles/units/heroes/hero_skeletonking/skeletonking_hellfireblast.vpcf"
local WARMUP_FX  = "particles/units/heroes/hero_skeletonking/skeletonking_hellfireblast_warmup.vpcf"
local BLAST_FX   = "particles/units/heroes/hero_skeletonking/skeletonking_hellfireblast_explosion.vpcf"
local STOMP_FX   = "particles/econ/items/centaur/centaur_ti6/centaur_ti6_warstomp.vpcf"
local BITS_FX    = "particles/units/heroes/hero_skeletonking/skeleton_king_death_bits.vpcf"
local REINC_FX   = "particles/units/heroes/hero_skeletonking/skeleton_king_reincarnate.vpcf"
local TOMB_UP_FX = "particles/units/heroes/hero_undying/undying_tombstone_spawn.vpcf"
local TOMB_DN_FX = "particles/units/heroes/hero_undying/undying_tombstone_destruction.vpcf"
local MARK_FX    = "particles/generic_gameplay/generic_has_quest.vpcf"
local ALERT_FX   = "particles/msg_fx/msg_aggro.vpcf"
local CRIT_FX    = "particles/units/heroes/hero_skeletonking/skeleton_king_weapon_blur_critical.vpcf"

local function Flat(v)
	return Vector(v.x, v.y, 0)
end

--------------------------------------------------------------------------------
-- Адский веер: замах, затем веер черепов. Между черепами - щели.
--------------------------------------------------------------------------------
leoric_hellfire_fan = leoric_hellfire_fan or class({})
local fan = leoric_hellfire_fan

-- направления черепов: считаются на замахе, по ним рисуются линии
function fan:_Dirs()
	local caster = self:GetCaster()
	local origin = caster:GetAbsOrigin()

	local dir = Flat(self:GetCursorPosition() - origin)
	if dir:Length2D() < 1 then dir = Flat(caster:GetForwardVector()) end
	dir = dir:Normalized()

	local count = self:GetSpecialValueFor("count")
	if caster:GetHealthPercent() < self:GetSpecialValueFor("low_hp_pct") then
		count = self:GetSpecialValueFor("count_low_hp")
	end

	local spread = self:GetSpecialValueFor("spread")
	local dirs = {}
	for i = 1, count do
		local angle = (i - (count + 1) / 2) * spread
		table.insert(dirs, RotatePosition(Vector(0, 0, 0), QAngle(0, angle, 0), dir))
	end
	return dirs
end

function fan:OnAbilityPhaseStart()
	if not IsServer() then return true end
	local caster = self:GetCaster()
	local origin = caster:GetAbsOrigin()
	local range = self:GetSpecialValueFor("range")
	local width = self:GetSpecialValueFor("width")

	self.warm = ParticleManager:CreateParticle(WARMUP_FX, PATTACH_ABSORIGIN_FOLLOW, caster)
	caster:EmitSound("Hero_SkeletonKing.Hellfire_Blast")

	-- красные линии: куда полетит каждый череп
	self.dirs = self:_Dirs()
	self.lines = {}
	for _, d in pairs(self.dirs) do
		table.insert(self.lines, BossKit:TelegraphLine(origin, origin + d * range, width, nil))
	end
	return true
end

function fan:_ClearLines()
	for _, l in pairs(self.lines or {}) do BossKit:StopParticle(l) end
	self.lines = nil
end

function fan:OnAbilityPhaseInterrupted()
	BossKit:StopParticle(self.warm)
	self.warm = nil
	self:_ClearLines()
	self.dirs = nil
end

function fan:OnSpellStart()
	BossKit:StopParticle(self.warm)
	self.warm = nil
	self:_ClearLines()

	local caster = self:GetCaster()
	local origin = caster:GetAbsOrigin()

	local dirs = self.dirs or self:_Dirs()
	self.dirs = nil

	local speed  = self:GetSpecialValueFor("speed")
	local range  = self:GetSpecialValueFor("range")
	local width  = self:GetSpecialValueFor("width")

	self.skulls = self.skulls or {}
	self.skullId = (self.skullId or 0)

	for _, d in pairs(dirs) do
		local endPos = origin + d * range

		self.skullId = self.skullId + 1
		local key = self.skullId

		-- черепу нужна цель: невидимый якорь в конце полёта
		local anchor = CreateModifierThinker(caster, self, "modifier_leoric_skull_anchor",
			{ duration = range / speed + 0.5 }, endPos, caster:GetTeamNumber(), false)

		local visual = ProjectileManager:CreateTrackingProjectile({
			Target = anchor,
			Source = caster,
			Ability = self,
			EffectName = SKULL_FX,
			iMoveSpeed = speed,
			bDodgeable = false,
			iSourceAttachment = DOTA_PROJECTILE_ATTACHMENT_ATTACK_1,
			ExtraData = { visual = 1 },
		})

		ProjectileManager:CreateLinearProjectile({
			Ability = self,
			EffectName = "",
			vSpawnOrigin = origin,
			fDistance = range,
			fStartRadius = width,
			fEndRadius = width,
			Source = caster,
			iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_ENEMY,
			iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
			iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
			vVelocity = d * speed,
			ExtraData = { key = key },
		})

		self.skulls[key] = { visual = visual, anchor = anchor }
	end
end

function fan:_DropSkull(key)
	local s = self.skulls and self.skulls[key]
	if not s then return end
	self.skulls[key] = nil

	if s.visual then ProjectileManager:DestroyTrackingProjectile(s.visual) end
	if s.anchor and not s.anchor:IsNull() then UTIL_Remove(s.anchor) end
end

function fan:OnProjectileHit_ExtraData(target, location, data)
	if data.visual == 1 then return true end

	local key = data.key

	if not target then
		self:_DropSkull(key)
		return true
	end

	local caster = self:GetCaster()

	BossKit:PctDamage(caster, self, target, self:GetSpecialValueFor("damage_pct"))
	target:AddNewModifier(caster, self, "modifier_stunned",
		{ duration = self:GetSpecialValueFor("stun") * (1 - target:GetStatusResistance()) })

	local fx = ParticleManager:CreateParticle(BLAST_FX, PATTACH_ABSORIGIN, target)
	ParticleManager:ReleaseParticleIndex(fx)
	target:EmitSound("Hero_SkeletonKing.Hellfire_BlastImpact")

	self:_DropSkull(key)
	return true
end

modifier_leoric_skull_anchor = modifier_leoric_skull_anchor or class({})
function modifier_leoric_skull_anchor:IsHidden() return true end
function modifier_leoric_skull_anchor:OnDestroy()
	if IsServer() and not self:GetParent():IsNull() then UTIL_Remove(self:GetParent()) end
end

--------------------------------------------------------------------------------
-- Кольцо костей: скелеты встают кольцом и сходятся к Королю.
-- Дошёл - лечит его. Задел героя - взрывается. Ломается N ударами.
--------------------------------------------------------------------------------
leoric_bone_ring = leoric_bone_ring or class({})
local ring = leoric_bone_ring

function ring:Precache(ctx)
	PrecacheResource("model", "models/creeps/neutral_creeps/n_creep_troll_skeleton/n_creep_skeleton_melee.vmdl", ctx)
	PrecacheUnitByNameSync("npc_aa_leoric_skeleton", ctx)
end

-- точки скелетов считаются на замахе: там заранее горят круги
function ring:_Points()
	local caster = self:GetCaster()
	local origin = caster:GetAbsOrigin()
	local count  = self:GetSpecialValueFor("count") + self:GetSpecialValueFor("count_per_death") * math.min(BossKit:Deaths(caster), 2)
	local radius = self:GetSpecialValueFor("radius")
	local start  = RandomFloat(0, 360)
	local res = {}
	for i = 1, count do
		local d = RotatePosition(Vector(0, 0, 0), QAngle(0, start + 360 / count * i, 0), Vector(1, 0, 0))
		table.insert(res, { pos = GetGroundPosition(origin + d * radius, nil), dir = d })
	end
	return res
end

function ring:OnAbilityPhaseStart()
	if not IsServer() then return true end
	self.points = self:_Points()
	self.marks = {}
	for _, pt in pairs(self.points) do
		table.insert(self.marks, BossKit:Telegraph(pt.pos, self:GetSpecialValueFor("explode_radius") + 30, self:GetCastPoint()))
	end
	self:GetCaster():EmitSound("Hero_SkeletonKing.MortalStrike.Cast")
	return true
end

function ring:OnAbilityPhaseInterrupted()
	for _, m in pairs(self.marks or {}) do BossKit:StopParticle(m) end
	self.marks, self.points = nil, nil
end

function ring:OnSpellStart()
	local caster = self:GetCaster()
	local hits   = self:GetSpecialValueFor("hits")
	local points = self.points or self:_Points()
	self.points, self.marks = nil, nil

	for _, pt in pairs(points) do
		local d, pos = pt.dir, pt.pos

		local sk = CreateUnitByName("npc_aa_leoric_skeleton", pos, false, nil, nil, caster:GetTeamNumber())
		if sk then
			sk:SetForwardVector(-d)
			sk:AddNewModifier(caster, self, "modifier_leoric_skeleton", {})
			BossKit:MakePips(sk, caster, self, hits, nil)

			local fx = ParticleManager:CreateParticle(TOMB_UP_FX, PATTACH_WORLDORIGIN, nil)
			ParticleManager:SetParticleControl(fx, 0, pos)
			ParticleManager:ReleaseParticleIndex(fx)
		end
	end
end

modifier_leoric_skeleton = modifier_leoric_skeleton or class({})
local skel = modifier_leoric_skeleton

function skel:IsHidden()   return true end
function skel:IsPurgable() return false end

function skel:CheckState()
	return {
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		[MODIFIER_STATE_DISARMED] = true,
		[MODIFIER_STATE_COMMAND_RESTRICTED] = true,
	}
end

function skel:OnCreated()
	if not IsServer() then return end
	local ab = self:GetAbility()
	self.healPct  = ab:GetSpecialValueFor("heal_pct")
	self.boomR    = ab:GetSpecialValueFor("explode_radius")
	self.boomPct  = ab:GetSpecialValueFor("explode_damage_pct")
	self.slowDur  = ab:GetSpecialValueFor("slow_duration")
	self.nextMove = 0
	self:StartIntervalThink(0.1)
end

function skel:_Die()
	local p = self:GetParent()
	local fx = ParticleManager:CreateParticle(BITS_FX, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(fx, 0, p:GetAbsOrigin())
	ParticleManager:ReleaseParticleIndex(fx)
	self:StartIntervalThink(-1)
	p:ForceKill(false)
end

function skel:OnIntervalThink()
	local p = self:GetParent()
	local boss = self:GetCaster()
	local ab = self:GetAbility()

	if not p:IsAlive() then return self:StartIntervalThink(-1) end
	if not boss or boss:IsNull() or not boss:IsAlive() or not ab or ab:IsNull() then return self:_Die() end

	local pos = p:GetAbsOrigin()

	local victims = BossKit:Enemies(boss, pos, self.boomR)
	if #victims > 0 then
		for _, v in pairs(victims) do
			BossKit:PctDamage(boss, ab, v, self.boomPct)
			v:AddNewModifier(boss, ab, "modifier_leoric_bone_slow", { duration = self.slowDur })
		end
		local fx = ParticleManager:CreateParticle(BLAST_FX, PATTACH_WORLDORIGIN, nil)
		ParticleManager:SetParticleControl(fx, 0, pos)
		ParticleManager:ReleaseParticleIndex(fx)
		p:EmitSound("Hero_SkeletonKing.Hellfire_BlastImpact")
		return self:_Die()
	end

	if (pos - boss:GetAbsOrigin()):Length2D() <= 160 then
		if not boss:HasModifier("modifier_leoric_fallen") then
			boss:Heal(boss:GetMaxHealth() * self.healPct / 100, ab)
			SendOverheadEventMessage(nil, OVERHEAD_ALERT_HEAL, boss, boss:GetMaxHealth() * self.healPct / 100, nil)
		end
		return self:_Die()
	end

	local now = GameRules:GetGameTime()
	if now >= self.nextMove then
		self.nextMove = now + 0.5
		p:MoveToPosition(boss:GetAbsOrigin())
	end
end

modifier_leoric_bone_slow = modifier_leoric_bone_slow or class({})
function modifier_leoric_bone_slow:IsDebuff() return true end
function modifier_leoric_bone_slow:GetEffectName() return "particles/generic_gameplay/generic_slowed_cold.vpcf" end
function modifier_leoric_bone_slow:DeclareFunctions() return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE } end
function modifier_leoric_bone_slow:OnCreated() local a = self:GetAbility() self.slow = a and a:GetSpecialValueFor("slow") or 0 end
function modifier_leoric_bone_slow:GetModifierMoveSpeedBonus_Percentage() return -self.slow end

--------------------------------------------------------------------------------
-- Могильный удар: меч вверх, круг перед Королём, через секунду удар.
--------------------------------------------------------------------------------
leoric_grave_slam = leoric_grave_slam or class({})
local slam = leoric_grave_slam

function slam:_Center()
	local caster = self:GetCaster()
	return caster:GetAbsOrigin() + Flat(caster:GetForwardVector()):Normalized() * self:GetSpecialValueFor("offset")
end

function slam:OnAbilityPhaseStart()
	if not IsServer() then return true end
	self.center = self:_Center()
	self.mark = BossKit:Telegraph(self.center, self:GetSpecialValueFor("radius"), self:GetCastPoint())
	self:GetCaster():EmitSound("Hero_SkeletonKing.PreAttack")
	return true
end

function slam:OnAbilityPhaseInterrupted()
	BossKit:StopParticle(self.mark)
	self.mark = nil
end

function slam:OnSpellStart()
	local caster = self:GetCaster()
	local center = self.center or self:_Center()
	local radius = self:GetSpecialValueFor("radius")
	self.mark = nil

	for _, v in pairs(BossKit:Enemies(caster, center, radius)) do
		BossKit:PctDamage(caster, self, v, self:GetSpecialValueFor("damage_pct"))
		v:AddNewModifier(caster, self, "modifier_stunned",
			{ duration = self:GetSpecialValueFor("stun") * (1 - v:GetStatusResistance()) })
	end

	local fx = ParticleManager:CreateParticle(STOMP_FX, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(fx, 0, center)
	ParticleManager:SetParticleControl(fx, 1, Vector(radius, 0, 0))
	ParticleManager:ReleaseParticleIndex(fx)
	caster:EmitSound("Hero_SkeletonKing.CriticalStrike")
end

--------------------------------------------------------------------------------
-- Реинкарнация: на 0 HP падает, встают надгробия. Разбили все за окно -
-- он мёртв (убийство тому, кто разбил последнее). Не успели - встаёт.
--------------------------------------------------------------------------------
leoric_reincarnation = leoric_reincarnation or class({})
function leoric_reincarnation:Precache(ctx)
	PrecacheResource("model", "models/heroes/undying/undying_tower.vmdl", ctx)
	PrecacheUnitByNameSync("npc_aa_leoric_tombstone", ctx)
end

function leoric_reincarnation:GetIntrinsicModifierName() return "modifier_leoric_reincarnation" end

modifier_leoric_reincarnation = modifier_leoric_reincarnation or class({})
local reinc = modifier_leoric_reincarnation

function reinc:IsHidden()   return true end
function reinc:IsPurgable() return false end
function reinc:RemoveOnDeath() return false end

function reinc:DeclareFunctions()
	return { MODIFIER_PROPERTY_MIN_HEALTH, MODIFIER_EVENT_ON_TAKEDAMAGE }
end

function reinc:GetMinHealth()
	if self.used or self.killing then return 0 end
	return 1
end

function reinc:OnTakeDamage(params)
	if not IsServer() then return end
	local p = self:GetParent()
	if params.unit ~= p then return end
	if self.used or self.falling then return end
	if p:GetHealth() > 1 then return end

	self:_Fall()
end

function reinc:_Fall()
	local p = self:GetParent()
	local ab = self:GetAbility()

	self.falling = true
	self.stones = {}

	local window = ab:GetSpecialValueFor("window")
	local count  = ab:GetSpecialValueFor("stones")
	local hits   = ab:GetSpecialValueFor("stone_hits")
	local radius = ab:GetSpecialValueFor("stone_radius") + ab:GetSpecialValueFor("stone_radius_per_death") * math.min(BossKit:Deaths(p), 2)

	p:AddNewModifier(p, ab, "modifier_leoric_fallen", { duration = window })
	p:EmitSound("Hero_SkeletonKing.Death")

	local origin = p:GetAbsOrigin()
	local start = RandomFloat(0, 360)

	for i = 1, count do
		local d = RotatePosition(Vector(0, 0, 0), QAngle(0, start + 360 / count * i, 0), Vector(1, 0, 0))
		local pos = GetGroundPosition(origin + d * radius, nil)

		local stone = CreateUnitByName("npc_aa_leoric_tombstone", pos, false, nil, nil, p:GetTeamNumber())
		if stone then
			FindClearSpaceForUnit(stone, pos, true)
			table.insert(self.stones, stone)

			BossKit:MakePips(stone, p, ab, hits, function(attacker)
				self:_StoneBroken(stone, attacker)
			end)

			local up = ParticleManager:CreateParticle(TOMB_UP_FX, PATTACH_WORLDORIGIN, nil)
			ParticleManager:SetParticleControl(up, 0, pos)
			ParticleManager:ReleaseParticleIndex(up)

			-- "!" над надгробием - сюда бить
			stone.aa_mark = ParticleManager:CreateParticle(MARK_FX, PATTACH_OVERHEAD_FOLLOW, stone)
		end
	end
end

function reinc:_StoneBroken(stone, attacker)
	local fx = ParticleManager:CreateParticle(TOMB_DN_FX, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(fx, 0, stone:GetAbsOrigin())
	ParticleManager:ReleaseParticleIndex(fx)
	BossKit:StopParticle(stone.aa_mark)
	stone:EmitSound("Hero_SkeletonKing.Attack.Impact")

	for i, s in pairs(self.stones) do
		if s == stone then table.remove(self.stones, i) break end
	end

	if #self.stones > 0 then return end

	-- все разбиты: Король умирает окончательно
	local p = self:GetParent()
	self.killing = true
	self.used = true
	p:RemoveModifierByName("modifier_leoric_fallen")
	p:Kill(self:GetAbility(), BossKit:KillCredit(attacker))
end

-- окно вышло: убрать оставшиеся надгробия, встать с частью здоровья
function reinc:_Rise()
	local p = self:GetParent()
	local ab = self:GetAbility()

	for _, s in pairs(self.stones or {}) do
		if s and not s:IsNull() then
			BossKit:StopParticle(s.aa_mark)
			UTIL_Remove(s)
		end
	end
	self.stones = {}
	self.falling = false
	self.used = true

	if not p:IsAlive() then return end

	p:SetHealth(p:GetMaxHealth() * ab:GetSpecialValueFor("revive_pct") / 100)

	local fx = ParticleManager:CreateParticle(REINC_FX, PATTACH_ABSORIGIN, p)
	ParticleManager:SetParticleControl(fx, 1, Vector(500, 0, 0))
	ParticleManager:ReleaseParticleIndex(fx)
	p:EmitSound("Hero_SkeletonKing.Reincarnate")
	p:StartGesture(ACT_DOTA_SPAWN)
end

modifier_leoric_fallen = modifier_leoric_fallen or class({})
local fallen = modifier_leoric_fallen

function fallen:IsHidden()   return false end
function fallen:IsPurgable() return false end
function fallen:GetTexture() return "skeleton_king_reincarnation" end

function fallen:CheckState()
	return {
		[MODIFIER_STATE_INVULNERABLE] = true,
		[MODIFIER_STATE_STUNNED] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
	}
end

function fallen:DeclareFunctions() return { MODIFIER_PROPERTY_OVERRIDE_ANIMATION } end
function fallen:GetOverrideAnimation() return ACT_DOTA_DIE end

function fallen:OnDestroy()
	if not IsServer() then return end
	local reincMod = self:GetParent():FindModifierByName("modifier_leoric_reincarnation")
	if reincMod and not reincMod.killing then
		reincMod:_Rise()
	end
end

--------------------------------------------------------------------------------
-- Смертельный удар: каждый hits-й удар - крит, % от макс. HP цели и короткий
-- стан. Когда удар заряжен, над Королём "!", на замахе - круг под целью.
--------------------------------------------------------------------------------
leoric_mortal_strike = leoric_mortal_strike or class({})
function leoric_mortal_strike:GetIntrinsicModifierName() return "modifier_leoric_mortal_strike" end

modifier_leoric_mortal_strike = modifier_leoric_mortal_strike or class({})
local ms = modifier_leoric_mortal_strike

function ms:IsHidden()   return false end
function ms:IsPurgable() return false end
function ms:GetTexture() return "skeleton_king_mortal_strike" end

function ms:OnCreated()
	if not IsServer() then return end
	self:SetStackCount(0)
end

function ms:DeclareFunctions()
	return { MODIFIER_EVENT_ON_ATTACK_START, MODIFIER_EVENT_ON_ATTACK_LANDED, MODIFIER_EVENT_ON_ATTACK_FAIL }
end

function ms:_Charged()
	return self:GetStackCount() >= self:GetAbility():GetSpecialValueFor("hits") - 1
end

function ms:_SetCharge(n)
	self:SetStackCount(n)
	local p = self:GetParent()
	if self:_Charged() then
		if not self.alert then
			self.alert = ParticleManager:CreateParticle(ALERT_FX, PATTACH_OVERHEAD_FOLLOW, p)
			self.blur = ParticleManager:CreateParticle(CRIT_FX, PATTACH_ABSORIGIN_FOLLOW, p)
		end
	else
		BossKit:StopParticle(self.alert)
		BossKit:StopParticle(self.blur)
		self.alert, self.blur = nil, nil
	end
end

function ms:_ClearRing()
	BossKit:StopParticle(self.ring)
	self.ring = nil
end

function ms:OnAttackStart(params)
	if not IsServer() or params.attacker ~= self:GetParent() then return end
	if not self:_Charged() then return end
	local t = params.target
	if not t or t:IsNull() then return end
	self:_ClearRing()
	self.ring = BossKit:TelegraphFollow(t, 160, 0.6)
	self:GetParent():EmitSound("Hero_SkeletonKing.PreAttack")
	local ring = self.ring
	Timers:CreateTimer(1.5, function() if self.ring == ring then self:_ClearRing() end end)
end

function ms:OnAttackFail(params)
	if not IsServer() or params.attacker ~= self:GetParent() then return end
	self:_ClearRing()
end

function ms:OnAttackLanded(params)
	if not IsServer() then return end
	local p = self:GetParent()
	if params.attacker ~= p then return end
	local t = params.target
	if not t or t:IsNull() or t:IsBuilding() or t:GetTeamNumber() == p:GetTeamNumber() then return end

	if not self:_Charged() then
		self:_SetCharge(self:GetStackCount() + 1)
		return
	end

	self:_ClearRing()
	self:_SetCharge(0)

	local ab = self:GetAbility()
	local dealt = BossKit:PctDamage(p, ab, t, ab:GetSpecialValueFor("damage_pct"))
	t:AddNewModifier(p, ab, "modifier_stunned", { duration = ab:GetSpecialValueFor("stun") * (1 - t:GetStatusResistance()) })
	SendOverheadEventMessage(nil, OVERHEAD_ALERT_CRITICAL, t, dealt or 0, nil)
	t:EmitSound("Hero_SkeletonKing.CriticalStrike")
end

function ms:OnDestroy()
	if not IsServer() then return end
	self:_ClearRing()
	BossKit:StopParticle(self.alert)
	BossKit:StopParticle(self.blur)
end
