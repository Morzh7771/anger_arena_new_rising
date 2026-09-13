modifier_hidden_from_map = modifier_hidden_from_map or class({})

-- Невидимый юнит, который стоит на карте только ради значка на миникарте.
--
-- Режим задаётся стаком (он синхронизируется с клиентом, а CheckState там
-- считается свой, так что флаги только через стак):
--   0 - обычная иконка: нейтральный юнит, виден всем сквозь туман
--   1 - погашенный оригинал: его иконку заменили копии команд (lib/minimap_spots.lua)
--   2 - копия команды, иконка горит (видит только своя команда)
--   3 - копия команды, иконка погашена: команда видела кемп пустым
MINIMAP_ICON_NORMAL = 0
MINIMAP_ICON_REPLACED = 1
MINIMAP_ICON_TEAM_SHOWN = 2
MINIMAP_ICON_TEAM_HIDDEN = 3

function modifier_hidden_from_map:IsHidden()
	return false
end

function modifier_hidden_from_map:IsPurgable()
	return false
end

-- Нейтральный юнит без обзора в тумане клиенту не отправляется, и значка нет.
-- PROVIDES_FOW_POSITION показывает его всем сквозь туман - так Valve держит на
-- миникарте здания в conquest. Копиям команд это не нужно: свои юниты своей
-- команде видны всегда, а врагу их светить незачем.
function modifier_hidden_from_map:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_PROVIDES_FOW_POSITION,
	}
end

function modifier_hidden_from_map:GetModifierProvidesFOWVision()
	return self:GetStackCount() == MINIMAP_ICON_NORMAL and 1 or 0
end

function modifier_hidden_from_map:CheckState()
	local mode = self:GetStackCount()

	return {
		[MODIFIER_STATE_NOT_ON_MINIMAP] 			= mode == MINIMAP_ICON_REPLACED or mode == MINIMAP_ICON_TEAM_HIDDEN,
		[MODIFIER_STATE_NOT_ON_MINIMAP_FOR_ENEMIES] = mode >= MINIMAP_ICON_TEAM_SHOWN,
		[MODIFIER_STATE_STUNNED] 					= true,
		[MODIFIER_STATE_INVULNERABLE] 				= true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] 			= true,
		-- OUT_OF_GAME тут нельзя: такой юнит пропадает и с миникарты, а он стоит
		-- ровно ради значка на ней. От всего остального он и так закрыт.
		[MODIFIER_STATE_MAGIC_IMMUNE] 				= true,
		[MODIFIER_STATE_ATTACK_IMMUNE] 				= true,
		[MODIFIER_STATE_UNSELECTABLE] 				= true,
		[MODIFIER_STATE_LOW_ATTACK_PRIORITY] 		= true,
		[MODIFIER_STATE_NO_HEALTH_BAR] 				= true,
		[MODIFIER_STATE_TRUESIGHT_IMMUNE] 			= true,
	}
end
