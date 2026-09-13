--[[
	Безумруд. Лежит на земле после зачищенного лагеря, подбирается сам
	(AutoPickup + ItemCastOnPickup) и сразу исчезает: заряды уходят в
	счётчик игрока, место в инвентаре не занимает.

	Счётчик, разряды и крафт держит
	scripts/vscripts/lib/neutral/madstone_system.lua.
]]

item_madstone_aa = class({})

function item_madstone_aa:OnSpellStart()
	if not IsServer() then return end

	local caster = self:GetCaster()
	local count  = self:GetCurrentCharges()

	if count == nil or count < 1 then
		count = 1
	end

	if MadstoneSystem then
		MadstoneSystem:AddMadstones(caster, count)
	end

	self:SetCurrentCharges(0)

	UTIL_Remove(self)
end
