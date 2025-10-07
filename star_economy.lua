print("inject")
local function sellPumpkin()
    SetEntityCoords(PlayerPedId(), -2188.2722, -408.5604, 13.1789)
    Wait(2000)
    TriggerServerEvent('star_economy:sv:sellall')
    Wait(2000)
    exports['star_shop']:BuyPumpkinCards()
end


exports('sellPumpkin', sellPumpkin)