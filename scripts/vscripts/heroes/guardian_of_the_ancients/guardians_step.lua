BaseClass = class({})
guardian_of_the_ancients_guardians_step = BaseClass

LinkLuaModifier( "BaseClass_dash", "heroes/guardian_of_the_ancients/guardians_step", LUA_MODIFIER_MOTION_HORIZONTAL)
LinkLuaModifier( "BaseClass_dash_buff", "heroes/guardian_of_the_ancients/guardians_step", LUA_MODIFIER_MOTION_NONE)

function BaseClass:OnSpellStart()
    local hCaster = self:GetCaster()
    local vStart = hCaster:GetOrigin()
    local vTarget = self:GetCursorPosition()
    local nRange = self:GetSpecialValueFor('dash_range') -- + hCaster:GetCastRangeBonus()
    local nSpeed = self:GetSpecialValueFor('dash_speed')
    local nDuration = self:GetSpecialValueFor('buff_duration')
    local nTreeBreak = self:GetSpecialValueFor('tree_cut_range')

    local vDelta = vTarget - vStart
    local nDelta = vDelta:Length2D()

    if nDelta > nRange then
        nDelta = nRange
        vTarget = vStart + vDelta:Normalized() * nRange
    end

    local nFlyTime = nDelta / nSpeed

    hCaster:Purge( false, true, false, false, false )
	ProjectileManager:ProjectileDodge(self:GetCaster())
    hCaster:AddNewModifier( hCaster, self, 'BaseClass_dash_buff', {
        duration = nDuration + nFlyTime,
    })
	local hMotion = hCaster:AddNewModifier( hCaster, self, 'BaseClass_dash', {} )
	if hMotion then
		hMotion:Start( vTarget, nSpeed, nTreeBreak )
	end

end



BaseClass_dash = class({
    IsHidden = function(self) return true end,
    IsPurgable = function(self) return true end,
    IsDebuff = function(self) return false end,
    CheckState = function(self) return{
        [MODIFIER_STATE_STUNNED] = true,
    }end,
})
function BaseClass_dash:OnCreated()
    self.targets = {}
end
function BaseClass_dash:Start( vTarget, nSpeed, nTreeBreak )
    self.vPos = self:GetParent():GetOrigin()
    self.vDir = vTarget - self.vPos
    self.vDir.z = 0
    self.nDistance = #self.vDir
    
    if self.nDistance < 1 then
        self:Destroy()
		return
    end
    
    self.vDir = self.vDir:Normalized()
    self.nSpeed = nSpeed
    self.nTreeBreak = nTreeBreak
    if not IsServer() then return end
        if self:ApplyHorizontalMotionController() == false then
            self:Destroy()
        end
end

function BaseClass_dash:End()
    if IsServer() then
        self:GetParent():RemoveHorizontalMotionController( self )
        self:Destroy()
    end
end

function BaseClass_dash:OnHorizontalMotionInterrupted()
    self:End()
end

function BaseClass_dash:OnDestroy()
    if IsServer() then
        local hParent = self:GetParent()
        FindClearSpaceForUnit( hParent, hParent:GetOrigin(), false )
    end
end

function BaseClass_dash:UpdateHorizontalMotion( hUnit, nTimeDelta )
    local bEnd = false
    local hParent = self:GetParent()
    local nDelta = self.nSpeed * nTimeDelta
    
    if nDelta > self.nDistance then
        nDelta = self.nDistance
        bEnd = true
    end
    GridNav:DestroyTreesAroundPoint( self.vPos, self.nTreeBreak, false )
    self.nDistance = self.nDistance - nDelta
    self.vPos = GetGroundPosition( self.vPos + self.vDir * nDelta, hParent )

    hParent:SetAbsOrigin( self.vPos )

    if self:GetAbility():GetSpecialValueFor("talant_caster_damage") == 1 then
        local enemies = FindUnitsInRadius(
                self:GetParent():GetTeamNumber(),	-- int, your team number
                self:GetParent():GetOrigin(),	-- point, center point
                nil,	-- handle, cacheUnit. (not known)
                150,	-- float, radius. or use FIND_UNITS_EVERYWHERE
                DOTA_UNIT_TARGET_TEAM_ENEMY,	-- int, team filter
                DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,	-- int, type filter
                0,	-- int, flag filter
                0,	-- int, order filter
                false	-- bool, can grow cache
            )
        for _,enemy in pairs(enemies) do 
            local attack = true
            for _,target in pairs(self.targets) do 
                if target == enemy then 
                    attack = false 
                end
            end
            if attack then 
                self.targets[#self.targets + 1] = enemy
                
                for _,enemy in pairs(enemies) do
                    self:GetParent():PerformAttack(enemy, true, true, true, true, false, false, true)
                end
            end
        end
    end
    if bEnd then
        self:End()
    end
end

BaseClass_dash_buff = class({
    IsPurgable = function(self) return false end,
})

function BaseClass_dash_buff:GetStatusEffectName()
    return 'particles/items/soul_wrapper/status_effect.vpcf'
end

function BaseClass_dash_buff:CheckState()
    if self:GetAbility():GetSpecialValueFor("talant_no_dmg") == 1 then
        return {
            [MODIFIER_STATE_INVULNERABLE] = true,
            [MODIFIER_STATE_OUT_OF_GAME] = true,
            [MODIFIER_STATE_NO_HEALTH_BAR] = true,
        }
    end
end

function BaseClass_dash_buff:OnCreated()
    if IsServer() then
        local hParent = self:GetParent()
        local sParticle2 = 'particles/items/soul_wrapper/trail.vpcf'
        self.nParticle2 = ParticleManager:CreateParticle( sParticle2, PATTACH_CUSTOMORIGIN, hParent )
        ParticleManager:SetParticleControlEnt( self.nParticle2, 0, hParent, PATTACH_POINT_FOLLOW, 'attach_hitloc', hParent:GetOrigin(), false )
        ParticleManager:SetParticleControl( self.nParticle2, 15, Vector( 110, 181, 203 ) )
    end
end
function BaseClass_dash_buff:OnDestroy()
    if IsServer() then
        ParticleManager:DestroyParticle( self.nParticle2, true )
    end
end