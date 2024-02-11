LinkLuaModifier("modifier_talant_bash_cd", "lib/special_bonus_base_aa/special", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_talant_bash", "lib/special_bonus_base_aa/special", LUA_MODIFIER_MOTION_NONE)
modifier_agi = class({
    IsHidden = function(self) return true end,
    DeclareFunctions = function(self) return {
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
    } end,
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    RemoveOnDeath = function (self) return false end,
    IsPurgable = function (self) return false end,
    GetModifierBonusStats_Agility = function(self) return self.value end,
    OnCreated = function (self,kv)
      self.value = 0
      self.kvValue = kv.value
      self.KvPercent = kv.pct
      self:StartIntervalThink(0.1)
    end,
    OnIntervalThink = function (self)
      if not IsServer() then return end
      self.value = 0
      if self.KvPercent ~= nil or self.KvPercent == 0 then self.value = self.kvValue + self:GetParent():GetAgility() * self.KvPercent / 100 else self.value = self.kvValue end
      self:GetParent():CalculateStatBonus(true)
    end,
})
modifier_str = class({
    IsHidden = function(self) return true end,
    DeclareFunctions = function(self) return {
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
    } end,
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    RemoveOnDeath = function (self) return false end,
    IsPurgable = function (self) return false end,
    GetModifierBonusStats_Strength = function(self) return self.value end,
    OnCreated = function (self,kv)
      self.value = 0
      self.kvValue = kv.value
      self.KvPercent = kv.pct
      self:StartIntervalThink(0.1)
    end,
    OnIntervalThink = function (self)
      if not IsServer() then return end
      self.value = 0
      if self.KvPercent ~= nil or self.KvPercent == 0 then self.value = self.kvValue + self:GetParent():GetStrength() * self.KvPercent / 100 else self.value = self.kvValue end
      self:GetParent():CalculateStatBonus(true)
    end,
})
modifier_int = class({
    IsHidden = function(self) return true end,
    DeclareFunctions = function(self) return {
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
    } end,
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    RemoveOnDeath = function (self) return false end,
    IsPurgable = function (self) return false end,
    GetModifierBonusStats_Intellect = function(self) return self.value end,
    OnCreated = function (self,kv)
      self.value = 0
      self.kvValue = kv.value
      self.KvPercent = kv.pct
      self:StartIntervalThink(0.1)
    end,
    OnIntervalThink = function (self)
      if not IsServer() then return end
      self.value = 0
      if self.KvPercent ~= nil or self.KvPercent == 0 then self.value = self.kvValue + self:GetParent():GetIntellect() * self.KvPercent / 100 else self.value = self.kvValue end
      self:GetParent():CalculateStatBonus(true)
    end,
})
modifier_all = class({
  IsHidden = function(self) return true end,
  DeclareFunctions = function(self) return {
  MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
  MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
  MODIFIER_PROPERTY_STATS_AGILITY_BONUS
  } end,
  GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
  RemoveOnDeath = function (self) return false end,
  IsPurgable = function (self) return false end,
  GetModifierBonusStats_Intellect = function(self) return self.int end,
  GetModifierBonusStats_Agility = function(self) return self.agi end,
  GetModifierBonusStats_Strength = function(self) return self.str end,
  OnCreated = function (self,kv)
    self.str = 0
    self.agi = 0
    self.int = 0
    self.kvValue = kv.value
    self.KvPercent = kv.pct
    self:StartIntervalThink(0.1)
  end,
  OnIntervalThink = function (self)
    if not IsServer() then return end
    self.str = 0
    self.agi = 0
    self.int = 0
    if self.KvPercent ~= nil or self.KvPercent == 0 then self.str = self.kvValue + self:GetParent():GetStrength() * self.KvPercent / 100 else self.str = self.kvValue end
    if self.KvPercent ~= nil or self.KvPercent == 0 then self.agi = self.kvValue + self:GetParent():GetAgility() * self.KvPercent / 100 else self.agi = self.kvValue end
    if self.KvPercent ~= nil or self.KvPercent == 0 then self.int = self.kvValue + self:GetParent():GetIntellect() * self.KvPercent / 100 else self.int = self.kvValue end
    self:GetParent():CalculateStatBonus(true)
  end,

})
modifier_hp = class({
  IsHidden = function(self) return true end,
  DeclareFunctions = function(self) return {
    MODIFIER_PROPERTY_HEALTH_BONUS,
  } end,
  GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
  RemoveOnDeath = function (self) return false end,
  IsPurgable = function (self) return false end,
  GetModifierHealthBonus = function(self) return self.value end,
  OnCreated = function (self,kv)
    self.value = 0
    self.kvValue = kv.value
    self.KvPercent = kv.pct
    self:StartIntervalThink(0.1)
  end,
  OnIntervalThink = function (self)
    if not IsServer() then return end
    if self.KvPercent ~= nil or self.KvPercent == 0 then self.value = self.kvValue + self:GetParent():GetMaxHealth() * self.KvPercent / 100 - self.value else self.value = self.kvValue end
    self:GetParent():CalculateStatBonus(true)
  end,
})
modifier_damage = class({
  IsHidden = function(self) return true end,
  DeclareFunctions = function(self) return {
    MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
  } end,
  GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
  RemoveOnDeath = function (self) return false end,
  IsPurgable = function (self) return false end,
  GetModifierPreAttack_BonusDamage = function(self) return self.value end,
  OnCreated = function (self,kv)
      self.value = 0
      self.kvValue = kv.value
      self.KvPercent = kv.pct
      self:StartIntervalThink(0.1)
  end,
  OnIntervalThink = function (self)
    if not IsServer() then return end
    self.value = 0
    if self.KvPercent ~= nil or self.KvPercent == 0 then self.value = self.kvValue + self:GetParent():GetDamageMax() * self.KvPercent / 100 else self.value = self.kvValue end
    self:GetParent():CalculateStatBonus(true)
  end,
})
modifier_baseDamage = class({
  IsHidden = function(self) return true end,
  DeclareFunctions = function(self) return {
    MODIFIER_PROPERTY_BASEATTACK_BONUSDAMAGE,
  } end,
  GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
  RemoveOnDeath = function (self) return false end,
  IsPurgable = function (self) return false end,
  GetModifierBaseAttack_BonusDamage = function(self) return self.value end,
  OnCreated = function (self,kv)
    self.value = 0
    self.kvValue = kv.value
    self.KvPercent = kv.pct
    self:StartIntervalThink(0.1)
  end,
  OnIntervalThink = function (self)
    if not IsServer() then return end
    self.value = 0
    if self.KvPercent ~= nil or self.KvPercent == 0 then self.value = self.kvValue + self:GetParent():GetDamageMax() * self.KvPercent / 100 else self.value = self.kvValue end
    self:GetParent():CalculateStatBonus(true)
  end,
})
modifier_miss = class({
  IsHidden = function(self) return true end,
  DeclareFunctions = function(self) return {
    MODIFIER_PROPERTY_EVASION_CONSTANT,
  } end,
  GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
  RemoveOnDeath = function (self) return false end,
  IsPurgable = function (self) return false end,
  GetModifierEvasion_Constant = function(self) return self.value end,
  OnCreated = function (self,kv)
    self.value = kv.value
    self.KvPercent = kv.pct
  end,
})
modifier_trueMiss = class({
  IsHidden = function(self) return true end,
  DeclareFunctions = function(self) return {
    MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
  } end,
  GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
  RemoveOnDeath = function (self) return false end,
  IsPurgable = function (self) return false end,
  OnCreated = function (self,kv)
    self.value = kv.value
  end,
  GetModifierIncomingDamage_Percentage = function (self)
    if RollPercentage(self.value) then
        local backtrack_fx = ParticleManager:CreateParticle("particles/units/heroes/hero_faceless_void/faceless_void_backtrack.vpcf", PATTACH_ABSORIGIN, self:GetCaster())
        ParticleManager:SetParticleControl(backtrack_fx, 0, self:GetCaster():GetAbsOrigin())
        ParticleManager:ReleaseParticleIndex(backtrack_fx)
        return -100
    end
end,
})
modifier_hpRegen = class({
  IsHidden = function(self) return true end,
  DeclareFunctions = function(self) return {
  MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
  MODIFIER_PROPERTY_HEALTH_REGEN_PERCENTAGE,
  } end,
  GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
  RemoveOnDeath = function (self) return false end,
  IsPurgable = function (self) return false end,
  GetModifierHealthRegenPercentage = function(self) return self.int end,
  GetModifierConstantHealthRegen = function(self) return self.agi end,
  OnCreated = function (self,kv)
    self.kvValue = kv.value
    self.KvPercent = kv.pct
  end,
})
modifier_agiLevel = class({
  IsHidden = function(self) return true end,
  DeclareFunctions = function(self) return {
  MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
  } end,
  GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
  RemoveOnDeath = function (self) return false end,
  IsPurgable = function (self) return false end,
  GetModifierBonusStats_Agility = function(self) return self.value end,
  OnCreated = function (self,kv)
    self.kvValue = kv.value
    self:StartIntervalThink(0.1)
  end,
  OnIntervalThink = function (self)
    if not IsServer() then return end
    self.value = self:GetParent():GetLevel() * self.kvValue
    self:GetParent():CalculateStatBonus(true)
  end,
})
modifier_strLevel = class({
  IsHidden = function(self) return true end,
  DeclareFunctions = function(self) return {
  MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
  } end,
  GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
  RemoveOnDeath = function (self) return false end,
  IsPurgable = function (self) return false end,
  GetModifierBonusStats_Strength = function(self) return self.value end,
  OnCreated = function (self,kv)
    self.kvValue = kv.value
    self:StartIntervalThink(0.1)
  end,
  OnIntervalThink = function (self)
    if not IsServer() then return end
    self.value = self:GetParent():GetLevel() * self.kvValue
    self:GetParent():CalculateStatBonus(true)
  end,
})
modifier_intLevel = class({
  IsHidden = function(self) return true end,
  DeclareFunctions = function(self) return {
  MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
  } end,
  GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
  RemoveOnDeath = function (self) return false end,
  IsPurgable = function (self) return false end,
  GetModifierBonusStats_Intellect = function(self) return self.value end,
  OnCreated = function (self,kv)
    self.kvValue = kv.value
    self:StartIntervalThink(0.1)
  end,
  OnIntervalThink = function (self)
    if not IsServer() then return end
    self.value = self:GetParent():GetLevel() * self.kvValue
    self:GetParent():CalculateStatBonus(true)
  end,
})
modifier_strHp = class({
  IsHidden = function(self) return true end,
  DeclareFunctions = function(self) return {
    MODIFIER_PROPERTY_HEALTH_BONUS,
  } end,
  GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
  RemoveOnDeath = function (self) return false end,
  IsPurgable = function (self) return false end,
  GetModifierHealthBonus = function(self) return self.value end,
  OnCreated = function (self,kv)
    self.kvValue = kv.value
    self:StartIntervalThink(0.1)
  end,
  OnIntervalThink = function (self)
    if not IsServer() then return end
    self.value = self:GetParent():GetStrength() * self.kvValue
    self:GetParent():CalculateStatBonus(true)
  end,
})
modifier_agiArmor = class({
  IsHidden = function(self) return true end,
  DeclareFunctions = function(self) return {
    MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
  } end,
  GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
  RemoveOnDeath = function (self) return false end,
  IsPurgable = function (self) return false end,
  GetModifierPhysicalArmorBonus = function(self) return self.value end,
  OnCreated = function (self,kv)
    self.kvValue = kv.value
    self:StartIntervalThink(0.1)
  end,
  OnIntervalThink = function (self)
    if not IsServer() then return end
    self.value = self:GetParent():GetAgility() * self.kvValue
    self:GetParent():CalculateStatBonus(true)
  end,
})
modifier_intSpell = class({
  IsHidden = function(self) return true end,
  DeclareFunctions = function(self) return {
    MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE ,
  } end,
  GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
  RemoveOnDeath = function (self) return false end,
  IsPurgable = function (self) return false end,
  GetModifierSpellAmplify_Percentage = function(self) return self.value end,
  OnCreated = function (self,kv)
    self.kvValue = kv.value
    self:StartIntervalThink(0.1)
  end,
  OnIntervalThink = function (self)
    if not IsServer() then return end
    self.value = self:GetParent():GetIntellect() * self.kvValue
    self:GetParent():CalculateStatBonus(true)
  end,
})
modifier_attackSpeed = class({
  IsHidden = function(self) return true end,
  DeclareFunctions = function(self) return {
    MODIFIER_PROPERTY_ATTACKSPEED_PERCENTAGE,
    MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
  } end,
  GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
  RemoveOnDeath = function (self) return false end,
  IsPurgable = function (self) return false end,
  GetModifierAttackSpeedPercentage = function(self) return self.KvPercent end,
  GetModifierAttackSpeedBonus_Constant = function(self) return self.kvValue end,
  OnCreated = function (self,kv)
    self.kvValue = kv.value
    self.KvPercent = kv.pct
  end,
})
modifier_dayVision = class({
  IsHidden = function(self) return true end,
  DeclareFunctions = function(self) return {
    MODIFIER_PROPERTY_BONUS_DAY_VISION,
  } end,
  GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
  RemoveOnDeath = function (self) return false end,
  IsPurgable = function (self) return false end,
  GetBonusDayVision = function(self) return self.kvValue end,
  OnCreated = function (self,kv)
    self.kvValue = kv.value
  end,
})
modifier_nightVision = class({
  IsHidden = function(self) return true end,
  DeclareFunctions = function(self) return {
    MODIFIER_PROPERTY_BONUS_NIGHT_VISION,
  } end,
  GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
  RemoveOnDeath = function (self) return false end,
  IsPurgable = function (self) return false end,
  GetBonusDayVision = function(self) return self.kvValue end,
  GetBonusDayVisionPercentage = function(self) return self.KvPercent end,
  OnCreated = function (self,kv)
    self.kvValue = kv.value
  end,
})
modifier_bash = class({
  IsHidden = function(self) return true end,
  DeclareFunctions = function(self) return {
    MODIFIER_EVENT_ON_ATTACK,
		MODIFIER_EVENT_ON_ATTACK_LANDED,
  } end,
  GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
  RemoveOnDeath = function (self) return false end,
  IsPurgable = function (self) return false end,
  OnCreated = function (self,kv)
    self.damage = kv.value
    self.chance = kv.pct
    self.cd = kv.restore_time
    self.bash_proc = false
    self.bash_duration = kv.bash_duration
  end,
  OnAttack = function (self,keys)
    print("gey")
    if keys.attacker == self:GetParent() and
    not self:GetParent():HasModifier("modifier_talant_bash_cd") and
    not keys.attacker:IsIllusion() and
    not keys.target:IsBuilding() and
    not keys.target:IsOther() then
      if RollPseudoRandomPercentage(self.chance,102,self:GetParent()) then
        self.bash_proc = true
      end
    end
  end,
  OnAttackLanded = function (self,keys)
    if keys.attacker == self:GetParent() and self.bash_proc then
      self.bash_proc = false
      self:GetParent():AddNewModifier(self:GetParent(),nil,"modifier_talant_bash_cd",{duration = self.cd})
        keys.target:EmitSound("DOTA_Item.SkullBasher")
        keys.target:AddNewModifier(self:GetParent(), nil, "modifier_talant_bash", {duration = self.bash_duration * (1 - keys.target:GetStatusResistance())})
    end
  end
})
modifier_crit = class({
  IsHidden = function (self) return true end,
  DeclareFunctions = function (self) return {
      MODIFIER_PROPERTY_PREATTACK_CRITICALSTRIKE,
  } end,
  GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
  OnCreated = function (self,kv)
    self.damage = kv.value
    self.chance = kv.pct
  end,
  GetModifierPreAttack_CriticalStrike = function (self,params)
    if self:LegitimateAttack(params) then
      if RollPseudoRandomPercentage(101,103,self:GetParent())then
          return self.damage
      end
    end 
  end,
})
function modifier_crit:LegitimateAttack(params)
  local target = params.unit or params.target
  local hero = self:GetParent()

  if
  IsServer()
          and params.attacker == hero
          and target:GetTeamNumber() ~= hero:GetTeamNumber()
          and (not target:IsBuilding())
          and (not target:IsOther())
          and ((params.inflictor == nil) or (params.inflictor:GetAbilityName() == "item_bfury"))
  then
      return true
  else
      return false
  end
end
modifier_bat = class({
  IsHidden = function (self) return true end,
  DeclareFunctions = function (self) return {
    MODIFIER_PROPERTY_FIXED_ATTACK_RATE,
  } end,
  GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
  OnCreated = function (self,kv)
    self.value = kv.value
    print(self.value)
    print(self:GetParent():GetBaseAttackTime())
  end,
  GetModifierFixedAttackRate = function (self) return self:GetParent():GetBaseAttackTime() - 1.1 end,
})

