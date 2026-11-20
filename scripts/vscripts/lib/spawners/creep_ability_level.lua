if not IsServer() then return end

-- Прокачка способностей нейтральных крипов по времени игры.
-- На спавне: уровень = min(MaxLevel, 1 + floor(минуты / MINUTES_PER_LEVEL)).
-- Способности с MaxLevel 1 (ванильные пассивки, наши кастомные активки) не трогаем.
CreepAbilityLevel = CreepAbilityLevel or {}

local MINUTES_PER_LEVEL = 5

function CreepAbilityLevel:ApplyOnSpawn(creep)
	if not creep or creep:IsNull() then return end

	local minutes = GameRules:GetDOTATime(false, false) / 60
	local timeLevel = 1 + math.floor(minutes / MINUTES_PER_LEVEL)

	for i = 0, creep:GetAbilityCount() - 1 do
		local ability = creep:GetAbilityByIndex(i)
		if ability and not ability:IsNull() then
			local maxLevel = ability:GetMaxLevel()
			if maxLevel and maxLevel > 1 then
				local level = math.min(maxLevel, timeLevel)
				if level > ability:GetLevel() then
					ability:SetLevel(level)
				end
			end
		end
	end
end
