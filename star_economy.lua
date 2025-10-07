MachoInjectResource('star_economy', [[

function getItemCount(itemName)
    local inventory = ESX.GetPlayerData().inventory
    for i = 1, #inventory do
        local item = inventory[i]
        if itemName == item.name then
            if item.count > 0 then
                return item.count
            else
                return 0
            end
        end
    end
    return 0
end

Citizen.CreateThread(function()
    while true do
        local ft = getItemCount("Pumpkin")
        if ft == 90 then
            SetEntityCoords(PlayerPedId(), -2188.2722, -408.5604, 13.1789)
            Wait(2000)
            TriggerServerEvent('star_economy:sv:sellall')
            Wait(2000)
            exports['star_shop']:BuyPumpkinCards()
        end
        Wait(1000) -- รอ 1 วินาทีแล้วตรวจใหม่
    end
end)


]])