LinkLuaModifier("modifier_item_disperser_aa", "items/item_disperser_aa", LUA_MODIFIER_MOTION_NONE)

item_disperser_aa_1 = class({
    GetAOERadius = function (self) return self:GetSpecialValueFor("radius") end,
    GetIntrinsicModifierName = function (self) return "modifier_item_disperser_aa" end,
    GetBehavior = function (self)
        if self:GetCaster():HasModifier("modifier_spirit_breaker_charge_of_darkness") then 
            return DOTA_ABILITY_BEHAVIOR_IMMEDIATE + DOTA_ABILITY_BEHAVIOR_NO_TARGET
        else
            return DOTA_ABILITY_BEHAVIOR_UNIT_TARGET + DOTA_ABILITY_BEHAVIOR_AOE
        end
    end,
    OnSpellStart = function (self)
        if not IsServer() then return end
        local ftarget = self:GetCursorTarget()
        if self:GetCaster():HasModifier("modifier_spirit_breaker_charge_of_darkness") then 
            ftarget = self:GetCaster()
        end
        local enemies = FindUnitsInRadius(self:GetCaster():GetTeamNumber(), ftarget:GetAbsOrigin(), nil, self:GetSpecialValueFor("radius"), DOTA_UNIT_TARGET_TEAM_BOTH, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NOT_ATTACK_IMMUNE, FIND_ANY_ORDER, false)
		for _, target in pairs(enemies) do
            if target:GetTeamNumber() == self:GetCaster():GetTeamNumber() then
                target:Purge(false, true, false, false, false)
                self:GetCaster():EmitSound("DOTA_Item.DiffusalBlade.Activate")
                target:AddNewModifier(self:GetCaster(), self, "modifier_disperser_movespeed_buff", {duration = self:GetSpecialValueFor("ally_effect_duration")})
            else
                if target:TriggerSpellAbsorb(self) then return end
                target:EmitSound("DOTA_Item.DiffusalBlade.Target")
                target:AddNewModifier(self:GetCaster(), self, "modifier_item_diffusal_blade_slow", {duration = self:GetSpecialValueFor("enemy_effect_duration")})
                if not target:IsHero() then
                    target:AddNewModifier(self:GetCaster(), self, "modifier_rooted", {duration = self:GetSpecialValueFor("purge_root_duration")})
                end
            end
        end
    end,
})
item_disperser_aa_2 = item_disperser_aa_1
item_disperser_aa_3 = item_disperser_aa_1

modifier_item_disperser_aa = class({
    IsHidden = function (self) return true end,
    IsPurgable = function (self) return false end,
    IsPurgeException = function (self) return false end,
    RemoveOnDeath = function (self) return false end,
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    DeclareFunctions = function (self)
        return {
            MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
            MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
            MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
            MODIFIER_EVENT_ON_ATTACK_LANDED,
        }
    end,
    GetModifierBonusStats_Agility = function (self) return self:GetAbility():GetSpecialValueFor("bonus_agility") end,
    GetModifierBonusStats_Intellect = function (self) return self:GetAbility():GetSpecialValueFor("bonus_intellect") end,
    GetModifierPreAttack_BonusDamage = function (self) return self:GetAbility():GetSpecialValueFor("bonus_damage") end,
})

function modifier_item_disperser_aa:OnAttackLanded(params)
    if params.attacker == self:GetParent() then
    	if params.no_attack_cooldown then return end
        print(params.target:GetMaxMana())
    	if self:GetParent():FindAllModifiersByName("modifier_item_disperser_aa")[1] ~= self then return end
			local damage_per_burn = self:GetAbility():GetSpecialValueFor("damage_per_burn")
			local mana_burn_illusion = self:GetAbility():GetSpecialValueFor("ilusion_mana_burn")
            local mana_burn_pct = params.target:GetMaxMana() * self:GetAbility():GetSpecialValueFor("mana_burn_pct") / 100
            local mana_burn = self:GetAbility():GetSpecialValueFor("mana_burn") + mana_burn_pct
			local damageTable = { 
                attacker = self:GetParent(),
                victim = params.target,
                ability = self:GetAbility(),
                damage_type = DAMAGE_TYPE_MAGICAL 
            }
			if not params.target:IsMagicImmune() then
				if(params.target:GetMana() >= mana_burn) then
					damageTable.damage = mana_burn * damage_per_burn
					if not self:GetParent():IsIllusion() then
						params.target:Script_ReduceMana(mana_burn, self:GetAbility())
					else
						params.target:Script_ReduceMana(mana_burn_illusion, self:GetAbility())
						damageTable.damage = mana_burn_illusion * damage_per_burn
					end
				else
					damageTable.damage = params.target:GetMana() * damage_per_burn
					if not self:GetParent():IsIllusion() then
						params.target:Script_ReduceMana(mana_burn, self:GetAbility())
					else
						params.target:Script_ReduceMana(mana_burn_illusion, self:GetAbility())
					end
				end
			ApplyDamage(damageTable)
		end
    end
end