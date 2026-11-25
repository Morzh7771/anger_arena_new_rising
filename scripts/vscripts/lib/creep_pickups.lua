if not IsServer() then return end

-- Подбираемые бонусы с нейтральных крипов.
-- С шансом DROP_CHANCE убитый крип роняет бонус (вид - по весам KINDS):
--   склянка здоровья / маны, мешочек золота, осколок руны (короткий бафф),
--   книга опыта (отстающим падает чаще).
-- Кому:
--  * убийца-герой в пределах GIVE_RANGE и вражеских героев рядом нет -> сразу ему;
--  * иначе бонус падает на землю вокруг крипа, забирает первый герой, подошедший
--    на PICKUP_RADIUS (кольцо на земле). Это предмет items/creep_pickups.txt:
--    наводится, вылетает по дуге. В инвентарь не попадает, срабатывает сразу.
-- Лежит LIFETIME секунд.
CreepPickups = CreepPickups or {}

local DROP_CHANCE   = 20
local GIVE_RANGE    = 1000
local SCATTER_MIN   = 100
local SCATTER_MAX   = 300
local PICKUP_RADIUS = 100
local LIFETIME      = 30
local THINK         = 0.1
local LAUNCH_TIME   = 0.6
local RING_PARTICLE = "particles/ui_mouseactions/range_display.vpcf"

local VIAL_PCT       = 20  -- % макс. здоровья/маны
local BIG_VIAL_PCT   = 40  -- со стакнутого лагеря
local GOLD_MULT      = 2   -- x награда крипа золотом
local XP_MULT        = 3   -- x награда крипа опытом
local SHARD_DURATION = 12
local UNDERDOG_XP_WEIGHT = 15 -- вес книги, если убийца ниже уровня лагеря

local KINDS = {
	{ kind = "heal",  weight = 35 },
	{ kind = "mana",  weight = 35 },
	{ kind = "gold",  weight = 15 },
	{ kind = "shard", weight = 10 },
	{ kind = "xp",    weight = 5  },
}

local VISUAL = {
	heal  = { model = "models/props_gameplay/salve.vmdl",     particle = "particles/items3_fx/fish_bones_active.vpcf",        sound = "DOTA_Item.FaerieSpark.Activate" },
	mana  = { model = "models/props_gameplay/clarity.vmdl",   particle = "particles/items_fx/arcane_boots_recipient.vpcf",    sound = "DOTA_Item.ArcaneBoots.Activate" },
	gold  = { model = "models/props_gameplay/gold_bag.vmdl",  particle = "particles/generic_gameplay/rune_bounty_owner.vpcf",  sound = "General.Coins" },
	xp    = { model = "models/props_gameplay/rune_goldxp.vmdl", particle = "particles/generic_hero_status/hero_levelup.vpcf", sound = "Item.TomeOfKnowledge" },
	shard_haste  = { model = "models/props_gameplay/rune_haste01.vmdl",        sound = "Rune.Haste",  modifier = "modifier_creep_shard_haste" },
	shard_damage = { model = "models/props_gameplay/rune_doubledamage01.vmdl", sound = "Rune.DD",     modifier = "modifier_creep_shard_damage" },
	shard_regen  = { model = "models/props_gameplay/rune_regeneration01.vmdl", sound = "Rune.Regen",  modifier = "modifier_creep_shard_regen" },
}
local SHARDS = { "shard_haste", "shard_damage", "shard_regen" }

CreepPickups.active = CreepPickups.active or {}

function CreepPickups:Precache(context)
	for _, v in pairs(VISUAL) do
		PrecacheResource("model", v.model, context)
		if v.particle then PrecacheResource("particle", v.particle, context) end
	end
	PrecacheResource("particle", RING_PARTICLE, context)
	PrecacheResource("particle", "particles/generic_gameplay/rune_haste_owner.vpcf", context)
	PrecacheResource("particle", "particles/generic_gameplay/rune_doubledamage_owner.vpcf", context)
	PrecacheResource("particle", "particles/generic_gameplay/rune_regen_owner.vpcf", context)
end

local function KillerHero(attacker)
	if not attacker or attacker:IsNull() or not attacker.GetPlayerOwnerID then return nil end
	local pid = attacker:GetPlayerOwnerID()
	if not pid or pid < 0 then return nil end
	local hero = PlayerResource:GetSelectedHeroEntity(pid)
	if hero and not hero:IsNull() and hero:IsAlive() then return hero end
	return nil
end

-- на землю бонус падает, только если рядом вражеский (для убийцы) герой;
-- союзники не мешают - бонус всё равно уходит убийце
local function EnemyHeroNear(pos, hero)
	local heroes = FindUnitsInRadius(hero:GetTeamNumber(), pos, nil, GIVE_RANGE,
		DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO,
		DOTA_UNIT_TARGET_FLAG_NO_INVIS + DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE,
		FIND_ANY_ORDER, false)
	for _, h in pairs(heroes) do
		if h:IsRealHero() and not h:IsClone() and h:IsAlive() then return true end
	end
	return false
end

-- убийца ниже уровня лагеря (тот же расчёт, по которому качаются крипы)
local function IsUnderdog(hero, creep)
	if not hero or not creep or not CreepLeveling or not CreepLeveling._calculateCampLevel then return false end
	local info = creep.spawner_info
	if not info then return false end
	return hero:GetLevel() < CreepLeveling:_calculateCampLevel(info.name)
end

local function RollKind(hero, creep)
	local total = 0
	local weights = {}
	for i, k in ipairs(KINDS) do
		local w = k.weight
		if k.kind == "xp" and IsUnderdog(hero, creep) then w = UNDERDOG_XP_WEIGHT end
		weights[i] = w
		total = total + w
	end
	local r = RandomInt(1, total)
	for i, k in ipairs(KINDS) do
		r = r - weights[i]
		if r <= 0 then return k.kind end
	end
	return "heal"
end

-- data: { kind, visual, pct, gold, xp }
function CreepPickups:Apply(hero, data)
	if not hero or hero:IsNull() or not hero:IsAlive() then return end
	local v = VISUAL[data.visual]
	local kind = data.kind

	if kind == "heal" then
		local amount = hero:GetMaxHealth() * data.pct / 100
		hero:Heal(amount, nil)
		SendOverheadEventMessage(nil, OVERHEAD_ALERT_HEAL, hero, amount, nil)
	elseif kind == "mana" then
		local amount = hero:GetMaxMana() * data.pct / 100
		hero:GiveMana(amount)
		SendOverheadEventMessage(nil, OVERHEAD_ALERT_MANA_ADD, hero, amount, nil)
	elseif kind == "gold" then
		local pid = hero:GetPlayerOwnerID()
		PlayerResource:ModifyGold(pid, data.gold, false, DOTA_ModifyGold_CreepKill)
		SendOverheadEventMessage(nil, OVERHEAD_ALERT_GOLD, hero, data.gold, nil)
	elseif kind == "xp" then
		hero:AddExperience(data.xp, DOTA_ModifyXP_CreepKill, false, false)
		SendOverheadEventMessage(nil, OVERHEAD_ALERT_XP, hero, data.xp, nil)
	elseif kind == "shard" then
		hero:AddNewModifier(hero, nil, v.modifier, { duration = SHARD_DURATION })
	end

	if v.particle then
		local fx = ParticleManager:CreateParticle(v.particle, PATTACH_ABSORIGIN_FOLLOW, hero)
		ParticleManager:ReleaseParticleIndex(fx)
	end
	EmitSoundOn(v.sound, hero)
end

local function CampStacked(creep)
	local info = creep.spawner_info
	if not info or not CreepSpawner or not CreepSpawner._GetActiveWaveCount then return false end
	-- крип к этому моменту уже снят с учёта лагеря: считаем живые волны без него
	return CreepSpawner:_GetActiveWaveCount(info.name) >= 2
end

function CreepPickups:OnCreepDeath(event)
	local creep = event and event.creep
	if not creep or creep:IsNull() then return end
	-- шанс и размер всегда одинаковые: стак лагеря их больше не поднимает (владелец, 2026-11-25)
	if RandomInt(1, 100) > DROP_CHANCE then return end

	local pos = creep:GetAbsOrigin()
	local hero = KillerHero(event.attacker)
	local kind = RollKind(hero, creep)

	local data = { kind = kind, visual = kind }
	if kind == "heal" or kind == "mana" then
		data.pct = VIAL_PCT
	elseif kind == "gold" then
		data.gold = math.max(1, math.floor(creep:GetMaximumGoldBounty() * GOLD_MULT))
	elseif kind == "xp" then
		data.xp = math.max(1, math.floor(creep:GetDeathXP() * XP_MULT))
	elseif kind == "shard" then
		data.visual = SHARDS[RandomInt(1, #SHARDS)]
	end

	if hero and (hero:GetAbsOrigin() - pos):Length2D() <= GIVE_RANGE and not EnemyHeroNear(pos, hero) then
		self:FlyTo("item_creep_pickup_" .. data.visual, pos, hero, function(h)
			self:Apply(h, data)
		end)
		return
	end

	self:Drop(pos, data)
end

-- Настоящий предмет (items/creep_pickups.txt): наводится, показывает имя,
-- вылетает из крипа по дуге. Вокруг - кольцо радиуса подбора.
function CreepPickups:Drop(center, data)
	local pos = GetGroundPosition(center + RandomVector(1) * RandomFloat(SCATTER_MIN, SCATTER_MAX), nil)

	local item = CreateItem("item_creep_pickup_" .. data.visual, nil, nil)
	if not item then return end
	item:SetPurchaseTime(0)
	item.pickup_data = data

	local drop = CreateItemOnPositionSync(center, item)
	if not drop then UTIL_Remove(item) return end
	if data.pct and data.pct >= BIG_VIAL_PCT then drop:SetModelScale(1.3) end
	CreepPickups:Toss(drop, center, pos, 250, LAUNCH_TIME)

	local fx = ParticleManager:CreateParticle(RING_PARTICLE, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(fx, 0, pos)
	ParticleManager:SetParticleControl(fx, 1, Vector(PICKUP_RADIUS, 0, 0))

	table.insert(self.active, {
		item = item, drop = drop, fx = fx, pos = pos, data = data,
		ready = GameRules:GetGameTime() + LAUNCH_TIME,
		expire = GameRules:GetGameTime() + LIFETIME,
	})
	self:_StartThink()
end

-- Лут, который сразу достаётся убийце, не исчезает молча: модель предмета
-- вылетает из крипа вверх и по дуге догоняет героя, бонус срабатывает в
-- момент касания. Предмет на это время не подбирается (FLY_* ниже).
-- Зовут и книги из lib/dropbox.lua. onArrive(hero) - что дать по прилёту.
local FLY_SPEED    = 1100  -- скорость полёта, ед/с
local FLY_HEIGHT   = 180   -- высота дуги
local FLY_DELAY    = 0.25  -- сначала подскок над крипом
local FLY_TIMEOUT  = 3     -- не догнал (блинк, телепорт) - выдаём всё равно
local FLY_TICK     = 0.03

-- Бросок предмета на землю по параболе (LaunchLoot в 7.42 дугу не рисует).
function CreepPickups:Toss(drop, from, to, height, duration)
	if not drop or drop:IsNull() then return end
	local a = GetGroundPosition(from, nil)
	local b = GetGroundPosition(to, nil)
	local start = GameRules:GetGameTime()
	drop:SetAbsOrigin(a)

	Timers:CreateTimer(FLY_TICK, function()
		if drop:IsNull() then return end
		local k = math.min(1, (GameRules:GetGameTime() - start) / duration)
		local p = a + (b - a) * k
		drop:SetAbsOrigin(p + Vector(0, 0, height * 4 * k * (1 - k)))
		if k >= 1 then return end
		return FLY_TICK
	end)
end

function CreepPickups:FlyTo(itemName, from, hero, onArrive)
	local item = CreateItem(itemName, nil, nil)
	local drop = item and CreateItemOnPositionSync(from, item)

	local function Finish()
		if drop and not drop:IsNull() then UTIL_Remove(drop) end
		if item and not item:IsNull() then UTIL_Remove(item) end
		if hero and not hero:IsNull() then onArrive(hero) end
	end

	if not drop then Finish() return end
	item:SetPurchaseTime(0)

	local ground = GetGroundPosition(from, nil)
	local start = GameRules:GetGameTime()
	local pos = Vector(ground.x, ground.y, ground.z)

	Timers:CreateTimer(FLY_TICK, function()
		if drop:IsNull() or not hero or hero:IsNull() then Finish() return end

		local t = GameRules:GetGameTime() - start

		-- подскок
		if t < FLY_DELAY then
			local k = t / FLY_DELAY
			drop:SetAbsOrigin(pos + Vector(0, 0, FLY_HEIGHT * math.sin(k * math.pi / 2)))
			return FLY_TICK
		end

		local target = hero:GetAbsOrigin() + Vector(0, 0, 100)
		local cur = Vector(pos.x, pos.y, pos.z)
		local diff = target - cur
		local dist = diff:Length2D()

		if dist <= 60 or t > FLY_DELAY + FLY_TIMEOUT then Finish() return end

		local step = math.min(dist, FLY_SPEED * FLY_TICK)
		local dir = Vector(diff.x, diff.y, 0):Normalized()
		pos = Vector(cur.x + dir.x * step, cur.y + dir.y * step, cur.z + (target.z - cur.z) * (step / dist))

		-- дуга опускается по мере приближения
		local lift = FLY_HEIGHT * math.min(1, dist / 400)
		drop:SetAbsOrigin(pos + Vector(0, 0, lift))
		return FLY_TICK
	end)
end

-- предмет подобрали кликом (items/item_creep_pickup.lua): убрать с учёта
function CreepPickups:ClearItem(item)
	for i = #self.active, 1, -1 do
		if self.active[i].item == item then
			self:_Remove(self.active[i])
			table.remove(self.active, i)
			return
		end
	end
	if item and not item:IsNull() then UTIL_Remove(item) end
end

function CreepPickups:_Remove(p)
	if p.fx then
		ParticleManager:DestroyParticle(p.fx, false)
		ParticleManager:ReleaseParticleIndex(p.fx)
		p.fx = nil
	end
	if p.drop and not p.drop:IsNull() then UTIL_Remove(p.drop) end
	if p.item and not p.item:IsNull() then
		local owner = p.item:GetOwnerEntity()
		if owner and owner.RemoveItem then owner:RemoveItem(p.item) else UTIL_Remove(p.item) end
	end
end

function CreepPickups:_StartThink()
	if self._thinking then return end
	self._thinking = true

	Timers:CreateTimer("CreepPickupsThink", {
		useGameTime = true,
		endTime = THINK,
		callback = function()
			local now = GameRules:GetGameTime()
			for i = #self.active, 1, -1 do
				local p = self.active[i]
				local taken = now >= p.expire
					or not p.item or p.item:IsNull() or not p.drop or p.drop:IsNull()

				if not taken and now >= p.ready then
					local heroes = FindUnitsInRadius(DOTA_TEAM_NEUTRALS, p.pos, nil, PICKUP_RADIUS,
						DOTA_UNIT_TARGET_TEAM_BOTH, DOTA_UNIT_TARGET_HERO,
						DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES, FIND_CLOSEST, false)
					for _, h in pairs(heroes) do
						if h:IsRealHero() and not h:IsClone() and h:IsAlive() then
							self:Apply(h, p.data)
							taken = true
							break
						end
					end
				end

				if taken then
					self:_Remove(p)
					table.remove(self.active, i)
				end
			end

			if #self.active == 0 then
				self._thinking = false
				return nil
			end
			return THINK
		end,
	})
end
