item_custom_seer_stone = item_custom_seer_stone or class({})
item_custom_seer_stone_2 = item_custom_seer_stone or class({})
item_custom_seer_stone_3 = item_custom_seer_stone or class({})


LinkLuaModifier("modifier_item_custom_seer_stone", "items/seer_stone", LUA_MODIFIER_MOTION_NONE)

function item_custom_seer_stone:GetIntrinsicModifierName()
    return "modifier_item_custom_seer_stone"
end
function item_custom_seer_stone:Precache(context)
    PrecacheResource("particle", "particles/items4_fx/seer_stone.vpcf", context)
end
function item_custom_seer_stone:GetAOERadius()
    return self:GetSpecialValueFor('active_radius')
end
function item_custom_seer_stone:OnSpellStart()
    local nDuration = self:GetSpecialValueFor('active_duration')
    local nRadius = self:GetAOERadius()
    local vTarget = self:GetCursorPosition()
    local hCaster = self:GetCaster()
    local nTeam = hCaster:GetTeam()

    AddFOWViewer( nTeam, vTarget, nRadius, nDuration, false )
    local nParticle = ParticleManager:CreateParticle( 'particles/items4_fx/seer_stone.vpcf', PATTACH_WORLDORIGIN, nil )
    ParticleManager:SetParticleControl( nParticle, 0, vTarget )
    ParticleManager:SetParticleControl( nParticle, 1, Vector( nDuration, nRadius, 0 ) )

    Timers:CreateTimer(nDuration+1, function()
        ParticleManager:DestroyParticle( nParticle, false )
        ParticleManager:ReleaseParticleIndex( nParticle )
    end)

    EmitSoundOnLocationWithCaster( vTarget, 'Item.SeerStone', hCaster )
end

modifier_item_custom_seer_stone = class({})
function modifier_item_custom_seer_stone:IsDebuff() return false end
function modifier_item_custom_seer_stone:IsHidden() return true end
function modifier_item_custom_seer_stone:IsPurgable() return false end

function modifier_item_custom_seer_stone:DeclareFunctions()
    local func = {
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
        MODIFIER_PROPERTY_MANA_BONUS,
        MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
		MODIFIER_PROPERTY_CAST_RANGE_BONUS_STACKING,
        MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE,
    }
    return func
end
function modifier_item_custom_seer_stone:GetModifierBonusStats_Intellect()
	if self:GetAbility() then
		return self:GetAbility():GetSpecialValueFor("int")
	end
end

function modifier_item_custom_seer_stone:GetModifierManaBonus()
	if self:GetAbility() then
		return self:GetAbility():GetSpecialValueFor("mp")
	end
end

function modifier_item_custom_seer_stone:GetModifierCastRangeBonusStacking()
    return self:GetAbility():GetSpecialValueFor("cast_range")
end
function modifier_item_custom_seer_stone:GetModifierConstantManaRegen()
    return self:GetAbility():GetSpecialValueFor("mp_regen")
end
function modifier_item_custom_seer_stone:GetModifierSpellAmplify_Percentage()
    return self:GetAbility():GetSpecialValueFor("spell_damage")
end

