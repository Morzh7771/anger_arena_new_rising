-- New-format (единый стиль):
-- - один файл
-- - все функции внутри class({ ... })
-- - LinkLuaModifier -> на этот файл
-- - Precache: ТОЛЬКО используемые particles/models
--   Здесь particles/models в коде НЕТ (нет GetEffectName/GetStatusEffectName/CreateParticle/ModelChange)
--   => Precache не нужен.

LinkLuaModifier("modifier_edible_gem_aura", "items/edible_gem/item_edible_gem", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_edible_gem", "items/edible_gem/item_edible_gem", LUA_MODIFIER_MOTION_NONE)

--------------------------------------------------------------------------------
-- Item
--------------------------------------------------------------------------------
item_edible_gem = class({
	OnSpellStart = function(self)
		local caster = self:GetCaster()

		caster:AddNewModifier(caster, nil, "modifier_edible_gem_aura", {
			radius = self:GetSpecialValueFor("radius") or 0
		})

		self:Destroy()
	end,
})

--------------------------------------------------------------------------------
-- Aura owner
--------------------------------------------------------------------------------
modifier_edible_gem_aura = class({
	IsAura = function(self) return true end,
	IsHidden = function(self) return false end,
	IsPurgable = function(self) return false end,
	RemoveOnDeath = function(self) return false end,
	AllowIllusionDuplicate = function(self) return true end,

	OnCreated = function(self, kv)
		self.radius = (kv and kv.radius) or 900
		if IsServer() then
			self:StartIntervalThink(0.1)
		end
	end,

	GetAuraRadius = function(self) return self.radius or 0 end,
	GetAuraSearchTeam = function(self) return DOTA_UNIT_TARGET_TEAM_ENEMY end,
	GetAuraSearchType = function(self) return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC + DOTA_UNIT_TARGET_OTHER end,
	GetAuraSearchFlags = function(self) return DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES end,
	GetModifierAura = function(self) return "modifier_edible_gem" end,

	GetTexture = function(self) return "item_gem" end,

	DeclareFunctions = function(self)
		return { MODIFIER_EVENT_ON_DEATH }
	end,

	OnDeath = function(self, keys)
		if not IsServer() then return end

		local dead = keys.unit
		if dead ~= self:GetParent() then return end
		if dead.IsReincarnating and dead:IsReincarnating() then return end

		self:Destroy()
	end,

	OnIntervalThink = function(self)
		if not IsServer() then return end

		local hero = self:GetParent()
		local radius = self.radius or 0

		-- Оригинальная логика: ищем "npc_dota_treant_eyes" и выдаём ему true sight
		local units = FindUnitsInRadius(
			hero:GetOpposingTeamNumber(),
			hero:GetAbsOrigin(),
			nil,
			radius,
			DOTA_UNIT_TARGET_TEAM_BOTH,
			DOTA_UNIT_TARGET_OTHER,
			DOTA_UNIT_TARGET_FLAG_NONE + DOTA_UNIT_TARGET_FLAG_INVULNERABLE,
			FIND_ANY_ORDER,
			false
		)

		for _, u in pairs(units) do
			if u and u:GetClassname() == "npc_dota_treant_eyes" then
				u:AddNewModifier(hero, self:GetAbility(), "modifier_truesight", { duration = 0.11 })
			end
		end
	end,
})

--------------------------------------------------------------------------------
-- Aura debuff (force visible unless techies mine)
--------------------------------------------------------------------------------
modifier_edible_gem = class({
	IsHidden = function(self) return false end,
	IsPurgable = function(self) return false end,
	IsDebuff = function(self) return IsClient() end,
	GetPriority = function(self) return MODIFIER_PRIORITY_HIGH end,
	DeclareFunctions = function(self)
		return {
			MODIFIER_PROPERTY_INVISIBILITY_LEVEL,
		}
	end,
	GetModifierInvisibilityLevel = function(self) return 0 end,
	CheckState = function(self)
		if self:GetParent():GetUnitName() == "npc_dota_techies_land_mine" then
			return {}
		end
		return { [MODIFIER_STATE_INVISIBLE] = false }
	end,
})