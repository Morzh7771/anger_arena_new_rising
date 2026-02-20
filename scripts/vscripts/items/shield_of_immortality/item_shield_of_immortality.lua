-- New-format (единый стиль):
-- - весь код в одном файле
-- - все функции внутри class({ ... })
-- - Precache: ТОЛЬКО реально используемые particles/models
-- - Timers ключи как в оригинале, но в OnDestroy у hex добавил безопасную уборку sheep-таймера на всякий

LinkLuaModifier("modifier_shield_of_immortality", "items/shield_of_immortality/item_shield_of_immortality", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_shield_of_immortality_hex", "items/shield_of_immortality/item_shield_of_immortality", LUA_MODIFIER_MOTION_NONE)

--------------------------------------------------------------------------------
-- Item
--------------------------------------------------------------------------------
item_shield_of_immortality = class({
	GetIntrinsicModifierName = function(self) return "modifier_shield_of_immortality" end,

	Precache = function(self, context)
		PrecacheResource("particle", "particles/units/heroes/hero_winter_wyvern/wyvern_cold_embrace_buff.vpcf", context)
	end,

	OnSpellStart = function(self)
		if not IsServer() then return end

		local caster = self:GetCaster()
		local dur = self:GetSpecialValueFor("barrier_duration")

		caster:AddNewModifier(caster, self, "modifier_shield_of_immortality_hex", { duration = dur })

		if caster:GetName() == "npc_dota_hero_axe" then
			EmitSoundOn("axe_axe_sheepstick_02", caster)
		else
			EmitSoundOn("General.MorphIn", caster)
		end

		Timers:CreateTimer("som_sheep_" .. tostring(caster:entindex()), {
			useGameTime = true,
			endTime = 0,
			callback = function()
				if IsValidEntity(caster) then
					EmitSoundOn("Hero_ShadowShaman.SheepHex.Target", caster)
					return 1.1
				end
				return nil
			end
		})

		Timers:CreateTimer({
			useGameTime = true,
			endTime = dur,
			callback = function()
				Timers:RemoveTimer("som_sheep_" .. tostring(caster:entindex()))
				if IsValidEntity(caster) then
					EmitSoundOn("General.MorphOut", caster)
				end
				return nil
			end
		})
	end
})

--------------------------------------------------------------------------------
-- Passive (barrier + stats)
--------------------------------------------------------------------------------
modifier_shield_of_immortality = class({
	IsBuff = function(self) return true end,
	IsHidden = function(self) return true end,
	IsPurgable = function(self) return false end,
	GetAttributes = function(self) return MODIFIER_ATTRIBUTE_MULTIPLE end,

	DeclareFunctions = function(self)
		return {
			MODIFIER_PROPERTY_HEALTH_BONUS,
			MODIFIER_PROPERTY_INCOMING_DAMAGE_CONSTANT,
			MODIFIER_PROPERTY_MANA_BONUS,
			MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
			MODIFIER_PROPERTY_PHYSICAL_CONSTANT_BLOCK,
		}
	end,

	GetModifierHealthBonus = function(self)
		return self:GetAbility():GetSpecialValueFor("bonus_hp")
	end,

	GetModifierManaBonus = function(self)
		return self:GetAbility():GetSpecialValueFor("bonus_mp")
	end,

	GetModifierConstantHealthRegen = function(self)
		return self:GetAbility():GetSpecialValueFor("bonus_hp_regen")
	end,

	GetModifierPhysical_ConstantBlock = function(self)
		-- оставил как в оригинале (да, RandomInt + math.random выглядит странно, но не трогаю логику)
		local proc = (RandomInt(1, 100) + math.random()) / 100
		if proc <= self:GetAbility():GetSpecialValueFor("block_chance") / 100 then
			if self:GetParent():IsRangedAttacker() then
				return self:GetAbility():GetSpecialValueFor("block_damage_ranged")
			else
				return self:GetAbility():GetSpecialValueFor("block_damage_melee")
			end
		end
	end,

	GetModifierIncomingDamageConstant = function(self, params)
		local damage = params.original_damage
		if damage < params.damage then
			damage = params.damage
		end

		-- пока в хексе: накапливаем барьер и "съедаем" весь входящий урон
		if self:GetParent():HasModifier("modifier_shield_of_immortality_hex") then
			local mult = self:GetAbility():GetSpecialValueFor("barrier_percent") / 100
			self:SetStackCount(self:GetStackCount() + mult * damage)

			if IsServer() then return damage * -1 end
			if IsClient() then return self:GetStackCount() end
		end

		-- вне хекса: барьер блокирует урон пока есть стаки
		local blocked = self:GetStackCount()

		self:SetStackCount(self:GetStackCount() - damage)
		if self:GetStackCount() < 0 then
			self:SetStackCount(0)
		end

		if IsServer() then return blocked * -1 end
		if IsClient() then return self:GetStackCount() end
	end,

	OnCreated = function(self)
		if not IsServer() then return end

		local parent = self:GetParent()
		local key = "som_decay" .. tostring(parent:entindex())

		Timers:CreateTimer(key, {
			useGameTime = true,
			endTime = 0,
			callback = function()
				if not IsValidEntity(parent) then return nil end
				if not self:GetAbility() then return nil end

				local decay_mult = self:GetAbility():GetSpecialValueFor("barrier_decay")
				if parent:HasModifier("modifier_shield_of_immortality_hex") then
					decay_mult = 0
				end

				self:SetStackCount(self:GetStackCount() - (self:GetStackCount() / 100 * decay_mult / 10))
				return 0.1
			end
		})
	end,

	OnDestroy = function(self)
		if not IsServer() then return end
		Timers:RemoveTimer("som_decay" .. tostring(self:GetParent():entindex()))
	end,
})

--------------------------------------------------------------------------------
-- Hex (turn into sheep, disable controls)
--------------------------------------------------------------------------------
modifier_shield_of_immortality_hex = class({
	IsBuff = function(self) return true end,
	IsPurgable = function(self) return false end,
	GetEffectName = function(self) return "particles/units/heroes/hero_winter_wyvern/wyvern_cold_embrace_buff.vpcf" end,
	GetTexture = function(self) return "../items/shield_of_immortality" end,

	DeclareFunctions = function(self)
		return { MODIFIER_PROPERTY_MODEL_CHANGE }
	end,

	CheckState = function(self)
		return {
			[MODIFIER_STATE_DISARMED] = true,
			[MODIFIER_STATE_SILENCED] = true,
			[MODIFIER_STATE_STUNNED] = true,
		}
	end,

	GetModifierModelChange = function(self)
		return "models/items/hex/sheep_hex/sheep_hex_gold.vmdl"
	end,

	OnDestroy = function(self)
		-- подстраховка: если хекс сняли раньше таймера (диспел/смерть), убираем повторяющийся "беее"
		if not IsServer() then return end
		local parent = self:GetParent()
		Timers:RemoveTimer("som_sheep_" .. tostring(parent:entindex()))
	end,
})