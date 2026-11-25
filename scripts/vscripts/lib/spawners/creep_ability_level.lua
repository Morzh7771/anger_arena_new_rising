if not IsServer() then return end

-- Прокачка способностей нейтральных крипов по уровню (тиру) крипа.
-- Тир ставит CreepLeveling:OnSpawnCallback (creep._aa_creep_tier из N тиров
-- creep_stats.kv) - он зарегистрирован раньше, поэтому к этому моменту уже есть.
-- Уровень способности = ceil(тир / N * MaxLevel): первый тир - 1-й уровень,
-- последний - максимальный. Способности с MaxLevel 1 не трогаем.
CreepAbilityLevel = CreepAbilityLevel or {}

function CreepAbilityLevel:ApplyOnSpawn(creep)
	if not creep or creep:IsNull() then return end

	local tier = creep._aa_creep_tier
	local total = creep._aa_creep_tier_count
	if not tier or not total or total <= 0 then return end

	-- основной путь: ability_level из тира (1..7); без него - доля тира
	local frac = math.max(0, math.min(1, tier / total))
	if creep._aa_creep_ability_level then
		frac = math.max(0, math.min(1, creep._aa_creep_ability_level / 7))
	end

	for i = 0, creep:GetAbilityCount() - 1 do
		local ability = creep:GetAbilityByIndex(i)
		if ability and not ability:IsNull() then
			local maxLevel = ability:GetMaxLevel()
			if maxLevel and maxLevel > 1 then
				local level = math.max(1, math.min(maxLevel, math.ceil(frac * maxLevel)))
				if level ~= ability:GetLevel() then
					ability:SetLevel(level)
				end
			end
		end
	end
end
