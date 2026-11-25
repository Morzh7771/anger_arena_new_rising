-- Reaver Lord: Superiority Instinct. Порт из Angel Arena Global (datadriven), переписано на Lua.
-- Пассивка: если в начале атаки у Reaver Lord % HP не меньше, чем у цели, и есть души -
-- бонус к урону за каждую душу (плоский + % базового) и вампиризм на эту атаку.
-- В Global datadriven не умножал свойства на стаки, бонус был как за одну душу;
-- тут работает как в описании - за каждую душу.

require("heroes/reaver_lord/reaver_lord_soul_collector")

reaver_lord_superiority_instinct = class({})

LinkLuaModifier("modifier_reaver_lord_superiority_instinct", "heroes/reaver_lord/reaver_lord_superiority_instinct", LUA_MODIFIER_MOTION_NONE)

function reaver_lord_superiority_instinct:GetIntrinsicModifierName()
	return "modifier_reaver_lord_superiority_instinct"
end

--------------------------------------------------------------------------------

modifier_reaver_lord_superiority_instinct = class({})

function modifier_reaver_lord_superiority_instinct:IsHidden() return self:GetStackCount() == 0 end
function modifier_reaver_lord_superiority_instinct:IsPurgable() return false end
function modifier_reaver_lord_superiority_instinct:RemoveOnDeath() return false end

function modifier_reaver_lord_superiority_instinct:OnCreated()
	self:OnRefresh()
end

function modifier_reaver_lord_superiority_instinct:OnRefresh()
	local ability = self:GetAbility()
	if not ability then return end
	self.damage_const = ability:GetSpecialValueFor("damage_const")
	self.damage_pct = ability:GetSpecialValueFor("damage_pct")
	self.lifesteal = ability:GetSpecialValueFor("lifesteal")
end

function modifier_reaver_lord_superiority_instinct:DeclareFunctions()
	return {
		MODIFIER_EVENT_ON_ATTACK_START,
		MODIFIER_EVENT_ON_TAKEDAMAGE,
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
		MODIFIER_PROPERTY_BASEDAMAGEOUTGOING_PERCENTAGE,
	}
end

-- Стак = число душ, если условие выполнено, иначе 0
function modifier_reaver_lord_superiority_instinct:OnAttackStart(params)
	if not IsServer() then return end

	local parent = self:GetParent()
	if params.attacker ~= parent then return end

	local target = params.target
	local souls = ReaverLordGetSouls(parent)

	if parent:PassivesDisabled() or not target or souls == 0 or parent:GetHealthPercent() < target:GetHealthPercent() then
		self:SetStackCount(0)
	else
		self:SetStackCount(souls)
	end
end

function modifier_reaver_lord_superiority_instinct:GetModifierPreAttack_BonusDamage()
	return self.damage_const * self:GetStackCount()
end

function modifier_reaver_lord_superiority_instinct:GetModifierBaseDamageOutgoing_Percentage()
	return self.damage_pct * self:GetStackCount()
end

function modifier_reaver_lord_superiority_instinct:OnTakeDamage(params)
	if not IsServer() then return end

	local parent = self:GetParent()
	if params.attacker ~= parent or self:GetStackCount() == 0 then return end
	if params.damage_category ~= DOTA_DAMAGE_CATEGORY_ATTACK then return end
	if not params.unit or params.unit:IsBuilding() or params.unit:GetTeamNumber() == parent:GetTeamNumber() then return end

	parent:Heal(params.damage * self.lifesteal / 100, self:GetAbility())
	local pfx = ParticleManager:CreateParticle("particles/generic_gameplay/generic_lifesteal.vpcf", PATTACH_ABSORIGIN_FOLLOW, parent)
	ParticleManager:ReleaseParticleIndex(pfx)
end
