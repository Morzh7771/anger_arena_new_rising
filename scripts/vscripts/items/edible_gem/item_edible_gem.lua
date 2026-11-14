-- Съедаемый гем. Логика один в один из мода frontier (items/consumable_gem):
-- аура снимает невидимость у врагов в радиусе, пропадает со смертью.
-- Предыдущая версия (скрытый item_gem + modifier_truesight) роняла кастомку.

print("[AA.gem] файл загружен, IsServer=" .. tostring(IsServer()))

LinkLuaModifier("modifier_edible_gem_aura", "items/edible_gem/item_edible_gem", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_edible_gem_reveal", "items/edible_gem/item_edible_gem", LUA_MODIFIER_MOTION_NONE)

item_edible_gem = item_edible_gem or class({})

function item_edible_gem:OnSpellStart()
	local caster = self:GetCaster()
	print("[AA.gem] OnSpellStart: " .. tostring(caster and caster:GetUnitName()) .. " radius=" .. tostring(self:GetSpecialValueFor("radius")))
	local mod = caster:AddNewModifier(caster, self, "modifier_edible_gem_aura", {})
	print("[AA.gem] аура повешена: " .. tostring(mod ~= nil) .. ", HasModifier=" .. tostring(caster:HasModifier("modifier_edible_gem_aura")))

	self:Destroy()
end

--------------------------------------------------------------------------------
-- Аура на владельце
--------------------------------------------------------------------------------
modifier_edible_gem_aura = modifier_edible_gem_aura or class({})

function modifier_edible_gem_aura:IsPurgable() return false end
function modifier_edible_gem_aura:RemoveOnDeath() return false end

function modifier_edible_gem_aura:IsAura() return true end
function modifier_edible_gem_aura:GetAuraRadius() return self.radius or 900 end
function modifier_edible_gem_aura:GetAuraSearchTeam() return DOTA_UNIT_TARGET_TEAM_ENEMY end
function modifier_edible_gem_aura:GetAuraSearchType() return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC + DOTA_UNIT_TARGET_OTHER end
function modifier_edible_gem_aura:GetAuraSearchFlags() return DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_INVULNERABLE end
function modifier_edible_gem_aura:GetModifierAura() return "modifier_edible_gem_reveal" end
function modifier_edible_gem_aura:GetTexture() return "item_gem" end

function modifier_edible_gem_aura:OnCreated()
	self.radius = 900

	local ability = self:GetAbility()
	if ability and not ability:IsNull() then
		self.radius = ability:GetSpecialValueFor("radius")
	end
	if self.radius <= 0 then self.radius = 900 end

	if IsServer() then
		print("[AA.gem] аура создана на " .. self:GetParent():GetUnitName() .. ", радиус " .. tostring(self.radius))
		self:StartIntervalThink(2)
	end
end

-- раз в 2 сек: кто из врагов рядом под эффектом гема
function modifier_edible_gem_aura:OnIntervalThink()
	local parent = self:GetParent()
	local n, revealed = 0, 0
	for _, u in pairs(FindUnitsInRadius(parent:GetTeamNumber(), parent:GetAbsOrigin(), nil, self.radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC + DOTA_UNIT_TARGET_OTHER,
		DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_INVULNERABLE, FIND_ANY_ORDER, false)) do
		n = n + 1
		if u:HasModifier("modifier_edible_gem_reveal") then revealed = revealed + 1 end
		if u:IsInvisible() then
			print("[AA.gem]   невидим: " .. u:GetUnitName() .. ", эффект гема=" .. tostring(u:HasModifier("modifier_edible_gem_reveal")))
		end
	end
	print(string.format("[AA.gem] тик: врагов в радиусе (видимых команде) %d, с эффектом %d", n, revealed))
end

function modifier_edible_gem_aura:DeclareFunctions()
	return { MODIFIER_EVENT_ON_DEATH }
end

function modifier_edible_gem_aura:OnDeath(params)
	if not IsServer() then return end
	if params.unit ~= self:GetParent() then return end
	if params.unit:IsReincarnating() then return end

	print("[AA.gem] владелец умер - аура снята")
	self:Destroy()
end

--------------------------------------------------------------------------------
-- Эффект ауры на враге: снимает невидимость
--------------------------------------------------------------------------------
modifier_edible_gem_reveal = modifier_edible_gem_reveal or class({})

function modifier_edible_gem_reveal:IsHidden() return true end
function modifier_edible_gem_reveal:IsDebuff() return IsClient() end
function modifier_edible_gem_reveal:IsPurgable() return false end
function modifier_edible_gem_reveal:GetPriority() return MODIFIER_PRIORITY_HIGH end

function modifier_edible_gem_reveal:OnCreated()
	if IsServer() then print("[AA.gem] эффект на " .. self:GetParent():GetUnitName()) end
end

function modifier_edible_gem_reveal:CheckState()
	return { [MODIFIER_STATE_INVISIBLE] = false }
end

function modifier_edible_gem_reveal:DeclareFunctions()
	return { MODIFIER_PROPERTY_INVISIBILITY_LEVEL }
end

function modifier_edible_gem_reveal:GetModifierInvisibilityLevel()
	return 0
end
