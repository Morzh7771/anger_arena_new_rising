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
function modifier_charon_last_word_aura_effect:SyncSlowStacks()
    self:SetStackCount(math.floor(self.slow_for_mana_pct * 100 + 0.5))
end

function modifier_charon_last_word_aura_effect:OnCreated(kv)
    if not IsServer() then return end
    self.slow_for_mana_pct = self:GetAbility():GetSpecialValueFor("slow_for_mana_pct")
    if self:GetAbility():GetCaster():HasTalent("charon_last_word_bonus_slow_per_mana_tallent") then
        self.slow_for_mana_pct = self.slow_for_mana_pct + self:GetAbility():GetCaster():GetTalentSpecialValueFor("charon_last_word_bonus_slow_per_mana_tallent")
    end
    self:SyncSlowStacks()
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
    self:SyncSlowStacks()
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

    -- Раньше значение ехало на клиент через общую нет-таблицу, которую сервер
    -- переписывал и рассылал на каждый пересчёт скорости. Ману клиент знает
    -- сам, а коэффициент (с талантом он есть только на сервере) лежит в
    -- стаках, умноженный на 100 - см. SyncSlowStacks.
    local slowPct = self:GetStackCount() / 100

    return -((100 - self:GetParent():GetManaPercent()) * slowPct)
end

-------------------------------------------------------------------------------