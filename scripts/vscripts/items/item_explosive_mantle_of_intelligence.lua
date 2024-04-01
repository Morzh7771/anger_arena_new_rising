item_explosive_mantle_of_intelligence = class({})
LinkLuaModifier("modifier_explosive_mantle_of_intelligence", 'items/item_explosive_mantle_of_intelligence', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_explosive_mantle_of_intelligence_active_channel", 'items/item_explosive_mantle_of_intelligence', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_explosive_mantle_of_intelligence_active_finish", 'items/item_explosive_mantle_of_intelligence', LUA_MODIFIER_MOTION_NONE)


function item_explosive_mantle_of_intelligence:GetIntrinsicModifierName()
    return "modifier_explosive_mantle_of_intelligence"
end

function item_explosive_mantle_of_intelligence:OnSpellStart()
	local pre_explode_duration = self:GetSpecialValueFor("pre_explode_duration")
	self:GetCaster():AddNewModifier(caster, self, "modifier_explosive_mantle_of_intelligence_active_channel", { duration = pre_explode_duration })
    self:GetCaster():AddNewModifier(caster, self, "modifier_explosive_mantle_of_intelligence_active_finish", { duration = pre_explode_duration })
    Timers:CreateTimer("time_until_happiness_" .. tostring(self:GetCaster():entindex()), {
            useGameTime = true,
            endTime = 0,
            callback = function()
               EmitSoundOn("Hero_Techies.StickyBomb.Priming", self:GetCaster())
               return 1
            end
         })
                
end



modifier_explosive_mantle_of_intelligence = class({
    IsHidden = function() return true end,
    IsPurgable = function() return false end,
    DestroyOnExpire = function() return false end,
    GetAttributes = function(self) return MODIFIER_ATTRIBUTE_PERMANENT end,

    DeclareFunctions = function(self)
        local funcs = {
            MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
        }
        return funcs
    end,

    GetModifierBonusStats_Intellect = function(self) return self:GetAbility():GetSpecialValueFor("bonus_int") end,
})

modifier_explosive_mantle_of_intelligence_active_channel = class({
	IsBuff = function (self) return true end,
	IsPurgable = function (self) return false end,
    DeclareFunctions = function(self) return{
         MODIFIER_PROPERTY_MOVESPEED_ABSOLUTE,
         MODIFIER_PROPERTY_MODEL_CHANGE,
    } end, 
	CheckState = function (self)
        return {
            [MODIFIER_STATE_DISARMED] = true,
            [MODIFIER_STATE_SILENCED] = true,
            [MODIFIER_STATE_HEXED] = true,
        }
    end,
    OnCreated = function(self)
    self.base_speed = 700
    self.model = "models/items/hex/sheep_hex/sheep_hex.vmdl"
		self:StartIntervalThink(0)
    end,
    OnRefresh = function(self)
        self.base_speed = 700
        if IsServer() then
            -- play effects
            self:PlayEffects( true )
        end
    end,
    OnDestroy = function(self)
        if IsServer() then
            -- play effects
         self:PlayEffects( false )
        end
    end,
     GetModifierMoveSpeed_Absolute = function(self) return self.base_speed end,
     GetModifierModelChange = function(self) return  self.model end,
})

function modifier_explosive_mantle_of_intelligence_active_channel:OnIntervalThink()
    local radius = self:GetAbility():GetSpecialValueFor("radius")
    local caster = self:GetParent()
    if IsServer() and caster:IsAlive() then

        local effect_cast = ParticleManager:CreateParticle(
            "particles/units/heroes/hero_techies/techies_blast_off_ringmodel.vpcf",
            PATTACH_ABSORIGIN_FOLLOW,
            self:GetParent()
        )
        ParticleManager:SetParticleControl( effect_cast, 1, Vector( radius, radius, radius ) )
        ParticleManager:ReleaseParticleIndex( effect_cast )

        local effect_cast = ParticleManager:CreateParticle(
            "particles/units/heroes/hero_doom_bringer/doom_infernal_blade_impact.vpcf",
            PATTACH_ABSORIGIN_FOLLOW,
            self:GetParent()
        )
        ParticleManager:SetParticleControl( effect_cast, 1, Vector( radius, radius+150, radius ) )
        ParticleManager:ReleaseParticleIndex( effect_cast )

        local damage_per_tick = caster:GetMaxHealth() / 100 * self:GetAbility():GetSpecialValueFor("burn_hp_to_damage")
	    local enemies = FindUnitsInRadius(caster:GetTeamNumber(), caster:GetAbsOrigin(), nil, radius, DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC + DOTA_TEAM_NEUTRALS, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
	    for _, enemy in pairs(enemies) do
            ApplyDamage({
                victim = enemy,
                attacker = caster,
                damage_type = DAMAGE_TYPE_MAGICAL ,
                damage_flags = DOTA_DAMAGE_FLAG_NONE, --Optional.
                ability = self:GetAbility(), --Optional.
                damage = damage_per_tick
            })
        end
        ApplyDamage({
            victim = caster,
            attacker = caster,
            damage_type = DAMAGE_TYPE_MAGICAL ,
            damage_flags = DOTA_DAMAGE_FLAG_NONE, --Optional.
            ability = self:GetAbility(), --Optional.
            damage = damage_per_tick
        })

    end
    self:StartIntervalThink(1)
end

modifier_explosive_mantle_of_intelligence_active_finish = class({
    IsBuff = function (self) return true end,
    IsPurgable = function (self) return false end,
     OnCreated = function(self)
        self:StartIntervalThink(3)
        self.item = self:GetParent():FindItemInInventory("item_explosive_mantle_of_intelligence")
        self.pre_explode_duration = self:GetSpecialValueFor("pre_explode_duration")
    end
})

function modifier_explosive_mantle_of_intelligence_active_finish:OnIntervalThink()
    local radius = self:GetAbility():GetSpecialValueFor("radius")
    local caster = self:GetParent()
    local int_dmg_mlp = (self:GetAbility():GetSpecialValueFor("int_dmg_mlp") / 100) * caster:GetIntellect() + 1
    local final_explode = caster:GetHealth() / 100 * self:GetAbility():GetSpecialValueFor("explosive_damage_per_hp") * int_dmg_mlp
    if IsServer() and caster:IsAlive() then
        local effect_cast = ParticleManager:CreateParticle(
            "particles/units/heroes/hero_techies/techies_blast_off_ringmodel.vpcf",
            PATTACH_ABSORIGIN_FOLLOW,
            self:GetParent()
        )
        ParticleManager:SetParticleControl( effect_cast, 1, Vector( radius, radius, radius ) )
        ParticleManager:ReleaseParticleIndex( effect_cast )

        local effect_cast = ParticleManager:CreateParticle(
            "particles/units/heroes/hero_techies/techies_blast_off.vpcf",
            PATTACH_ABSORIGIN_FOLLOW,
            self:GetParent()
        )
        ParticleManager:SetParticleControl( effect_cast, 1, Vector( radius, radius, radius ) )
        ParticleManager:ReleaseParticleIndex( effect_cast )

        local enemies = FindUnitsInRadius(caster:GetTeamNumber(), caster:GetAbsOrigin(), nil, radius, DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC + DOTA_TEAM_NEUTRALS, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
        for _, enemy in pairs(enemies) do
            ApplyDamage({
                victim = enemy,
                attacker = caster,
                damage_type = DAMAGE_TYPE_MAGICAL ,
                damage_flags = DOTA_DAMAGE_FLAG_NONE, --Optional.
                ability = self:GetAbility(), --Optional.
                damage = final_explode
            })
        end
        local MANTLE_PURGE_MODIFIERS = {
            "modifier_dazzle_shallow_grave",
            "modifier_troll_warlord_battle_trance",
            "modifier_skeleton_king_reincarnation_scepter",
            "modifier_skeleton_king_reincarnation_scepter_active",
        }
        for _,modifier_name in pairs(MANTLE_PURGE_MODIFIERS) do
            caster:RemoveAllModifiersByName(modifier_name)
        end
        Timers:CreateTimer({
            useGameTime = true,
            endTime = self.pre_explode_duration,
            callback = function()
               Timers:RemoveTimer("time_until_happiness_" .. tostring(caster:entindex()))
               EmitSoundOn("Hero_Gyrocopter.CallDown.Damage", caster)
            end
         })
        if self.item:GetCurrentCharges() > 1 then 
            self.item:SetCurrentCharges(self.item:GetCurrentCharges() - 1)
        else
            caster:RemoveItem(self.item)
        end
        caster:Kill(caster, caster)
        ParticleManager:CreateParticle("particles/units/heroes/hero_life_stealer/life_stealer_infest_emerge_bloody.vpcf", PATTACH_ABSORIGIN, caster)
        ParticleManager:CreateParticle("particles/units/heroes/hero_life_stealer/life_stealer_infest_emerge_bloody.vpcf", PATTACH_ABSORIGIN, caster)
        ParticleManager:CreateParticle("particles/units/heroes/hero_life_stealer/life_stealer_infest_emerge_bloody.vpcf", PATTACH_ABSORIGIN, caster)
        ParticleManager:CreateParticle("particles/units/heroes/hero_life_stealer/life_stealer_infest_emerge_bloody.vpcf", PATTACH_ABSORIGIN, caster)
        ParticleManager:CreateParticle("particles/units/heroes/hero_life_stealer/life_stealer_infest_emerge_bloody.vpcf", PATTACH_ABSORIGIN, caster)
        ParticleManager:CreateParticle("particles/units/heroes/hero_doom_bringer/doom_bringer_lvl_death.vpcf", PATTACH_ABSORIGIN, caster)
    end
    self:StartIntervalThink(3.0)
    
end