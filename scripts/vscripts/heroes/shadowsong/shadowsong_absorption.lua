shadowsong_absorption = class({})

-- Сгенерировано: ресурсы, на которые ссылается этот скрипт.
-- Движок зовёт этот метод при прекеше юнита со способностью, поэтому
-- партиклы приезжают вместе с героем (пик/репик), а не на старте карты.
function shadowsong_absorption:Precache(context)
	PrecacheResource("particle", "particles/econ/items/lifestealer/lifestealer_immortal_backbone/lifestealer_immortal_backbone_rage.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/lifestealer/lifestealer_immortal_backbone/lifestealer_immortal_backbone_rage_flek.vpcf", context)
	PrecacheResource("particle", "particles/generic_gameplay/generic_lifesteal.vpcf", context)
	PrecacheResource("particle", "particles/shadowsong/shadowsong_absorbtion/shadowsong_absorbtion.vpcf", context)
end


local ability = shadowsong_absorption

LinkLuaModifier( "modifier_shadowsong_absorption_aura", 		"heroes/shadowsong/modifiers/modifier_shadowsong_absorption_aura", 			LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_shadowsong_absorption_aura_effect", 	"heroes/shadowsong/modifiers/modifier_shadowsong_absorption_aura_effect", 	LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_shadowsong_absorption_talent", 		"heroes/shadowsong/modifiers/modifier_shadowsong_absorption_talent", 		LUA_MODIFIER_MOTION_NONE )

function ability:IsHiddenWhenStolen() return false end

function ability:OnSpellStart( kv )
	if not IsServer() then return end

	local caster 	= self:GetCaster()
	local duration 	= self:GetSpecialValueFor("duration")

	caster:AddNewModifier(caster, self, "modifier_shadowsong_absorption_aura", { duration = duration })

	caster:EmitSound("Hero_Antimage.ManaVoidCast")
end
