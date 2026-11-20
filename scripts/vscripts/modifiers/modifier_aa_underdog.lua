-- "Отстающая команда" (2026-11-16): механика камбэка, ставит lib/underdog.lua.
-- Стаки = сила баффа в процентах (0..30): +N% золота (AngelArena:GoldFilter), +N% урона по крипам,
-- -N% урона от крипов. Боссов не касается ни в одну сторону. Видно игроку, не снимается.
-- Клиентская привязка - addon_init.lua (иначе тултип молчит).

modifier_aa_underdog = class({})

function modifier_aa_underdog:IsHidden() return self:GetStackCount() <= 0 end
function modifier_aa_underdog:IsDebuff() return false end
function modifier_aa_underdog:IsBuff() return true end
function modifier_aa_underdog:IsPurgable() return false end
function modifier_aa_underdog:RemoveOnDeath() return false end
function modifier_aa_underdog:GetTexture() return "alchemist_goblins_greed" end

function modifier_aa_underdog:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_TOTALDAMAGEOUTGOING_PERCENTAGE,
		MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
		MODIFIER_PROPERTY_TOOLTIP,
	}
end

-- крип в смысле баффа: не герой, не здание, не босс и не юнит игрока (саммоны врага - не крипы)
local function IsCreep(u)
	if not u or u:IsNull() then return false end
	if u.IsAngelArenaBoss then return false end
	if u:IsHero() or u:IsBuilding() then return false end

	local pid = u.GetPlayerOwnerID and u:GetPlayerOwnerID() or -1

	return pid == nil or pid < 0
end

function modifier_aa_underdog:GetModifierTotalDamageOutgoing_Percentage(params)
	if not IsServer() then return 0 end
	if IsCreep(params.target) then return self:GetStackCount() end

	return 0
end

function modifier_aa_underdog:GetModifierIncomingDamage_Percentage(params)
	if not IsServer() then return 0 end
	if IsCreep(params.attacker) then return -self:GetStackCount() end

	return 0
end

function modifier_aa_underdog:OnTooltip()
	return self:GetStackCount()
end
