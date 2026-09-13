satan_overpain = class({})

-- Сгенерировано: ресурсы, на которые ссылается этот скрипт.
-- Движок зовёт этот метод при прекеше юнита со способностью, поэтому
-- партиклы приезжают вместе с героем (пик/репик), а не на старте карты.
function satan_overpain:Precache(context)
	PrecacheResource("particle", "particles/econ/items/legion/legion_fallen/legion_fallen_press_owner.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/monkey_king/arcana/fire/monkey_king_spring_fire_base.vpcf", context)
end

LinkLuaModifier("modifier_satan_overpain_active", "heroes/satan/satan_overpain/modifier_satan_overpain_active", LUA_MODIFIER_MOTION_NONE)

function satan_overpain:OnSpellStart()
	local caster = self:GetCaster()
	local duration = self:GetSpecialValueFor("duration")
	caster:AddNewModifier(caster, self, "modifier_satan_overpain_active", {duration = duration})
	--
	local particle = ParticleManager:CreateParticle("particles/econ/items/monkey_king/arcana/fire/monkey_king_spring_fire_base.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
	ParticleManager:SetParticleControl(particle, 0, caster:GetAbsOrigin())
	ParticleManager:SetParticleControl(particle, 1, caster:GetAbsOrigin())
	ParticleManager:ReleaseParticleIndex(particle)
end
