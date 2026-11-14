if not IsServer() then return end

--[[
	Стики заряжаются и от собственных кастов владельца.

	Ванильные Magic Stick / Magic Wand / Holy Locket получают заряд, только когда
	рядом колдует враг. Здесь добавляем заряд, когда способность кастует сам
	владелец стика. Правило то же, что у врагов в доте: способность (не предмет),
	с ценой маны больше нуля, не переключаемая.
]]

StickSelfCharge = StickSelfCharge or {}

-- имя предмета -> запасной максимум зарядов, если в KV нет max_charges
local STICKS = {
	item_magic_stick = 10,
	item_magic_wand = 20,
	item_holy_locket = 20,
	item_holy_locket_2 = 20,
	item_holy_locket_3 = 20,
}

local function CountsAsCast(ability)
	if not ability or ability:IsNull() then return false end
	if ability:IsItem() then return false end
	if ability:IsToggle() then return false end

	local level = ability:GetLevel()

	if level <= 0 then return false end

	return ability:GetManaCost(level - 1) > 0
end

function StickSelfCharge:AddCharge(unit)
	-- стик работает только из основных шести слотов
	for slot = 0, 5 do
		local item = unit:GetItemInSlot(slot)

		if item and not item:IsNull() and STICKS[item:GetAbilityName()] then
			local max = item:GetSpecialValueFor("max_charges")

			if not max or max <= 0 then max = STICKS[item:GetAbilityName()] end

			local charges = item:GetCurrentCharges()

			if charges < max then
				item:SetCurrentCharges(charges + 1)
			end

			-- как в доте: заряжается только один стик
			return
		end
	end
end

function StickSelfCharge:OnAbilityUsed(event)
	local caster = event.caster_entindex and EntIndexToHScript(event.caster_entindex)

	if not caster or caster:IsNull() or not caster.GetItemInSlot then return end
	if not caster:HasInventory() then return end

	local ability = caster:FindAbilityByName(event.abilityname or "")

	if not CountsAsCast(ability) then return end

	self:AddCharge(caster)
end

if not StickSelfCharge.listening then
	StickSelfCharge.listening = true

	ListenToGameEvent("dota_player_used_ability", function(event)
		StickSelfCharge:OnAbilityUsed(event)
	end, nil)
end
