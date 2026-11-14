-- Скрытая пассивка юнитов героев: вешает бафф суммонов от характеристик
-- хозяина (modifiers/modifier_summon_power.lua). Прописана в heroes/*/unit.txt.

summon_power_passive = class({})

function summon_power_passive:GetIntrinsicModifierName()
	return "modifier_summon_power"
end
