ghost_small_red_manaburn = class({})

-- Сгенерировано: ресурсы, на которые ссылается этот скрипт.
-- Движок зовёт этот метод при прекеше юнита со способностью, поэтому
-- партиклы приезжают вместе с героем (пик/репик), а не на старте карты.
function ghost_small_red_manaburn:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_antimage/antimage_spell_blink.vpcf", context)
end

--------------------------------------------------------------------------------

function ghost_small_red_manaburn:OnSpellStart( keys )
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()

	-- ReduceMana в 7.42 нет, только Script_ReduceMana(кол-во, способность)
	target:Script_ReduceMana( self:GetSpecialValueFor("mana_burn"), self )
	
	target:EmitSound("Hero_Antimage.ManaBreak")

	local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_antimage/antimage_spell_blink.vpcf", PATTACH_ABSORIGIN_FOLLOW, target) 
	ParticleManager:ReleaseParticleIndex(particle)
end
