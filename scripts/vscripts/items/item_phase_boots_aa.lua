LinkLuaModifier("modifier_item_phase_boots_aa", "items/item_phase_boots_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_phase_boots_aa_active", "items/item_phase_boots_aa", LUA_MODIFIER_MOTION_HORIZONTAL)

item_phase_boots_aa_2 = item_phase_boots_aa

item_phase_boots_aa = class({
    GetIntrinsicModifierName = function (self) return "modifier_item_phase_boots_aa"end,
    GetCastRange = function (self) if IsClient() then return self:GetSpecialValueFor("range") end return 99999 end,
    OnSpellStart =  function (self)
        if not IsServer() then return end

        local point = self:GetCaster():GetCursorPosition()
        if point == self:GetCaster():GetAbsOrigin() then 
            point = self:GetCaster():GetForwardVector()*10 + self:GetCaster():GetAbsOrigin()
        end

        local dir = (point - self:GetCaster():GetAbsOrigin()):Normalized()

        self:GetCaster():SetForwardVector(dir)
        self:GetCaster():FaceTowards(point)

        ProjectileManager:ProjectileDodge(self:GetCaster())

        self:GetCaster():EmitSound("Item.Falcon_blade")
        self:GetCaster():AddNewModifier(self:GetCaster(), self, "modifier_item_phase_boots_aa_active", {x = point.x, y = point.y, z = point.z, duration = self:GetSpecialValueFor("duration")})
        self:GetCaster():AddNewModifier(self:GetCaster(), self, "modifier_item_phase_boots_active", {duration = self:GetSpecialValueFor("phase_duration")})
    end,
})
item_phase_boots_aa_2 = item_phase_boots_aa

modifier_item_phase_boots_aa_active = class({
    IsDebuff = function (self) return false end,
    IsHidden = function (self) return true end,
    IsPurgable = function (self) return true end,
    GetActivityTranslationModifiers = function (self) return "haste" end,
    GetModifierDisableTurning = function (self) return 1 end,
    GetEffectName = function (self) return "particles/falcon_blade_charge.vpcf" end,
    GetStatusEffectName = function (self) return "particles/status_fx/status_effect_forcestaff.vpcf" end,
    StatusEffectPriority = function (self) return 100 end,
    DeclareFunctions = function (self) 
        return
        {
            MODIFIER_PROPERTY_TRANSLATE_ACTIVITY_MODIFIERS,
            MODIFIER_PROPERTY_DISABLE_TURNING
        } 
    end,
    OnCreated = function (self,kv) 
        if not IsServer() then return end
        self.pfx = ParticleManager:CreateParticle("particles/items_fx/force_staff.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
        self:GetParent():StartGesture(ACT_DOTA_RUN)
    
        self.point = Vector(kv.x, kv.y, kv.z)
    
        self.angle = self:GetParent():GetForwardVector():Normalized()--(self.point - self:GetParent():GetAbsOrigin()):Normalized() 
    
        self.distance = self:GetAbility():GetSpecialValueFor("range") / ( self:GetDuration() / FrameTime())
    
        self.targets = {}
    
        if self:ApplyHorizontalMotionController() == false then
            self:Destroy()
        end
    end,
    OnDestroy = function (self) 
        if not IsServer() then return end
        self:GetParent():InterruptMotionControllers( true )
        ParticleManager:DestroyParticle(self.pfx, false)
        ParticleManager:ReleaseParticleIndex(self.pfx)

        self:GetParent():FadeGesture(ACT_DOTA_RUN)

        local dir = self:GetParent():GetForwardVector()
        dir.z = 0
        self:GetParent():SetForwardVector(dir)
        self:GetParent():FaceTowards(self:GetParent():GetAbsOrigin() + dir*10)

        ResolveNPCPositions(self:GetParent():GetAbsOrigin(), 128)
    end,
    UpdateHorizontalMotion = function (self) 
        if not IsServer() then return end
        local pos = self:GetParent():GetAbsOrigin()
        GridNav:DestroyTreesAroundPoint(pos, 80, false)
        local pos_p = self.angle * self.distance
        local next_pos = GetGroundPosition(pos + pos_p,self:GetParent())
        self:GetParent():SetAbsOrigin(next_pos)
    end,
    OnHorizontalMotionInterrupted = function (self) 
        self:Destroy()
    end,
})

modifier_item_phase_boots_aa = class({
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    IsHidden = function (self) return true end,
    IsPurgable = function (self) return false end,
    DeclareFunctions = function (self) 
        return {
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
        MODIFIER_PROPERTY_MOVESPEED_BONUS_UNIQUE,
        MODIFIER_PROPERTY_HEALTH_BONUS,
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
        MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
    }
    end,
    GetModifierHealthBonus = function (self)  if self:GetAbility() then return self:GetAbility():GetSpecialValueFor("bonus_health") end end,
    GetModifierConstantManaRegen = function (self) if self:GetAbility() then return self:GetAbility():GetSpecialValueFor("bonus_mana_regen") end end,
    GetModifierPreAttack_BonusDamage = function (self) if self:GetAbility() and self:GetCaster():IsRangedAttacker() then
            return self:GetAbility():GetSpecialValueFor("bonus_damage_range")
        else 
            return self:GetAbility():GetSpecialValueFor("bonus_damage_melee")
        end 
    end,
    GetModifierMoveSpeedBonus_Special_Boots = function (self) if self:GetAbility() then return self:GetAbility():GetSpecialValueFor("bonus_movement_speed") end end,

    GetModifierPhysicalArmorBonus = function (self) if self:GetAbility() then return self:GetAbility():GetSpecialValueFor("bonus_armor") end end,
})