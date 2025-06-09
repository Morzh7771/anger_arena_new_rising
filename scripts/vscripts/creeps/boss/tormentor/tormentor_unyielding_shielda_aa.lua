LinkLuaModifier( "modifier_tormentor_unyielding_shielda_aa", 'creeps/boss/tormentor/tormentor_unyielding_shielda_aa', LUA_MODIFIER_MOTION_NONE )

tormentor_unyielding_shielda_aa = class({
    GetIntrinsicModifierName = function (self) return "modifier_tormentor_unyielding_shielda_aa" end,
    Spawn = function (self) if IsServer() then return self:SetLevel(1) end end,
})

modifier_tormentor_unyielding_shielda_aa = class ({

    IsDebuff = function (self) return false end,
    IsHidden = function (self) return false end,
    IsPurgable = function (self) return false end,

    OnCreated = function (self)
        if not IsServer() then return end

        self.parent = self:GetParent()
        self.ability = self:GetAbility()

        self.minArmor = self.ability:GetSpecialValueFor("min_armor")

        -- Инициализируем currentShield только при первом создании
        self:UpdateStats()
        if not self.currentShield then
            self.currentShield = self.maxShield
        end

        self.regenPerSecondThink = self.regenPerSecond * FrameTime()
        self:SetHasCustomTransmitterData(true)
        self:StartIntervalThink(FrameTime())
    end,

    OnRefresh = function (self)
        if not IsServer() then return end
        self:UpdateStats()
        self.regenPerSecondThink = self.regenPerSecond * FrameTime()
        self:SendBuffRefreshToClients()
    end,

    UpdateStats = function(self)
        local minute = math.floor(GameRules:GetDOTATime(false, false) / 60)
        local absorbBonusPerInterval = self.ability:GetSpecialValueFor("absorb_bonus_per_interval") * minute
        local regenBonusPerInterval = self.ability:GetSpecialValueFor("regen_bonus_per_interval") * minute

        local maxShieldNew = self.ability:GetSpecialValueFor("damage_absorb") + absorbBonusPerInterval
        local regenPerSecondNew = self.ability:GetSpecialValueFor("regen_per_second") + regenBonusPerInterval

        -- Обновляем maxShield и regenPerSecond
        self.maxShield = maxShieldNew
        self.regenPerSecond = regenPerSecondNew

        -- Если currentShield больше maxShield, уменьшаем currentShield до maxShield
        if self.currentShield and self.currentShield > self.maxShield then
            self.currentShield = self.maxShield
        end
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
            regenPerSecond = self.regenPerSecond,
        }
    end,

    HandleCustomTransmitterData = function (self, data)
        self.currentShield = data.currentShield
        self.maxShield = data.maxShield
        self.regenPerSecond = data.regenPerSecond
    end,

    GetModifierIncomingDamageConstant = function (self,event)
        if IsClient() then
            if event.report_max then
                return self.maxShield
            else
                return self.currentShield
            end
        else
            local damage = event.damage
            if damage <= 0 then return 0 end
            if bit.band(event.damage_flags, DOTA_DAMAGE_FLAG_HPLOSS) == DOTA_DAMAGE_FLAG_HPLOSS then return 0 end

            local barrier_hp = self.currentShield
            local block_amount = math.min(damage, barrier_hp)
            self.currentShield = self.currentShield - block_amount

            if block_amount > 0 then
                SendOverheadEventMessage(nil, OVERHEAD_ALERT_BLOCK, self.parent, block_amount, nil)
            end

            self:SendBuffRefreshToClients()
            event.attacker:EmitSound("Miniboss.Tormenter.Target")

            return -block_amount
        end
    end,

    OnIntervalThink = function (self)
        -- Обновляем параметры с учётом текущего времени
        self:UpdateStats()

        -- Регенерируем щит
        self.currentShield = math.min(self.currentShield + self.regenPerSecond * FrameTime(), self.maxShield)

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
        if self.checkArmor then return 0 end

        self.checkArmor = true
        local base_armor = self.parent:GetPhysicalArmorBaseValue()
        local current_armor = self.parent:GetPhysicalArmorValue(false)
        self.checkArmor = false

        if current_armor < self.minArmor then
            return self.minArmor - current_armor
        end
        return 0
    end,
})
