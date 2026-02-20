LinkLuaModifier("modifier_item_corrosion_custom", "items/item_corrosion_custom", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_corrosion_custom_active_slow", "items/item_corrosion_custom", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_corrosion_custom_passive_slow", "items/item_corrosion_custom", LUA_MODIFIER_MOTION_NONE)

item_corrosion_custom = class({
    Precache = function (self, context) 
        PrecacheResource("particle", "particles/corrosion_custom.vpcf", context)
        PrecacheResource("particle", "particles/status_fx/status_effect_poison_dazzle.vpcf", context)
        PrecacheResource("particle", "particles/units/heroes/hero_dazzle/dazzle_poison_debuff.vpcf", context)
    end,
    GetIntrinsicModifierName = function (self) return "modifier_item_corrosion_custom" end,
    OnSpellStart = function (self) 
    if not IsServer() then return end
    self:GetCaster():EmitSound("Item.Paintball.Cast")
    for _,mod in pairs(self:GetCaster():FindAllModifiers()) do 
        print(mod:GetName())
    end
    ProjectileManager:CreateTrackingProjectile({
        Target = self:GetCursorTarget(),
        Source = self:GetCaster(),
        Ability = self, 
        EffectName = "particles/corrosion_custom.vpcf",
        iMoveSpeed = 900,
        bReplaceExisting = false,                         
        bProvidesVision = true,                           
        iVisionRadius = 30,        
        iVisionTeamNumber = self:GetCaster():GetTeamNumber()      
    })
    end,
    OnProjectileHit = function (self,hTarget) 
        if not IsServer() then return end
        if hTarget==nil then return end
        if hTarget:IsInvulnerable() then return end
        if hTarget:IsMagicImmune() then return end

        hTarget:AddNewModifier(self:GetCaster(), self, "modifier_item_corrosion_custom_active_slow", {duration = self:GetSpecialValueFor("duration")})
        hTarget:EmitSound("Item.Paintball.Target")
        hTarget:EmitSound("Hero_Dazzle.Poison_Touch")
    end
})

modifier_item_corrosion_custom_active_slow = class({
    IsHidden = function (self) return false end,
    IsPurgable = function (self) return true end,
    GetStatusEffectName = function (self) return "particles/status_fx/status_effect_poison_dazzle.vpcf" end,
    GetEffectName = function (self) return "particles/units/heroes/hero_dazzle/dazzle_poison_debuff.vpcf" end,
    StatusEffectPriority = function (self) return 10000 end,
    OnIntervalThink = function (self) 
        ApplyDamage(self.damageTable)
        SendOverheadEventMessage(self:GetParent(), 4, self:GetParent(), self.damage, nil)
        self:IncrementStackCount()
    end,
    DeclareFunctions = function (self) return {MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE} end,
    GetModifierMoveSpeedBonus_Percentage = function (self) return self.tick*self:GetStackCount() end,
    OnCreated = function (self)
        self.max_slow = self:GetAbility():GetSpecialValueFor("max_slow")
        self.tick = self.max_slow/(self:GetRemainingTime() - 1.5)
        self.damage = self:GetAbility():GetSpecialValueFor("total_damage")/(self:GetAbility():GetSpecialValueFor("duration") + 1)
        self.damageTable = { attacker = self:GetCaster(), victim = self:GetParent(), damage = self.damage, damage_type = DAMAGE_TYPE_PHYSICAL, ability = self:GetAbility() }

        if not IsServer() then return end
        self:OnIntervalThink()
        self:StartIntervalThink(1)
    end,
})


modifier_item_corrosion_custom_passive_slow = class({
    IsHidden = function (self) return false end,
    IsPurgable = function (self) return true end,
    DeclareFunctions = function (self)  
    return{
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
        MODIFIER_PROPERTY_HEAL_AMPLIFY_PERCENTAGE_TARGET,
        MODIFIER_PROPERTY_HP_REGEN_AMPLIFY_PERCENTAGE,
        MODIFIER_PROPERTY_LIFESTEAL_AMPLIFY_PERCENTAGE,
    }
    end,
    GetModifierMoveSpeedBonus_Percentage = function (self) return self.slow end,
    GetModifierLifestealRegenAmplify_Percentage = function (self) return self:GetAbility():GetSpecialValueFor("heal_reduction") end,
    GetModifierHealAmplify_PercentageTarget = function (self) return self:GetAbility():GetSpecialValueFor("heal_reduction") end,
    OnCreated = function (self)
        self.slow = self:GetAbility():GetSpecialValueFor("melee_slow")
        if self:GetCaster():IsRangedAttacker() then 
        self.slow = self:GetAbility():GetSpecialValueFor("ranged_slow")
        end
        self.damageTable = { attacker = self:GetCaster(), victim = self:GetParent(), damage = self:GetAbility():GetSpecialValueFor("damage"), damage_type = DAMAGE_TYPE_MAGICAL, ability = self:GetAbility() }
        if not IsServer() then return end
        self:StartIntervalThink(1)
    end,
    OnRefresh = function (self)
        self.slow = self:GetAbility():GetSpecialValueFor("melee_slow")
        if self:GetCaster():IsRangedAttacker() then 
        self.slow = self:GetAbility():GetSpecialValueFor("ranged_slow")
        end
    end,
    OnIntervalThink = function (self)
        if not IsServer() then return end
        ApplyDamage(self.damageTable)
        SendOverheadEventMessage(self:GetParent(), 4, self:GetParent(), self:GetAbility():GetSpecialValueFor("damage"), nil)
    end,
})


modifier_item_corrosion_custom = class({
    IsHidden = function (self) return true end,
    IsPurgable = function (self) return false end,
    DeclareFunctions = function (self)  
    return{
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
        MODIFIER_EVENT_ON_ATTACK_LANDED
    }
    end,
    GetModifierPhysicalArmorBonus = function (self) if self:GetAbility() then return self:GetAbility():GetSpecialValueFor("armor") end end,
    GetModifierAttackSpeedBonus_Constant = function (self) if self:GetAbility() then return self:GetAbility():GetSpecialValueFor("attack_speed") end end,
})

function modifier_item_corrosion_custom:OnAttackLanded(params)
    if not IsServer() then return end
    if self:GetParent() ~= params.attacker then return end
    if not params.target:IsHero() and not params.target:IsCreep() then return end
    if params.target:IsMagicImmune() then return end
    if self:GetParent():HasModifier("modifier_item_orb_of_venom") then return end

    params.target:AddNewModifier(self:GetCaster(), self:GetAbility(), "modifier_item_corrosion_custom_passive_slow", {duration = self:GetAbility():GetSpecialValueFor("duration_passive")})
end


