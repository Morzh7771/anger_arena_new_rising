megacreep_beast_bonus_attackspeed = class({})

-- Сгенерировано: ресурсы, на которые ссылается этот скрипт.
-- Движок зовёт этот метод при прекеше юнита со способностью, поэтому
-- партиклы приезжают вместе с героем (пик/репик), а не на старте карты.
function megacreep_beast_bonus_attackspeed:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_troll_warlord/troll_warlord_battletrance_buff.vpcf", context)
end


LinkLuaModifier("modifier_megacreep_beast_bonus_attackspeed", "creeps/abilities/megacreep_beast/modifiers/modifier_megacreep_beast_bonus_attackspeed", LUA_MODIFIER_MOTION_NONE)

function megacreep_beast_bonus_attackspeed:OnSpellStart()
	local caster = self:GetCaster() 
	local duration = self:GetSpecialValueFor("duration")

	caster:AddNewModifier(caster, self, "modifier_megacreep_beast_bonus_attackspeed", { duration = duration })

	caster:EmitSound("Hero_LoneDruid.BattleCry.Bear")
end
