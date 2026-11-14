-- Отражение урона торментора, как в 1х6: каждый, кто бьёт торментора,
-- получает damage% от нанесённого урона чистым уроном. Во время
-- неуязвимости (порог Unyielding Shield) - в invun_damage раз больше и с
-- тройной вспышкой.
-- Само событие урона ловит щит (tormentor_unyielding_shielda_aa.lua) и зовёт
-- Reflect: так отражается и урон, полностью съеденный барьером.

tormentor_reflect_aa = class({
	Spawn = function (self) if IsServer() then return self:SetLevel(1) end end,
})

local FX = {
	radiant = {
		reflect = "particles/neutral_fx/miniboss_damage_reflect.vpcf",
		impact  = "particles/neutral_fx/miniboss_damage_impact.vpcf",
	},
	dire = {
		reflect = "particles/neutral_fx/miniboss_damage_reflect_dire.vpcf",
		impact  = "particles/neutral_fx/miniboss_dire_damage_impact.vpcf",
	},
}

-- "Miniboss.Tormenter.Reflect" без номера в доте нет, есть Reflect0..7
local SND_REFLECT = "Miniboss.Tormenter.Reflect0"

function tormentor_reflect_aa:Precache(context)
	for _, side in pairs(FX) do
		for _, name in pairs(side) do
			PrecacheResource("particle", name, context)
		end
	end
	PrecacheResource("soundfile", "soundevents/game_sounds_creeps.vsndevts", context)
end

function tormentor_reflect_aa:Reflect(attacker, damage, flags, invun)
	if not IsServer() then return end
	if not attacker or attacker:IsNull() or not attacker:IsAlive() then return end
	if damage <= 0 then return end
	-- урон, который сам является отражением, обратно не возвращаем
	if bit.band(flags or 0, DOTA_DAMAGE_FLAG_REFLECTION) ~= 0 then return end
	-- Blade Mail, Dispersion и подобное могут вернуть урон обратно в торментора
	-- внутри нашего же ApplyDamage: не даём цепочке раскрутиться
	if self.reflecting then return end

	local caster = self:GetCaster()
	local name = caster.aa_boss_name
	local fx = (name and name:find("dire")) and FX.dire or FX.radiant

	local amount = damage * self:GetSpecialValueFor("damage") / 100
	local count = 1
	if invun then
		amount = amount * self:GetSpecialValueFor("invun_damage")
		count = 3
	end

	for _ = 1, count do
		local i = ParticleManager:CreateParticle(fx.impact, PATTACH_ABSORIGIN_FOLLOW, caster)
		ParticleManager:ReleaseParticleIndex(i)
		local p = ParticleManager:CreateParticle(fx.reflect, PATTACH_ABSORIGIN_FOLLOW, caster)
		ParticleManager:SetParticleControl(p, 0, caster:GetAbsOrigin())
		ParticleManager:SetParticleControlEnt(p, 1, attacker, PATTACH_POINT_FOLLOW, "attach_hitloc", attacker:GetAbsOrigin(), true)
		ParticleManager:ReleaseParticleIndex(p)
	end
	attacker:EmitSound(SND_REFLECT)

	self.reflecting = true
	pcall(ApplyDamage, {
		victim = attacker,
		attacker = caster,
		ability = self,
		damage = amount,
		damage_type = DAMAGE_TYPE_PURE,
		damage_flags = DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION + DOTA_DAMAGE_FLAG_REFLECTION,
	})
	self.reflecting = false
end
