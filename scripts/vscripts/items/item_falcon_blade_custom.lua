LinkLuaModifier("modifier_item_falcon_blade_custom", "items/item_falcon_blade_custom", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_falcon_blade_custom_active", "items/item_falcon_blade_custom", LUA_MODIFIER_MOTION_HORIZONTAL)

item_falcon_blade_custom = class({
    Precache = function (self, context) 
        PrecacheResource("particle", "particles/falcon_blade_charge.vpcf", context)
        PrecacheResource("particle", "particles/items_fx/force_staff.vpcf", context)
        PrecacheResource("particle", "particles/status_fx/status_effect_forcestaff.vpcf", context)
    end,
    GetIntrinsicModifierName = function (self) return "modifier_item_falcon_blade_custom"end,
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

        self:GetCaster():EmitSound("DOTA_Item.Force_Boots.Cast")
        self:GetCaster():AddNewModifier(self:GetCaster(), self, "modifier_item_falcon_blade_custom_active", {x = point.x, y = point.y, z = point.z, duration = self:GetSpecialValueFor("duration")})

    end,
})

modifier_item_falcon_blade_custom_active = class({
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

modifier_item_falcon_blade_custom = class({
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    IsHidden = function (self) return true end,
    IsPurgable = function (self) return false end,
    DeclareFunctions = function (self) 
        return {
        MODIFIER_PROPERTY_HEALTH_BONUS,
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
        MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
        MODIFIER_EVENT_ON_TAKEDAMAGE
    }
    end,
    GetModifierHealthBonus = function (self)  if self:GetAbility() then return self:GetAbility():GetSpecialValueFor("bonus_health") end end,
    GetModifierConstantManaRegen = function (self) if self:GetAbility() then return self:GetAbility():GetSpecialValueFor("bonus_mana_regen") end end,
    GetModifierPreAttack_BonusDamage = function (self) if self:GetAbility() then return self:GetAbility():GetSpecialValueFor("bonus_damage") end end,
    OnTakeDamage = function (self,params)
        if not IsServer() then return end
        if self:GetParent() ~= params.unit then return end
        if self:GetParent() == params.attacker then return end
        if not params.attacker:IsRealHero() and not params.attacker:IsIllusion() then return end
        if bit.band(params.damage_flags, DOTA_DAMAGE_FLAG_REFLECTION) == DOTA_DAMAGE_FLAG_REFLECTION then return end

        if params.damage < 5 then return end
        if self:GetAbility():GetCooldownTime() > self:GetAbility():GetSpecialValueFor("damage_cd") then return end

        self:GetAbility():EndCooldown()
        self:GetAbility():StartCooldown(self:GetAbility():GetSpecialValueFor("damage_cd"))
    end,
})