LinkLuaModifier( "modifier_tormentor_unyielding_shielda_aa", 'creeps/boss/tormentor/tormentor_unyielding_shielda_aa', LUA_MODIFIER_MOTION_NONE )

tormentor_unyielding_shielda_aa = class({
    GetIntrinsicModifierName = function (self) return "modifier_tormentor_unyielding_shielda_aa" end,
    Spawn = function (self) if IsServer() then return self:SetLevel(1) end end,
})

modifier_tormentor_unyielding_shielda_aa = class ({
    IsDebuff = function (self) return false end,
    IsHidden = function (self) return false end,
    IsPurgable = function (self) return false end,
    OnRefresh = function (self)  
        self:OnCreated()
        if IsServer() then self:SendBuffRefreshToClients() end end,
    OnCreated = function (self)
        if not IsServer() then return end

        local parent = self:GetParent()
        local ability = self:GetAbility()

        self.minArmor = ability:GetSpecialValueFor("min_armor")

        self.minute = math.floor(GameRules:GetDOTATime( false, false ) / 60)
        self.absorbBonusPerInterval = ability:GetSpecialValueFor("absorb_bonus_per_interval") * self.minute
        self.regenBonusPerInterval = ability:GetSpecialValueFor("regen_bonus_per_interval") * self.minute

        self.maxShield = ability:GetSpecialValueFor("damage_absorb") + self.absorbBonusPerInterval
        self.currentShield = self.maxShield
        self.regenPerSecond = ability:GetSpecialValueFor("regen_per_second") + self.regenBonusPerInterval
        self.regenPerSecondThink = self.regenPerSecond * FrameTime()

        self:SetHasCustomTransmitterData(true)
        self:StartIntervalThink(FrameTime())
    end,
    DeclareFunctions = function (self)
        return {
            MODIFIER_PROPERTY_INCOMING_DAMAGE_CONSTANT,
            MODIFIER_PROPERTY_TOOLTIP,
            MODIFIER_PROPERTY_TOOLTIP2,
            MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
        }
    end,
    AddCustomTransmitterData = function (self)
        return {
            currentShield = self.currentShield,
            maxShield = self.maxShield,
            regenPerSecond = self.regenPerSecond, -- sent to client only because of MODIFIER_PROPERTY_TOOLTIP2
        }
    end,
    HandleCustomTransmitterData = function (self,data)
        self.currentShield = data.currentShield
        self.maxShield = data.maxShield
        self.regenPerSecond = data.regenPerSecond
    end,
    GetModifierIncomingDamageConstant = function (self,event)
        -- Return the max health on the client if it's a max report, otherwise return the current health
        if IsClient() then
            if event.report_max then
                return self.maxShield
            else
                return self.currentShield
            end
        else
            local damage = event.damage

            -- Don't do anything if damage is 0 or somehow negative
            if damage <= 0 then
                return 0
            end

            -- Don't react to damage with HP removal flag
            if bit.band(event.damage_flags, DOTA_DAMAGE_FLAG_HPLOSS) == DOTA_DAMAGE_FLAG_HPLOSS then
                return 0
            end

            -- Don't block more than remaining hp
            local barrier_hp = self.currentShield
            local block_amount = math.min(damage, barrier_hp)

            -- Reduce barrier hp
            self.currentShield = self.currentShield - block_amount

            if block_amount > 0 then
                -- Visual effect
                local parent = self:GetParent()
                SendOverheadEventMessage(nil, OVERHEAD_ALERT_BLOCK, parent, block_amount, nil)
            end

            -- Tell the client that we need to update the health property
            self:SendBuffRefreshToClients()

            -- EmitSoundOnClient("Miniboss.Tormenter.Target", event.attacker)
            event.attacker:EmitSound("Miniboss.Tormenter.Target")

            return -block_amount
        end
    end,
    OnIntervalThink = function (self)
        self.currentShield = math.min(self.currentShield + self.regenPerSecondThink, self.maxShield)
        self:SendBuffRefreshToClients()
    end,
    OnTooltip = function (self)
        return self.maxShield
    end,
    OnTooltip2 = function (self)
        return self.regenPerSecond
    end,
    
    GetModifierPhysicalArmorBonus = function (self)
        if not IsServer() then return end
    
        local parent = self:GetParent()
        if self.checkArmor then
            return 0
        else
            self.checkArmor = true
            local base_armor = parent:GetPhysicalArmorBaseValue()
            local current_armor = parent:GetPhysicalArmorValue(false)
            self.checkArmor = false
            local min_armor = self.minArmor
            if current_armor < min_armor then
                return min_armor - current_armor
            end
        end
        return 0
    end
})

