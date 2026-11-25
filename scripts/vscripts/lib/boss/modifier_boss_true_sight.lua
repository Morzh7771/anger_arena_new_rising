-- Истинное зрение босса, как у гема: невидимые враги рядом с ним видны
-- (ванильный modifier_truesight аурой). Вешает BossSpawner:SpawnBoss и
-- тест aa_boss. ИИ боссов с ним видит невидимых (AIHelpers:GetEnemiesNear).

modifier_boss_true_sight = modifier_boss_true_sight or class({})
local mod = modifier_boss_true_sight

local RADIUS = 900

function mod:IsHidden()      return true  end
function mod:IsPurgable()    return false end
function mod:RemoveOnDeath() return false end

function mod:IsAura()             return true end
function mod:GetAuraRadius()      return RADIUS end
function mod:GetAuraSearchTeam()  return DOTA_UNIT_TARGET_TEAM_ENEMY end
function mod:GetAuraSearchType()  return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC end
function mod:GetAuraSearchFlags() return DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_INVULNERABLE end
function mod:GetModifierAura()    return "modifier_truesight" end
function mod:GetAuraDuration()    return 0.1 end

function mod:OnCreated()
	if not IsServer() then return end
	self:GetParent().aa_true_sight = true
end
