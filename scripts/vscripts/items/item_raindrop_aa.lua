LinkLuaModifier("modifier_item_raindrop_aa_off", "items/item_raindrop_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_raindrop_aa", "items/item_raindrop_aa", LUA_MODIFIER_MOTION_NONE)

item_raindrop_aa = class({
    GetIntrinsicModifierName = function(self) return "modifier_item_raindrop_aa" end,
})
modifier_item_raindrop_aa_off = class({
    IsHidden = function(self) return false end,
})
modifier_item_raindrop_aa = class({
    IsHidden = function(self) return false end,
    IsPurgable = function(self) return false end,
    GetTexture = function(self) return "item_infused_raindrop" end,
    RemoveOnDeath = function(self) return false end,
    DeclareFunctions = function(self) return {
        MODIFIER_PROPERTY_INCOMING_SPELL_DAMAGE_CONSTANT,
        MODIFIER_PROPERTY_TOOLTIP,
        MODIFIER_EVENT_ON_TAKEDAMAGE,
        MODIFIER_PROPERTY_HEALTH_BONUS,
        MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
        MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
    } end,
    GetModifierConstantHealthRegen = function(self) return self:GetAbility():GetSpecialValueFor("hp_regen") end,
    GetModifierConstantManaRegen = function(self) return self:GetAbility():GetSpecialValueFor("mana_regen") end,
    GetModifierHealthBonus = function(self) return self:GetAbility():GetSpecialValueFor("bonus_hp") end,
    OnTooltip = function(self) return self:GetStackCount() end,
    OnTakeDamage = function(self,e) 
        if e.damage_type ~= DAMAGE_TYPE_MAGICAL then return end
        if e.unit ~= self:GetParent() then return end
        self:GetParent():AddNewModifier(self:GetParent(),self:GetAbility(),"modifier_item_raindrop_aa_off",{duration = self:GetAbility():GetSpecialValueFor("time_since_last_damage")})
    end,
    GetModifierIncomingSpellDamageConstant = function(self,params)
        if IsClient() then 
            return self:GetStackCount()
        end
        if not IsServer() then return end
        if self:GetParent() == params.attacker then return end
        if self:GetStackCount() > params.damage then
            self:SetStackCount(self:GetStackCount() - params.damage)
            local i = params.damage
            return -i
        else
            local i = self:GetStackCount()
            self:SetStackCount(0)
            return -i
        end
    end,
    OnIntervalThink = function(self)
        local addbonus = self:GetStackCount() + self:GetAbility():GetSpecialValueFor("magic_damage_block") / 100 * (self:GetAbility():GetSpecialValueFor("regen_pct")/self:GetAbility():GetSpecialValueFor("regen_tick_per_sec"))
        if not self:GetParent():HasModifier("modifier_item_raindrop_aa_off") then
            if addbonus > self:GetAbility():GetSpecialValueFor("magic_damage_block") then
                self:SetStackCount(self:GetAbility():GetSpecialValueFor("magic_damage_block"))
            else
                self:SetStackCount(addbonus)
            end
        end
    end,

    OnCreated = function(self,kv) 
    if not IsServer() then return end
        self.CanRefresh = true
        self:GetParent():EmitSound("DOTA_Item.Pipe.Activate")
            
        self.particle = ParticleManager:CreateParticle("particles/items2_fx/pipe_of_insight_v2.vpcf", PATTACH_OVERHEAD_FOLLOW, self:GetParent())
        ParticleManager:SetParticleControl(self.particle, 0, self:GetParent():GetAbsOrigin())
        ParticleManager:SetParticleControlEnt(self.particle, 1, self:GetParent(), PATTACH_POINT_FOLLOW, "attach_origin", self:GetParent():GetAbsOrigin(), true)
        ParticleManager:SetParticleControl(self.particle, 2, Vector(125, 0, 0))
        
        self:AddParticle(self.particle,false, false, -1, false, false)
        self:StartIntervalThink(1/self:GetAbility():GetSpecialValueFor("regen_tick_per_sec"))
    end,
})