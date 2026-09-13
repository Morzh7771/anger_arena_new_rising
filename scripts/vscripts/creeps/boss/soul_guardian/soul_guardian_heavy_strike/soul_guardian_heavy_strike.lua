soul_guardian_heavy_strike =  class({})

-- Сгенерировано: ресурсы, на которые ссылается этот скрипт.
-- Движок зовёт этот метод при прекеше юнита со способностью, поэтому
-- партиклы приезжают вместе с героем (пик/репик), а не на старте карты.
function soul_guardian_heavy_strike:Precache(context)
	PrecacheResource("particle", "particles/bosses/soul_guardian/soul_guardian_heavy_strike/econ/items/ursa/ursa_ti10/soul_guardian_heavy_strike.vpcf", context)
	PrecacheResource("particle", "particles/generic_gameplay/generic_stunned.vpcf", context)
end


LinkLuaModifier("modifier_soul_guardian_heavy_strike", "creeps/boss/soul_guardian/soul_guardian_heavy_strike/modifier_soul_guardian_heavy_strike", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_soul_guardian_heavy_strike_slow", "creeps/boss/soul_guardian/soul_guardian_heavy_strike/modifier_soul_guardian_heavy_strike_slow", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_soul_guardian_heavy_strike_knockback", "creeps/boss/soul_guardian/soul_guardian_heavy_strike/modifier_soul_guardian_heavy_strike_knockback", LUA_MODIFIER_MOTION_HORIZONTAL)
LinkLuaModifier("modifier_soul_guardian_heavy_strike_stun", "creeps/boss/soul_guardian/soul_guardian_heavy_strike/modifier_soul_guardian_heavy_strike_stun", LUA_MODIFIER_MOTION_NONE)

function soul_guardian_heavy_strike:GetIntrinsicModifierName()
    return "modifier_soul_guardian_heavy_strike"
end
