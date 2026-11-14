LinkLuaModifier("modifier_agi", "lib/special_bonus_base_aa/talantes", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_str", "lib/special_bonus_base_aa/talantes", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_int", "lib/special_bonus_base_aa/talantes", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_all", "lib/special_bonus_base_aa/talantes", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_hp", "lib/special_bonus_base_aa/talantes", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_damage", "lib/special_bonus_base_aa/talantes", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_baseDamage", "lib/special_bonus_base_aa/talantes", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_miss", "lib/special_bonus_base_aa/talantes", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_trueMiss", "lib/special_bonus_base_aa/talantes", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_hpRegen", "lib/special_bonus_base_aa/talantes", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_strLevel", "lib/special_bonus_base_aa/talantes", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_agiLevel", "lib/special_bonus_base_aa/talantes", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_intLevel", "lib/special_bonus_base_aa/talantes", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_strHP", "lib/special_bonus_base_aa/talantes", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_agiArmor", "lib/special_bonus_base_aa/talantes", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_intSpell", "lib/special_bonus_base_aa/talantes", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_attackSpeed", "lib/special_bonus_base_aa/talantes", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_bash", "lib/special_bonus_base_aa/talantes", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_crit", "lib/special_bonus_base_aa/talantes", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_bat_fixed_rate_aa", "lib/special_bonus_base_aa/talantes", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_talant_stat_refresher", "lib/special_bonus_base_aa/talantes", LUA_MODIFIER_MOTION_NONE)

if Special_bonus_base_aa == nil then
	print ( '[special_bonus_base_aa] created special_bonus_base_aa' )
	Special_bonus_base_aa = {}
	Special_bonus_base_aa.__index = Special_bonus_base_aa
end

function Special_bonus_base_aa:OnAbilityLearned(event)
	-- После изучения ЛЮБОГО таланта сразу пересылаем героя клиенту. Раньше это
	-- невольно делал рефрешер статов (полный пересчёт каждые 0.1 с); когда
	-- лишние пересчёты убрали, окно выбора таланта перестало закрываться само
	-- и ждало следующего клика.
	if event.abilityname and string.match(event.abilityname, "^special_bonus") then
		local learner = PlayerResource:GetSelectedHeroEntity(event.PlayerID)

		if learner and not learner:IsNull() then
			learner:CalculateStatBonus(true)
		end
	end

	if string.match(event.abilityname, "^special_bonus_base_aa")then
        local hero = PlayerResource:GetSelectedHeroEntity( event.PlayerID )
        local modifierName = "modifier_"..string.match(event.abilityname, "^special_bonus_base_aa_(.-)_")
        local abilityName = hero:FindAbilityByName(event.abilityname)
        hero:AddNewModifier(hero,abilityName,modifierName,{
			duration = -1,
			value = abilityName:GetSpecialValueFor('value'),
			pct = abilityName:GetSpecialValueFor('pct'),
			restore_time = abilityName:GetSpecialValueFor('restore_time'),
			bash_duration = abilityName:GetSpecialValueFor('bash_duration')
		})

		-- один пересчёт статов на героя вместо отдельного тика у каждого таланта;
		-- модификатор не MULTIPLE, повторное добавление его просто обновляет
		hero:AddNewModifier(hero, nil, "modifier_talant_stat_refresher", { duration = -1 })
	end
end