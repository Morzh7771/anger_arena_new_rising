LinkLuaModifier("modifier_talant_bash_cd", "lib/special_bonus_base_aa/special", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_talant_bash", "lib/special_bonus_base_aa/special", LUA_MODIFIER_MOTION_NONE)

--[[
	Пересчёт талантов.

	Бонусы талантов считаются от текущих статов героя, поэтому пересчитывать их
	нужно каждый тик - иначе после смены статов значение отстанет. Проблема была
	не в самом пересчёте, а в том, что КАЖДЫЙ талант отдельно дёргал
	CalculateStatBonus(true) - полный пересчёт статов с сетевым апдейтом. На
	десяток изученных талантов у десяти героев это сотни полных пересчётов
	в секунду.

	Теперь так:
	- на героя вешается один modifier_talant_stat_refresher; он раз в тик
	  вызывает Recompute() у всех талантов героя и ОДИН раз - CalculateStatBonus.
	  Частота пересчёта прежняя, но пересчёт один на героя, а не на каждый талант;
	- Recompute() только считает число, движок при этом не трогается;
	- таланты, которые не зависят от статов (от уровня и т.п.), Recompute не
	  имеют вообще - их значение считается прямо в геттере, и общий пересчёт
	  подхватывает его сам.
]]
local TALANT_REFRESH_INTERVAL = 0.1

-- по именам, а не по наличию метода: FindAllModifiers возвращает и нативные
-- модификаторы, у них произвольные поля лучше не трогать
local RECOMPUTE_MODIFIERS = {
	["modifier_agi"]        = true,
	["modifier_str"]        = true,
	["modifier_int"]        = true,
	["modifier_all"]        = true,
	["modifier_hp"]         = true,
	["modifier_damage"]     = true,
	["modifier_baseDamage"] = true,
}

modifier_talant_stat_refresher = class({
	IsHidden        = function(self) return true end,
	RemoveOnDeath   = function(self) return false end,
	IsPurgable      = function(self) return false end,
	OnCreated = function(self)
		if not IsServer() then return end
		self:StartIntervalThink(TALANT_REFRESH_INTERVAL)
	end,
	OnRefresh = function(self)
		if not IsServer() then return end
		self:StartIntervalThink(TALANT_REFRESH_INTERVAL)
	end,
	OnIntervalThink = function(self)
		if not IsServer() then return end

		local parent = self:GetParent()

		if not parent or parent:IsNull() then return end

		for _, mod in pairs(parent:FindAllModifiers()) do
			if RECOMPUTE_MODIFIERS[mod:GetName()] then
				mod:Recompute()
			end
		end

		parent:CalculateStatBonus(true)
	end,
})

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
      self.kvValue = self:GetAbility():GetSpecialValueFor("value")
      self.KvPercent = self:GetAbility():GetSpecialValueFor("pct")
      self:Recompute()
    end,
    -- только считает значение, пересчёт статов делает modifier_talant_stat_refresher
    Recompute = function (self)
      self.value = self.kvValue + self:GetParent():GetAgility() * self.KvPercent / 100
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
      self.kvValue = self:GetAbility():GetSpecialValueFor("value")
      self.KvPercent = self:GetAbility():GetSpecialValueFor("pct")
      self:Recompute()
    end,
    Recompute = function (self)
      self.value = self.kvValue + self:GetParent():GetStrength() * self.KvPercent / 100
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
      self.kvValue = self:GetAbility():GetSpecialValueFor("value")
      self.KvPercent = self:GetAbility():GetSpecialValueFor("pct")
      self:Recompute()
    end,
    Recompute = function (self)
      self.value = self.kvValue + self:GetParent():GetIntellect(false) * self.KvPercent / 100
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
    self.kvValue = self:GetAbility():GetSpecialValueFor("value")
    self.KvPercent = self:GetAbility():GetSpecialValueFor("pct")
    self:Recompute()
  end,
  Recompute = function (self)
    local parent = self:GetParent()
    local pct = self.KvPercent / 100

    self.str = self.kvValue + parent:GetStrength() * pct
    self.agi = self.kvValue + parent:GetAgility() * pct
    self.int = self.kvValue + parent:GetIntellect(false) * pct
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
    self.kvValue = self:GetAbility():GetSpecialValueFor("value")
    self.KvPercent = self:GetAbility():GetSpecialValueFor("pct")
    self:Recompute()
  end,
  -- ВНИМАНИЕ: "- self.value" в формуле похоже на опечатку (GetMaxHealth и так
  -- включает этот бонус, из-за вычитания талант в итоге даёт примерно половину
  -- от "value + pct% от макс. хп"). Формулу не трогаю, чтобы не менять баланс;
  -- если это баг - убрать вычитание.
  Recompute = function (self)
    self.value = self.kvValue + self:GetParent():GetMaxHealth() * self.KvPercent / 100 - self.value
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
      self.kvValue = self:GetAbility():GetSpecialValueFor("value")
      self.KvPercent = self:GetAbility():GetSpecialValueFor("pct")
      self:Recompute()
  end,
  Recompute = function (self)
    self.value = self.kvValue + self:GetParent():GetDamageMax() * self.KvPercent / 100
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
    self.kvValue = self:GetAbility():GetSpecialValueFor("value")
    self.KvPercent = self:GetAbility():GetSpecialValueFor("pct")
    self:Recompute()
  end,
  Recompute = function (self)
    self.value = self.kvValue + self:GetParent():GetDamageMax() * self.KvPercent / 100
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
    self.value = self:GetAbility():GetSpecialValueFor("pct")
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
    self.value = self:GetAbility():GetSpecialValueFor("value")
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
  GetModifierHealthRegenPercentage = function(self) return self.kvValue end,
  GetModifierConstantHealthRegen = function(self) return self.KvPercent end,
  OnCreated = function (self,kv)
    self.kvValue = self:GetAbility():GetSpecialValueFor("value")
    self.KvPercent = self:GetAbility():GetSpecialValueFor("pct")
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
  -- от уровня, не от статов - обратной связи нет, считаем в геттере без тика
  GetModifierBonusStats_Agility = function(self) return self:GetParent():GetLevel() * (self.kvValue or 0) end,
  OnCreated = function (self,kv)
    self.kvValue = self:GetAbility():GetSpecialValueFor("value")
    self:GetParent():CalculateStatBonus(true) -- один раз, чтобы бонус применился сразу
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
  -- от уровня, не от статов - обратной связи нет, считаем в геттере без тика
  GetModifierBonusStats_Strength = function(self) return self:GetParent():GetLevel() * (self.kvValue or 0) end,
  OnCreated = function (self,kv)
    self.kvValue = self:GetAbility():GetSpecialValueFor("value")
    self:GetParent():CalculateStatBonus(true) -- один раз, чтобы бонус применился сразу
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
  -- от уровня, не от статов - обратной связи нет, считаем в геттере без тика
  GetModifierBonusStats_Intellect = function(self) return self:GetParent():GetLevel() * (self.kvValue or 0) end,
  OnCreated = function (self,kv)
    self.kvValue = self:GetAbility():GetSpecialValueFor("value")
    self:GetParent():CalculateStatBonus(true) -- один раз, чтобы бонус применился сразу
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
  -- хп от силы: бонус хп на силу не влияет, обратной связи нет - считаем в геттере
  GetModifierHealthBonus = function(self) return self:GetParent():GetStrength() * (self.kvValue or 0) end,
  OnCreated = function (self,kv)
    self.kvValue = self:GetAbility():GetSpecialValueFor("value")
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
  -- армор от агилити: армор на агилити не влияет, обратной связи нет
  GetModifierPhysicalArmorBonus = function(self) return self:GetParent():GetAgility() * (self.kvValue or 0) end,
  OnCreated = function (self,kv)
    self.kvValue = self:GetAbility():GetSpecialValueFor("value")
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
  -- усиление магии от интеллекта: на интеллект не влияет, обратной связи нет
  GetModifierSpellAmplify_Percentage = function(self) return self:GetParent():GetIntellect(false) * (self.kvValue or 0) end,
  OnCreated = function (self,kv)
    self.kvValue = self:GetAbility():GetSpecialValueFor("value")
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
    self.kvValue = self:GetAbility():GetSpecialValueFor("value")
    self.KvPercent = self:GetAbility():GetSpecialValueFor("pct")
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
    self.kvValue = self:GetAbility():GetSpecialValueFor("value")
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
  OnCreated = function (self,kv)
    self.kvValue = self:GetAbility():GetSpecialValueFor("value")
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
    self.damage = self:GetAbility():GetSpecialValueFor("damage")
    self.chance = self:GetAbility():GetSpecialValueFor("chance")
    self.cd = self:GetAbility():GetSpecialValueFor("bash_cd")
    self.bash_proc = false
    self.bash_duration = self:GetAbility():GetSpecialValueFor("bash_duration")
  end,
  OnAttack = function (self,keys)
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
    self.damage = self:GetAbility():GetSpecialValueFor("damage")
    self.chance = self:GetAbility():GetSpecialValueFor("chance")
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
  end,
  GetModifierFixedAttackRate = function (self) return self:GetParent():GetBaseAttackTime() - 1.1 end,
})

