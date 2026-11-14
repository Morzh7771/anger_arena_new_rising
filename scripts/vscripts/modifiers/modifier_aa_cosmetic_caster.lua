-- Состояние невидимого юнита-кастера косметических умений (lib/cosmetics/caster.lua).
-- Как modifier_dummy_caster в aaf: неуязвим, не выбирается мышью, не таргетится,
-- без коллизии, невидим, вне игры. Ходит за героем через FollowEntity.

modifier_aa_cosmetic_caster = class({})

function modifier_aa_cosmetic_caster:IsHidden() return true end
function modifier_aa_cosmetic_caster:IsPurgable() return false end
function modifier_aa_cosmetic_caster:IsPermanent() return true end
function modifier_aa_cosmetic_caster:RemoveOnDeath() return false end
function modifier_aa_cosmetic_caster:GetPriority() return MODIFIER_PRIORITY_SUPER_ULTRA end

function modifier_aa_cosmetic_caster:CheckState()
	return {
		[MODIFIER_STATE_INVULNERABLE] = true,
		[MODIFIER_STATE_UNSELECTABLE] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		[MODIFIER_STATE_NO_HEALTH_BAR] = true,
		[MODIFIER_STATE_UNTARGETABLE] = true,
		[MODIFIER_STATE_MAGIC_IMMUNE] = true,
		[MODIFIER_STATE_CANNOT_BE_MOTION_CONTROLLED] = true,
		[MODIFIER_STATE_FLYING_FOR_PATHING_PURPOSES_ONLY] = true,
		[MODIFIER_STATE_DISARMED] = true,
		[MODIFIER_STATE_OUT_OF_GAME] = true,
		[MODIFIER_STATE_NOT_ON_MINIMAP] = true,
		[MODIFIER_STATE_INVISIBLE] = true,
	}
end
