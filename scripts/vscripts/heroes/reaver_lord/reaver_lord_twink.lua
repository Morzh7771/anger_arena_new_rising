-- Reaver Lord: Twink. Порт из Angel Arena Global. Блинк на дальность range (талант +800).
-- Клик дальше радиуса: тратятся души, каждая +range_per_soul к дальности (2026-11-26).

reaver_lord_twink = class({})

function reaver_lord_twink:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_terrorblade/terrorblade_mirror_image_c.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_antimage.vsndevts", context)
end

function reaver_lord_twink:GetCastRange(location, target)
	if IsServer() then return 99999 end
	return self:GetSpecialValueFor("range")
end

function reaver_lord_twink:OnSpellStart()
	local caster = self:GetCaster()
	local origin = caster:GetAbsOrigin()
	local point = self:GetCursorPosition()
	local range = self:GetSpecialValueFor("range") + caster:GetCastRangeBonus()
	local dist = (point - origin):Length2D()

	-- альтернативное применение: души не тратятся, блинк только на свою дальность
	local alt = false
	pcall(function() alt = self:GetAltCastState() and true or false end)

	-- дальше радиуса - тратим души: каждая даёт +range_per_soul к дальности
	if dist > range and alt then
		point = origin + (point - origin):Normalized() * range
	elseif dist > range then
		local per = self:GetSpecialValueFor("range_per_soul")
		local have = ReaverLordGetSouls and ReaverLordGetSouls(caster) or 0
		local need = per > 0 and math.ceil((dist - range) / per) or 0
		local spend = math.min(have, need)

		if spend > 0 then
			ReaverLordAddSouls(caster, -spend)
			range = range + spend * per
		end

		if dist > range then
			point = origin + (point - origin):Normalized() * range
		end
	end

	local forward = caster:GetForwardVector()
	ProjectileManager:ProjectileDodge(caster)

	local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_terrorblade/terrorblade_mirror_image_c.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(pfx, 0, origin)
	ParticleManager:ReleaseParticleIndex(pfx)
	EmitSoundOnLocationWithCaster(origin, "Hero_Antimage.Blink_out", caster)

	FindClearSpaceForUnit(caster, point, true)

	-- шард: на месте старта остаётся иллюзия
	local illusion_duration = self:GetSpecialValueFor("shard_illusion_duration")
	if illusion_duration > 0 then
		-- создаём уже после блинка, чтобы герой не сдвигал её: иллюзия ровно в точке старта, лицом туда же, куда смотрел герой
		-- (CreateIllusions сам раскидывал её в сторону от героя)
		local list = CreateIllusions(caster, caster, {
			duration = illusion_duration,
			outgoing_damage = self:GetSpecialValueFor("shard_illusion_outgoing") - 100,
			incoming_damage = self:GetSpecialValueFor("shard_illusion_incoming") - 100,
		}, 1, 0, false, false)
		for _, ill in pairs(list or {}) do
			if ill and not ill:IsNull() then
				ill:SetAbsOrigin(origin)
				FindClearSpaceForUnit(ill, origin, true)
				ill:SetForwardVector(forward)
				ill:Stop()
			end
		end
	end


	pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_terrorblade/terrorblade_mirror_image_c.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
	ParticleManager:ReleaseParticleIndex(pfx)
	caster:EmitSound("Hero_Antimage.Blink_in")
end
