print("inject 1.2")
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


local function startPumpkin()
	TriggerServerEvent("donut::party::job.start", {})
end

exports('startPumpkin', startPumpkin)


local propcheck = false
Config.CreatePartyDelay = 0
Config.PickupDelay = 0
RegisterNetEvent("donut::party::job.start")
AddEventHandler("donut::party::job.start", function()
    Wait(300)
    local coords = vector3(-585.7443, 5710.6162, 36.6571)
    local propHash = GetHashKey("zinnerhalloweenpumpkineventjob")
    local radius = 1.0

    local obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, radius, propHash, false, false, false)
    if DoesEntityExist(obj) then
        propcheck = true
    else
        propcheck = false
    end

    print("propcheck = ", propcheck)

    -- เลือก JobLine set ตาม propcheck
    local lineSet = propcheck and Config.JobLine[1] or Config.JobLine[2]
    local number = propcheck and 1 or 2
    for i, pos in ipairs(lineSet) do
        -- วาปผู้เล่นไปตำแหน่ง pos
        local playerPed = PlayerPedId()
        SetEntityCoords(playerPed, pos.x, pos.y, pos.z, false, false, false, true)
        print("วาปไปจุด #" .. i .. ": ", pos)
        Wait(500)
        if lineSet == Config.JobLine[1] then
            TriggerServerEvent("donut::party::job.pickup", 1, i)
        end
		if lineSet == Config.JobLine[2] then
            TriggerServerEvent("donut::party::job.pickup", 2, i)
        end
        Wait(2000)
		local countpump = getItemCount("Pumpkin")
        if i == 30 then
            ClearData();
            countpump = getItemCount("Pumpkin")
            if countpump < 90 then
                local target = vector3(-277.2416, 6044.6504, 30.9002)
                local radius = 50.0

                local ped = PlayerPedId()
                SetEntityCoords(ped, target)

                -- รอจนกว่าจะอยู่ในรัศมี
                while #(GetEntityCoords(ped) - target) > radius do
                    Wait(500)
                end
                print("อยู่ในรัศมีแล้ว ออกจากลูป")
                TriggerServerEvent("donut::party::job.start", {})
            end

            if countpump == 90 then
                 exports['star_economy']:sellPumpkin()
            end

            if countpump > 90 then
                 exports['star_economy']:sellPumpkin()

            end
        end

        Wait(1500)
    end
end)