-- ВНИМАНИЕ: файл ниоткуда не подключается (ни require, ни KV на него не
-- ссылаются). Тут исправлен только синтаксис, чтобы он не падал, если его
-- когда-нибудь всё же подключат:
--   - ключ таблицы был записан как "item_black_king_bar" = 1 (нужны скобки);
--   - в цикле использовался keys.ability, хотя параметр называется event.
local not_refreshing_items = {
	["item_black_king_bar"] = 1,
}

function Refresh(event)
	local caster = event.caster

	-- refreshing abilities
	for i = 0, caster:GetAbilityCount() - 1 do
		local ability = caster:GetAbilityByIndex( i )
		if ability and ability ~= event.ability then
			ability:EndCooldown()
		end
	end

	-- refreshing items
end