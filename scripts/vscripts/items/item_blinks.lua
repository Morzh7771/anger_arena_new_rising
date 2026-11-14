--[[
	Все блинки мода (Blink Dagger, Swift, Arcane, Overwhelming и их вторые уровни).

	Все блинки как в 1х6: урон от вражеского героя НЕ отправляет в перезарядку,
	а на blink_damage_cooldown секунд вешает дебафф, под которым дальность -
	1/damaged_range_div (по умолчанию 6) без бонуса дальности. Клик дальше
	дальности - прыжок на всю доступную дальность в ту сторону.

	Второй уровень (из души босса) не сбивается вообще и даёт доп. эффекты:
	  Swift 2: под эффектом базовое время атаки снижено на bat_reduction.
	  Arcane 2: лечит heal_pct %% макс. здоровья и маны (heal_pct_damaged %% под дебаффом).
	  Overwhelming 2: через second_wave_delay сек. в точке прыжка вторая волна.
]]

LinkLuaModifier("modifier_item_blink_aa_passive", "items/item_blinks", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_blink_aa_break", "items/item_blinks", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_swift_blink_aa_active", "items/item_blinks", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_overwhelming_blink_aa_debuff", "items/item_blinks", LUA_MODIFIER_MOTION_NONE)

---------------------------------------------------------------------------------------------------
-- Общая основа
---------------------------------------------------------------------------------------------------

local BlinkBase = {}

BlinkBase.pfx_start = "particles/items_fx/blink_dagger_start.vpcf"
BlinkBase.pfx_end = "particles/items_fx/blink_dagger_end.vpcf"
BlinkBase.sound = "DOTA_Item.BlinkDagger.Activate"

-- иконки как в 1х6: под "сбитым" дебаффом картинка блинка меняется
local BLINK_ICONS = {
	item_blink = "item_blink",
	item_swift_blink = "item_swift_blink",
	item_arcane_blink = "item_arcane_blink",
	item_overwhelming_blink = "item_overwhelming_blink",
	item_swift_blink_2 = "swift_blink3",
	item_arcane_blink_2 = "arcane_blink3",
	item_overwhelming_blink_2 = "overwhelming_blink3",
}

function BlinkBase:GetAbilityTextureName()
	local name = self:GetAbilityName()
	local icon = BLINK_ICONS[name] or "item_blink"

	if self:IsBroken() then
		-- своих "_break" картинок у второго уровня нет - берём от первого
		local base = string.gsub(name, "_2$", "")
		return "items/" .. (BLINK_ICONS[base] or "item_blink") .. "_break"
	end

	return icon
end

function BlinkBase:Precache(context)
	PrecacheResource("particle", self.pfx_start, context)
	PrecacheResource("particle", self.pfx_end, context)
end

function BlinkBase:GetIntrinsicModifierName()
	return "modifier_item_blink_aa_passive"
end

-- второй уровень (из души босса): имя кончается на _2
function BlinkBase:IsUpgradedBlink()
	return string.sub(self:GetAbilityName(), -2) == "_2"
end

-- владелец недавно получил урон от героя: дальность режется у всех блинков,
-- в том числе второго уровня (из души босса)
function BlinkBase:IsBroken()
	local caster = self:GetCaster()

	return caster and caster:HasModifier("modifier_item_blink_aa_break") or false
end

function BlinkBase:BrokenRange()
	local div = self:GetSpecialValueFor("damaged_range_div")

	if div <= 0 then div = 6 end

	return self:GetSpecialValueFor("blink_range") / div
end

-- полная дальность с бонусом дальности применения
function BlinkBase:MaxRange()
	if self:IsBroken() then return self:BrokenRange() end

	return self:GetSpecialValueFor("blink_range") + self:GetCaster():GetCastRangeBonus()
end

-- сервер кастует на любую дальность, сам решает, куда прыгнуть; клиент рисует круг
function BlinkBase:GetCastRange(location, target)
	if IsServer() then return 99999 end

	if self:IsBroken() then
		-- движок сам прибавит бонус дальности к кругу, вычитаем его
		return self:BrokenRange() - self:GetCaster():GetCastRangeBonus()
	end

	return self:GetSpecialValueFor("blink_range")
end

function BlinkBase:OnSpellStart()
	local caster = self:GetCaster()
	local origin = caster:GetAbsOrigin()
	local point = self:GetCursorPosition()
	local dir = point - origin
	dir.z = 0

	local max_range = self:MaxRange()

	if dir:Length2D() > max_range then
		point = origin + dir:Normalized() * max_range
	end

	if dir:Length2D() > 0 then
		caster:FaceTowards(point)
	end

	-- косметика премиума (слот blink_effect): 1-й партикл - старт, 2-й - конец
	local pfx_start = AACosmeticPath and AACosmeticPath(caster, "blink_effect", 1, self.pfx_start) or self.pfx_start
	local pfx_end = AACosmeticPath and AACosmeticPath(caster, "blink_effect", 2, self.pfx_end) or self.pfx_end

	local fx = ParticleManager:CreateParticle(pfx_start, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(fx, 0, origin)
	ParticleManager:ReleaseParticleIndex(fx)

	EmitSoundOnLocationWithCaster(origin, self.sound, caster)

	ProjectileManager:ProjectileDodge(caster)
	FindClearSpaceForUnit(caster, point, true)

	local fx_end = ParticleManager:CreateParticle(pfx_end, PATTACH_ABSORIGIN, caster)
	ParticleManager:ReleaseParticleIndex(fx_end)

	caster:EmitSound(self.sound)

	self:OnBlinked(origin, caster:GetAbsOrigin())
end

function BlinkBase:OnBlinked(from, to) end

-- имена ванильные: на них завязаны магазин, рецепты и общий откат "blink"
local function MakeBlink(names, extra)
	for _, name in ipairs(names) do
		local class_table = class({})

		for k, v in pairs(BlinkBase) do class_table[k] = v end
		for k, v in pairs(extra or {}) do class_table[k] = v end

		_G[name] = class_table
	end
end

---------------------------------------------------------------------------------------------------
-- Blink Dagger
---------------------------------------------------------------------------------------------------

MakeBlink({ "item_blink" })

---------------------------------------------------------------------------------------------------
-- Swift Blink
---------------------------------------------------------------------------------------------------

local swift = {
	pfx_start = "particles/items3_fx/blink_swift_start.vpcf",
	pfx_end = "particles/items3_fx/blink_swift_end.vpcf",
	sound = "DOTA_Item.Swift_Blink.Activate",
}

function swift:Precache(context)
	BlinkBase.Precache(self, context)
	PrecacheResource("particle", "particles/items3_fx/blink_swift_buff.vpcf", context)
end

function swift:OnBlinked()
	local caster = self:GetCaster()

	caster:AddNewModifier(caster, self, "modifier_item_swift_blink_aa_active", { duration = self:GetSpecialValueFor("duration") })
end

MakeBlink({ "item_swift_blink", "item_swift_blink_2" }, swift)

---------------------------------------------------------------------------------------------------
-- Arcane Blink
---------------------------------------------------------------------------------------------------

local arcane = {
	pfx_start = "particles/items3_fx/blink_arcane_start.vpcf",
	pfx_end = "particles/items3_fx/blink_arcane_end.vpcf",
	sound = "DOTA_Item.Arcane_Blink.Activate",
}

function arcane:OnBlinked()
	local caster = self:GetCaster()
	local heal = self:GetSpecialValueFor("heal_amount")
	local mana = self:GetSpecialValueFor("mana_amount")

	-- второй уровень: плюс процент от максимума (меньше, если недавно получал урон)
	if self:IsUpgradedBlink() then
		local damaged = self:GetCaster():HasModifier("modifier_item_blink_aa_break")
		local pct = damaged and self:GetSpecialValueFor("heal_pct_damaged") or self:GetSpecialValueFor("heal_pct")

		-- KV без этих ключей (не перезагружен) - значения по умолчанию
		if pct <= 0 then pct = damaged and 5 or 10 end

		heal = heal + math.floor(caster:GetMaxHealth() * pct / 100)
		mana = mana + math.floor(caster:GetMaxMana() * pct / 100)
	end

	if heal > 0 then
		caster:Heal(heal, self)
		SendOverheadEventMessage(nil, OVERHEAD_ALERT_HEAL, caster, heal, nil)
	end

	if mana > 0 then
		caster:GiveMana(mana)
		SendOverheadEventMessage(nil, OVERHEAD_ALERT_MANA_ADD, caster, mana, nil)
	end
end

MakeBlink({ "item_arcane_blink", "item_arcane_blink_2" }, arcane)

---------------------------------------------------------------------------------------------------
-- Overwhelming Blink
---------------------------------------------------------------------------------------------------

local overwhelming = {
	pfx_start = "particles/items3_fx/blink_overwhelming_start.vpcf",
	pfx_end = "particles/items3_fx/blink_overwhelming_end.vpcf",
	sound = "DOTA_Item.Overwhelming_Blink.Activate",
}

function overwhelming:Precache(context)
	BlinkBase.Precache(self, context)
	PrecacheResource("particle", "particles/items3_fx/blink_overwhelming_burst.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_brewmaster/brewmaster_thunder_clap_debuff.vpcf", context)
	PrecacheResource("particle", "particles/status_fx/status_effect_brewmaster_thunder_clap.vpcf", context)
end

-- волна: значения сняты заранее, чтобы вторая волна сработала и если предмет продали
local function OverwhelmingWave(caster, ability, point, radius, damage, duration)
	if not caster or caster:IsNull() then return end
	if ability and ability:IsNull() then ability = nil end

	local fx = ParticleManager:CreateParticle("particles/items3_fx/blink_overwhelming_burst.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(fx, 0, point)
	ParticleManager:SetParticleControl(fx, 1, Vector(radius, radius, radius))
	ParticleManager:ReleaseParticleIndex(fx)

	local enemies = FindUnitsInRadius(caster:GetTeamNumber(), point, nil, radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

	for _, enemy in ipairs(enemies) do
		ApplyDamage({
			victim = enemy,
			attacker = caster,
			damage = damage,
			damage_type = DAMAGE_TYPE_MAGICAL,
			ability = ability,
		})

		if ability and enemy:IsAlive() then
			enemy:AddNewModifier(caster, ability, "modifier_item_overwhelming_blink_aa_debuff", { duration = duration * (1 - enemy:GetStatusResistance()) })
		end
	end
end

function overwhelming:OnBlinked(from, to)
	local caster = self:GetCaster()
	local radius = self:GetSpecialValueFor("radius")
	local duration = self:GetSpecialValueFor("duration")
	local str = caster.GetStrength and caster:GetStrength() or 0
	local damage = self:GetSpecialValueFor("damage_base") + str * self:GetSpecialValueFor("damage_pct_instant") / 100

	OverwhelmingWave(caster, self, to, radius, damage, duration)

	local delay = self:GetSpecialValueFor("second_wave_delay")

	if delay <= 0 then delay = 2 end

	if self:IsUpgradedBlink() and delay > 0 then
		local ability = self

		caster:SetContextThink(DoUniqueString("overwhelming_blink_wave"), function()
			-- вторая волна под владельцем, где бы он ни был через delay сек.
			if caster:IsNull() or not caster:IsAlive() then return nil end

			OverwhelmingWave(caster, ability, caster:GetAbsOrigin(), radius, damage, duration)
			return nil
		end, delay)
	end
end

MakeBlink({ "item_overwhelming_blink", "item_overwhelming_blink_2" }, overwhelming)

---------------------------------------------------------------------------------------------------
-- Пассивка: статы предмета и реакция на урон от героев
---------------------------------------------------------------------------------------------------

modifier_item_blink_aa_passive = class({})

function modifier_item_blink_aa_passive:IsHidden() return true end
function modifier_item_blink_aa_passive:IsPurgable() return false end
function modifier_item_blink_aa_passive:RemoveOnDeath() return false end
function modifier_item_blink_aa_passive:GetAttributes() return MODIFIER_ATTRIBUTE_MULTIPLE end

function modifier_item_blink_aa_passive:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
		MODIFIER_EVENT_ON_TAKEDAMAGE,
	}
end

function modifier_item_blink_aa_passive:GetModifierBonusStats_Strength()
	local ability = self:GetAbility()
	return ability and ability:GetSpecialValueFor("bonus_strength") or 0
end

function modifier_item_blink_aa_passive:GetModifierBonusStats_Agility()
	local ability = self:GetAbility()
	return ability and ability:GetSpecialValueFor("bonus_agility") or 0
end

function modifier_item_blink_aa_passive:GetModifierBonusStats_Intellect()
	local ability = self:GetAbility()
	return ability and ability:GetSpecialValueFor("bonus_intellect") or 0
end

-- как в доте: считается урон от вражеских героев (и их иллюзий), кроме отражённого
function modifier_item_blink_aa_passive:OnTakeDamage(params)
	if not IsServer() then return end

	local parent = self:GetParent()

	if params.unit ~= parent then return end
	if params.damage <= 0 then return end

	local attacker = params.attacker

	if not attacker or attacker:IsNull() then return end
	if attacker:GetTeamNumber() == parent:GetTeamNumber() then return end
	if not attacker:IsHero() then return end
	if bit.band(params.damage_flags or 0, DOTA_DAMAGE_FLAG_REFLECTION) ~= 0 then return end

	local ability = self:GetAbility()

	if not ability or ability:IsNull() then return end

	local block = ability:GetSpecialValueFor("blink_damage_cooldown")

	if block <= 0 then return end

	-- как в 1х6: не перезарядка, а укороченная дальность. Сбивается и второй
	-- уровень (Arcane 2 по той же метке ещё и лечит меньше)
	parent:AddNewModifier(parent, ability, "modifier_item_blink_aa_break", { duration = block })
end

---------------------------------------------------------------------------------------------------
-- Второй уровень: недавно получил урон - дальность блинка уменьшена
---------------------------------------------------------------------------------------------------

modifier_item_blink_aa_break = class({})

function modifier_item_blink_aa_break:IsHidden() return false end
function modifier_item_blink_aa_break:IsDebuff() return true end
function modifier_item_blink_aa_break:IsPurgable() return false end

function modifier_item_blink_aa_break:GetTexture()
	return "item_blink"
end

---------------------------------------------------------------------------------------------------
-- Swift Blink: эффект после прыжка
---------------------------------------------------------------------------------------------------

modifier_item_swift_blink_aa_active = class({})

function modifier_item_swift_blink_aa_active:IsPurgable() return true end

function modifier_item_swift_blink_aa_active:GetTexture()
	return "item_swift_blink"
end

function modifier_item_swift_blink_aa_active:OnCreated()
	local ability = self:GetAbility()

	if not ability then return end

	self.move = ability:GetSpecialValueFor("bonus_movement")
	self.agi = ability:GetSpecialValueFor("bonus_agi_active")
	self.bat = ability:GetSpecialValueFor("bat_reduction")

	if not IsServer() then return end

	local parent = self:GetParent()

	-- BAT считает общий modifier_bat (стакает все снижения), он видит этот баф по имени
	if self.bat > 0 and not parent:HasModifier("modifier_bat") then
		parent:AddNewModifier(parent, nil, "modifier_bat", { duration = -1 })
	end

	local fx = ParticleManager:CreateParticle("particles/items3_fx/blink_swift_buff.vpcf", PATTACH_ABSORIGIN_FOLLOW, parent)
	self:AddParticle(fx, false, false, -1, false, false)

	parent:CalculateStatBonus(true)
end

function modifier_item_swift_blink_aa_active:OnRefresh()
	self:OnCreated()
end

function modifier_item_swift_blink_aa_active:OnDestroy()
	if not IsServer() then return end

	self:GetParent():CalculateStatBonus(true)
end

function modifier_item_swift_blink_aa_active:CheckState()
	return { [MODIFIER_STATE_NO_UNIT_COLLISION] = true }
end

-- BAT здесь не трогаем: снижение применяет modifier_bat (modifiers/modifier_bat.lua)
function modifier_item_swift_blink_aa_active:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_TOOLTIP,
	}
end

function modifier_item_swift_blink_aa_active:GetModifierMoveSpeedBonus_Percentage()
	return self.move or 0
end

function modifier_item_swift_blink_aa_active:GetModifierBonusStats_Agility()
	return self.agi or 0
end

-- в тултипе бафа: %dMODIFIER_PROPERTY_TOOLTIP% = снижение BAT в сотых
function modifier_item_swift_blink_aa_active:OnTooltip()
	return (self.bat or 0) * 100
end

---------------------------------------------------------------------------------------------------
-- Overwhelming Blink: замедление и урон со временем
---------------------------------------------------------------------------------------------------

modifier_item_overwhelming_blink_aa_debuff = class({})

function modifier_item_overwhelming_blink_aa_debuff:IsDebuff() return true end
function modifier_item_overwhelming_blink_aa_debuff:IsPurgable() return true end

function modifier_item_overwhelming_blink_aa_debuff:GetTexture()
	return "item_overwhelming_blink"
end

function modifier_item_overwhelming_blink_aa_debuff:GetStatusEffectName()
	return "particles/status_fx/status_effect_brewmaster_thunder_clap.vpcf"
end

function modifier_item_overwhelming_blink_aa_debuff:GetEffectName()
	return "particles/units/heroes/hero_brewmaster/brewmaster_thunder_clap_debuff.vpcf"
end

function modifier_item_overwhelming_blink_aa_debuff:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end

function modifier_item_overwhelming_blink_aa_debuff:OnCreated()
	local ability = self:GetAbility()

	if not ability then return end

	self.move = ability:GetSpecialValueFor("movement_slow")
	self.attack = ability:GetSpecialValueFor("attack_slow")

	if not IsServer() then return end

	local caster = self:GetCaster()
	local str = caster and caster.GetStrength and caster:GetStrength() or 0
	local total = str * ability:GetSpecialValueFor("damage_pct_over_time") / 100
	local duration = self:GetDuration()

	if total <= 0 or duration <= 0 then return end

	self.tick_damage = total / duration
	self:StartIntervalThink(1.0)
end

function modifier_item_overwhelming_blink_aa_debuff:OnRefresh()
	self:OnCreated()
end

function modifier_item_overwhelming_blink_aa_debuff:OnIntervalThink()
	local caster = self:GetCaster()

	if not caster or caster:IsNull() or not self.tick_damage then return end

	ApplyDamage({
		victim = self:GetParent(),
		attacker = caster,
		damage = self.tick_damage,
		damage_type = DAMAGE_TYPE_MAGICAL,
		ability = self:GetAbility(),
	})
end

function modifier_item_overwhelming_blink_aa_debuff:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
	}
end

function modifier_item_overwhelming_blink_aa_debuff:GetModifierMoveSpeedBonus_Percentage()
	return -(self.move or 0)
end

function modifier_item_overwhelming_blink_aa_debuff:GetModifierAttackSpeedBonus_Constant()
	return -(self.attack or 0)
end
