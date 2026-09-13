modifier_hidden_from_map = modifier_hidden_from_map or class({})

-- Невидимый юнит, который стоит на карте только ради значка на миникарте.
--
-- Режим задаётся стаком (он синхронизируется с клиентом, а CheckState там
-- считается свой, так что флаги только через стак):
--   0 - обычная иконка (боссы, порталы)
--   1 - погашенный оригинал: его иконку заменили копии команд (lib/minimap_spots.lua)
--   2 - копия команды, иконка горит (видит только своя команда)
--   3 - копия команды, иконка погашена: команда видела спот пустым
MINIMAP_ICON_NORMAL = 0
MINIMAP_ICON_REPLACED = 1
MINIMAP_ICON_TEAM_SHOWN = 2
MINIMAP_ICON_TEAM_HIDDEN = 3

-- Модификатор висит примерно на 170 юнитах, а CheckState движок зовёт часто.
-- Новая таблица на каждый вызов - это поток мусора и паузы сборщика, которые
-- в логе выглядели как "thinking for N ms" у случайных юнитов. Поэтому таблицы
-- собраны один раз на режим и отдаются одни и те же.
local function BuildState(notOnMinimap, onlyForAllies)
	return {
		[MODIFIER_STATE_NOT_ON_MINIMAP] 			= notOnMinimap,
		[MODIFIER_STATE_NOT_ON_MINIMAP_FOR_ENEMIES] = onlyForAllies,
		[MODIFIER_STATE_STUNNED] 					= true,
		[MODIFIER_STATE_INVULNERABLE] 				= true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] 			= true,
		-- вне игры: юнит не попадает ни в поиски юнитов, ни в ауры, ни в туман.
		-- Без этого ~170 невидимых иконок участвовали в каждом FindUnitsInRadius и
		-- игра лагала. Значок на миникарте при этом остаётся (так делает и 1x6).
		[MODIFIER_STATE_OUT_OF_GAME] 				= true,
		[MODIFIER_STATE_MAGIC_IMMUNE] 				= true,
		[MODIFIER_STATE_ATTACK_IMMUNE] 				= true,
		[MODIFIER_STATE_UNSELECTABLE] 				= true,
		[MODIFIER_STATE_LOW_ATTACK_PRIORITY] 		= true,
		[MODIFIER_STATE_NO_HEALTH_BAR] 				= true,
		[MODIFIER_STATE_TRUESIGHT_IMMUNE] 			= true,
	}
end

local STATES = {
	[MINIMAP_ICON_NORMAL]      = BuildState(false, false),
	[MINIMAP_ICON_REPLACED]    = BuildState(true, false),
	[MINIMAP_ICON_TEAM_SHOWN]  = BuildState(false, true),
	[MINIMAP_ICON_TEAM_HIDDEN] = BuildState(true, true),
}

function modifier_hidden_from_map:IsHidden()
	return false
end

function modifier_hidden_from_map:IsPurgable()
	return false
end

function modifier_hidden_from_map:CheckState()
	return STATES[self:GetStackCount()] or STATES[MINIMAP_ICON_NORMAL]
end

-- Нейтральный юнит без обзора в тумане клиенту не отправляется, и значка нет.
-- PROVIDES_FOW_POSITION показывает его всем сквозь туман - так Valve держит на
-- миникарте здания в conquest. Отдельным модификатором, чтобы движок не
-- дёргал Lua ради копий команд и погашенных оригиналов: вешается только на
-- обычные иконки (addon_game_mode.lua), с замещённых кемпов его снимает
-- lib/minimap_spots.lua.
modifier_minimap_icon_fow = modifier_minimap_icon_fow or class({})

function modifier_minimap_icon_fow:IsHidden() return true end
function modifier_minimap_icon_fow:IsPurgable() return false end

function modifier_minimap_icon_fow:DeclareFunctions()
	return { MODIFIER_PROPERTY_PROVIDES_FOW_POSITION }
end

function modifier_minimap_icon_fow:GetModifierProvidesFOWVision()
	return 1
end
