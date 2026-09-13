satan_might = class({})

-- Сгенерировано: ресурсы, на которые ссылается этот скрипт.
-- Движок зовёт этот метод при прекеше юнита со способностью, поэтому
-- партиклы приезжают вместе с героем (пик/репик), а не на старте карты.
function satan_might:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_doom_bringer/doom_bringer_devour.vpcf", context)
end

LinkLuaModifier("modifier_satan_might_passive", "heroes/satan/satan_might/modifier_satan_might_passive", LUA_MODIFIER_MOTION_NONE)


function satan_might:GetIntrinsicModifierName()
	return "modifier_satan_might_passive"
end

function satan_might:OnUpgrade( )
	if IsServer() then
		local caster = self:GetCaster()
		local mod = caster:FindModifierByName("modifier_satan_might_passive")
		if mod then
			mod:ForceRefresh()
		end
	end
end
