shadowsong_dark_reflection = class({})

-- Сгенерировано: ресурсы, на которые ссылается этот скрипт.
-- Движок зовёт этот метод при прекеше юнита со способностью, поэтому
-- партиклы приезжают вместе с героем (пик/репик), а не на старте карты.
function shadowsong_dark_reflection:Precache(context)
	PrecacheResource("particle", "particles/econ/events/nexon_hero_compendium_2014/blink_dagger_end_sparkles_end_nexon_hero_cp_2014.vpcf", context)
	PrecacheResource("particle", "particles/econ/events/ti4/blink_dagger_start_ti4.vpcf", context)
	PrecacheResource("particle", "particles/generic_gameplay/generic_stunned.vpcf", context)
	PrecacheResource("particle", "particles/items_fx/black_king_bar_avatar.vpcf", context)
end


local ability = shadowsong_dark_reflection

LinkLuaModifier( "modifier_shadowsong_dark_reflection_stun", "heroes/shadowsong/modifiers/modifier_shadowsong_dark_reflection_stun", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_shadowsong_dark_reflection_immune", "heroes/shadowsong/modifiers/modifier_shadowsong_dark_reflection_immune", LUA_MODIFIER_MOTION_NONE )

function ability:IsHiddenWhenStolen() return false end

function ability:CastFilterResultTarget(target)
	local caster = self:GetCaster()

	if caster:GetTeamNumber() ~= target:GetTeamNumber() then
		return UF_SUCCESS
	end

	if not caster.HasTalent then return UF_FAIL_CUSTOM end
	if not caster:HasTalent("shadowsong_special_bonus_reflection_teammate") then return UF_FAIL_CUSTOM end

	return UF_SUCCESS
end

function ability:GetCustomCastErrorTarget(target)
    return "#dota_hud_error_cant_cast_on_ally"
end

function ability:OnAbilityPhaseStart()
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()


	ParticleManager:ReleaseParticleIndex(ParticleManager:CreateParticle("particles/econ/events/nexon_hero_compendium_2014/blink_dagger_end_sparkles_end_nexon_hero_cp_2014.vpcf", PATTACH_ABSORIGIN, caster))
	ParticleManager:ReleaseParticleIndex(ParticleManager:CreateParticle("particles/econ/events/nexon_hero_compendium_2014/blink_dagger_end_sparkles_end_nexon_hero_cp_2014.vpcf", PATTACH_ABSORIGIN, target))

	return true
end

function ability:OnSpellStart( kv )
	if not IsServer() then return end

	local caster = self:GetCaster()
	local target = self:GetCursorTarget()

	local casterPos = caster:GetAbsOrigin()
	local targetPos = target:GetAbsOrigin()

	local isEnemy = caster:GetTeamNumber() ~= target:GetTeamNumber()
	if isEnemy then
		target:TriggerSpellReflect(self)

		if target:TriggerSpellAbsorb(self) then
			return
		end
	end

	FindClearSpaceForUnit(caster, targetPos, false)
	FindClearSpaceForUnit(target, casterPos, false)

	ParticleManager:ReleaseParticleIndex(ParticleManager:CreateParticle("particles/econ/events/ti4/blink_dagger_start_ti4.vpcf", PATTACH_ABSORIGIN, caster))
	ParticleManager:ReleaseParticleIndex(ParticleManager:CreateParticle("particles/econ/events/ti4/blink_dagger_start_ti4.vpcf", PATTACH_ABSORIGIN, target))


	if isEnemy then
		local stunDuration = self:GetSpecialValueFor("stun_duration")

		target:AddNewModifier(caster, self, "modifier_shadowsong_dark_reflection_stun", { duration = stunDuration })
	end

	-- Аганим: массовый обмен местами
	local scepterRadius = self:GetSpecialValueFor("scepter_radius")
	if scepterRadius > 0 and isEnemy then
		local scepterStunDuration = self:GetSpecialValueFor("scepter_stun_duration")

		-- Найти врагов в радиусе вокруг цели
		local enemies = FindUnitsInRadius(
			caster:GetTeamNumber(),
			targetPos,
			nil,
			scepterRadius,
			DOTA_UNIT_TARGET_TEAM_ENEMY,
			DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
			DOTA_UNIT_TARGET_FLAG_NONE,
			FIND_ANY_ORDER,
			false
		)

		for _, enemy in pairs(enemies) do
			if enemy ~= target then
				local enemyPos = enemy:GetAbsOrigin()
				FindClearSpaceForUnit(enemy, targetPos, false)
				FindClearSpaceForUnit(target, enemyPos, false)
				target = enemy

				ParticleManager:ReleaseParticleIndex(ParticleManager:CreateParticle("particles/econ/events/ti4/blink_dagger_start_ti4.vpcf", PATTACH_ABSORIGIN, enemy))
				ParticleManager:ReleaseParticleIndex(ParticleManager:CreateParticle("particles/econ/events/ti4/blink_dagger_start_ti4.vpcf", PATTACH_ABSORIGIN, target))

				enemy:AddNewModifier(caster, self, "modifier_shadowsong_dark_reflection_stun", { duration = scepterStunDuration })
			end
		end
	end

	local immuneDuration = caster:GetTalentSpecialValueFor("shadowsong_special_bonus_reflection_magic_immune")

	if immuneDuration ~= 0 then
		caster:AddNewModifier(caster, self, "modifier_shadowsong_dark_reflection_immune", { duration = immuneDuration })
	end

	caster:EmitSound("Hero_Antimage.Counterspell.Cast")
end
