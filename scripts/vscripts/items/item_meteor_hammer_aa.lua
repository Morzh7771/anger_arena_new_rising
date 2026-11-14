LinkLuaModifier("modifier_item_meteor_hammer_oaa_passives", "items/item_meteor_hammer_aa.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_meteor_hammer_oaa_thinker", "items/item_meteor_hammer_aa.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_meteor_hammer_oaa_dot", "items/item_meteor_hammer_aa.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_meteor_hammer_oaa_stun", "items/item_meteor_hammer_aa.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_meteor_hammer_oaa_channel", "items/item_meteor_hammer_aa.lua", LUA_MODIFIER_MOTION_NONE)

item_meteor_hammer = class({})

function item_meteor_hammer:Precache(context)
  PrecacheResource("particle", "particles/items4_fx/meteor_hammer_cast.vpcf", context)
  PrecacheResource("particle", "particles/items4_fx/meteor_hammer_aoe.vpcf", context)
  PrecacheResource("particle", "particles/items4_fx/meteor_hammer_spell.vpcf", context)
  PrecacheResource("particle", "particles/items4_fx/meteor_hammer_spell_debuff.vpcf", context)
  PrecacheResource("particle", "particles/generic_gameplay/generic_stunned.vpcf", context)
end

item_meteor_hammer_aa = item_meteor_hammer
item_meteor_hammer_aa_2 = item_meteor_hammer
item_meteor_hammer_aa_3 = item_meteor_hammer

modifier_item_meteor_hammer_oaa_channel = class({
  IsHidden = function(self) return false end,
  GetTexture = function(self) return "item_meteor_hammer" end,
})
function item_meteor_hammer:GetAOERadius()
  return self:GetSpecialValueFor("impact_radius")
end

function item_meteor_hammer:GetChannelTime()
	return self:GetSpecialValueFor( "max_duration" )
end

function item_meteor_hammer:GetIntrinsicModifierName()
  return "modifier_item_meteor_hammer_oaa_passives"
end

function item_meteor_hammer:OnSpellStart()
  local caster = self:GetCaster()
  local target_location = self:GetCursorPosition()
  local vision_duration = math.max(self:GetChannelTime() + self:GetSpecialValueFor("land_time") + self:GetSpecialValueFor("stun_duration"), 3.8)
  local radius = self:GetSpecialValueFor("impact_radius")

  -- Как у ванильного молота: своя анимация канала (не поза телепорта), без
  -- лишнего бафа на панели, эффект вокруг героя едет вместе с ним.
  caster:EmitSound("DOTA_Item.MeteorHammer.Channel")
  caster:StartGesture(ACT_DOTA_GENERIC_CHANNEL_1)

  self:CreateVisibilityNode(target_location, radius, vision_duration)

  self.meteor_target = target_location

  -- полоска канала как ванильная: у item_lua ванильная не появляется (lib/channel_bar.lua)
  if ChannelBar then ChannelBar:Start(caster, self, self:GetChannelTime()) end

  self.channel_particle_caster = ParticleManager:CreateParticle("particles/items4_fx/meteor_hammer_cast.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)

  -- круг области: видит только своя команда, как в доте
  self.channel_particle = ParticleManager:CreateParticleForTeam("particles/items4_fx/meteor_hammer_aoe.vpcf", PATTACH_CUSTOMORIGIN, caster, caster:GetTeam())
  ParticleManager:SetParticleControl(self.channel_particle, 0, target_location)
  ParticleManager:SetParticleControl(self.channel_particle, 1, Vector(radius, 0, 0))
end

function item_meteor_hammer:OnChannelThink(fInterval)
end

function item_meteor_hammer:OnChannelFinish(bInterrupted)
  local caster = self:GetCaster()
  local caster_particle = self.channel_particle_caster
  local aoe_particle = self.channel_particle

  self.channel_particle_caster = nil
  self.channel_particle = nil

  caster:FadeGesture(ACT_DOTA_GENERIC_CHANNEL_1)
  if ChannelBar then ChannelBar:Stop(caster) end
  caster:StopSound("DOTA_Item.MeteorHammer.Channel")

  if caster_particle then
    ParticleManager:DestroyParticle(caster_particle, bInterrupted)
    ParticleManager:ReleaseParticleIndex(caster_particle)
  end

  if bInterrupted then
    if aoe_particle then
      ParticleManager:DestroyParticle(aoe_particle, true)
      ParticleManager:ReleaseParticleIndex(aoe_particle)
    end

    return
  end

  caster:EmitSound("DOTA_Item.MeteorHammer.Cast")

  local land_time = self:GetSpecialValueFor("land_time")

  CreateModifierThinker(
    caster,
    self,
    "modifier_item_meteor_hammer_oaa_thinker",
    {duration = land_time + self:GetSpecialValueFor("stun_duration")},
    self.meteor_target or self:GetCursorPosition(),
    caster:GetTeamNumber(),
    false
  )

  -- круг области держим до падения метеорита и гасим в момент удара
  if aoe_particle then
    Timers:CreateTimer(land_time, function()
      ParticleManager:DestroyParticle(aoe_particle, false)
      ParticleManager:ReleaseParticleIndex(aoe_particle)
    end)
  end
end

---------------------------------------------------------------------------------------------------

modifier_item_meteor_hammer_oaa_passives = class({})

function modifier_item_meteor_hammer_oaa_passives:IsHidden()
  return true
end

function modifier_item_meteor_hammer_oaa_passives:IsDebuff()
  return false
end

function modifier_item_meteor_hammer_oaa_passives:IsPurgable()
  return false
end

function modifier_item_meteor_hammer_oaa_passives:GetAttributes()
  return MODIFIER_ATTRIBUTE_MULTIPLE
end

function modifier_item_meteor_hammer_oaa_passives:OnCreated()
  self:OnRefresh()
  if IsServer() then
    self:StartIntervalThink(0.3)
  end
end

function modifier_item_meteor_hammer_oaa_passives:OnRefresh()
  local ability = self:GetAbility()
  if ability and not ability:IsNull() then
    self.bonus_str = ability:GetSpecialValueFor("bonus_strength")
    self.bonus_agi = ability:GetSpecialValueFor("bonus_agility")
    self.bonus_int = ability:GetSpecialValueFor("bonus_intellect")
    self.spell_amp = ability:GetSpecialValueFor("spell_amp")
    self.mana_regen_amp = ability:GetSpecialValueFor("mana_regen_multiplier")
    self.spell_lifesteal_amp = ability:GetSpecialValueFor("spell_lifesteal_amp")
  end

  if IsServer() then
    self:OnIntervalThink()
  end
end

function modifier_item_meteor_hammer_oaa_passives:OnIntervalThink()
  if self:GetCaster() then
    self:SetStackCount(1)
  end
end

function modifier_item_meteor_hammer_oaa_passives:DeclareFunctions()
  return {
    MODIFIER_PROPERTY_STATS_STRENGTH_BONUS, -- GetModifierBonusStats_Strength
    MODIFIER_PROPERTY_STATS_AGILITY_BONUS, -- GetModifierBonusStats_Agility
    MODIFIER_PROPERTY_STATS_INTELLECT_BONUS, -- GetModifierBonusStats_Intellect
    MODIFIER_PROPERTY_MP_REGEN_AMPLIFY_PERCENTAGE, -- GetModifierMPRegenAmplify_Percentage
    MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE,    -- GetModifierSpellAmplify_Percentage
    MODIFIER_PROPERTY_SPELL_LIFESTEAL_AMPLIFY_PERCENTAGE, -- GetModifierSpellLifestealRegenAmplify_Percentage
  }
end

function modifier_item_meteor_hammer_oaa_passives:GetModifierBonusStats_Strength()
  return self.bonus_str or self:GetAbility():GetSpecialValueFor("bonus_strength")
end

function modifier_item_meteor_hammer_oaa_passives:GetModifierBonusStats_Agility()
  return self.bonus_agi or self:GetAbility():GetSpecialValueFor("bonus_agility")
end

function modifier_item_meteor_hammer_oaa_passives:GetModifierBonusStats_Intellect()
  return self.bonus_int or self:GetAbility():GetSpecialValueFor("bonus_intellect")
end

-- Doesn't stack with Kaya items
function modifier_item_meteor_hammer_oaa_passives:GetModifierMPRegenAmplify_Percentage()
  return self.mana_regen_amp or self:GetAbility():GetSpecialValueFor("mana_regen_multiplier")
end

-- Doesn't stack with Kaya items
function modifier_item_meteor_hammer_oaa_passives:GetModifierSpellAmplify_Percentage()
  return self.spell_amp or self:GetAbility():GetSpecialValueFor("spell_amp")
end

-- Doesn't stack with Kaya items
function modifier_item_meteor_hammer_oaa_passives:GetModifierSpellLifestealRegenAmplify_Percentage()
  return self.spell_lifesteal_amp or self:GetAbility():GetSpecialValueFor("spell_lifesteal_amp")
end

---------------------------------------------------------------------------------------------------

modifier_item_meteor_hammer_oaa_thinker = class({})

function modifier_item_meteor_hammer_oaa_thinker:IsHidden()
  return true
end

function modifier_item_meteor_hammer_oaa_thinker:IsPurgable()
  return false
end

function modifier_item_meteor_hammer_oaa_thinker:OnCreated()
  if IsServer() then
    local ability = self:GetAbility()
    local parent = self:GetParent()
    -- item info from kv
    self.impact_radius = ability:GetSpecialValueFor("impact_radius")
    self.impact_damage = ability:GetSpecialValueFor("impact_damage_units")
    self.damage_to_the_boss = ability:GetSpecialValueFor("damage_to_the_boss") * 0.01
    self.impact_damage_bosses = self.impact_damage * self.damage_to_the_boss

    self.land_time = ability:GetSpecialValueFor("land_time")
    self.burn_duration = ability:GetSpecialValueFor("burn_duration")
    self.stun_duration = ability:GetSpecialValueFor("stun_duration")
    --landtime should not be a negative number
    self:StartIntervalThink(self.land_time)

    local impact_particle = ParticleManager:CreateParticle("particles/items4_fx/meteor_hammer_spell.vpcf", PATTACH_WORLDORIGIN, nil)

    --Controls the metoer position to origin
    ParticleManager:SetParticleControl(impact_particle, 0, parent:GetOrigin() + Vector(0, 0, 1000))
    ParticleManager:SetParticleControl(impact_particle, 1, parent:GetOrigin())
    --Fade time of cetain particles
    ParticleManager:SetParticleControl(impact_particle, 2, Vector(self.land_time, 0, 0))
    ParticleManager:ReleaseParticleIndex(impact_particle)
  end
end

function modifier_item_meteor_hammer_oaa_thinker:OnIntervalThink()
  local parent = self:GetParent() -- thinker
  local caster = self:GetCaster() -- item owner
  local ability = self:GetAbility() -- item
  local parent_loc = parent:GetAbsOrigin()

  -- Sound
  EmitSoundOnLocationWithCaster(parent_loc, "DOTA_Item.MeteorHammer.Impact", caster)

  -- Destroy trees
  GridNav:DestroyTreesAroundPoint(parent_loc, self.impact_radius, true)

  local enemies = FindUnitsInRadius(
    caster:GetTeamNumber(),
    parent_loc,
    nil,
    self.impact_radius,
    DOTA_UNIT_TARGET_TEAM_ENEMY,
    bit.bor(DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_BASIC),
    DOTA_UNIT_TARGET_FLAG_NONE,
    FIND_ANY_ORDER,
    false
  )

  local damage_table = {
    attacker = caster,
    damage_type = DAMAGE_TYPE_MAGICAL,
    ability = ability,
  }

  for _, enemy in pairs(enemies) do
    if enemy and not enemy:IsNull() then
      -- Apply damage-over-time debuff (duration is not affected by status resistance)
      enemy:AddNewModifier(caster, ability, "modifier_item_meteor_hammer_oaa_dot", {duration = self.burn_duration})
      -- Apply stun debuff (duration is affected by status resistance)
      local stun_duration = self.stun_duration * (1 - enemy:GetStatusResistance())
      enemy:AddNewModifier(caster, ability, "modifier_item_meteor_hammer_oaa_stun", {duration = stun_duration})

      -- Is the enemy a boss?
      if BossSpawner:IsBoss(enemy) then
        damage_table.damage = self.impact_damage_bosses + (self.damage_to_the_boss * enemy:GetMaxHealth() * ability:GetSpecialValueFor("max_hp_impact_damage") * 0.01)
      else
        damage_table.damage = self.impact_damage + (enemy:GetMaxHealth() * ability:GetSpecialValueFor("max_hp_impact_damage") * 0.01)
      end

      if enemy:IsAlive() then
        damage_table.victim = enemy
        ApplyDamage(damage_table)
      end
    end
  end

  -- Вышки: обычный урон они блокируют (lib/tower/tower_base.lua), поэтому
  -- снимаем процент максимального здоровья через их модификатор.
  local tower_pct = ability:GetSpecialValueFor("tower_damage_pct")

  if tower_pct > 0 then
    local towers = FindUnitsInRadius(
      caster:GetTeamNumber(),
      parent_loc,
      nil,
      self.impact_radius,
      DOTA_UNIT_TARGET_TEAM_ENEMY,
      DOTA_UNIT_TARGET_BUILDING,
      DOTA_UNIT_TARGET_FLAG_INVULNERABLE + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
      FIND_ANY_ORDER,
      false
    )

    for _, tower in pairs(towers) do
      local controller = tower and not tower:IsNull() and tower:FindModifierByName("tower_controller")

      if controller and controller.TakeScriptDamage then
        controller:TakeScriptDamage(tower:GetMaxHealth() * tower_pct / 100)
      end
    end
  end

  self:StartIntervalThink(-1)
  self:Destroy()
end

function modifier_item_meteor_hammer_oaa_thinker:OnDestroy()
  if not IsServer() then
    return
  end
  local parent = self:GetParent()
  if parent and not parent:IsNull() then
    parent:Destroy()
  end
end

---------------------------------------------------------------------------------------------------

modifier_item_meteor_hammer_oaa_dot = class({})

function modifier_item_meteor_hammer_oaa_dot:IsHidden()
  return false
end

function modifier_item_meteor_hammer_oaa_dot:IsDebuff()
  return true
end

function modifier_item_meteor_hammer_oaa_dot:IsPurgable()
  return not self:GetParent():IsBoss()
end

function modifier_item_meteor_hammer_oaa_dot:GetAttributes()
  return MODIFIER_ATTRIBUTE_MULTIPLE
end

function modifier_item_meteor_hammer_oaa_dot:OnCreated()
  --local parent = self:GetParent()
  local ability = self:GetAbility()
  local movement_slow = ability:GetSpecialValueFor("move_speed_slow_pct")
  if IsServer() then
    self.burn_dps = ability:GetSpecialValueFor("burn_dps_units")
    self.burn_dps_boss = ability:GetSpecialValueFor("burn_dps_units")
    self.burn_interval = ability:GetSpecialValueFor("burn_interval")

    self:OnIntervalThink()
    self:StartIntervalThink(self.burn_interval)
  end
  -- Move Speed Slow is reduced with Slow Resistance
  self.slow = movement_slow --parent:GetValueChangedBySlowResistance(movement_slow)
end

function modifier_item_meteor_hammer_oaa_dot:OnIntervalThink()
  if IsServer() then
    local enemy = self:GetParent()
    local caster = self:GetCaster()
    local ability = self:GetAbility()
    self.damage_to_the_boss = ability:GetSpecialValueFor("damage_to_the_boss") * 0.01

    local damage_table = {
      victim = enemy,
      attacker = caster,
      damage = self.burn_dps * self.burn_interval + (enemy:GetHealth() * ability:GetSpecialValueFor("max_hp_burn_damage") * 0.01),
      damage_type = DAMAGE_TYPE_MAGICAL,
      ability = ability,
    }

    if BossSpawner:IsBoss(enemy) then
      damage_table.damage = self.burn_dps_boss * self.damage_to_the_boss * self.burn_interval + (self.damage_to_the_boss * enemy:GetHealth() *  ability:GetSpecialValueFor("max_hp_burn_damage") * 0.01)
    end

    ApplyDamage(damage_table)
  end
end

function modifier_item_meteor_hammer_oaa_dot:DeclareFunctions()
  return {
    MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
  }
end

function modifier_item_meteor_hammer_oaa_dot:GetModifierMoveSpeedBonus_Percentage()
  return 0 - math.abs(self.slow or 0)
end

function modifier_item_meteor_hammer_oaa_dot:GetEffectName()
  return "particles/items4_fx/meteor_hammer_spell_debuff.vpcf"
end

function modifier_item_meteor_hammer_oaa_dot:GetTexture()
  return "item_meteor_hammer"
end

---------------------------------------------------------------------------------------------------

modifier_item_meteor_hammer_oaa_stun = class({})

function modifier_item_meteor_hammer_oaa_stun:IsHidden()
  return false
end

function modifier_item_meteor_hammer_oaa_stun:IsDebuff()
  return true
end

function modifier_item_meteor_hammer_oaa_stun:IsStunDebuff()
  return true
end

function modifier_item_meteor_hammer_oaa_stun:IsPurgable()
  return not self:GetParent():IsBoss()
end

function modifier_item_meteor_hammer_oaa_stun:GetEffectName()
  return "particles/generic_gameplay/generic_stunned.vpcf"
end

function modifier_item_meteor_hammer_oaa_stun:GetEffectAttachType()
  return PATTACH_OVERHEAD_FOLLOW
end

function modifier_item_meteor_hammer_oaa_stun:DeclareFunctions()
  return {
    MODIFIER_PROPERTY_OVERRIDE_ANIMATION,
  }
end

function modifier_item_meteor_hammer_oaa_stun:GetOverrideAnimation()
  return ACT_DOTA_DISABLED
end

function modifier_item_meteor_hammer_oaa_stun:CheckState()
  return {
    [MODIFIER_STATE_STUNNED] = true,
  }
end

function modifier_item_meteor_hammer_oaa_stun:GetTexture()
  return "item_meteor_hammer"
end