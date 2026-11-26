-- Gun Joe: Calibrated Shot (ульт). Порт из Angel Arena Global.
-- Выстрел с увеличенной дальностью: настоящая атака с множителем урона + оглушение.
-- Автокаст: сам стреляет при начале атаки, когда готов.

gun_joe_calibrated_shot = class({})

LinkLuaModifier("modifier_gun_joe_calibrated_shot_autocast", "heroes/gun_joe/gun_joe_calibrated_shot", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_gun_joe_calibrated_shot_buff", "heroes/gun_joe/gun_joe_calibrated_shot", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_gun_joe_calibrated_shot_pierce", "heroes/gun_joe/gun_joe_calibrated_shot", LUA_MODIFIER_MOTION_NONE)

function gun_joe_calibrated_shot:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_sniper/sniper_assassinate.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_sniper.vsndevts", context)
end

function gun_joe_calibrated_shot:GetIntrinsicModifierName()
	return "modifier_gun_joe_calibrated_shot_autocast"
end

-- замах из AbilityValues (талант его сокращает)
function gun_joe_calibrated_shot:GetCastPoint()
	return self:GetSpecialValueFor("cast_point")
end

function gun_joe_calibrated_shot:GetCastRange(location, target)
	return self:GetCaster():Script_GetAttackRange() + self:GetSpecialValueFor("bonus_attack_range")
end

function gun_joe_calibrated_shot:OnSpellStart()
	local caster = self:GetCaster()
	caster:EmitSound("Ability.Assassinate")

	ProjectileManager:CreateTrackingProjectile({
		Target				= self:GetCursorTarget(),
		Source				= caster,
		Ability				= self,
		EffectName			= "particles/units/heroes/hero_sniper/sniper_assassinate.vpcf",
		bDodgeable			= true,
		bProvidesVision		= false,
		iMoveSpeed			= self:GetSpecialValueFor("projectile_speed"),
		iSourceAttachment	= DOTA_PROJECTILE_ATTACHMENT_ATTACK_1,
	})
end

function gun_joe_calibrated_shot:OnProjectileHit(target, location)
	if not target or target:IsNull() or not target:IsAlive() then return end

	local caster = self:GetCaster()
	if target:TriggerSpellAbsorb(self) then return end

	-- аганим: выстрел пробивает насквозь - бьёт и всех врагов на линии за целью
	local victims = { target }
	local length = self:GetSpecialValueFor("scepter_pierce_length")

	if length > 0 then
		local dir = target:GetAbsOrigin() - caster:GetAbsOrigin()
		dir.z = 0
		dir = dir:Normalized()
		local from = target:GetAbsOrigin()
		local line = FindUnitsInLine(caster:GetTeamNumber(), from, from + dir * length, nil, self:GetSpecialValueFor("scepter_pierce_width"),
			DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE)
		for _, u in pairs(line) do
			if u ~= target then table.insert(victims, u) end
		end
	end

	-- Выстрел не критует: урон считаем сами от среднего урона атаки (без крита),
	-- а PerformAttack делаем фейковым - только ради эффектов атаки (проки, орбы).
	local mult = self:GetSpecialValueFor("damage_from_attack") / 100
	for _, v in ipairs(victims) do
		if not v:IsNull() and v:IsAlive() then
			-- выстрел игнорирует часть брони цели
			local pierce = v:AddNewModifier(caster, self, "modifier_gun_joe_calibrated_shot_pierce", { duration = 0.1 })
			caster:PerformAttack(v, true, true, true, true, false, true, true)
			ApplyDamage({
				victim = v, attacker = caster, ability = self,
				damage = caster:GetAverageTrueAttackDamage(v) * mult,
				damage_type = DAMAGE_TYPE_PHYSICAL,
			})
			if pierce and not pierce:IsNull() then pierce:Destroy() end
			v:EmitSound("Hero_Sniper.AssassinateDamage")
			if v:IsAlive() and not v:IsMagicImmune() then
				v:AddNewModifier(caster, self, "modifier_stunned", { duration = self:GetSpecialValueFor("stun_duration") })
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Множитель урона на одну атаку выстрела

modifier_gun_joe_calibrated_shot_buff = class({})

function modifier_gun_joe_calibrated_shot_buff:IsHidden() return true end
function modifier_gun_joe_calibrated_shot_buff:IsPurgable() return false end

function modifier_gun_joe_calibrated_shot_buff:OnCreated()
	local ability = self:GetAbility()
	-- damage_from_attack = % урона атаки (250 = x2.5), сюда прибавка сверх 100
	self.bonus = ability and (ability:GetSpecialValueFor("damage_from_attack") - 100) or 0
end

function modifier_gun_joe_calibrated_shot_buff:DeclareFunctions()
	return { MODIFIER_PROPERTY_DAMAGEOUTGOING_PERCENTAGE }
end

function modifier_gun_joe_calibrated_shot_buff:GetModifierDamageOutgoing_Percentage()
	return self.bonus
end

--------------------------------------------------------------------------------
-- Автокаст: при начале атаки по врагу кастует выстрел, если готов.

modifier_gun_joe_calibrated_shot_autocast = class({})

function modifier_gun_joe_calibrated_shot_autocast:IsHidden() return true end
function modifier_gun_joe_calibrated_shot_autocast:IsPurgable() return false end
function modifier_gun_joe_calibrated_shot_autocast:RemoveOnDeath() return false end

function modifier_gun_joe_calibrated_shot_autocast:DeclareFunctions()
	return { MODIFIER_EVENT_ON_ATTACK_START }
end

function modifier_gun_joe_calibrated_shot_autocast:OnAttackStart(params)
	if not IsServer() then return end

	local parent = self:GetParent()
	local ability = self:GetAbility()
	local target = params.target

	if params.attacker ~= parent or not ability or not target or target:IsNull() then return end
	if not ability:GetAutoCastState() or not ability:IsFullyCastable() or parent:IsSilenced() then return end
	if target:GetTeamNumber() == parent:GetTeamNumber() then return end
	if ability:CastFilterResultTarget(target) ~= UF_SUCCESS then return end

	parent:CastAbilityOnTarget(target, ability, parent:GetPlayerOwnerID())
end

--------------------------------------------------------------------------------
-- На время выстрела: цель теряет armor_ignore_pct% брони

modifier_gun_joe_calibrated_shot_pierce = class({})

function modifier_gun_joe_calibrated_shot_pierce:IsHidden() return true end
function modifier_gun_joe_calibrated_shot_pierce:IsPurgable() return false end

function modifier_gun_joe_calibrated_shot_pierce:OnCreated()
	local ability = self:GetAbility()
	local armor = self:GetParent():GetPhysicalArmorValue(false)
	self.armor = (ability and armor > 0) and -armor * ability:GetSpecialValueFor("armor_ignore_pct") / 100 or 0
end

function modifier_gun_joe_calibrated_shot_pierce:DeclareFunctions()
	return { MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS }
end

function modifier_gun_joe_calibrated_shot_pierce:GetModifierPhysicalArmorBonus()
	return self.armor
end
