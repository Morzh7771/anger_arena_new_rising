ghost_small_blue_lightning = class({})

-- Сгенерировано: ресурсы, на которые ссылается этот скрипт.
-- Движок зовёт этот метод при прекеше юнита со способностью, поэтому
-- партиклы приезжают вместе с героем (пик/репик), а не на старте карты.
function ghost_small_blue_lightning:Precache(context)
	PrecacheResource("particle", "particles/econ/items/juggernaut/jugg_arcana/juggernaut_arcana_trigger_beams.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_razor/razor_static_link_beam.vpcf", context)
end

--------------------------------------------------------------------------------

function ghost_small_blue_lightning:OnSpellStart( keys )
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()
	
	if IsServer() then 
		local damage_type = self:GetAbilityDamageType() 

		ApplyDamage({ 
			victim = target, 
			attacker = caster, 
			damage = self:GetSpecialValueFor("damage_main"), 
			damage_type = damage_type, 
			ability = self })

		local units = FindUnitsInRadius(	caster:GetTeamNumber(), 
													target:GetAbsOrigin(), 
													nil, 
													self:GetSpecialValueFor("radius"), 
													DOTA_UNIT_TARGET_TEAM_ENEMY, 
													DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_CREEP, 
													DOTA_UNIT_TARGET_FLAG_NONE, 
													0, 
													false) 
		
		if units then
			for i = 1, #units do
				if units[i] and units[i] ~= target then
					ApplyDamage({ 
						victim = units[i], 
						attacker = caster, 
						damage = self:GetSpecialValueFor("damage_second"), 
						damage_type = damage_type, 
						ability = self })
				end
			end
		end

	end 

	local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_razor/razor_static_link_beam.vpcf",  PATTACH_ABSORIGIN_FOLLOW, target)
	ParticleManager:SetParticleControlEnt(particle, 1, caster, PATTACH_POINT_FOLLOW, "attach_hitloc", caster:GetAbsOrigin(), false)

	local f = function()
		ParticleManager:DestroyParticle(particle, false)
		ParticleManager:ReleaseParticleIndex(particle)
		return nil 
	end 

	Timers:CreateTimer(0.1, f)

	target:EmitSound("Hero_Zuus.ArcLightning.Cast")
	
	local particle2 = ParticleManager:CreateParticle("particles/econ/items/juggernaut/jugg_arcana/juggernaut_arcana_trigger_beams.vpcf",  PATTACH_ABSORIGIN_FOLLOW, target)
	ParticleManager:SetParticleControlEnt(particle2, 1, target, PATTACH_POINT_FOLLOW, "attach_hitloc", target:GetAbsOrigin(), false)
	ParticleManager:ReleaseParticleIndex(particle2)
end
