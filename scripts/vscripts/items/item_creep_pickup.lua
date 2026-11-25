-- Подборы с нейтральных крипов: вся логика в lib/creep_pickups.lua.
-- Сюда попадаем, только если предмет подобрали кликом (ItemCastOnPickup);
-- обычно его забирает кольцо подбора раньше.

local function OnPickup(self)
	if not IsServer() then return end
	local hero = self:GetCaster()
	if CreepPickups and self.pickup_data then
		CreepPickups:Apply(hero, self.pickup_data)
	end
	CreepPickups:ClearItem(self)
end

for _, k in ipairs({ "heal", "mana", "gold", "xp", "shard_haste", "shard_damage", "shard_regen" }) do
	local c = class({})
	c.OnSpellStart = OnPickup
	_G["item_creep_pickup_" .. k] = c
end
