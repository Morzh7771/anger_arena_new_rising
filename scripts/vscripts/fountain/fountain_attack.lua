LinkLuaModifier( "modifier_fountain_attack", "Fountain/fountain_attack.lua", LUA_MODIFIER_MOTION_NONE )
--Abilities
if fountain_attack == nil then
	fountain_attack = class({})
end
function fountain_attack:GetIntrinsicModifierName()
	return "modifier_fountain_attack"
end
---------------------------------------------------------------------
--Modifiers
if modifier_fountain_attack == nil then
	modifier_fountain_attack = class({})
end
function modifier_fountain_attack:OnCreated(params)
	self.bonusDmg = self:GetAbility():GetSpecialValueFor('BonusPercentDamage')
end

function modifier_fountain_attack:DeclareFunctions()
	return {
        MODIFIER_EVENT_ON_ATTACK,
	}
end
function modifier_fountain_attack:OnAttack(event)
    if event.attacker == self:GetParent() then
        print(event.target:GetMaxHealth()/100*self.bonusDmg)
        local damageTable = {
            victim = event.target,
            attacker = self:GetCaster(),
            damage = event.target:GetMaxHealth()/100*self.bonusDmg,
            damage_type = DAMAGE_TYPE_PURE,
            ability = self:GetAbility(), --Optional.
        }
        ApplyDamage(damageTable)
    end
end
