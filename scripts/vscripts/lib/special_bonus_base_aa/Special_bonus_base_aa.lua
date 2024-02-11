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
LinkLuaModifier("modifier_bat", "lib/special_bonus_base_aa/talantes", LUA_MODIFIER_MOTION_NONE)

if Special_bonus_base_aa == nil then
	print ( '[special_bonus_base_aa] created special_bonus_base_aa' )
	Special_bonus_base_aa = {}
	Special_bonus_base_aa.__index = Special_bonus_base_aa
end

function Special_bonus_base_aa:OnAbilityLearned(event)
	if string.match(event.abilityname, "^special_bonus_base_aa")then
		print("modifier_"..string.match(event.abilityname, "^special_bonus_base_aa_(.-)_")) -- return special_bonus_base_aa_THISwOrd_2424
        local hero = PlayerResource:GetSelectedHeroEntity( event.PlayerID )
        local modifierName = "modifier_"..string.match(event.abilityname, "^special_bonus_base_aa_(.-)_")
        local abilityName = hero:FindAbilityByName(event.abilityname)
        hero:AddNewModifier(abilityName,hero,modifierName,{
			duration = -1,
			value = abilityName:GetSpecialValueFor('value'),
			pct = abilityName:GetSpecialValueFor('pct'),
			restore_time = abilityName:GetSpecialValueFor('restore_time'),
			bash_duration = abilityName:GetSpecialValueFor('bash_duration')
		})
	end
end