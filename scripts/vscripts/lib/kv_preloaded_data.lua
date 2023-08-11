require('lib/base_lua_helpers')

PreloadCache = PreloadCache or class({})

function PreloadCache:_init()
	function load_base_kv(path)
		print("[PreloadCache] Load KV '" .. path .."'")

		local data = LoadKeyValues(path)

		data['Version'] = nil
		
		return data
	end

	function load_kv_data(path)
		local data = load_base_kv(path)
		return data
	end

	if not self.hero_data then
		self.hero_data = LoadKeyValues('scripts/npc/npc_heroes_custom.txt')
	end

	self.ability_data = LoadKeyValues('scripts/npc/npc_abilities_custom.txt')
end

function PreloadCache:GetHeroData()
	return self.hero_data
end

function PreloadCache:GetAbilityData()
	return self.ability_data
end

PreloadCache:_init()