
item_solar_crest_1 = class({})
item_solar_crest_2 = class({})
item_solar_crest_3 = class({})

LinkLuaModifier("modifier_solar_crest_passive_1", "items/item_solar_crest.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_solar_crest_passive_2", "items/item_solar_crest.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_solar_crest_passive_3", "items/item_solar_crest.lua", LUA_MODIFIER_MOTION_NONE)

LinkLuaModifier("modifier_solar_crest_buff_1", "items/item_solar_crest.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_solar_crest_buff_2", "items/item_solar_crest.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_solar_crest_buff_3", "items/item_solar_crest.lua", LUA_MODIFIER_MOTION_NONE)

LinkLuaModifier("modifier_solar_crest_debuff_1", "items/item_solar_crest.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_solar_crest_debuff_2", "items/item_solar_crest.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_solar_crest_debuff_3", "items/item_solar_crest.lua", LUA_MODIFIER_MOTION_NONE)


LinkLuaModifier("modifier_item_sollar_shield", "items/item_solar_crest.lua", LUA_MODIFIER_MOTION_NONE)

function item_solar_crest_1:Precache(context)
    PrecacheResource("particle", "particles/item/solar_crest/star_emblem.vpcf", context)
    PrecacheResource("particle", "particles/items3_fx/star_emblem_friend_shield.vpcf", context)
    PrecacheResource("particle", "particles/items3_fx/star_emblem_friend.vpcf", context)
    PrecacheResource("particle", "particles/items2_fx/pavise_friend.vpcf", context)
end

function item_solar_crest_2:Precache(context)
    PrecacheResource("particle", "particles/item/solar_crest/star_emblem.vpcf", context)
    PrecacheResource("particle", "particles/items3_fx/star_emblem_friend_shield.vpcf", context)
    PrecacheResource("particle", "particles/items3_fx/star_emblem_friend.vpcf", context)
    PrecacheResource("particle", "particles/items2_fx/pavise_friend.vpcf", context)
end

function item_solar_crest_3:Precache(context)
    PrecacheResource("particle", "particles/item/solar_crest/star_emblem.vpcf", context)
    PrecacheResource("particle", "particles/items3_fx/star_emblem_friend_shield.vpcf", context)
    PrecacheResource("particle", "particles/items3_fx/star_emblem_friend.vpcf", context)
    PrecacheResource("particle", "particles/items2_fx/pavise_friend.vpcf", context)
end

function item_solar_crest_1:GetIntrinsicModifierName() return "modifier_solar_crest_passive_1" end
function item_solar_crest_1:OnSpellStart()
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()
	if caster:GetTeamNumber() == target:GetTeamNumber() then
		target:EmitSound("Item.StarEmblem.Friendly")
		target:AddNewModifier(caster, self, "modifier_solar_crest_buff_1", {duration = self:GetSpecialValueFor("duration")})
        target:AddNewModifier(self:GetCaster(), self, "modifier_item_sollar_shield", {duration = self:GetSpecialValueFor("duration"),bonus = target:GetMaxHealth()})
	else
		target:EmitSound("Item.StarEmblem.Enemy")
		target:AddNewModifier(caster, self, "modifier_solar_crest_debuff_1", {duration = self:GetSpecialValueFor("duration")})
	end
end

function item_solar_crest_2:GetIntrinsicModifierName() return "modifier_solar_crest_passive_2" end
function item_solar_crest_2:OnSpellStart()
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()
	if caster:GetTeamNumber() == target:GetTeamNumber() then
		target:EmitSound("Item.StarEmblem.Friendly")
		target:AddNewModifier(caster, self, "modifier_solar_crest_buff_2", {duration = self:GetSpecialValueFor("duration")})
        target:AddNewModifier(self:GetCaster(), self, "modifier_item_sollar_shield", {duration = self:GetSpecialValueFor("duration"),bonus = target:GetMaxHealth()})
	else
		target:EmitSound("Item.StarEmblem.Enemy")
		target:AddNewModifier(caster, self, "modifier_solar_crest_debuff_2", {duration = self:GetSpecialValueFor("duration")})
	end
end

function item_solar_crest_3:GetIntrinsicModifierName() return "modifier_solar_crest_passive_3" end
function item_solar_crest_3:OnSpellStart()
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()
	if caster:GetTeamNumber() == target:GetTeamNumber() then
		target:EmitSound("Item.StarEmblem.Friendly")
		target:AddNewModifier(caster, self, "modifier_solar_crest_buff_3", {duration = self:GetSpecialValueFor("duration")})
        target:AddNewModifier(self:GetCaster(), self, "modifier_item_sollar_shield", {duration = self:GetSpecialValueFor("duration")})
	else
		target:EmitSound("Item.StarEmblem.Enemy")
		target:AddNewModifier(caster, self, "modifier_solar_crest_debuff_3", {duration = self:GetSpecialValueFor("duration")})
	end
end

modifier_solar_crest_passive_1 = class({
    IsDebuff = function (self) return false end,
    IsHidden = function (self) return true end,
    IsPurgable = function (self) return false end,
    IsPurgeException = function (self) return false end,
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
        MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT,
        MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
        MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
    } end,
    GetModifierPhysicalArmorBonus = function (self) return self:GetAbility():GetSpecialValueFor("bonus_armor") end,
    GetModifierMoveSpeedBonus_Constant = function (self) return self:GetAbility():GetSpecialValueFor("movement_speed") end,
    GetModifierConstantManaRegen = function (self) return self:GetAbility():GetSpecialValueFor("bonus_mana_regen_pct") end,
    GetModifierBonusStats_Strength = function (self) return self:GetAbility():GetSpecialValueFor("all_stats") end,
    GetModifierBonusStats_Agility = function (self) return self:GetAbility():GetSpecialValueFor("all_stats") end,
    GetModifierBonusStats_Intellect = function (self) return self:GetAbility():GetSpecialValueFor("all_stats") end,
})
modifier_solar_crest_passive_2 = class({
    IsDebuff = function (self) return false end,
    IsHidden = function (self) return true end,
    IsPurgable = function (self) return false end,
    IsPurgeException = function (self) return false end,
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
        MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT,
        MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
        MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
    } end,
    GetModifierPhysicalArmorBonus = function (self) return self:GetAbility():GetSpecialValueFor("bonus_armor") end,
    GetModifierMoveSpeedBonus_Constant = function (self) return self:GetAbility():GetSpecialValueFor("movement_speed") end,
    GetModifierConstantManaRegen = function (self) return self:GetAbility():GetSpecialValueFor("bonus_mana_regen_pct") end,
    GetModifierBonusStats_Strength = function (self) return self:GetAbility():GetSpecialValueFor("all_stats") end,
    GetModifierBonusStats_Agility = function (self) return self:GetAbility():GetSpecialValueFor("all_stats") end,
    GetModifierBonusStats_Intellect = function (self) return self:GetAbility():GetSpecialValueFor("all_stats") end,
})
modifier_solar_crest_passive_3 = class({
    IsDebuff = function (self) return false end,
    IsHidden = function (self) return true end,
    IsPurgable = function (self) return false end,
    IsPurgeException = function (self) return false end,
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
        MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT,
        MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
        MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
    } end,
    GetModifierPhysicalArmorBonus = function (self) return self:GetAbility():GetSpecialValueFor("bonus_armor") end,
    GetModifierMoveSpeedBonus_Constant = function (self) return self:GetAbility():GetSpecialValueFor("movement_speed") end,
    GetModifierConstantManaRegen = function (self) return self:GetAbility():GetSpecialValueFor("bonus_mana_regen_pct") end,
    GetModifierBonusStats_Strength = function (self) return self:GetAbility():GetSpecialValueFor("all_stats") end,
    GetModifierBonusStats_Agility = function (self) return self:GetAbility():GetSpecialValueFor("all_stats") end,
    GetModifierBonusStats_Intellect = function (self) return self:GetAbility():GetSpecialValueFor("all_stats") end,
})


modifier_solar_crest_debuff_1 = class({
    IsDebuff = function (self) return true end,
    IsHidden = function (self) return false end,
    IsPurgable = function (self) return true end,
    IsPurgeException = function (self) return true end,
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS
    } end,
    GetModifierPhysicalArmorBonus = function (self) return 0 - self:GetAbility():GetSpecialValueFor("target_armor") end,
    GetModifierMoveSpeedBonus_Percentage = function (self) return 0 - self:GetAbility():GetSpecialValueFor("target_movement_speed") end,
    GetModifierAttackSpeedBonus_Constant =  function (self) return 0 - self:GetAbility():GetSpecialValueFor("target_attack_speed") end,
    GetTexture = function (self) return "item_solar_crest" end,
})
modifier_solar_crest_debuff_2 = class({
    IsDebuff = function (self) return true end,
    IsHidden = function (self) return false end,
    IsPurgable = function (self) return true end,
    IsPurgeException = function (self) return true end,
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS
    } end,
    GetModifierPhysicalArmorBonus = function (self) return 0 - self:GetAbility():GetSpecialValueFor("target_armor") end,
    GetModifierMoveSpeedBonus_Percentage = function (self) return 0 - self:GetAbility():GetSpecialValueFor("target_movement_speed") end,
    GetModifierAttackSpeedBonus_Constant =  function (self) return 0 - self:GetAbility():GetSpecialValueFor("target_attack_speed") end,
    GetTexture = function (self) return "../items/solar_crest2" end,
})
modifier_solar_crest_debuff_3 = class({
    IsDebuff = function (self) return true end,
    IsHidden = function (self) return false end,
    IsPurgable = function (self) return true end,
    IsPurgeException = function (self) return true end,
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS
    } end,
    GetModifierPhysicalArmorBonus = function (self) return 0 - self:GetAbility():GetSpecialValueFor("target_armor") end,
    GetModifierMoveSpeedBonus_Percentage = function (self) return 0 - self:GetAbility():GetSpecialValueFor("target_movement_speed") end,
    GetModifierAttackSpeedBonus_Constant =  function (self) return 0 - self:GetAbility():GetSpecialValueFor("target_attack_speed") end,
    GetTexture = function (self) return "../items/solar_crest3" end,
})

function modifier_solar_crest_debuff_1:OnCreated()
	if IsServer() then
		local pfx = ParticleManager:CreateParticle("particles/item/solar_crest/star_emblem.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
		--ParticleManager:SetParticleControl(pfx, 0, Vector(50000, 50000, -2000))
		ParticleManager:SetParticleControlEnt(pfx, 1, self:GetParent(), PATTACH_ABSORIGIN_FOLLOW, nil, self:GetParent():GetAbsOrigin(), true)
		self:AddParticle(pfx, false, false, 15, false, false)
	end
end
function modifier_solar_crest_debuff_2:OnCreated()
	if IsServer() then
		local pfx = ParticleManager:CreateParticle("particles/item/solar_crest/star_emblem.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
		--ParticleManager:SetParticleControl(pfx, 0, Vector(50000, 50000, -2000))
		ParticleManager:SetParticleControlEnt(pfx, 1, self:GetParent(), PATTACH_ABSORIGIN_FOLLOW, nil, self:GetParent():GetAbsOrigin(), true)
		self:AddParticle(pfx, false, false, 15, false, false)
	end
end
function modifier_solar_crest_debuff_3:OnCreated()
	if IsServer() then
		local pfx = ParticleManager:CreateParticle("particles/item/solar_crest/star_emblem.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
		--ParticleManager:SetParticleControl(pfx, 0, Vector(50000, 50000, -2000))
		ParticleManager:SetParticleControlEnt(pfx, 1, self:GetParent(), PATTACH_ABSORIGIN_FOLLOW, nil, self:GetParent():GetAbsOrigin(), true)
		self:AddParticle(pfx, false, false, 15, false, false)
	end
end


modifier_solar_crest_buff_1 = class({
    IsDebuff = function (self) return false end,
    IsHidden = function (self) return false end,
    IsPurgable = function (self) return true end,
    IsPurgeException = function (self) return true end,
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
    } end,
    GetEffectAttachType = function (self) return PATTACH_OVERHEAD_FOLLOW end,
    ShouldUseOverheadOffset = function (self) return true end,
    GetModifierPhysicalArmorBonus = function (self) return self:GetAbility():GetSpecialValueFor("target_armor") end,
    GetModifierMoveSpeedBonus_Percentage = function (self) return self:GetAbility():GetSpecialValueFor("target_movement_speed") end,
    GetModifierAttackSpeedBonus_Constant =  function (self) return self:GetAbility():GetSpecialValueFor("target_attack_speed") end,
    GetEffectName = function (self) return "particles/items3_fx/star_emblem_friend_shield.vpcf" end,
})
function modifier_solar_crest_buff_1:OnCreated()
	if IsServer() then
		local pfx = ParticleManager:CreateParticle("particles/items3_fx/star_emblem_friend.vpcf", PATTACH_CUSTOMORIGIN, self:GetParent())
		ParticleManager:SetParticleControl(pfx, 0, Vector(50000, 50000, -2000))
		ParticleManager:SetParticleControlEnt(pfx, 1, self:GetParent(), PATTACH_ABSORIGIN_FOLLOW, nil, self:GetParent():GetAbsOrigin(), true)
		ParticleManager:SetParticleControlEnt(pfx, 5, self:GetParent(), PATTACH_ABSORIGIN_FOLLOW, nil, self:GetParent():GetAbsOrigin(), true)
		self:AddParticle(pfx, false, false, 15, false, false)
	end
end

modifier_solar_crest_buff_2 = class({
    IsDebuff = function (self) return false end,
    IsHidden = function (self) return false end,
    IsPurgable = function (self) return true end,
    IsPurgeException = function (self) return true end,
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
    } end,
    GetEffectAttachType = function (self) return PATTACH_OVERHEAD_FOLLOW end,
    ShouldUseOverheadOffset = function (self) return true end,
    GetModifierPhysicalArmorBonus = function (self) return self:GetAbility():GetSpecialValueFor("target_armor") end,
    GetModifierMoveSpeedBonus_Percentage = function (self) return self:GetAbility():GetSpecialValueFor("target_movement_speed") end,
    GetModifierAttackSpeedBonus_Constant =  function (self) return self:GetAbility():GetSpecialValueFor("target_attack_speed") end,
    GetEffectName = function (self) return "particles/items3_fx/star_emblem_friend_shield.vpcf" end,
})
function modifier_solar_crest_buff_2:OnCreated()
	if IsServer() then
		local pfx = ParticleManager:CreateParticle("particles/items3_fx/star_emblem_friend.vpcf", PATTACH_CUSTOMORIGIN, self:GetParent())
		ParticleManager:SetParticleControl(pfx, 0, Vector(50000, 50000, -2000))
		ParticleManager:SetParticleControlEnt(pfx, 1, self:GetParent(), PATTACH_ABSORIGIN_FOLLOW, nil, self:GetParent():GetAbsOrigin(), true)
		ParticleManager:SetParticleControlEnt(pfx, 5, self:GetParent(), PATTACH_ABSORIGIN_FOLLOW, nil, self:GetParent():GetAbsOrigin(), true)
		self:AddParticle(pfx, false, false, 15, false, false)
	end
end

modifier_solar_crest_buff_3 = class({
    IsDebuff = function (self) return false end,
    IsHidden = function (self) return false end,
    IsPurgable = function (self) return true end,
    IsPurgeException = function (self) return true end,
    GetAttributes = function (self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
    } end,
    GetEffectAttachType = function (self) return PATTACH_OVERHEAD_FOLLOW end,
    ShouldUseOverheadOffset = function (self) return true end,
    GetModifierPhysicalArmorBonus = function (self) return self:GetAbility():GetSpecialValueFor("target_armor") end,
    GetModifierMoveSpeedBonus_Percentage = function (self) return self:GetAbility():GetSpecialValueFor("target_movement_speed") end,
    GetModifierAttackSpeedBonus_Constant =  function (self) return self:GetAbility():GetSpecialValueFor("target_attack_speed") end,
     GetEffectName = function (self) return "particles/items3_fx/star_emblem_friend_shield.vpcf" end,
})
function modifier_solar_crest_buff_3:OnCreated()
	if IsServer() then
		local pfx = ParticleManager:CreateParticle("particles/items3_fx/star_emblem_friend.vpcf", PATTACH_CUSTOMORIGIN, self:GetParent())
		ParticleManager:SetParticleControl(pfx, 0, Vector(50000, 50000, -2000))
		ParticleManager:SetParticleControlEnt(pfx, 1, self:GetParent(), PATTACH_ABSORIGIN_FOLLOW, nil, self:GetParent():GetAbsOrigin(), true)
		ParticleManager:SetParticleControlEnt(pfx, 5, self:GetParent(), PATTACH_ABSORIGIN_FOLLOW, nil, self:GetParent():GetAbsOrigin(), true)
		self:AddParticle(pfx, false, false, 15, false, false)
	end
end


modifier_item_sollar_shield = class({
    IsHidden = function (self) return true end,
    IsPurgable = function (self) return false end,
    IsDebuff = function (self) return false end,
    GetTexture = function (self) return "../items/" .. (self:GetAbility():GetAbilityTextureName() or "") end,
    OnTooltip = function (self) return self:GetStackCount() end,
    DeclareFunctions = function (self) return {
        MODIFIER_PROPERTY_INCOMING_DAMAGE_CONSTANT ,
        MODIFIER_PROPERTY_TOOLTIP,
        }end,
})

function modifier_item_sollar_shield:OnCreated(table)
    if not IsServer() then return end
    self.shield = self:GetAbility():GetSpecialValueFor("barrier_block")+self:GetParent():GetMaxHealth()*self:GetAbility():GetSpecialValueFor("health_pct")/100

    self:SetStackCount(self.shield)  

    self.particle = ParticleManager:CreateParticle("particles/items2_fx/pavise_friend.vpcf", PATTACH_OVERHEAD_FOLLOW, self:GetParent())
    ParticleManager:SetParticleControl(self.particle, 0, self:GetParent():GetAbsOrigin())
    ParticleManager:SetParticleControlEnt(self.particle, 1, self:GetParent(), PATTACH_POINT_FOLLOW, "attach_origin", self:GetParent():GetAbsOrigin(), true)
    ParticleManager:SetParticleControl(self.particle, 2, Vector(125, 0, 0))

    self:AddParticle(self.particle,false, false, -1, false, false)

end
function modifier_item_sollar_shield:OnRefresh(table)
    if not IsServer() then return end
    if self:GetStackCount() < self:GetAbility():GetSpecialValueFor("barrier_block")+self:GetParent():GetMaxHealth()*self:GetAbility():GetSpecialValueFor("health_pct")/100 then
        self.shield = self:GetAbility():GetSpecialValueFor("barrier_block")+self:GetParent():GetMaxHealth()*self:GetAbility():GetSpecialValueFor("health_pct")/100
        self:SetStackCount(self.shield)
    end
end

function modifier_item_sollar_shield:GetModifierIncomingDamageConstant(params)

    if IsClient() then 
    return self:GetStackCount()
    end

    if not IsServer() then return end

    if self:GetParent() == params.attacker then return end


    if self:GetStackCount() > params.damage then
        self:SetStackCount(self:GetStackCount() - params.damage)
        local i = params.damage
        return -i
    else
        
        local i = self:GetStackCount()
        self:SetStackCount(0)
        self:Destroy()
        return -i
    end

end