require('lib/base_lua_helpers')

PreloadCache = PreloadCache or class({})

function PreloadCache:_init()
	function load_base_kv(path)
		print("[PreloadCache] Load KV '" .. path .."'")

		local data = LoadKeyValues(path)

		data['Version'] = nil
		
		return data
	end

	function load_kv_data(path, custom_path)
		local data = load_base_kv(path)
		local new_data = load_base_kv(custom_path)

		merge_table(data, new_data)

		return data
	end

	if not self.hero_data then
		self.hero_data = load_kv_data('scripts/npc/npc_heroes_custom.txt','scripts/npc/npc_heroes_custom.txt')

		local for_delete = {}
		-- If we has a 'override_hero' in hero block, lets replace data in original hero and delete that overrider from 

		for _, hero_name in pairs(for_delete) do
			self.hero_data[hero_name] = nil
		end
	end

	self.ability_data = self.ability_data or load_kv_data('scripts/npc/npc_abilities.txt', 'scripts/npc/npc_abilities_custom.txt')
end

function PreloadCache:GetHeroData()
	return self.hero_data
end

function PreloadCache:GetAbilityData()
	return self.ability_data
end

PreloadCache:_init()