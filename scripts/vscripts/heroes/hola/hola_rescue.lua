-- Hola: Rescue (ульт). Порт из Angel Arena Frontier, цифры Angel Arena Global.
-- Сильное развеивание союзников в радиусе и короткое бессмертие (как False Promise).
-- Талант: заодно накладывает на них Grace.

hola_rescue = class({})

LinkLuaModifier("modifier_hola_rescue", "heroes/hola/hola_rescue", LUA_MODIFIER_MOTION_NONE)

function hola_rescue:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_omniknight/omniknight_guardian_angel_ally.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_omniknight/omniknight_guardian_angel_omni.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_omniknight.vsndevts", context)
end

function hola_rescue:GetAOERadius()
	return self:GetSpecialValueFor("radius")
end

function hola_rescue:OnSpellStart()
	local caster = self:GetCaster()
	local duration = self:GetSpecialValueFor("duration")

	local grace = caster:FindAbilityByName("hola_grace")
	local apply_grace = self:GetSpecialValueFor("apply_grace") > 0 and grace and grace:GetLevel() > 0

	local allies = FindUnitsInRadius(caster:GetTeamNumber(), caster:GetAbsOrigin(), nil, self:GetSpecialValueFor("radius"),
		DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

	for _, ally in pairs(allies) do
		ally:Purge(false, true, false, true, true)
		ally:AddNewModifier(caster, self, "modifier_hola_rescue", { duration = duration })

		if apply_grace then
			grace:Apply(ally)
		end
	end

	caster:EmitSound("Hero_Omniknight.GuardianAngel.Cast")

	local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_omniknight/omniknight_guardian_angel_omni.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
	ParticleManager:ReleaseParticleIndex(pfx)
end

--------------------------------------------------------------------------------
-- Не даёт умереть: HP не опускается ниже 1, пока висит бафф.

modifier_hola_rescue = class({})

function modifier_hola_rescue:IsHidden() return false end
function modifier_hola_rescue:IsDebuff() return false end
function modifier_hola_rescue:IsPurgable() return false end

-- аганим: когда бафф заканчивается, союзник лечится на % макс. здоровья
function modifier_hola_rescue:OnDestroy()
	if not IsServer() then return end
	local ability = self:GetAbility()
	local parent = self:GetParent()
	local pct = ability and ability:GetSpecialValueFor("scepter_heal_pct") or 0
	if pct > 0 and parent:IsAlive() then
		local heal = parent:GetMaxHealth() * pct / 100
		parent:Heal(heal, ability)
		SendOverheadEventMessage(nil, OVERHEAD_ALERT_HEAL, parent, heal, nil)
	end
end

function modifier_hola_rescue:DeclareFunctions()
	return { MODIFIER_PROPERTY_MIN_HEALTH }
end

function modifier_hola_rescue:GetMinHealth()
	return 1
end

function modifier_hola_rescue:GetEffectName()
	return "particles/units/heroes/hero_omniknight/omniknight_guardian_angel_ally.vpcf"
end

function modifier_hola_rescue:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end
