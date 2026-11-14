-- Усталость после убийства босса: -30% урона по боссам за каждое убийство.
-- Вешается на всех героев команды, убившей босса (BossClass:OnDeath).
-- Каждое убийство - свой стак со своим таймером (spawn_interval убитого
-- босса): 3 убийства = -90%, стаки спадают по одному, когда истекает их время.
-- Подконтрольные юниты (самоны, иллюзии) режутся через хозяина: проверка
-- в modifier_boss_power смотрит модификатор и на атакующем, и на его герое.

modifier_boss_slayer_fatigue = class({})

BOSS_SLAYER_FATIGUE_PCT = 30

function modifier_boss_slayer_fatigue:IsHidden() return false end
function modifier_boss_slayer_fatigue:IsDebuff() return true end
function modifier_boss_slayer_fatigue:IsPurgable() return false end
function modifier_boss_slayer_fatigue:RemoveOnDeath() return false end
function modifier_boss_slayer_fatigue:DestroyOnExpire() return true end
function modifier_boss_slayer_fatigue:GetTexture() return "roshan_spell_block" end

-- Итоговое снижение урона, % (не больше 100).
function modifier_boss_slayer_fatigue:GetReductionPct()
	return math.min(100, self:GetStackCount() * BOSS_SLAYER_FATIGUE_PCT)
end

function modifier_boss_slayer_fatigue:OnCreated(kv)
	if not IsServer() then return end
	self.expires = {}
	self:AddStack(kv.duration)
	self:StartIntervalThink(0.5)
end

-- Повторный AddNewModifier - новое убийство: ещё один стак со своим временем.
function modifier_boss_slayer_fatigue:OnRefresh(kv)
	if not IsServer() then return end
	self:AddStack(kv.duration)
end

function modifier_boss_slayer_fatigue:AddStack(duration)
	duration = tonumber(duration) or 0
	if duration > 0 then
		table.insert(self.expires, GameRules:GetGameTime() + duration)
	end
	self:Sync()
end

function modifier_boss_slayer_fatigue:OnIntervalThink()
	local now = GameRules:GetGameTime()
	for i = #self.expires, 1, -1 do
		if self.expires[i] <= now then table.remove(self.expires, i) end
	end
	if #self.expires == 0 then
		self:Destroy()
		return
	end
	self:Sync()
end

-- Число стаков и полоска длительности - до самого позднего стака.
function modifier_boss_slayer_fatigue:Sync()
	if #self.expires == 0 then return end
	local last = 0
	for _, t in ipairs(self.expires) do last = math.max(last, t) end
	if self:GetStackCount() ~= #self.expires then self:SetStackCount(#self.expires) end
	local left = last - GameRules:GetGameTime()
	if math.abs(self:GetRemainingTime() - left) > 0.1 then self:SetDuration(left, true) end
end

function modifier_boss_slayer_fatigue:DeclareFunctions()
	return { MODIFIER_PROPERTY_TOOLTIP }
end

-- в подсказке и пинге без потолка (4 стака = 120%), урон режется не больше чем до нуля
function modifier_boss_slayer_fatigue:OnTooltip() return self:GetStackCount() * BOSS_SLAYER_FATIGUE_PCT end

