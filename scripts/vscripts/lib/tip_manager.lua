-- Типы игрокам в стиле Dota Plus.
--
-- Зажатый Alt показывает кнопку под каждым игроком на топбаре; клик проигрывает
-- партикл с шардами на герое получателя и показывает карточку всем.
-- Чисто косметика: ничего не тратится и не начисляется.
--
-- Контракт событий взят из реализации IONTC, чтобы клиентский код совпадал:
--   клиент -> сервер : player_tip   { target_playerID }
--   сервер -> всем   : player_tipped { source_playerID, target_playerID, amount }
--   сервер -> одному : tip_cooldown  { cooldown }

if TipManager == nil then
	TipManager = class({})
end

TipManager.COOLDOWN = 30.0
TipManager.PARTICLE = "particles/custom_tips/tip_player_shards.vpcf"
TipManager.SOUND = "General.Coins"
TipManager.AMOUNT = 322

-- playerID -> время игры, когда снова можно типать
TipManager.next_tip = TipManager.next_tip or {}

function TipManager:IsOnCooldown(playerID)
	local ready_at = self.next_tip[playerID]

	return ready_at ~= nil and GameRules:GetGameTime() < ready_at
end

-- Сообщает клиенту, гасить ли кнопки.
function TipManager:PushCooldown(playerID, on_cooldown)
	local player = PlayerResource:GetPlayer(playerID)

	if player == nil then
		return
	end

	CustomGameEventManager:Send_ServerToPlayer(player, "tip_cooldown", {
		cooldown = on_cooldown,
		duration = self.COOLDOWN,
	})
end

function TipManager:PlayTipEffect(playerID)
	local hero = PlayerResource:GetSelectedHeroEntity(playerID)

	if hero == nil or hero:IsNull() then
		return
	end

	EmitGlobalSound(self.SOUND)

	local fx = ParticleManager:CreateParticle(self.PARTICLE, PATTACH_ABSORIGIN_FOLLOW, hero)
	ParticleManager:SetParticleControl(fx, 0, hero:GetAbsOrigin() + Vector(0, 0, 120))
	ParticleManager:ReleaseParticleIndex(fx)
end

-- ВНИМАНИЕ про сигнатуру.
--
-- CustomGameEventManager зовёт слушателя как listener(eventSourceIndex, data),
-- а не как метод объекта. Если объявить через двоеточие, в self прилетит
-- eventSourceIndex - обычное число, и любое self:Метод() падает с
-- "attempt to index local 'self' (a number value)".
-- Поэтому объявляем через точку, первый аргумент игнорируем, а к своим полям
-- обращаемся по имени TipManager.
function TipManager.OnPlayerTip(_, data)
	local source = data.PlayerID
	local target = tonumber(data.target_playerID)

	if source == nil or target == nil then
		return
	end

	-- Кто отправитель, клиенту не доверяем: PlayerID проставляет движок,
	-- target_playerID - нет.
	if source == target then
		return
	end

	if not PlayerResource:IsValidPlayerID(target) then
		return
	end

	if TipManager:IsOnCooldown(source) then
		TipManager:PushCooldown(source, true)
		return
	end

	local hero = PlayerResource:GetSelectedHeroEntity(target)

	if hero == nil or hero:IsNull() then
		return
	end

	TipManager.next_tip[source] = GameRules:GetGameTime() + TipManager.COOLDOWN

	TipManager:PlayTipEffect(target)

	CustomGameEventManager:Send_ServerToAllClients("player_tipped", {
		source_playerID = source,
		target_playerID = target,
		amount = TipManager.AMOUNT,
	})

	TipManager:PushCooldown(source, true)

	Timers:CreateTimer(TipManager.COOLDOWN, function()
		if not TipManager:IsOnCooldown(source) then
			TipManager:PushCooldown(source, false)
		end
	end)
end

CustomGameEventManager:RegisterListener("player_tip", Dynamic_Wrap(TipManager, 'OnPlayerTip'))
