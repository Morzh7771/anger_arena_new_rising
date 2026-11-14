function GPM_Init()
	local timeToBaseGPM = 1
	local baseGoldPerTick = 3

	Timers:CreateTimer(function()
		local all_heroes = HeroList:GetAllHeroes()
			--print("START GAME GPM")
			--for i,x in pairs(all_heroes) do print(i,x) end
			for _, hero in pairs(all_heroes) do
				-- Tempest Double (и солдаты Wukong's Command из пула) золото не получают
				if hero:IsRealHero() and not hero:IsTempestDouble() then
					--print("HERO: ", hero, " NAME: ", hero:GetName(), " GOLD: ", baseGoldPerTick)
					local _ = (AATagGold or function(_, f) f() end)("gpm", function() hero:ModifyGold(baseGoldPerTick, false, 0) end)
				end
			end
		return timeToBaseGPM
	end)
end
