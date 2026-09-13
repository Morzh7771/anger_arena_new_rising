satan_curse = class({})

-- Сгенерировано: ресурсы, на которые ссылается этот скрипт.
-- Движок зовёт этот метод при прекеше юнита со способностью, поэтому
-- партиклы приезжают вместе с героем (пик/репик), а не на старте карты.
function satan_curse:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_shadow_demon/shadow_demon_demonic_purge_debuff.vpcf", context)
end

LinkLuaModifier("modifier_satan_curse", "heroes/satan/modifier_satan_curse", LUA_MODIFIER_MOTION_NONE)

function satan_curse:IsHiddenWhenStolen() 		return false end

function satan_curse:OnSpellStart( ... )
	if not IsServer() then return end

	local caster 		= self:GetCaster()
	local target 		= self:GetCursorTarget()

	if target:TriggerSpellAbsorb(self) then return end
	
	if target:TriggerSpellReflect(self) then return end

	caster:EmitSound("doom_bringer_doom_ability_doom_0" .. RandomInt(1,7))
	
	local duration = self:GetSpecialValueFor("duration")
	target:AddNewModifier(caster,self, "modifier_satan_curse", {duration = duration})
end

