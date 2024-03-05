LinkLuaModifier( "modifier_shield_of_immortality", 'items/shield_of_immortality/item_shield_of_immortality', LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_shield_of_immortality_hex", 'items/shield_of_immortality/item_shield_of_immortality', LUA_MODIFIER_MOTION_NONE )

item_shield_of_immortality = class({
    GetIntrinsicModifierName = function (self) return "modifier_shield_of_immortality" end,
    OnSpellStart = function (self)
         if not IsServer() then return end

         local caster = self:GetCaster()

         caster:AddNewModifier(caster, self, "modifier_shield_of_immortality_hex", { duration = self:GetSpecialValueFor("barrier_duration")})
         if (caster:GetName() == "npc_dota_hero_axe") then
         	EmitSoundOn("axe_axe_sheepstick_02", self:GetCaster())
         else
            EmitSoundOn("General.MorphIn", self:GetCaster())
         end

         Timers:CreateTimer("som_sheep_" .. tostring(caster:entindex()), {
            useGameTime = true,
            endTime = 0,
            callback = function()
               EmitSoundOn("Hero_ShadowShaman.SheepHex.Target", self:GetCaster())
               return 1.1
            end
         })
         Timers:CreateTimer({
            useGameTime = true,
            endTime = self:GetSpecialValueFor("barrier_duration"),
            callback = function()
               Timers:RemoveTimer("som_sheep_" .. tostring(caster:entindex()))
               EmitSoundOn("General.MorphOut", self:GetCaster())
            end
         })
    end
})

modifier_shield_of_immortality = class ({
    IsBuff = function (self) return true end,
    IsHidden = function (self) return true end,
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    DeclareFunctions = function (self)
        return {
            MODIFIER_PROPERTY_HEALTH_BONUS,
            MODIFIER_PROPERTY_INCOMING_DAMAGE_CONSTANT,
            MODIFIER_PROPERTY_MANA_BONUS,
            MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
            MODIFIER_PROPERTY_PHYSICAL_CONSTANT_BLOCK
        }
    end,
    GetModifierHealthBonus = function (self) return self:GetAbility():GetSpecialValueFor('bonus_hp') end,
    GetModifierManaBonus = function (self) return self:GetAbility():GetSpecialValueFor('bonus_mp') end,
    GetModifierConstantHealthRegen = function (self) return self:GetAbility():GetSpecialValueFor('bonus_hp_regen') end,
    GetModifierPhysical_ConstantBlock = function (self)
        local proc = (RandomInt(1, 100) + math.random()) / 100

        if proc <= self:GetAbility():GetSpecialValueFor("block_chance") / 100 then
            if (self:GetParent():IsRangedAttacker()) then
                return self:GetAbility():GetSpecialValueFor("block_damage_ranged")
            else
                return self:GetAbility():GetSpecialValueFor("block_damage_melee")
            end
        end
    end,
    GetModifierIncomingDamageConstant = function (self, params)
        if (self:GetParent():HasModifier("modifier_shield_of_immortality_hex")) then
            local mult = self:GetAbility():GetSpecialValueFor("barrier_percent") / 100

            self:SetStackCount(self:GetStackCount() + mult * params.original_damage)

            if IsServer() then
                return params.original_damage * -1
            end

            if IsClient() then
                return self:GetStackCount()
            end
        end

        local damage_left = params.original_damage - self:GetStackCount()

        if (damage_left < 0) then
            damage_left = 0
        end

        local blocked = self:GetStackCount()

        self:SetStackCount(self:GetStackCount() - params.original_damage)

        if (self:GetStackCount() < 0) then
            self:SetStackCount(0)
        end

        if IsServer() then
            return blocked * -1
        end

        if IsClient() then
            return self:GetStackCount()
        end
    end,
    OnCreated = function (self)
        Timers:CreateTimer("som_decay" .. tostring(self:GetParent():entindex()), {
            useGameTime = true,
            endTime = 0,
            callback = function()
               local decay_mult = self:GetAbility():GetSpecialValueFor("barrier_decay")

               if (self:GetParent():HasModifier("modifier_shield_of_immortality_hex")) then
                   decay_mult = 0
               end

               self:SetStackCount(self:GetStackCount() - self:GetStackCount() / 100 * decay_mult / 10)

               return 0.1
            end
        })
    end,
    OnRemoved = function (self)
        Timers:RemoveTimer("som_decay" .. tostring(self:GetParent():entindex()))
    end
})

modifier_shield_of_immortality_hex = class ({
    IsBuff = function (self) return true end,
    --GetEffectName = function (self) return "particles/units/heroes/hero_winter_wyvern/wyvern_cold_embrace_buff.vpcf" end,
    GetEffectName = function (self) return "particles/units/heroes/hero_winter_wyvern/wyvern_cold_embrace_buff.vpcf" end,
    GetTexture = function (self) return "../items/shield_of_immortality" end,
    DeclareFunctions = function (self)
        return {
            MODIFIER_PROPERTY_MODEL_CHANGE
        }
    end,
    CheckState = function (self)
        return {
            [MODIFIER_STATE_DISARMED] = true,
            [MODIFIER_STATE_SILENCED] = true,
            [MODIFIER_STATE_STUNNED] = true,
        }
    end,
    GetModifierModelChange = function (self) return "models/items/hex/sheep_hex/sheep_hex_gold.vmdl" end,
})