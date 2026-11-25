-- Reaver Lord: Twink. Порт из Angel Arena Global. Блинк на дальность range (талант +800).

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

	if (point - origin):Length2D() > range then
		point = origin + (point - origin):Normalized() * range
	end

	ProjectileManager:ProjectileDodge(caster)

	-- шард: на месте старта остаётся иллюзия
	local illusion_duration = self:GetSpecialValueFor("shard_illusion_duration")
	if illusion_duration > 0 then
		CreateIllusions(caster, caster, {
			duration = illusion_duration,
			outgoing_damage = self:GetSpecialValueFor("shard_illusion_outgoing") - 100,
			incoming_damage = self:GetSpecialValueFor("shard_illusion_incoming") - 100,
		}, 1, 0, false, false)
	end

	local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_terrorblade/terrorblade_mirror_image_c.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(pfx, 0, origin)
	ParticleManager:ReleaseParticleIndex(pfx)
	EmitSoundOnLocationWithCaster(origin, "Hero_Antimage.Blink_out", caster)

	FindClearSpaceForUnit(caster, point, true)

	pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_terrorblade/terrorblade_mirror_image_c.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
	ParticleManager:ReleaseParticleIndex(pfx)
	caster:EmitSound("Hero_Antimage.Blink_in")
end
