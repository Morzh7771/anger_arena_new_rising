--[[
	Urn of Shadows и Spirit Vessel (1-3) полностью на Lua.

	Как в доте:
	  - пассивно: статы, броня, реген маны (+ здоровье у вессела);
	  - активка тратит 1 заряд, цель - герой:
	      союзник: лечение soul_heal_amount в секунду на duration сек.;
	      враг:    soul_damage_amount чистого урона в секунду, у вессела ещё
	               enemy_hp_drain %% текущего здоровья магией в секунду и
	               restoration_reduction_enemy %% срезания лечения/регена/вампиризма;
	  - заряд за смерть вражеского героя в радиусе soul_radius: получает только
	    ближайшая к трупу урна команды, пустая урна получает soul_initial_charge,
	    иначе soul_additional_charges (lib/urn_charges.lua).
	Наше сверху (lib/urn_charges.lua):
	  - +1 заряд раз в 120 сек.;
	  - стаки Soul Keeper как в 1х6 (modifiers/modifier_urn_soul_stacks.lua):
	    +6%% к урону и лечению урны за каждого вражеского героя, умершего рядом
	    с владельцем или убитого им, до 15 стаков, навсегда.
]]

LinkLuaModifier("modifier_item_urn_aa_passive", "items/item_urn_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_urn_aa_heal", "items/item_urn_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_urn_aa_damage", "items/item_urn_aa", LUA_MODIFIER_MOTION_NONE)

local TICK = 1.0

-- множитель от стаков Soul Keeper владельца
local function SoulKeeperMult(caster, ability)
	if not caster or caster:IsNull() then return 1 end

	local mod = caster:FindModifierByName("modifier_urn_soul_stacks")

	if not mod then return 1 end

	local pct = ability and not ability:IsNull() and ability:GetSpecialValueFor("soul_keeper_pct") or 0

	if pct <= 0 then pct = URN_SOUL_KEEPER_PCT or 6 end

	return 1 + mod:GetStackCount() * pct / 100
end

---------------------------------------------------------------------------------------------------
-- Предмет
---------------------------------------------------------------------------------------------------

local UrnBase = {}

function UrnBase:GetIntrinsicModifierName()
	return "modifier_item_urn_aa_passive"
end

function UrnBase:IsVessel()
	return self:GetAbilityName() ~= "item_urn_of_shadows"
end

function UrnBase:CastFilterResultTarget(target)
	if self:GetCurrentCharges() < 1 then
		return UF_FAIL_CUSTOM
	end

	return UnitFilter(target, DOTA_UNIT_TARGET_TEAM_BOTH, DOTA_UNIT_TARGET_HERO,
		DOTA_UNIT_TARGET_FLAG_NONE, self:GetCaster():GetTeamNumber())
end

function UrnBase:GetCustomCastErrorTarget(target)
	if self:GetCurrentCharges() < 1 then
		return "#dota_hud_error_no_charges"
	end

	return ""
end

function UrnBase:OnSpellStart()
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()

	if not target or target:IsNull() then return end

	local charges = self:GetCurrentCharges()

	if charges < 1 then return end

	self:SetCurrentCharges(charges - 1)

	local duration = self:GetSpecialValueFor("duration")
	local vessel = self:IsVessel()

	if target:GetTeamNumber() == caster:GetTeamNumber() then
		target:AddNewModifier(caster, self, "modifier_item_urn_aa_heal", { duration = duration })
		target:EmitSound(vessel and "Item.SpiritVessel.Heal" or "DOTA_Item.UrnOfShadows.Activate")
	else
		if target:TriggerSpellAbsorb(self) then return end

		target:AddNewModifier(caster, self, "modifier_item_urn_aa_damage", { duration = duration * (1 - target:GetStatusResistance()) })
		target:EmitSound(vessel and "Item.SpiritVessel.Damage" or "DOTA_Item.UrnOfShadows.Activate")
	end

	local fx = ParticleManager:CreateParticle(
		vessel and "particles/items4_fx/spirit_vessel_cast.vpcf" or "particles/items_fx/urn_of_shadows.vpcf",
		PATTACH_CUSTOMORIGIN, caster)
	ParticleManager:SetParticleControlEnt(fx, 0, caster, PATTACH_POINT_FOLLOW, "attach_hitloc", caster:GetAbsOrigin(), true)
	ParticleManager:SetParticleControlEnt(fx, 1, target, PATTACH_POINT_FOLLOW, "attach_hitloc", target:GetAbsOrigin(), true)
	ParticleManager:ReleaseParticleIndex(fx)
end

local function MakeUrn()
	local def = {}

	for k, v in pairs(UrnBase) do def[k] = v end

	return class(def)
end

item_urn_of_shadows = MakeUrn()
item_spirit_vessel = MakeUrn()
item_spirit_vessel_2 = MakeUrn()
item_spirit_vessel_3 = MakeUrn()

---------------------------------------------------------------------------------------------------
-- Пассивка: статы
---------------------------------------------------------------------------------------------------

modifier_item_urn_aa_passive = class({})

function modifier_item_urn_aa_passive:IsHidden() return true end
function modifier_item_urn_aa_passive:IsPurgable() return false end
function modifier_item_urn_aa_passive:GetAttributes() return MODIFIER_ATTRIBUTE_MULTIPLE end

function modifier_item_urn_aa_passive:OnCreated()
	self:OnRefresh()

	-- стаки Soul Keeper живут вместе с урной: появилась урна - есть модификатор
	if IsServer() then
		local parent = self:GetParent()
		if parent:IsRealHero() and not parent:HasModifier("modifier_urn_soul_stacks") then
			parent:AddNewModifier(parent, nil, "modifier_urn_soul_stacks", {})
		end
	end
end

-- убрали последнюю урну/вессел - убираем и стаки. Проверяем через кадр:
-- при сборке урна -> вессел старый предмет исчезает раньше, чем появится новый
function modifier_item_urn_aa_passive:OnDestroy()
	if not IsServer() then return end

	local parent = self:GetParent()

	Timers:CreateTimer(FrameTime(), function()
		if not parent or parent:IsNull() then return nil end
		if not parent:HasModifier("modifier_item_urn_aa_passive") then
			parent:RemoveModifierByName("modifier_urn_soul_stacks")
		end
		return nil
	end)
end

function modifier_item_urn_aa_passive:OnRefresh()
	local ability = self:GetAbility()

	if not ability or ability:IsNull() then return end

	self.stats = ability:GetSpecialValueFor("bonus_all_stats")
	self.armor = ability:GetSpecialValueFor("bonus_armor")
	self.health = ability:GetSpecialValueFor("bonus_health")
	-- у урны ключ mana_regen, у вессела bonus_mana_regen
	self.mana_regen = ability:GetSpecialValueFor("bonus_mana_regen")

	if self.mana_regen == 0 then
		self.mana_regen = ability:GetSpecialValueFor("mana_regen")
	end
end

function modifier_item_urn_aa_passive:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
		MODIFIER_PROPERTY_HEALTH_BONUS,
		MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
	}
end

function modifier_item_urn_aa_passive:GetModifierBonusStats_Strength() return self.stats end
function modifier_item_urn_aa_passive:GetModifierBonusStats_Agility() return self.stats end
function modifier_item_urn_aa_passive:GetModifierBonusStats_Intellect() return self.stats end
function modifier_item_urn_aa_passive:GetModifierPhysicalArmorBonus() return self.armor end
function modifier_item_urn_aa_passive:GetModifierHealthBonus() return self.health end
function modifier_item_urn_aa_passive:GetModifierConstantManaRegen() return self.mana_regen end

---------------------------------------------------------------------------------------------------
-- Союзник: лечение
---------------------------------------------------------------------------------------------------

-- Иконка дебаффа/баффа. GetAbilityTextureName у предмета есть не всегда (на сервере
-- его нет): раньше OnCreated падал на этой строке, тик урона не запускался и урна с
-- весселами не наносили урон вообще (а срез лечения брал nil).
local URN_TEXTURES = {
	item_urn_of_shadows = "item_urn_of_shadows",
	item_spirit_vessel = "item_spirit_vessel",
	item_spirit_vessel_2 = "spirit_vessel2",
	item_spirit_vessel_3 = "spirit_vessel3",
}

function UrnTexture(ability)
	if not ability or ability:IsNull() then return "item_urn_of_shadows" end

	if ability.GetAbilityTextureName then
		local ok, tex = pcall(ability.GetAbilityTextureName, ability)
		if ok and tex and tex ~= "" then return tex end
	end

	return URN_TEXTURES[ability:GetAbilityName()] or "item_urn_of_shadows"
end

modifier_item_urn_aa_heal = class({})

function modifier_item_urn_aa_heal:IsPurgable() return true end
function modifier_item_urn_aa_heal:GetTexture() return self.texture end

function modifier_item_urn_aa_heal:OnCreated()
	local ability = self:GetAbility()

	self.texture = UrnTexture(ability)
	self.heal = (ability and ability:GetSpecialValueFor("soul_heal_amount") or 0) * SoulKeeperMult(self:GetCaster(), ability)

	if not IsServer() then return end

	self:SetHasCustomTransmitterData(true)
end

function modifier_item_urn_aa_heal:AddCustomTransmitterData() return { heal = self.heal } end
function modifier_item_urn_aa_heal:HandleCustomTransmitterData(data) self.heal = data.heal end

function modifier_item_urn_aa_heal:GetEffectName()
	return "particles/items4_fx/spirit_vessel_heal.vpcf"
end

function modifier_item_urn_aa_heal:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end

function modifier_item_urn_aa_heal:DeclareFunctions()
	return { MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT }
end

function modifier_item_urn_aa_heal:GetModifierConstantHealthRegen()
	return self.heal
end

---------------------------------------------------------------------------------------------------
-- Враг: урон и срезание лечения
---------------------------------------------------------------------------------------------------

modifier_item_urn_aa_damage = class({})

function modifier_item_urn_aa_damage:IsDebuff() return true end
function modifier_item_urn_aa_damage:IsPurgable() return true end
function modifier_item_urn_aa_damage:GetTexture() return self.texture end

function modifier_item_urn_aa_damage:OnCreated()
	local ability = self:GetAbility()

	self.texture = UrnTexture(ability)
	self.reduction = ability and ability:GetSpecialValueFor("restoration_reduction_enemy") or 0

	if not IsServer() then return end

	self.mult = SoulKeeperMult(self:GetCaster(), ability)
	self.damage = ability:GetSpecialValueFor("soul_damage_amount") * self.mult
	self.drain = ability:GetSpecialValueFor("enemy_hp_drain") * self.mult

	self:StartIntervalThink(TICK)
end

function modifier_item_urn_aa_damage:OnIntervalThink()
	local parent = self:GetParent()
	local caster = self:GetCaster()
	local ability = self:GetAbility()

	if not caster or caster:IsNull() or not parent:IsAlive() then return end

	-- значения перечитываем на каждом тике: если на момент наложения предмет
	-- отдал 0 (уровень/KV ещё не подтянулись), урон не пропадает на все 8 сек.
	if ability and not ability:IsNull() then
		self.mult = SoulKeeperMult(caster, ability)
		self.damage = ability:GetSpecialValueFor("soul_damage_amount") * self.mult
		self.drain = ability:GetSpecialValueFor("enemy_hp_drain") * self.mult
	end

	if (self.damage or 0) > 0 then
		ApplyDamage({
			victim = parent, attacker = caster, ability = ability,
			damage = self.damage * TICK, damage_type = DAMAGE_TYPE_PURE,
		})
	end

	if (self.drain or 0) > 0 and parent:IsAlive() then
		ApplyDamage({
			victim = parent, attacker = caster, ability = ability,
			damage = parent:GetHealth() * self.drain / 100 * TICK, damage_type = DAMAGE_TYPE_MAGICAL,
		})
	end
end

function modifier_item_urn_aa_damage:GetEffectName()
	return "particles/items4_fx/spirit_vessel_damage.vpcf"
end

function modifier_item_urn_aa_damage:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end

function modifier_item_urn_aa_damage:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_HP_REGEN_AMPLIFY_PERCENTAGE,
		MODIFIER_PROPERTY_HEAL_AMPLIFY_PERCENTAGE_TARGET,
		MODIFIER_PROPERTY_LIFESTEAL_AMPLIFY_PERCENTAGE,
		MODIFIER_PROPERTY_SPELL_LIFESTEAL_AMPLIFY_PERCENTAGE,
	}
end

function modifier_item_urn_aa_damage:GetModifierHPRegenAmplify_Percentage() return -(self.reduction or 0) end
function modifier_item_urn_aa_damage:GetModifierHealAmplify_PercentageTarget() return -(self.reduction or 0) end
function modifier_item_urn_aa_damage:GetModifierLifestealRegenAmplify_Percentage() return -(self.reduction or 0) end
function modifier_item_urn_aa_damage:GetModifierSpellLifestealRegenAmplify_Percentage() return -(self.reduction or 0) end
