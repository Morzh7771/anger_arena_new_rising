modifier_boss_power = modifier_boss_power or class({})
local mod = modifier_boss_power

function mod:IsHidden()         return true  end
function mod:IsPurgable()       return false end
function mod:DestroyOnExpire()  return false end
function mod:IsPurgable()       return false end
function mod:IsPurgeException() return false end

function mod:DeclareFunctions() return 
{
	MODIFIER_EVENT_ON_TAKEDAMAGE,
	MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
}
end

if IsServer() then require('lib/summon_utils') end

-- Самоны (юниты с modifier_summon_power) бьют боссов вполовину.
local SUMMON_BOSS_DAMAGE_MULT = 0.5

-- Урон по боссу режется:
--   * самону - вдвое;
--   * если у атакующего или у его героя-хозяина висит усталость после
--     убийства боссов - на 30% за стак (3 убийства = -90%).
-- Оба множителя перемножаются.
function mod:GetModifierIncomingDamage_Percentage(params)
	if not IsServer() then return 0 end
	local attacker = params.attacker
	if not attacker or attacker:IsNull() or not attacker.HasModifier then return 0 end

	local mult = 1

	if attacker:HasModifier("modifier_summon_power") then
		mult = mult * SUMMON_BOSS_DAMAGE_MULT
	end

	local fatigue = attacker:FindModifierByName("modifier_boss_slayer_fatigue")
	if not fatigue then
		local hero = SummonUtils:GetOwnerHero(attacker)
		fatigue = hero and not hero:IsNull() and hero:FindModifierByName("modifier_boss_slayer_fatigue")
	end
	if fatigue and fatigue.GetReductionPct then
		mult = mult * (1 - fatigue:GetReductionPct() / 100)
	end

	return (mult - 1) * 100
end

function mod:OnTakeDamage(params)
	local attacker  = params.attacker
	if not attacker then return end

	local caster 	= params.unit

	if IsServer() then
		-- событие приходит от любого урона на карте; свой босс - только parent
		if caster == self:GetParent() then
			BossSpawner:OnBossDamaged(caster, attacker)
		end

		if BossSpawner:IsBoss(caster) then 
			attacker:RemoveModifierByName("modifier_smoke_of_deceit")
			attacker:RemoveModifierByName("modifier_bane_nightmare_invulnerable")
			attacker:RemoveModifierByName("modifier_bane_nightmare")
			attacker:RemoveModifierByName("modifier_phantom_assassin_blur_active")


			if(caster:GetAbsOrigin() - attacker:GetAbsOrigin()):Length2D() > 2000 and attacker and attacker:GetUnitName() == "npc_dota_hero_shredder" then
				caster:Heal(params.damage, caster)
			end
		end
	end
end