require("lib/attack_potency")
LinkLuaModifier("modifier_item_dark_edge", "items/item_dark_edge", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_dark_edge_debuff", "items/item_dark_edge", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_dark_edge_cold", "items/item_dark_edge", LUA_MODIFIER_MOTION_NONE)

item_dark_edge = class({
    Precache = function(self, context)
        PrecacheResource("particle", "particles/items3_fx/silver_edge.vpcf", context)
        PrecacheResource("particle", "particles/status_fx/status_effect_frost_lich.vpcf", context)
    end,
    GetIntrinsicModifierName = function(self) return 'modifier_item_dark_edge' end,
    OnSpellStart = function (self)
        EmitSoundOn("DOTA_Item.MaskOfMadness.Activate", self:GetCaster())
        self:GetCaster():AddNewModifier(self:GetCaster(), self, "modifier_item_silver_edge_windwalk", {duration = self:GetSpecialValueFor("windwalk_duration")})
    end
})

modifier_item_dark_edge = class({
    IsHidden = function(self) return true end,
    GetAttributes = function(self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    GetTexture = function (self) return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "") end,
    DeclareFunctions = function(self) return 
        {
            MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
            MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
            MODIFIER_EVENT_ON_ATTACK_LANDED,
            MODIFIER_PROPERTY_STATS_STRENGTH_BONUS, -- GetModifierBonusStats_Strength
            MODIFIER_PROPERTY_STATS_AGILITY_BONUS, -- GetModifierBonusStats_Agility
            MODIFIER_PROPERTY_STATS_INTELLECT_BONUS, -- GetModifierBonusStats_Intellect
            MODIFIER_PROPERTY_HEALTH_BONUS,
            MODIFIER_PROPERTY_MANA_BONUS,
            MODIFIER_EVENT_ON_ATTACK,
            MODIFIER_EVENT_ON_ATTACK_RECORD_DESTROY,
        }
    end,
    GetModifierPreAttack_BonusDamage = function (self) return self:GetAbility():GetSpecialValueFor("bonus_damage") end,
    GetModifierAttackSpeedBonus_Constant = function (self) return self:GetAbility():GetSpecialValueFor("bonus_attack_speed") end,
    GetModifierBonusStats_Strength = function (self) return self:GetAbility():GetSpecialValueFor("bonus_all_stats") end,
    GetModifierBonusStats_Agility = function (self) return self:GetAbility():GetSpecialValueFor("bonus_all_stats") end,
    GetModifierBonusStats_Intellect = function (self) return self:GetAbility():GetSpecialValueFor("bonus_all_stats") end,
    GetModifierHealthBonus = function (self) return self:GetAbility():GetSpecialValueFor("bonus_health") end,
    GetModifierManaBonus = function (self) return self:GetAbility():GetSpecialValueFor("bonus_mana") end,
    -- Удар из Shadow Walk. Инвиз снимается в момент вылета атаки, а иногда и
    -- раньше нашего события, поэтому помним, когда инвиз был в последний раз
    -- (думалка каждый кадр), и метим удар по его record. Брейк вешается, когда
    -- именно этот удар попал - хоть снаряд летит секунду.
    OnCreated = function (self)
        if not IsServer() then return end
        self.ww_time = -100
        self.backstab_records = {}
        self:StartIntervalThink(FrameTime())
    end,
    OnIntervalThink = function (self)
        if self:GetParent():HasModifier("modifier_item_silver_edge_windwalk") then
            self.ww_time = GameRules:GetGameTime()
        end
    end,
    OnAttack = function (self, keys)
        if not IsServer() or keys.attacker ~= self:GetParent() then return end
        local recent = GameRules:GetGameTime() - (self.ww_time or -100) <= 0.2
        if recent or self:GetParent():HasModifier("modifier_item_silver_edge_windwalk") then
            self.backstab_records[keys.record] = true
            self.ww_time = -100 -- один удар из инвиза - один брейк
            print("[AA.silver] удар из инвиза помечен, record " .. tostring(keys.record))
        end
    end,
    OnAttackRecordDestroy = function (self, keys)
        if self.backstab_records then self.backstab_records[keys.record] = nil end
    end,
    OnAttackLanded = function (self,keys) 
        if keys.attacker == self:GetParent() then
            local ability = self:GetAbility()
            local target = keys.target
            local potency = IsServer() and AttackPotency:Get(self:GetParent(), keys) or 1
            -- свой холод: ванильный modifier_item_skadi_slow от Lua-предмета значений не берёт
            if IsServer() and target:GetTeamNumber() ~= self:GetParent():GetTeamNumber() and not target:IsBuilding() and not target:IsMagicImmune() then
                target:AddNewModifier(self:GetParent(), ability, "modifier_item_dark_edge_cold", AttackPotency:Kv(potency, {duration = ability:GetSpecialValueFor("cold_duration")}))
            end

            if IsServer() and self.backstab_records and self.backstab_records[keys.record] then
                self.backstab_records[keys.record] = nil
                if target:GetTeamNumber() ~= self:GetParent():GetTeamNumber() and not target:IsBuilding() and not target:IsMagicImmune() then
                    target:AddNewModifier(self:GetParent(), ability, "modifier_item_dark_edge_debuff", {duration = ability:GetSpecialValueFor("backstab_duration") * potency})
                    print("[AA.silver] брейк на " .. target:GetUnitName() .. " на " .. tostring(ability:GetSpecialValueFor("backstab_duration")) .. " с")
                end
            end
        end
    end,
})

-- Брейк от удара из Shadow Walk: отключает пассивные способности цели
modifier_item_dark_edge_debuff = class({
    IsHidden = function(self) return false end,
    IsDebuff = function(self) return true end,
    IsPurgable = function(self) return true end,
    GetTexture = function(self) return "item_dark_edge" end,
    GetEffectName = function(self) return "particles/items3_fx/silver_edge.vpcf" end,
    GetEffectAttachType = function(self) return PATTACH_ABSORIGIN_FOLLOW end,
    CheckState = function(self) return { [MODIFIER_STATE_PASSIVES_DISABLED] = true } end,
})

-- Cold Attack: замедление бега и атаки (по типу атаки цели) и срез лечения
modifier_item_dark_edge_cold = class({
    IsHidden = function(self) return false end,
    IsDebuff = function(self) return true end,
    IsPurgable = function(self) return true end,
    GetTexture = function(self) return "item_dark_edge" end,
    GetStatusEffectName = function(self) return "particles/status_fx/status_effect_frost_lich.vpcf" end,
    StatusEffectPriority = function(self) return 10 end,
})

function modifier_item_dark_edge_cold:OnCreated(kv)
    self:OnRefresh(kv)
end

-- замедления и срез лечения с действенностью атаки (apply_effectiveness, как у Skadi)
function modifier_item_dark_edge_cold:OnRefresh(kv)
    AttackPotency:Attach(self, kv)
    local ability = self:GetAbility()
    self.move, self.attack, self.heal = 0, 0, 0
    if not ability or ability:IsNull() then return end

    local ranged = self:GetParent():IsRangedAttacker()
    self.move = ability:GetSpecialValueFor(ranged and "cold_slow_ranged" or "cold_slow_melee")
    self.attack = ability:GetSpecialValueFor(ranged and "cold_attack_slow_ranged" or "cold_attack_slow_melee")
    self.heal = -math.abs(ability:GetSpecialValueFor("heal_reduction"))
end

function modifier_item_dark_edge_cold:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
        MODIFIER_PROPERTY_HEAL_AMPLIFY_PERCENTAGE_TARGET,
        MODIFIER_PROPERTY_HP_REGEN_AMPLIFY_PERCENTAGE,
        MODIFIER_PROPERTY_LIFESTEAL_AMPLIFY_PERCENTAGE,
        MODIFIER_PROPERTY_SPELL_LIFESTEAL_AMPLIFY_PERCENTAGE,
    }
end

AttackPotency:Transmitter(modifier_item_dark_edge_cold)

function modifier_item_dark_edge_cold:GetModifierMoveSpeedBonus_Percentage() return self.move * self:Potency() end
function modifier_item_dark_edge_cold:GetModifierAttackSpeedBonus_Constant() return self.attack * self:Potency() end
function modifier_item_dark_edge_cold:GetModifierHealAmplify_PercentageTarget() return self.heal * self:Potency() end
function modifier_item_dark_edge_cold:GetModifierHPRegenAmplify_Percentage() return self.heal * self:Potency() end
function modifier_item_dark_edge_cold:GetModifierLifestealRegenAmplify_Percentage() return self.heal * self:Potency() end
function modifier_item_dark_edge_cold:GetModifierSpellLifestealRegenAmplify_Percentage() return self.heal * self:Potency() end
