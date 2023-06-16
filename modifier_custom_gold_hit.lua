modifier_custom_gold_hit = class({})

--------------------------------------------------------------------------------


function modifier_custom_gold_hit:IsHidden()
	return false
end
function modifier_custom_gold_hit:IsPurgable()
	return false
end
function modifier_custom_gold_hit:IsDebuff() 
	return false
end
function modifier_custom_gold_hit:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE end

function modifier_custom_gold_hit:OnCreated( kv )
	self.gold_cost_damage1 = self:GetAbility():GetSpecialValueFor( "gold_cost_damage" )
	self.damage_per_gold1 = self:GetAbility():GetSpecialValueFor( "damage_per_gold" )
	self:StartIntervalThink(1)
end
local talent_name_1 = "special_bonus_unique_custom_gold_hit"
function modifier_custom_gold_hit:GetModifierProcAttack_Feedback(keys)
	local particleName = "particles/custom/mammonite_small.vpcf"
	if self:GetStackCount() > 50 and self:GetStackCount() < 200 then
		particleName = "particles/custom/mammonite_medium.vpcf"
	elseif self:GetStackCount() >= 200 then
		particleName = "particles/custom/mammonite_large.vpcf"
	end
	
	local coin_pfx = ParticleManager:CreateParticle(particleName, PATTACH_CUSTOMORIGIN, nil)
	ParticleManager:SetParticleControl(coin_pfx, 0, keys.target:GetAbsOrigin())
	ParticleManager:ReleaseParticleIndex(coin_pfx)
end
function modifier_custom_gold_hit:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE
	}
	return funcs
end
function modifier_custom_gold_hit:GetModifierPreAttack_BonusDamage()
	local damage_per_gold = self.damage_per_gold1
	return self:GetStackCount()*damage_per_gold--урон от стаков
end
function modifier_custom_gold_hit:OnIntervalThink()
	if IsClient() then return end
	local gold_cost_damage = self.gold_cost_damage1
	local hero = self:GetParent()
	 if hero:HasAbility(talent_name_1) and  hero:FindAbilityByName(talent_name_1):GetLevel() ~= 0 then
	 	gold_cost_damage = gold_cost_damage - hero:FindAbilityByName(talent_name_1):GetSpecialValueFor("value")
	 end
	self:SetStackCount(math.floor(self:GetParent():GetGold() / gold_cost_damage))
	--self:SetStackCount(math.floor(self:GetParent():GetGold() / self:GetAbility():GetSpecialValueFor("damage_per_gold")))--единица демеджа за такое количество голы 
end