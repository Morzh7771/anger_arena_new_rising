LinkLuaModifier("modifier_item_hurricane_pike_aa", "items/item_hurricane_pike_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_hurricane_pike_aa_caster", "items/item_hurricane_pike_aa", LUA_MODIFIER_MOTION_HORIZONTAL)
LinkLuaModifier("modifier_item_hurricane_pike_aa_enemy", "items/item_hurricane_pike_aa", LUA_MODIFIER_MOTION_HORIZONTAL)
LinkLuaModifier("modifier_item_hurricane_pike_aa_active", "items/item_hurricane_pike_aa", LUA_MODIFIER_MOTION_HORIZONTAL)
LinkLuaModifier("modifier_item_hurricane_pike_aa_active_caster", "items/item_hurricane_pike_aa", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_hurricane_pike_aa_cd", "items/item_hurricane_pike_aa", LUA_MODIFIER_MOTION_NONE)

item_hurricane_pike_aa_1 = class({
    GetIntrinsicModifierName = function(self)return "modifier_item_hurricane_pike_aa" end,
})
item_hurricane_pike_aa_2 = item_hurricane_pike_aa_1
item_hurricane_pike_aa_3 = item_hurricane_pike_aa_1
modifier_item_hurricane_pike_aa_cd = class({
    IsHidden = function(self)return false end,
    GetTexture = function (self) return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "") end,
})
function item_hurricane_pike_aa_1:OnSpellStart()
    if not IsServer() then return end
    local target = self:GetCursorTarget()

    if self:GetCaster():GetTeamNumber() == target:GetTeamNumber() then
        target:EmitSound("DOTA_Item.HurricanePike.Activate")
        target:AddNewModifier(self:GetCaster(), self, "modifier_item_hurricane_pike_aa_active", {duration = 0.3})
    else
        if target:TriggerSpellAbsorb(self) then
            return nil
        end
        target:EmitSound("DOTA_Item.HurricanePike.Activate")
        self:GetCaster():EmitSound("DOTA_Item.HurricanePike.Activate")
        target:AddNewModifier(self:GetCaster(), self, "modifier_item_hurricane_pike_aa_enemy", {})
        self:GetCaster():AddNewModifier(self:GetCaster(), self, "modifier_item_hurricane_pike_aa_caster", {target = target:entindex()})
        self:GetCaster():AddNewModifier(self:GetCaster(), self, "modifier_item_hurricane_pike_aa_active_caster", {duration = self:GetSpecialValueFor("range_duration"),target = target:entindex()})
    end
end
modifier_item_hurricane_pike_aa = class({
    IsHidden = function(self)return true end,
    IsPurgable = function(self)return false end,
    RemoveOnDeath = function(self)return false end,
    GetAttributes = function(self)return MODIFIER_ATTRIBUTE_MULTIPLE end,
    DeclareFunctions = function(self)return{
        MODIFIER_PROPERTY_HEALTH_BONUS,
        MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
        MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
        MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
        MODIFIER_PROPERTY_ATTACK_RANGE_BONUS,
	    MODIFIER_EVENT_ON_ATTACK_FINISHED,
	    MODIFIER_EVENT_ON_ATTACK_RECORD,
	    MODIFIER_EVENT_ON_ATTACK_FAIL,

    } end,
    OnCreated = function (self)
        self.attacks = {}
    end,
    GetModifierHealthBonus = function(self)return self:GetAbility():GetSpecialValueFor("bonus_health") end,
    GetModifierBonusStats_Intellect = function(self)return self:GetAbility():GetSpecialValueFor("bonus_intellect") end,
    GetModifierBonusStats_Strength = function(self)return self:GetAbility():GetSpecialValueFor("bonus_strength") end,
    GetModifierBonusStats_Agility = function(self)return self:GetAbility():GetSpecialValueFor("bonus_agility") end,
    GetModifierAttackRangeBonus = function(self)
        if self:GetParent():IsRangedAttacker() then
            return self:GetAbility():GetSpecialValueFor("base_attack_range")
        else
            return 0
        end 
    end,
})
function modifier_item_hurricane_pike_aa:OnAttackRecord( params )
	if not IsServer() then return end

	if not self or self:IsNull() then return end

	if self:GetParent() ~= params.attacker then return end

	if self.handleID then
		self.attacks[params.record] = 1
	end
end

function modifier_item_hurricane_pike_aa:OnAttackFinished( params )
	if not IsServer() then return end

	if not self or self:IsNull() then return end

	local ability = self:GetAbility()

	if not ability or ability:IsNull() then return end

	local parent = self:GetParent()

	if not parent or parent:IsNull() then return end

	local target = params.target

	if not target or target:IsNull() then return end

	if parent ~= params.attacker then return end

	-- must delete secondary attack there, because we can cause memleak if dont delete when parent/target is dead
	local myAttackID = params.record

	local isSecondaryAttack = self.attacks[ myAttackID ] ~= nil

	self.attacks[ myAttackID ] = nil

	-- but apply any options if parent or target is dead is not our choice
	if not parent:IsAlive() or not target:IsAlive() then return end

	local mod = self.mod
	
	if mod then
		self.mod = nil

		if not mod:IsNull() then
			mod:Destroy()
		end
	end	

	if not parent:IsRangedAttacker() then return end
    if parent:IsIllusion() then return end
	if not isSecondaryAttack then
		if parent:HasModifier("modifier_item_hurricane_pike_aa_cd") then return end

		parent:AddNewModifier(parent, ability, "modifier_item_hurricane_pike_aa_cd", { duration = ability:GetSpecialValueFor("double_attack_cd") * self:GetParent():GetCooldownReduction() })

		local falseAttack = false
		local useProj = true

		self.handleID = true
		parent:PerformAttack(target, false, true, true, true, useProj, falseAttack, true) 
		self.handleID = false
	end
end
function modifier_item_hurricane_pike_aa:OnAttackFail( params )
	if not IsServer() then return end
	if not self or self:IsNull() then return end

	self.attacks[ params.record ] = nil
end
modifier_item_hurricane_pike_aa_active_caster = class({
    IsHidden = function(self)return false end,
    IsPurgable = function(self)return false end,
    RemoveOnDeath = function(self)return true end,
    OnCreated = function(self,kv)
        if not IsServer() then return end
        self.target = EntIndexToHScript(kv.target)
        self.attack_range = 0
    end,
    DeclareFunctions = function(self)return{
        MODIFIER_PROPERTY_PROJECTILE_SPEED_BONUS,
        MODIFIER_EVENT_ON_ORDER,
        MODIFIER_PROPERTY_ATTACK_RANGE_BONUS
    } end,
    GetModifierProjectileSpeedBonus = function(self)return self:GetAbility():GetSpecialValueFor("bonus_projectile_speed") end,
    GetModifierAttackRangeBonus = function(self)return self.attack_range end,
    OnOrder = function(self,ord)
        if not self:GetParent():IsRangedAttacker() then return end
        if ord.order_type == DOTA_UNIT_ORDER_ATTACK_TARGET then
            if ord.target == self.target then
                self.attack_range = 99999999
            else
                self.attack_range = 0
            end
            return true
        end
    end,
    GetTexture = function (self) return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "") end,
})


modifier_item_hurricane_pike_aa_active = class({})

function modifier_item_hurricane_pike_aa_active:IsDebuff() return false end
function modifier_item_hurricane_pike_aa_active:IsHidden() return true end

function modifier_item_hurricane_pike_aa_active:OnCreated()
    if not IsServer() then return end
    self.pfx = ParticleManager:CreateParticle("particles/items_fx/force_staff.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
    self:GetParent():StartGesture(ACT_DOTA_FLAIL)
    self.angle = self:GetParent():GetForwardVector():Normalized()
    self.distance = self:GetAbility():GetSpecialValueFor("push_length") / ( self:GetDuration() / FrameTime())

    if self:ApplyHorizontalMotionController() == false then
        self:Destroy()
    end
end

function modifier_item_hurricane_pike_aa_active:GetStatusEffectName() return "particles/status_fx/status_effect_forcestaff.vpcf" end
function modifier_item_hurricane_pike_aa_active:StatusEffectPriority() return 100 end

function modifier_item_hurricane_pike_aa_active:OnDestroy()
    if not IsServer() then return end
    self:GetParent():InterruptMotionControllers( true )
    ParticleManager:DestroyParticle(self.pfx, false)
    ParticleManager:ReleaseParticleIndex(self.pfx)
    self:GetParent():FadeGesture(ACT_DOTA_FLAIL)
    ResolveNPCPositions(self:GetParent():GetAbsOrigin(), 128)
end


function modifier_item_hurricane_pike_aa_active:UpdateHorizontalMotion( me, dt )
    if not IsServer() then return end
    local pos = self:GetParent():GetAbsOrigin()
    GridNav:DestroyTreesAroundPoint(pos, 80, false)
    local pos_p = self.angle * self.distance
    local next_pos = GetGroundPosition(pos + pos_p,self:GetParent())
    self:GetParent():SetAbsOrigin(next_pos)
end

function modifier_item_hurricane_pike_aa_active:OnHorizontalMotionInterrupted()
    self:Destroy()
end

--///////////////////

modifier_item_hurricane_pike_aa_caster = class({})

function modifier_item_hurricane_pike_aa_caster:IsDebuff() return false end
function modifier_item_hurricane_pike_aa_caster:IsHidden() return true end

function modifier_item_hurricane_pike_aa_caster:OnCreated(params)
    if not IsServer() then return end
    self.target = EntIndexToHScript(params.target)
    self.speed = 1400
    self.pfx = ParticleManager:CreateParticle("particles/items_fx/force_staff.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
    self:GetParent():StartGesture(ACT_DOTA_FLAIL)
    self.angle = (self.target:GetAbsOrigin() - self:GetParent():GetAbsOrigin()):Normalized()
    self.point =  self:GetParent():GetAbsOrigin() - self.angle * self:GetAbility():GetSpecialValueFor("push_length")

    if self:ApplyHorizontalMotionController() == false then
        self:Destroy()
    end
end

function modifier_item_hurricane_pike_aa_caster:GetStatusEffectName() return "particles/status_fx/status_effect_forcestaff.vpcf" end
function modifier_item_hurricane_pike_aa_caster:StatusEffectPriority() return 100 end

function modifier_item_hurricane_pike_aa_caster:OnDestroy()
    if not IsServer() then return end
    self:GetParent():InterruptMotionControllers( true )
    ParticleManager:DestroyParticle(self.pfx, false)
    ParticleManager:ReleaseParticleIndex(self.pfx)
    self:GetParent():FadeGesture(ACT_DOTA_FLAIL)
    ResolveNPCPositions(self:GetParent():GetAbsOrigin(), 128)
    if not self:GetParent():IsChanneling() then 
         self:GetParent():MoveToTargetToAttack(self.target)
    end
end


function modifier_item_hurricane_pike_aa_caster:UpdateHorizontalMotion( me, dt )
    if not IsServer() then return end
    local origin = self:GetParent():GetOrigin()
    if not self.target:IsAlive() then
        self:Destroy()
    end
    local direction = self.point - origin
    direction.z = 0
    local distance = direction:Length2D()
    direction = direction:Normalized()

    local flPad = self:GetParent():GetPaddedCollisionRadius()

    if distance<flPad then
        self:Destroy()
    elseif distance>1500 then
        self:Destroy()
    end

    GridNav:DestroyTreesAroundPoint(origin, 80, false)
    local target = origin + direction * self.speed * dt
    self:GetParent():SetOrigin( target )
    self:GetParent():FaceTowards( self.target:GetOrigin() )
end

function modifier_item_hurricane_pike_aa_caster:OnHorizontalMotionInterrupted()
    self:Destroy()
end

modifier_item_hurricane_pike_aa_enemy = class({})

function modifier_item_hurricane_pike_aa_enemy:IsDebuff() return false end
function modifier_item_hurricane_pike_aa_enemy:IsHidden() return true end

function modifier_item_hurricane_pike_aa_enemy:OnCreated(params)
    if not IsServer() then return end
    self.target = self:GetCaster()
    self.speed = 1400
    self.pfx = ParticleManager:CreateParticle("particles/items_fx/force_staff.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
    self:GetParent():StartGesture(ACT_DOTA_FLAIL)
    self.angle = (self.target:GetAbsOrigin() - self:GetParent():GetAbsOrigin()):Normalized()
    self.point =  self:GetParent():GetAbsOrigin() - self.angle * self:GetAbility():GetSpecialValueFor("push_length")

    if self:ApplyHorizontalMotionController() == false then
        self:Destroy()
    end
end

function modifier_item_hurricane_pike_aa_enemy:GetStatusEffectName() return "particles/status_fx/status_effect_forcestaff.vpcf" end
function modifier_item_hurricane_pike_aa_enemy:StatusEffectPriority() return 100 end

function modifier_item_hurricane_pike_aa_enemy:OnDestroy()
    if not IsServer() then return end
    self:GetParent():InterruptMotionControllers( true )
    ParticleManager:DestroyParticle(self.pfx, false)
    ParticleManager:ReleaseParticleIndex(self.pfx)
    self:GetParent():FadeGesture(ACT_DOTA_FLAIL)
    ResolveNPCPositions(self:GetParent():GetAbsOrigin(), 128)
    if not self:GetParent():IsChanneling() then 
         self:GetParent():MoveToTargetToAttack(self:GetCaster())
    end
end


function modifier_item_hurricane_pike_aa_enemy:UpdateHorizontalMotion( me, dt )
    if not IsServer() then return end
    local origin = self:GetParent():GetOrigin()
    if not self.target:IsAlive() then
        self:Destroy()
    end
    local direction = self.point - origin
    direction.z = 0
    local distance = direction:Length2D()
    direction = direction:Normalized()

    local flPad = self:GetParent():GetPaddedCollisionRadius()

    if distance<flPad then
        self:Destroy()
    elseif distance>1500 then
        self:Destroy()
    end

    GridNav:DestroyTreesAroundPoint(origin, 80, false)
    local target = origin + direction * self.speed * dt
    self:GetParent():SetOrigin( target )
    self:GetParent():FaceTowards( self.target:GetOrigin() )
end

function modifier_item_hurricane_pike_aa_enemy:OnHorizontalMotionInterrupted()
    self:Destroy()
end