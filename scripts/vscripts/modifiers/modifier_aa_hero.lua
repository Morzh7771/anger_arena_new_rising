--[[
	Бонусы героя от характеристик (плавные формулы, без порогов и капов).

	Интеллект -> усиление заклинаний, линейно:
	  spell_amp% = INT_SPELL_AMP_PER_POINT * интеллект
	  1000 -> 20%   2500 -> 50%   5000 -> 100%   10000 -> 200%

	Сила -> снижение входящего урона, убывающая отдача:
	  снижение% = STR_RESIST_LIMIT * сила / (сила + STR_RESIST_HALF)
	  к STR_RESIST_LIMIT только стремится и никогда его не достигает (и тем более 100%)
	  1000 -> 8.6%   2500 -> 15%   5000 -> 20%   10000 -> 24%
]]
AA_HERO_INT_SPELL_AMP_PER_POINT = 0.04 -- было 0.02, усилено в 2 раза
AA_HERO_STR_RESIST_LIMIT = 30
AA_HERO_STR_RESIST_HALF = 2500

function AAHeroStatSpellAmp(int)
	return AA_HERO_INT_SPELL_AMP_PER_POINT * math.max(0, int or 0)
end

function AAHeroStatDamageReduction(str)
	str = math.max(0, str or 0)
	return AA_HERO_STR_RESIST_LIMIT * str / (str + AA_HERO_STR_RESIST_HALF)
end

modifier_aa_hero = class({})
LinkLuaModifier("bonus_str_tome", "modifiers/modifier_aa_hero", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("bonus_agi_tome", "modifiers/modifier_aa_hero", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("bonus_int_tome", "modifiers/modifier_aa_hero", LUA_MODIFIER_MOTION_NONE)
bonus_str_tome = class({
	IsHidden = function (self) 
		if self:GetStackCount() > 1 then return false else return true end end,
	IsPurgable = function (self) return false end,
	RemoveOnDeath = function (self) return false end,
	GetTexture = function (self)
		if self:GetName() == "bonus_str_tome" then return "../items/tome_str_6" end
		if self:GetName() == "bonus_agi_tome" then return "../items/tome_agi_6" end
		if self:GetName() == "bonus_int_tome" then return "../items/tome_int_6" end
	end,
})
bonus_agi_tome = bonus_str_tome
bonus_int_tome = bonus_str_tome

function modifier_aa_hero:IsHidden()
	return true
end
function modifier_aa_hero:IsPurgable()
	return false
end
function modifier_aa_hero:RemoveOnDeath()
    return false
end

function modifier_aa_hero:OnCreated()
	self.limit = 700
	-- OnCreated и тик идут и на клиенте, а у клиентской копии юнита нет
	-- AddNewModifier и SetBaseMagicalResistanceValue - там сыпались ошибки
	if not IsServer() then return end
	self:StartIntervalThink(1.0)
	if not self:GetParent():IsIllusion() then  
		self:GetParent():AddNewModifier(self:GetParent(),nil,'bonus_str_tome',{duration = -1})
		self:GetParent():AddNewModifier(self:GetParent(),nil,'bonus_agi_tome',{duration = -1})
		self:GetParent():AddNewModifier(self:GetParent(),nil,'bonus_int_tome',{duration = -1})
	end
	-- единый BAT героя (modifiers/modifier_bat.lua): вешаем тут, чтобы был у всех героев,
	-- в том числе созданных мимо первого спавна (боты, -createhero, репик)
	if not self:GetParent():HasModifier("modifier_bat") then
		self:GetParent():AddNewModifier(self:GetParent(), nil, "modifier_bat", {duration = -1})
	end
end

function modifier_aa_hero:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_MOVESPEED_LIMIT,
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
		MODIFIER_PROPERTY_IGNORE_MOVESPEED_LIMIT,
		MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
		MODIFIER_EVENT_ON_DEATH,
		MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE,
		MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
	}
	return funcs
end
function GetPlayerSteamID(heroEntity)
    local playerID = heroEntity:GetPlayerID()
    if playerID and playerID ~= -1 then
        local playerInfo = PlayerResource:GetPlayer(playerID)
        if playerInfo then
            return tostring(PlayerResource:GetSteamAccountID(playerID))
        end
    end
    return nil
end
function modifier_aa_hero:OnDeath(data)
	if data.unit == self:GetParent() then
		if self:GetParent():FindModifierByName('bonus_str_tome'):GetStackCount() > 10 then
			self:GetParent():FindModifierByName('bonus_str_tome'):SetStackCount(self:GetParent():FindModifierByName('bonus_str_tome'):GetStackCount() * (1 - 20/100))
		end
		if self:GetParent():FindModifierByName('bonus_agi_tome'):GetStackCount() > 10 then
			self:GetParent():FindModifierByName('bonus_agi_tome'):SetStackCount(self:GetParent():FindModifierByName('bonus_agi_tome'):GetStackCount() * (1 - 20/100))
		end
		if self:GetParent():FindModifierByName('bonus_int_tome'):GetStackCount() > 10 then
			self:GetParent():FindModifierByName('bonus_int_tome'):SetStackCount(self:GetParent():FindModifierByName('bonus_int_tome'):GetStackCount() * (1 - 20/100))
		end
	end
end
function modifier_aa_hero:GetModifierIgnoreMovespeedLimit()
    return 1
end
function modifier_aa_hero:GetModifierBonusStats_Strength() if self:GetParent():HasModifier("bonus_str_tome") and self:GetParent():FindModifierByName('bonus_str_tome'):GetStackCount() > 1 then return self:GetParent():FindModifierByName('bonus_str_tome'):GetStackCount() end end
function modifier_aa_hero:GetModifierBonusStats_Agility() if self:GetParent():HasModifier("bonus_agi_tome") and self:GetParent():FindModifierByName('bonus_agi_tome'):GetStackCount() > 1 then return self:GetParent():FindModifierByName('bonus_agi_tome'):GetStackCount() end end
function modifier_aa_hero:GetModifierBonusStats_Intellect() if self:GetParent():HasModifier("bonus_int_tome") and self:GetParent():FindModifierByName('bonus_int_tome'):GetStackCount() > 1 then return self:GetParent():FindModifierByName('bonus_int_tome'):GetStackCount() end end

function modifier_aa_hero:GetModifierMoveSpeed_Limit( params )
	-- FindAllModifiers есть только на сервере; на клиенте модификатор тоже живёт
	local parent = self:GetParent()
	for _, mod in ipairs(parent.FindAllModifiers and parent:FindAllModifiers() or {}) do
		if string.find(string.lower(mod:GetName()), "tailwind", 1, true) then
			local ability = mod:GetAbility() or self:GetParent():FindAbilityByName("windrunner_tailwind")
			if ability then return ability:GetSpecialValueFor("max_movespeed") end
		end
	end
	-- Обычный лимит: 700, Fleetfooted (чара в нейтральном пассивном слоте) +movespeed_limit_bonus.
	-- Руна Haste даёт этот же текущий лимит. Скиллы, снимающие лимит, - без изменений.
	local limit = 700
	local enh = parent.GetItemInSlot and parent:GetItemInSlot(DOTA_ITEM_NEUTRAL_PASSIVE_SLOT or 17)
	if enh and not enh:IsNull() and enh:GetAbilityName() == "item_aa_enhancement_fleetfooted" then
		limit = limit + enh:GetSpecialValueFor("movespeed_limit_bonus")
	end
	if     self:GetParent():HasModifier("modifier_rune_haste") then
		return limit
	elseif self:GetParent():HasModifier("modifier_spirit_breaker_charge_of_darkness")
	or 	   self:GetParent():HasModifier("modifier_bloodseeker_thirst")
	or 	   self:GetParent():HasModifier("modifier_primal_beast_trample")
	or 	   self:GetParent():HasModifier("modifier_spirit_breaker_bulldoze")
	or 	   self:GetParent():HasModifier("modifier_weaver_shukuchi")
	or 	   self:GetParent():HasModifier("modifier_dark_seer_surge") then
		return 10000
	elseif self:GetParent():HasModifier("modifier_centaur_horsepower") then
		return math.max(800, limit)
	end
	return limit
end
function modifier_aa_hero:GetModifierMoveSpeedBonus_Percentage()
	if(0.05 * self:GetParent():GetAgility()>35) then
		return 35
	else
		return (0.05 * self:GetParent():GetAgility())
	end
end
function modifier_aa_hero:OnIntervalThink()
	if not IsServer() then return end
	-- раз в минуту в console.log: что сейчас дают сила и интеллект
	self.aa_log_tick = (self.aa_log_tick or 0) + 1
	if self.aa_log_tick % 60 == 1 and not self:GetParent():IsIllusion() then
		local parent = self:GetParent()
		print(string.format("[AA.stats] %s str=%d int=%d -> damage_reduction=%.1f%% spell_amp=%.1f%%",
			parent:GetUnitName(), parent:GetStrength(), parent:GetIntellect(false),
			AAHeroStatDamageReduction(parent:GetStrength()), AAHeroStatSpellAmp(parent:GetIntellect(false))))
	end
	-- снижение урона от силы - в net table юнита: его показывает панель
	-- статов при наведении на портрет (panorama stats_tooltip.js), без
	-- запроса к серверу
	local reduction = math.floor(AAHeroStatDamageReduction(self:GetParent():GetStrength()) * 10 + 0.5) / 10
	if reduction ~= self.net_reduction then
		self.net_reduction = reduction
		self:GetParent():SetNetworkableEntityInfo("aa_damage_reduction", reduction)
	end

    local int = self:GetParent():GetIntellect(false)
	if int ~= self.int then
		self.int = int
		local resist = 0.125 * int -- как в доте 7.42: 0.125% сопротивления магии за интеллект
		self:GetParent():SetBaseMagicalResistanceValue(25 - resist)
	end
end
-- интеллект -> усиление заклинаний (формула в начале файла)
function modifier_aa_hero:GetModifierSpellAmplify_Percentage()
	return AAHeroStatSpellAmp(self:GetParent():GetIntellect(false))
end

-- сила -> снижение входящего урона (формула в начале файла)
function modifier_aa_hero:GetModifierIncomingDamage_Percentage()
	return -AAHeroStatDamageReduction(self:GetParent():GetStrength())
end
