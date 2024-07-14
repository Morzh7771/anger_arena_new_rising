life_stealer_feast_aa = class({})
LinkLuaModifier( "modifier_life_stealer_feast_aa", "heroes/life_stealer/life_stealer_feast_aa", LUA_MODIFIER_MOTION_NONE )

--------------------------------------------------------------------------------
-- Passive Modifier
function life_stealer_feast_aa:GetIntrinsicModifierName()
	return "modifier_life_stealer_feast_aa"
end

modifier_life_stealer_feast_aa = class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_life_stealer_feast_aa:IsHidden()
	return true
end

function modifier_life_stealer_feast_aa:IsPurgable()
	return false
end

--------------------------------------------------------------------------------
-- Initializations
function modifier_life_stealer_feast_aa:OnCreated( kv )
	-- references
	self.leech_percent = self:GetAbility():GetSpecialValueFor( "hp_leech_percent" )/100 -- special value
	self.damage_percent = self:GetAbility():GetSpecialValueFor( "hp_damage_percent" )/100 -- special value	
end

function modifier_life_stealer_feast_aa:OnRefresh( kv )
	-- references
	self.leech_percent = self:GetAbility():GetSpecialValueFor( "hp_leech_percent" )/100 -- special value	
	self.damage_percent = self:GetAbility():GetSpecialValueFor( "hp_damage_percent" )/100 -- special value	
end

function modifier_life_stealer_feast_aa:OnDestroy( kv )

end

--------------------------------------------------------------------------------
-- Modifier Effects
function modifier_life_stealer_feast_aa:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_PROCATTACK_BONUS_DAMAGE_PHYSICAL,
	}

	return funcs
end

function modifier_life_stealer_feast_aa:GetModifierProcAttack_BonusDamage_Physical( params )
	if IsServer() then
		if self:GetParent():PassivesDisabled() then return end
			local leech = params.target:GetMaxHealth() * self.leech_percent
			local damage = params.target:GetMaxHealth() * self.damage_percent
		if BossSpawner:IsBoss(params.target) then 
			damage = damage / 2
		else 
			self:GetParent():Heal( leech, self:GetParent() )
		end
		self:PlayEffects()
		return damage
	end
end

--------------------------------------------------------------------------------
-- Graphics & Animations
-- function modifier_life_stealer_feast_aa:GetEffectName()
-- 	return "particles/string/here.vpcf"
-- end

-- function modifier_life_stealer_feast_aa:GetEffectAttachType()
-- 	return PATTACH_ABSORIGIN_FOLLOW
-- end

function modifier_life_stealer_feast_aa:PlayEffects()
	-- Get Resources
	local particle_cast = "particles/generic_gameplay/generic_lifesteal.vpcf"

	-- Create Particle
	local effect_cast = ParticleManager:CreateParticle( particle_cast, PATTACH_ABSORIGIN_FOLLOW, self:GetParent() )
	-- ParticleManager:SetParticleControl( effect_cast, iControlPoint, vControlVector )
	-- ParticleManager:SetParticleControlEnt(
	-- 	effect_cast,
	-- 	iControlPoint,
	-- 	hTarget,
	-- 	PATTACH_NAME,
	-- 	"attach_name",
	-- 	vOrigin, -- unknown
	-- 	bool -- unknown, true
	-- )
	ParticleManager:ReleaseParticleIndex( effect_cast )
end