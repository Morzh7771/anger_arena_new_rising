modifier_hidden_from_map = modifier_hidden_from_map or class({})

function modifier_hidden_from_map:IsHidden()
	return false
end

function modifier_hidden_from_map:IsPurgable()
	return false
end

-- Юнит стоит ради значка на миникарте, но он нейтральный и без обзора: в тумане
-- клиенту его не отправляют, и значка нет. PROVIDES_FOW_POSITION показывает его
-- всем сквозь туман - так Valve держит на миникарте здания в conquest.
function modifier_hidden_from_map:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_PROVIDES_FOW_POSITION,
	}
end

function modifier_hidden_from_map:GetModifierProvidesFOWVision()
	return 1
end

function modifier_hidden_from_map:CheckState() return {
	[MODIFIER_STATE_STUNNED] 				= true,
	[MODIFIER_STATE_INVULNERABLE] 			= true,
	[MODIFIER_STATE_NO_UNIT_COLLISION] 		= true,
	-- OUT_OF_GAME тут нельзя: такой юнит пропадает и с миникарты, а он стоит
	-- ровно ради значка на ней. От всего остального он и так закрыт.
	[MODIFIER_STATE_MAGIC_IMMUNE] 			= true,
	[MODIFIER_STATE_ATTACK_IMMUNE] 			= true,
	[MODIFIER_STATE_UNSELECTABLE] 			= true,
	[MODIFIER_STATE_LOW_ATTACK_PRIORITY] 	= true,
	[MODIFIER_STATE_NO_HEALTH_BAR] 			= true,
	[MODIFIER_STATE_TRUESIGHT_IMMUNE] 		= true,
} end
