LinkLuaModifier("modifier_item_harpoon_custom", "items/item_harpoon_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_harpoon_custom_pull", "items/item_harpoon_aa",LUA_MODIFIER_MOTION_HORIZONTAL)
LinkLuaModifier("modifier_item_harpoon_custom_speed", "items/item_harpoon_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_harpoon_custom_cd", "items/item_harpoon_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_harpoon_custom_slow", "items/item_harpoon_aa", LUA_MODIFIER_MOTION_NONE)
require('lib/second_attacks')

MeleeSecondAttack:RegisterSecondAttack("modifier_item_harpoon_custom_cd")

item_harpoon_aa_1 = item_harpoon_aa_1 or class({})
item_harpoon_aa_3 = item_harpoon_aa_1
item_harpoon_aa_2 = item_harpoon_aa_1

function item_harpoon_aa_1:Precache(context)
    PrecacheResource("particle", "particles/items_fx/harpoon_projectile.vpcf", context)
    PrecacheResource("particle", "particles/items_fx/harpoon_pull.vpcf", context)
    PrecacheResource("particle", "particles/status_fx/status_effect_forcestaff.vpcf", context)
end

function item_harpoon_aa_1:GetIntrinsicModifierName()
    return "modifier_item_harpoon_custom"
end
function item_harpoon_aa_1:OnSpellStart()
    if not IsServer() then
        return
    end
    local target = self:GetCursorTarget()

    self:GetCaster():EmitSound("Item.Harpoon.Cast")

    if target:TriggerSpellAbsorb(self) then
        return nil
    end

    local projectile = {
        Target = target,
        Source = self:GetCaster(),
        Ability = self,
        EffectName = "particles/items_fx/harpoon_projectile.vpcf",
        iMoveSpeed = self:GetSpecialValueFor("projectile_speed"),
        vSourceLoc = self:GetCaster():GetAbsOrigin(),
        bDodgeable = false,
        bProvidesVision = false
    }

    local hProjectile = ProjectileManager:CreateTrackingProjectile(projectile)
end
function item_harpoon_aa_1:OnProjectileHit(hTarget, vLocation)
    if not hTarget then
        return
    end
    if not IsServer() then
        return
    end

    ApplyDamage(
        {
            victim = hTarget,
            attacker = self:GetCaster(),
            ability = self,
            damage_type = DAMAGE_TYPE_PURE,
            damage = self:GetSpecialValueFor("damage")
        }
    )

    local dis = (hTarget:GetAbsOrigin() - self:GetCaster():GetAbsOrigin()):Length2D()

    if dis <= self:GetSpecialValueFor("min_distance") then
        return
    end

    hTarget:EmitSound("Item.Harpoon.Target")

    hTarget:AddNewModifier(
        self:GetCaster(),
        self,
        "modifier_item_harpoon_custom_slow",
        {duration = (1 - hTarget:GetStatusResistance()) * self:GetSpecialValueFor("hit_slow_duration")}
    )

    hTarget:AddNewModifier(
        self:GetCaster(),
        self,
        "modifier_item_harpoon_custom_pull",
        {duration = self:GetSpecialValueFor("pull_duration"), target = self:GetCaster():entindex()}
    )
    self:GetCaster():AddNewModifier(
        self:GetCaster(),
        self,
        "modifier_item_harpoon_custom_pull",
        {duration = self:GetSpecialValueFor("pull_duration"), target = hTarget:entindex()}
    )
end

modifier_item_harpoon_custom = class({
    IsHidden = function(self)return true end,
    IsPurgable = function(self)return false end,
    RemoveOnDeath = function(self)return false end,
    GetAttributes = function(self)return MODIFIER_ATTRIBUTE_MULTIPLE end,
    DeclareFunctions = function(self)return{
        MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
        MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
        MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
        MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
        MODIFIER_EVENT_ON_ATTACK_LANDED,

    } end,
    GetModifierPreAttack_BonusDamage = function(self)return self:GetAbility():GetSpecialValueFor("bonus_damage") end,
    GetModifierConstantManaRegen = function(self)return self:GetAbility():GetSpecialValueFor("bonus_mana_regen") end,
    GetModifierAttackSpeedBonus_Constant = function(self)return self:GetAbility():GetSpecialValueFor("bonus_attack_speed") end,
    GetModifierBonusStats_Intellect = function(self)return self:GetAbility():GetSpecialValueFor("bonus_intellect") end,
    GetModifierBonusStats_Strength = function(self)return self:GetAbility():GetSpecialValueFor("bonus_strength") end,
    GetModifierBonusStats_Agility = function(self)return self:GetAbility():GetSpecialValueFor("bonus_agility") end,
})

function modifier_item_harpoon_custom:OnAttackLanded(params)
    if not IsServer() then return end

	local parent = self:GetParent()
	local target = params.target

	if not parent or parent ~= params.attacker or not target then return end

	local ability = self:GetAbility()

	if not ability then return end

	if not target:IsAlive() or not parent:IsAlive() then return end

	if not parent:IsIllusion() and not parent:IsRangedAttacker() and MeleeSecondAttack:CanSecondAttack(parent) then
		local cd = self:GetAbility():GetSpecialValueFor("passive_cooldown") * parent:GetCooldownReduction()

		parent:AddNewModifier(parent, ability, "modifier_item_harpoon_custom_cd", { duration = cd })

		local timer = self.timer

		if timer ~= nil then
			Timers:RemoveTimer(timer)
		end
        
		self.timer = Timers:CreateTimer( 0.1, function()
			if not ability or ability:IsNull() then return end
			if not parent or parent:IsNull() then return end
			if not target or target:IsNull() then return end

			parent:PerformAttack(target, true, true, true, true, true, false, false)
		end)
        target:AddNewModifier(
            parent,
            ability,
            "modifier_item_harpoon_custom_slow",
            {duration = (1 - target:GetStatusResistance()) * self:GetAbility():GetSpecialValueFor("slow_duration")}
        )
	end
end

--///////////////////

modifier_item_harpoon_custom_pull = class({
    GetTexture = function (self) return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "") end,
})

function modifier_item_harpoon_custom_pull:IsDebuff()
    return false
end
function modifier_item_harpoon_custom_pull:IsHidden()
    return true
end

function modifier_item_harpoon_custom_pull:OnCreated(params)
    if not IsServer() then
        return
    end
    self.target = EntIndexToHScript(params.target)
    self.pfx =
        ParticleManager:CreateParticle(
        "particles/items_fx/harpoon_pull.vpcf",
        PATTACH_ABSORIGIN_FOLLOW,
        self:GetParent()
    )

    self:GetParent():StartGesture(ACT_DOTA_FLAIL)

    self.angle = (self.target:GetAbsOrigin() - self:GetParent():GetAbsOrigin()):Normalized()
    self.point = (self:GetParent():GetAbsOrigin() + self.target:GetAbsOrigin()) / 2

    self.point = self.point - (self.target:GetAbsOrigin() - self:GetParent():GetAbsOrigin()):Normalized() * 50

    self.speed = (self:GetParent():GetAbsOrigin() - self.point):Length2D() / self:GetRemainingTime()

    if self:ApplyHorizontalMotionController() == false then
        self:Destroy()
    end
end

function modifier_item_harpoon_custom_pull:GetStatusEffectName()
    return "particles/status_fx/status_effect_forcestaff.vpcf"
end
function modifier_item_harpoon_custom_pull:StatusEffectPriority()
    return 100
end

function modifier_item_harpoon_custom_pull:OnDestroy()
    if not IsServer() then
        return
    end
    self:GetParent():InterruptMotionControllers(true)
    ParticleManager:DestroyParticle(self.pfx, false)
    ParticleManager:ReleaseParticleIndex(self.pfx)

    self:GetParent():FadeGesture(ACT_DOTA_FLAIL)

    ResolveNPCPositions(self:GetParent():GetAbsOrigin(), 128)

    if not self:GetParent():IsChanneling() then
    --self:GetParent():MoveToTargetToAttack(self.target)
    end
end

function modifier_item_harpoon_custom_pull:UpdateHorizontalMotion(me, dt)
    if not IsServer() then
        return
    end

    if not self.target or self.target:IsNull() or not self.target:IsAlive() then
        self:Destroy()
        return
    end

    local origin = self:GetParent():GetOrigin()

    local direction = self.point - origin
    direction.z = 0
    local distance = direction:Length2D()
    direction = direction:Normalized()

    local flPad = self:GetParent():GetPaddedCollisionRadius()

    if distance < flPad then
        self:Destroy()
    elseif distance > 1500 then
        self:Destroy()
    end

    GridNav:DestroyTreesAroundPoint(origin, 80, false)
    local target = origin + direction * self.speed * dt
    self:GetParent():SetOrigin(target)
    self:GetParent():FaceTowards(self.target:GetOrigin())
end

function modifier_item_harpoon_custom_pull:OnHorizontalMotionInterrupted()
    self:Destroy()
end

modifier_item_harpoon_custom_cd = class({
    GetTexture = function (self) return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "") end,
})
function modifier_item_harpoon_custom_cd:IsHidden()
    return false
end
function modifier_item_harpoon_custom_cd:IsPurgable()
    return false
end
function modifier_item_harpoon_custom_cd:RemoveOnDeath()
    return false
end
function modifier_item_harpoon_custom_cd:IsDebuff()
    return true
end

modifier_item_harpoon_custom_speed = class({
    GetTexture = function (self) return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "") end,
})
function modifier_item_harpoon_custom_speed:IsHidden()
    return true
end
function modifier_item_harpoon_custom_speed:IsPurgable()
    return false
end
function modifier_item_harpoon_custom_speed:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
        MODIFIER_EVENT_ON_ATTACK_LANDED,
        MODIFIER_EVENT_ON_ATTACK_FAIL
    }
end

function modifier_item_harpoon_custom_speed:GetModifierAttackSpeedBonus_Constant()
    return 500
end

function modifier_item_harpoon_custom_speed:OnCreated(table)
    if not IsServer() then
        return
    end
    self:StartIntervalThink(0.2)
end

function modifier_item_harpoon_custom_speed:OnIntervalThink()
    if self:GetParent():IsRangedAttacker() or not self:GetAbility() then
        self:Destroy()
    end
end

function modifier_item_harpoon_custom_speed:OnAttackLanded(params)
    if not IsServer() then
        return
    end
    if self:GetParent() ~= params.attacker then
        return
    end
    if self:GetParent():IsRangedAttacker() then
        return
    end

    if self:GetAbility() and not params.target:IsBuilding() and not params.target:IsMagicImmune() then
        params.target:AddNewModifier(
            self:GetCaster(),
            self:GetAbility(),
            "modifier_item_harpoon_custom_slow",
            {duration = 0.8}
        )
    end

    self:Destroy()
end

function modifier_item_harpoon_custom_speed:OnAttackFail(params)
    if not IsServer() then
        return
    end
    if self:GetParent() ~= params.attacker then
        return
    end
    if self:GetParent():IsRangedAttacker() then
        return
    end

    self:Destroy()
end

modifier_item_harpoon_custom_slow = class({
    GetTexture = function (self) return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "") end,
})
function modifier_item_harpoon_custom_slow:IsHidden()
    return false
end
function modifier_item_harpoon_custom_slow:IsPurgable()
    return true
end
function modifier_item_harpoon_custom_slow:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE
    }
end

function modifier_item_harpoon_custom_slow:GetModifierMoveSpeedBonus_Percentage()
    return -100
end
