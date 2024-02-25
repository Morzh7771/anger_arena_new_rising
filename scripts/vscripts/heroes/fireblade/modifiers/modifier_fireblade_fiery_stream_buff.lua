modifier_fireblade_fiery_stream_buff = class({})


--------------------------------------------------------------------------------

function modifier_fireblade_fiery_stream_buff:IsHidden()
	return false
end

--------------------------------------------------------------------------------

function modifier_fireblade_fiery_stream_buff:IsDebuff()
	return false
end

--------------------------------------------------------------------------------

function modifier_fireblade_fiery_stream_buff:IsPurgable()
	return false
end

function modifier_fireblade_fiery_stream_buff:GetAttributes()
	return MODIFIER_ATTRIBUTE_MULTIPLE
end

--------------------------------------------------------------------------------

function modifier_fireblade_fiery_stream_buff:DestroyOnExpire()
	return true
end

--------------------------------------------------------------------------------

function modifier_fireblade_fiery_stream_buff:OnCreated( kv )
	if kv.dmg ~= nil then 
		self.damage = kv.dmg
	end
end
--------------------------------------------------------------------------------

function modifier_fireblade_fiery_stream_buff:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
	}
	return funcs
end

--------------------------------------------------------------------------------

function modifier_fireblade_fiery_stream_buff:GetModifierPreAttack_BonusDamage()
	return self:GetCaster():GetNetworkableEntityInfo("fireblade_fiery_stream")
end

--------------------------------------------------------------------------------
