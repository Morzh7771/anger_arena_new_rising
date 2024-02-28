divine_intervention = divine_intervention or {}
function divine_intervention:Spawn()
    if IsServer() then
        self:SetLevel(1)
    end
end