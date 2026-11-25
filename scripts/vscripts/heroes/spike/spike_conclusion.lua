-- Spike: Conclusion (ульт). Порт из Angel Arena Global (datadriven), переписано на Lua.
-- Снимает дебафы и на duration обнуляет перезарядку всех своих способностей и предметов.
-- Пока действует, каждый каст ставит на этой вещи увеличенный КД (total_cooldown% от обычного).
-- Когда бафф спадает, вещам, которые не кастовались, возвращается остаток их прежнего КД.
-- Талант: каждое убийство навсегда даёт урон атаки (за героя/босса и за крипа).

spike_conclusion = class({})

LinkLuaModifier("modifier_spike_conclusion", "heroes/spike/spike_conclusion", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_spike_conclusion_kills", "heroes/spike/spike_conclusion", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_spike_conclusion_damage", "heroes/spike/spike_conclusion", LUA_MODIFIER_MOTION_NONE)

-- Не обнуляются: сам ульт и наши рефрешеры (иначе бесконечный цикл сброса)
local NO_REFRESH = {
	spike_conclusion		= true,
	item_refresher			= true,
	item_refresher_shard	= true,
}

function spike_conclusion:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_ursa/ursa_enrage_buff_b.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_ursa.vsndevts", context)
end

function spike_conclusion:GetIntrinsicModifierName()
	return "modifier_spike_conclusion_kills"
end

local function for_each_ability(caster, fn)
	for i = 0, caster:GetAbilityCount() - 1 do
		local a = caster:GetAbilityByIndex(i)
		if a then fn(a) end
	end
	for slot = DOTA_ITEM_SLOT_1, DOTA_ITEM_SLOT_6 do
		local item = caster:GetItemInSlot(slot)
		if item then fn(item) end
	end
	for _, slot in pairs({ DOTA_ITEM_TP_SCROLL, DOTA_ITEM_NEUTRAL_SLOT }) do
		local item = caster:GetItemInSlot(slot)
		if item then fn(item) end
	end
end

function spike_conclusion:OnSpellStart()
	local caster = self:GetCaster()

	caster:Purge(false, true, false, true, true)

	local saved = {}
	for_each_ability(caster, function(a)
		if NO_REFRESH[a:GetAbilityName()] then return end
		local cd = a:GetCooldownTimeRemaining()
		if cd > 0 then saved[a:entindex()] = cd end
		a:EndCooldown()
		a:RefreshCharges()
	end)

	local mod = caster:AddNewModifier(caster, self, "modifier_spike_conclusion", { duration = self:GetSpecialValueFor("duration") })
	if mod then
		mod.saved = saved
		mod.start_time = GameRules:GetGameTime()
	end

	caster:EmitSound("Hero_Ursa.Enrage")
end

--------------------------------------------------------------------------------

modifier_spike_conclusion = class({})

function modifier_spike_conclusion:IsHidden() return false end
function modifier_spike_conclusion:IsPurgable() return false end

function modifier_spike_conclusion:OnCreated()
	local ability = self:GetAbility()
	self.multiplier = ability and ability:GetSpecialValueFor("total_cooldown") / 100 or 1
	self.status_resist = ability and ability:GetSpecialValueFor("scepter_status_resist") or 0
end

function modifier_spike_conclusion:DeclareFunctions()
	return {
		MODIFIER_EVENT_ON_ABILITY_FULLY_CAST,
		MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING,
	}
end

-- аганим: сопротивление эффектам на время ульты
function modifier_spike_conclusion:GetModifierStatusResistanceStacking()
	return self.status_resist
end

function modifier_spike_conclusion:OnAbilityFullyCast(params)
	if not IsServer() then return end
	if params.unit ~= self:GetParent() then return end

	local used = params.ability
	if not used or used:IsNull() or NO_REFRESH[used:GetAbilityName()] then return end

	-- Каст в бафе - увеличенный КД; прежний КД этой вещи уже не возвращаем
	if self.saved then self.saved[used:entindex()] = nil end

	local mult = self.multiplier
	Timers:CreateTimer(FrameTime(), function()
		if used:IsNull() then return end
		local cd = used:GetCooldown(used:GetLevel() - 1) * self:GetParent():GetCooldownReduction() * mult
		if cd > 0 then
			used:EndCooldown()
			used:StartCooldown(cd)
		end
	end)
end

function modifier_spike_conclusion:OnDestroy()
	if not IsServer() or not self.saved then return end

	local passed = GameRules:GetGameTime() - (self.start_time or GameRules:GetGameTime())

	for_each_ability(self:GetParent(), function(a)
		local cd = self.saved[a:entindex()]
		if cd and a:GetCooldownTimeRemaining() <= 0 then
			local left = cd - passed
			if left > 0 then a:StartCooldown(left) end
		end
	end)
end

function modifier_spike_conclusion:GetEffectName()
	return "particles/units/heroes/hero_ursa/ursa_enrage_buff_b.vpcf"
end

function modifier_spike_conclusion:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end

--------------------------------------------------------------------------------
-- Талант: урон за убийства. Работает, только если взят special_bonus_unique_spike_conclusion_kill_damage.

modifier_spike_conclusion_kills = class({})

function modifier_spike_conclusion_kills:IsHidden() return true end
function modifier_spike_conclusion_kills:IsPurgable() return false end
function modifier_spike_conclusion_kills:RemoveOnDeath() return false end

function modifier_spike_conclusion_kills:DeclareFunctions()
	return { MODIFIER_EVENT_ON_DEATH }
end

function modifier_spike_conclusion_kills:OnDeath(params)
	if not IsServer() then return end

	local parent = self:GetParent()
	local ability = self:GetAbility()
	if params.attacker ~= parent or parent:IsIllusion() or not ability then return end
	if ability:GetSpecialValueFor("kill_damage_enabled") <= 0 then return end

	local unit = params.unit
	if not unit or unit:GetTeamNumber() == parent:GetTeamNumber() or unit:IsIllusion() or unit:IsBuilding() then return end

	local is_big = unit:IsRealHero() or (BossSpawner and BossSpawner.IsBoss and BossSpawner:IsBoss(unit))
	local add = is_big and ability:GetSpecialValueFor("damage_by_hero") or ability:GetSpecialValueFor("damage_by_creep")

	local mod = parent:FindModifierByName("modifier_spike_conclusion_damage") or parent:AddNewModifier(parent, ability, "modifier_spike_conclusion_damage", {})
	if mod then mod:SetStackCount(mod:GetStackCount() + add) end
end

modifier_spike_conclusion_damage = class({})

function modifier_spike_conclusion_damage:IsHidden() return false end
function modifier_spike_conclusion_damage:IsPurgable() return false end
function modifier_spike_conclusion_damage:RemoveOnDeath() return false end
function modifier_spike_conclusion_damage:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT end

function modifier_spike_conclusion_damage:DeclareFunctions()
	return { MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE }
end

function modifier_spike_conclusion_damage:GetModifierPreAttack_BonusDamage()
	return self:GetStackCount()
end
