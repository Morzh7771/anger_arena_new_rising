LinkLuaModifier( "modifier_curruption_armor_debuff_1", "items/desolator_blood.lua", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_curruption_armor_debuff_2", "items/desolator_blood.lua", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_curruption_armor_debuff_3", "items/desolator_blood.lua", LUA_MODIFIER_MOTION_NONE )

LinkLuaModifier( "modifier_item_desolator_lua_1", "items/desolator_blood.lua", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_item_desolator_lua_2", "items/desolator_blood.lua", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_item_desolator_lua_3", "items/desolator_blood.lua", LUA_MODIFIER_MOTION_NONE )

LinkLuaModifier( "modifier_blood", "items/desolator_blood.lua", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_blood_count", "items/desolator_blood.lua", LUA_MODIFIER_MOTION_NONE )

item_desolator_aa_1 = class({
    GetIntrinsicModifierName = function (self) return "modifier_item_desolator_lua_1" end
})
item_desolator_aa_2 = class({
    GetIntrinsicModifierName = function (self) return "modifier_item_desolator_lua_2" end
})
item_desolator_aa_3 = class({
    GetIntrinsicModifierName = function (self) return "modifier_item_desolator_lua_3" end
})

modifier_item_desolator_lua_1 = class({
    IsHidden = function (self) return true end,
    IsPurgable = function (self) return false end,
    RemoveOnDeath = function (self) return false end,
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    DeclareFunctions = function (self) 
    local funcs = {
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
		MODIFIER_PROPERTY_PROJECTILE_NAME,
		MODIFIER_PROPERTY_PROCATTACK_FEEDBACK
    }
    if self:GetAbility():GetName() == "item_desolator_aa_3" then table.insert(funcs, MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT ) end
        return funcs
    end,
    CheckState = function (self)
        if self:GetAbility():GetName() == "item_desolator_aa_3" then return {[MODIFIER_STATE_CANNOT_MISS] = true,} end
    end,
    GetModifierAttackSpeedBonus_Constant = function (self) return self:GetAbility():GetSpecialValueFor("bonus_attack_speed") end,
    GetModifierProjectileName = function (self) return "particles/items_fx/desolator_projectile.vpcf" end,
    GetModifierPreAttack_BonusDamage = function (self) return self:GetAbility():GetSpecialValueFor("bonus_damage")  end,
})

modifier_item_desolator_lua_2 = modifier_item_desolator_lua_1
modifier_item_desolator_lua_3 = modifier_item_desolator_lua_1

function modifier_item_desolator_lua_1:GetModifierProcAttack_Feedback(data)
    if data.target:HasModifier("modifier_curruption_armor_debuff_2") or data.target:HasModifier("modifier_curruption_armor_debuff_3") then return end
	data.target:AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_curruption_armor_debuff_1", {duration = self:GetAbility():GetSpecialValueFor("corruption_duration"),})
end

function modifier_item_desolator_lua_2:GetModifierProcAttack_Feedback(data)
    if data.target:HasModifier("modifier_curruption_armor_debuff_3") then return end
    if data.target:HasModifier("modifier_curruption_armor_debuff_1") then data.target:RemoveModifierByName("modifier_curruption_armor_debuff_1") end
    data.target:AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_curruption_armor_debuff_2", {duration = self:GetAbility():GetSpecialValueFor("corruption_duration"),})
end

function modifier_item_desolator_lua_3:GetModifierProcAttack_Feedback(data)
    if data.target:HasModifier("modifier_curruption_armor_debuff_1") then data.target:RemoveModifierByName("modifier_curruption_armor_debuff_1") end
    if data.target:HasModifier("modifier_curruption_armor_debuff_2") then data.target:RemoveModifierByName("modifier_curruption_armor_debuff_2") end
    if RollPseudoRandomPercentage(self:GetAbility():GetSpecialValueFor("chance"),12,self:GetParent()) then
        data.target:AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_blood_count", {duration = self:GetAbility():GetSpecialValueFor("corruption_duration")})
        data.target:AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_blood", {duration = self:GetAbility():GetSpecialValueFor("corruption_duration")})
    end
    data.target:AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_curruption_armor_debuff_3", {duration = self:GetAbility():GetSpecialValueFor("corruption_duration"),})
end

modifier_curruption_armor_debuff_1 = class({
    IsHidden = function (self) return false end,
    IsPurgable = function (self) return true end,
    RemoveOnDeath = function (self) return true end,
    DeclareFunctions= function (self) return {
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS
	}end,
    GetModifierPhysicalArmorBonus = function (self) return self:GetAbility():GetSpecialValueFor("corruption_armor") * -1 end,
    GetTexture = function (self) return "item_desolator" end
})
modifier_curruption_armor_debuff_2 = modifier_curruption_armor_debuff_1
modifier_curruption_armor_debuff_3 = modifier_curruption_armor_debuff_1

modifier_blood = ({
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    IsHidden = function (self) return true end,
    IsPurgable = function (self) return true end,
    GetTexture = function (self) return "../spellicons/crit_blood" end,
    DeclareFunctions = function(self) return {MODIFIER_PROPERTY_TOOLTIP} end,
    OnTooltip = function(self) return self:GetStackCount() end,
    OnCreated = function(self) 
        self.damage = (self:GetParent():GetMaxHealth() * (self:GetAbility():GetSpecialValueFor("damage_pct") / 100)) / 2 / self:GetAbility():GetSpecialValueFor("corruption_duration")
        self:StartIntervalThink(0.5)
    end,
   
    OnIntervalThink = function(self)
        if not IsServer() then return end
        ApplyDamage({victim = self:GetParent(), attacker = self:GetCaster(), damage = self.damage/3.33, damage_type = DAMAGE_TYPE_MAGICAL,  ability = self:GetAbility(), damage_flags = DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION,DOTA_DAMAGE_FLAG_NO_SPELL_LIFESTEAL})
        ApplyDamage({victim = self:GetParent(), attacker = self:GetCaster(), damage = self.damage/3.33, damage_type = DAMAGE_TYPE_PHYSICAL, ability = self:GetAbility(), damage_flags = DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION,DOTA_DAMAGE_FLAG_NO_SPELL_LIFESTEAL})
        ApplyDamage({victim = self:GetParent(), attacker = self:GetCaster(), damage = self.damage/3.33, damage_type = DAMAGE_TYPE_PURE,     ability = self:GetAbility(), damage_flags = DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION,DOTA_DAMAGE_FLAG_NO_SPELL_LIFESTEAL})
        SendOverheadEventMessage(nil, OVERHEAD_ALERT_DAMAGE , self:GetParent(), self.damage, nil)
    end,
})

modifier_blood_count = ({
    IsHidden = function (self) return false end,
    GetTexture = function (self) return "../spellicons/crit_blood" end,
    OnCreated = function (self) return self:StartIntervalThink(0.1) end,
    OnIntervalThink = function (self) if not IsServer() then return end self:SetStackCount(#self:GetParent():FindAllModifiersByName("modifier_blood")) end,
})