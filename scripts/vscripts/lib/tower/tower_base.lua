
-- таблица опыта мода: Constants в каждом файле своя локальная, глобальной нет
local Constants = require('consts')

tower_ability = class{}

function tower_ability:GetIntrinsicModifierName()
	return 'tower_controller'
end
LinkLuaModifier( "tower_controller", "lib/tower/tower_base", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "attack_slow", "lib/tower/tower_base", LUA_MODIFIER_MOTION_NONE )

-- Замедление атаки по вышке. Значения - в AbilityValues у tower_ability:
--   slow_attack_rate - интервал атаки в начале серии ударов
--   slow_ramp_time   - за сколько секунд непрерывных ударов интервал плавно
--                      возвращается к обычному интервалу героя
--   slow_grace       - сколько живёт замедление после удара; должно быть
--                      больше slow_attack_rate, иначе серия рвётся между ударами
-- Урон по вышке от этого не зависит - каждый удар снимает % здоровья.
local function TowerValue(ability, key, default)
	if ability and not ability:IsNull() then
		local v = ability:GetSpecialValueFor(key)
		if v and v > 0 then return v end
	end
	return default
end

attack_slow = class{
	DeclareFunctions = function(self)return {
		MODIFIER_PROPERTY_FIXED_ATTACK_RATE,
	}end,
}

function attack_slow:OnCreated()
	if not IsServer() then return end

	local ability = self:GetAbility()

	self.rate = TowerValue(ability, 'slow_attack_rate', 1.5)
	self.ramp = TowerValue(ability, 'slow_ramp_time', 3)
	self.start = GameRules:GetGameTime()
end

function attack_slow:GetModifierFixedAttackRate()
	if not self.start or self.inQuery then return end

	local t = (GameRules:GetGameTime() - self.start) / self.ramp

	if t >= 1 then return end

	-- обычный интервал героя без этого модификатора: на время запроса
	-- модификатор ничего не отдаёт
	self.inQuery = true
	local natural = self:GetParent():GetSecondsPerAttack(false)
	self.inQuery = false

	if not natural or natural <= 0 then return self.rate end

	return self.rate + (natural - self.rate) * t
end

tower_controller = class{
	IsDebuff = function (self) return false end,
	DeclareFunctions = function(self) return {
		MODIFIER_PROPERTY_MIN_HEALTH,
		MODIFIER_EVENT_ON_ATTACK,
		MODIFIER_EVENT_ON_ATTACKED,
		MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
		MODIFIER_EVENT_ON_ATTACK_LANDED ,
		MODIFIER_PROPERTY_HEALTH_REGEN_PERCENTAGE,
    } end,
	GetMinHealth = function (self) return 1 end,
}
function tower_controller:GetModifierIncomingDamage_Percentage()
	return -100
end

function tower_controller:OnCreated()
	self.damage = 0

	-- у вышек в KV нет уровня, а на нулевом уровне GetSpecialValueFor отдаёт 0
	-- и все значения из AbilityValues были бы нулями (как было у шрайнов)
	local ability = self:GetAbility()

	if IsServer() and ability and not ability:IsNull() and ability:GetLevel() < 1 then
		ability:SetLevel(1)
	end
end
function tower_controller:OnAttack(e)
	if e.target ~= self:GetParent() then return end 
	e.attacker:AddNewModifier(self:GetParent(),self:GetAbility(),'attack_slow',{duration = TowerValue(self:GetAbility(), 'slow_grace', 2)})
end
function tower_controller:OnAttackLanded(e)
	if e.attacker == self:GetParent() then 
		if BossSpawner:IsBoss(e.target) ~= nil then return end
		if not e.target:IsRealHero() then 
			self.damage = e.target:GetMaxHealth() * 10000
		else
			self.damage = e.target:GetMaxHealth() * 0.025
		end
		ApplyDamage{
			victim = e.target,
			attacker = self:GetParent(),
			ability = self:GetAbility(),
			damage = self.damage,
			damage_flags = DOTA_DAMAGE_FLAG_IGNORES_PHYSICAL_ARMOR+DOTA_DAMAGE_FLAG_IGNORES_MAGIC_ARMOR,
			damage_type = DAMAGE_TYPE_PHYSICAL,
		}
	end
end
function tower_controller:OnAttacked(e)
	if e.target == self:GetParent() then  
		if (e.attacker:GetOrigin() - e.target:GetOrigin()):Length2D() < e.target:Script_GetAttackRange() + e.attacker:GetHullRadius() + e.target:GetHullRadius() and e.attacker:IsRealHero() then
			if e.target:GetHealth() <= e.target:GetMaxHealth() * 0.025 + 10 then
				local captured = e.target
				local ability = self:GetAbility()
				local team = e.attacker:GetTeamNumber()
				local attackerID = e.attacker:GetPlayerOwnerID()

				captured:SetTeam(captured:GetOpposingTeamNumber())

				-- Захваченная вышка встаёт не с 1 хп, а с половины: иначе её
				-- сразу перехватывает первый подошедший враг. Ставим здоровье
				-- и в следующем кадре: смена команды сбрасывает его обратно.
				local captureHP = math.floor(math.max(1, captured:GetMaxHealth() * TowerValue(ability, 'capture_health_pct', 50) / 100))

				captured:SetHealth(captureHP)
				self.CanRegen = true

				Timers:CreateTimer(0, function()
					if captured and not captured:IsNull() and captured:IsAlive() and captured:GetHealth() < captureHP then
						captured:SetHealth(captureHP)
					end
				end)

				-- лужа под вышкой - отдельная способность башни
				-- (lib/tower/tower_capture_pool.lua, Ability3 у npc_dota_custom_tower)
				local ok, err = pcall(function()
					local pool = captured:FindAbilityByName('tower_capture_pool')

					if pool then
						pool:ActivatePool()
					else
						print('[AA] tower: у вышки нет способности tower_capture_pool')
					end
				end)

				if not ok then print('[AA] tower: лужа не создалась: ' .. tostring(err)) end

				-- Награда за захват. Каждый герой отдельно в pcall: если упадёт
				-- на одном, остальные всё равно получат своё.
				local towerGold = 300 + (GameRules:GetDOTATime(false, false) / 60) * 100

				TeamHelper:ApplyForHeroes(team, function(playerid, hero)
					local ok2, err2 = pcall(function()
						PlayerResource:ModifyGold(playerid, towerGold, false, DOTA_ModifyGold_RoshanKill)
						AngelArena:ShowGoldPopup(playerid, towerGold)

						-- HeroLevelUp при кастомной таблице опыта не работает - уровень
						-- даём опытом до следующего порога, как том уровня (tome.lua)
						local nextXP = Constants and Constants.XP_PER_LEVEL_TABLE[hero:GetLevel() + 1]

						if nextXP then
							local need = nextXP - hero:GetCurrentXP()

							if need > 0 then hero:AddExperience(need, 0, false, true) end
						end
					end)

					if not ok2 then print('[AA] tower: награда за захват упала: ' .. tostring(err2)) end
				end)

				if KillFeed and attackerID then
					KillFeed:Tower(attackerID, team, towerGold)
				end
			else
				e.target:SetHealth( (e.target:GetHealth() - e.target:GetMaxHealth() * 0.025 ))
				self.CanRegen = false
				self.timeLastDamage = GameRules:GetDOTATime( false, false )
				local timeLastDamage = GameRules:GetDOTATime( false, false )
				self.timer = Timers:CreateTimer( 10, function()
					if (self.timeLastDamage == timeLastDamage) then
						self.CanRegen = true
					end
				end )
			end
		end
	end
end

-- Урон по вышке от способностей мода (сейчас - Meteor Hammer). Обычный урон
-- вышка блокирует целиком, поэтому здоровье снимаем напрямую, как при ударе
-- героя вплотную. Ниже порога захвата не опускаем: забирает вышку только
-- герой ударом, иначе награду за захват получали бы издалека.
function tower_controller:TakeScriptDamage(amount)
	local tower = self:GetParent()
	local floor = tower:GetMaxHealth() * 0.025 + 11

	tower:SetHealth(math.max(floor, tower:GetHealth() - amount))

	self.CanRegen = false
	self.timeLastDamage = GameRules:GetDOTATime(false, false)

	local timeLastDamage = self.timeLastDamage

	Timers:CreateTimer(10, function()
		if self.timeLastDamage == timeLastDamage then
			self.CanRegen = true
		end
	end)
end

function tower_controller:GetModifierHealthRegenPercentage(tData)
	if self.CanRegen then 
		return 0.8
	end
end
