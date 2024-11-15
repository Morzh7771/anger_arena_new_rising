modifier_charon_last_word_aura_effect = class({})

--------------------------------------------------------------------------------
function modifier_charon_last_word_aura_effect:IsHidden()
    return false
end

--------------------------------------------------------------------------------
function modifier_charon_last_word_aura_effect:IsDebuff()
    return true
end

--------------------------------------------------------------------------------
function modifier_charon_last_word_aura_effect:IsPurgable()
    return false
end

--------------------------------------------------------------------------------
function modifier_charon_last_word_aura_effect:OnCreated(kv)
    if not IsServer() then return end
    self.slow_for_mana_pct = self:GetAbility():GetSpecialValueFor("slow_for_mana_pct")
    if self:GetAbility():GetCaster():HasTalent("charon_last_word_bonus_slow_per_mana_tallent") then
        self.slow_for_mana_pct = self.slow_for_mana_pct + self:GetAbility():GetCaster():GetTalentSpecialValueFor("charon_last_word_bonus_slow_per_mana_tallent")
    end
    if self:GetCaster():HasModifier("modifier_item_aghanims_shard") then
        self:StartIntervalThink(self:GetAbility():GetSpecialValueFor("tick_per_sec")/60)
    end
end

-------------------------------------------------------------------------------
function modifier_charon_last_word_aura_effect:OnRefresh(kv)
    if not IsServer() then return end
    self.slow_for_mana_pct = self:GetAbility():GetSpecialValueFor("slow_for_mana_pct")
    if self:GetAbility():GetCaster():HasTalent("charon_last_word_bonus_slow_per_mana_tallent") then
        self.slow_for_mana_pct = self.slow_for_mana_pct + self:GetAbility():GetCaster():GetTalentSpecialValueFor("charon_last_word_bonus_slow_per_mana_tallent")
    end
    if self:GetCaster():HasModifier("modifier_item_aghanims_shard") then
        self:StartIntervalThink(self:GetAbility():GetSpecialValueFor("tick_per_sec")/60)
    end
end
function modifier_charon_last_word_aura_effect:OnDestroy(kv)
    if not IsServer() then return end
    self:StartIntervalThink(-1)
end

-------------------------------------------------------------------------------
function modifier_charon_last_word_aura_effect:DeclareFunctions()
    local funcs = {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
    }
    return funcs
end

function modifier_charon_last_word_aura_effect:OnIntervalThink()
    local damage = (self:GetParent():GetMaxMana() - self:GetParent():GetMana())/100*self:GetAbility():GetSpecialValueFor("damage_per_mana_pct")/self:GetAbility():GetSpecialValueFor("tick_per_sec")
    local info = {
        victim = self:GetParent(),
        attacker = self:GetCaster(),
        damage = damage,
        damage_type = DAMAGE_TYPE_MAGICAL,
    }
    if damage <= 0 then return end
    ApplyDamage(info)
end

-------------------------------------------------------------------------------
function modifier_charon_last_word_aura_effect:GetModifierMoveSpeedBonus_Percentage(params)
    if self:GetCaster():PassivesDisabled() then return end

    local net_table = CustomNetTables:GetTableValue("heroes", "anti_valve_perks") or {}
    local unicalUnitString = tostring("modifier_charon_last_word_aura_effect_movespeed" .. self:GetParent():entindex())
    local bonusMoveSpeed
    if IsServer() then
        bonusMoveSpeed = -((100 - self:GetParent():GetManaPercent()) * self.slow_for_mana_pct)
        net_table[unicalUnitString .. "modifier_charon_last_word_aura_effect_movespeed"] = bonusMoveSpeed
        CustomNetTables:SetTableValue("heroes", "anti_valve_perks", net_table)
    else
        bonusMoveSpeed = net_table[unicalUnitString .. "modifier_charon_last_word_aura_effect_movespeed"]
    end
    return bonusMoveSpeed
end

-------------------------------------------------------------------------------