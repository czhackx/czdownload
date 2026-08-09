local Client = {}
Client.__index = Client

local animForHoldingTablet = {
    'amb@code_human_in_bus_passenger_idles@female@tablet@idle_a',
    'idle_a'
}
local tabletPropName = 'prop_cs_tablet'
local tabletProp = nil


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


function Client.new()
    local self = setmetatable({}, Client)
    self.nuiReady = false
    self.zoneId = nil
    self.selectDimension = nil
    self._cacheItems = {}
    self._cacheDimension = {}
    self.debug = false
    self.auto = false
    self.worker_ped = nil
    self.equipments = nil
    self.tb_object = nil
    self.isWorking = false
    self.GoToEntity = false
    self.propModel = nil
    self.lastSpawnTry = 0
    return self
end

local client = Client.new()

local WEAPON_UNARMED = GetHashKey('WEAPON_UNARMED')

local function forceUnarmed()
    local ped = cache.ped or PlayerPedId()
    if GetSelectedPedWeapon(ped) ~= WEAPON_UNARMED then
        SetCurrentPedWeapon(ped, WEAPON_UNARMED, true)
    end
end

lib.onCache('weapon', function(weapon)
    if client.zoneId and weapon and weapon ~= WEAPON_UNARMED then
        forceUnarmed()
    end
end)

RegisterCommand('farm.debug', function() client.debug = not client.debug end, false)

local function addPropToPlayer(propName, bone, off1, off2, off3, rot1, rot2, rot3)
  local ped = cache.ped
  local x, y, z = table.unpack(GetEntityCoords(ped))

  lib.requestModel(propName)

  local prop = CreateObject(GetHashKey(propName), x, y, z + 0.2, false, false, false)
  AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, bone), off1, off2, off3, rot1, rot2, rot3, true, true, false, true, 1, true)
  SetModelAsNoLongerNeeded(propName)

  tabletProp = prop
end

local clearTabletIfExists = function()
    if tabletProp then
        DeleteObject(tabletProp)
        tabletProp = nil
    end

    ClearPedTasks(cache.ped)
end

local createTabletIfNotExistsAndPlayAnim = function()
     if tabletProp == nil then
        addPropToPlayer(tabletPropName, 28422, -0.05, 0.0, 0.0, 0.0, 0.0, 0.0)
    end

    lib.requestAnimDict(animForHoldingTablet[1])
    TaskPlayAnim(cache.ped, animForHoldingTablet[1], animForHoldingTablet[2], 2.0, 2.0, -1, 49, 0, false, false, false)
end

local debug = function(...)
    if client.debug then
        print(string.format('^3[DEBUG]^7 %s', table.concat({ ... }, " ")))
    end
end

local sendNui = function(data)
    debug("Sending NUI Message:", data.type)
    SendNUIMessage(data)
end

local fetchItem = function(itemName)
    local item_m = client._cacheItems[itemName]
    if not item_m then
        debug('GetPlayerItem on ESX')
        item_m = ESX.GetPlayerItem(itemName)
        client._cacheItems[itemName] = item_m
    else
        debug('GetPlayerItem on Cache')
    end
    return item_m or nil
end

local onSpawnProps = function()
    local setting = Config.Zone[client.zoneId]
    if not setting or not client.selectDimension then return false end
    local dim = setting.dimension[client.selectDimension]
    if not dim or not dim.props or not dim.props.model then return false end
    local model = dim.props.model

    if not pcall(lib.requestModel, model, 10000) then
        print(('^1[r5x_alljob] model timeout: %s^7'):format(tostring(model)))
        pcall(function() exports.r5x_notify:SendNotify({ type = 'error', text = 'โหลด prop ไม่ได้ กำลังลองใหม่...' }) end)
        return false
    end

    local radius = math.max(1, (setting.radius - 10) - 1)
    local posX = setting.coords.x
    local posY = setting.coords.y
    local baseZ = setting.coords.z

    local obj = CreateObject(model, posX, posY, baseZ + 3.0, false, false, false)
    RequestCollisionAtCoord(posX, posY, baseZ)
    local tries = 0
    while not HasCollisionLoadedAroundEntity(obj) and tries < 40 do
        RequestCollisionAtCoord(posX, posY, baseZ)
        Wait(20)
        tries = tries + 1
    end

    if not PlaceObjectOnGroundProperly(obj) then
        local foundGround, groundZ = GetGroundZFor_3dCoord(posX, posY, baseZ + 3.0, false)
        if foundGround then
            SetEntityCoordsNoOffset(obj, posX, posY, groundZ, false, false, false)
        end
    end

    SetEntityCollision(obj, false, false)
    FreezeEntityPosition(obj, true)
    if not client.tb_object then client.tb_object = {} end
    client.tb_object[#client.tb_object+1] = {
        object = obj,
        coords = GetEntityCoords(obj)
    }
    client.propModel = model
    return true
end

local clearObjects = function()
    if client.tb_object then
        for k, v in next, client.tb_object do
            if v and v.object and DoesEntityExist(v.object) then DeleteObject(v.object) end
        end
        client.tb_object = nil
    end
    if client.propModel then
        SetModelAsNoLongerNeeded(client.propModel)
        client.propModel = nil
    end
end

local function onEnter(self)
    client.zoneId = self.id
    debug("Zone ID Entered:", client.zoneId)

    forceUnarmed()

    local conf = Config.Zone[client.zoneId]
    if conf and conf.dimension then
        local dims = {}
        for k in pairs(conf.dimension) do dims[#dims+1] = k end
        table.sort(dims)
        if #dims > 0 then
            local picked = dims[1]
            if not conf.noWorld then
                pcall(function() exports.r5x_systemzone:SetWorld(1) end)
            end
            TriggerEvent('r5x_alljob:setTypeFarm', picked)
        end
    end
end

local clearWorker = function()
    if client.worker_ped and DoesEntityExist(client.worker_ped) then
        DeletePed(client.worker_ped)
        client.worker_ped = nil
    end
    client.GoToEntity = false
    client.isWorking = false
end

local spawnWorker = function(model)
    clearWorker()
    local ped = PlayerPedId()
    if not model or model == '' or type(model) ~= "number" then return end

    if not pcall(lib.requestModel, model) then return end

    local playerCoords = GetEntityCoords(ped)
    client.worker_ped = CreatePed(4, model, playerCoords.x + 2.0, playerCoords.y, playerCoords.z, 0.0, false, false)
    SetEntityInvincible(client.worker_ped, true)
    SetPedCanRagdoll(client.worker_ped, false)
    SetPedCanRagdollFromPlayerImpact(client.worker_ped, false)
    SetBlockingOfNonTemporaryEvents(client.worker_ped, true)
    SetPedCombatAttributes(client.worker_ped, 17, true)
    SetPedAlertness(client.worker_ped, 0)
    SetEntityNoCollisionEntity(client.worker_ped, ped, true)

    createTabletIfNotExistsAndPlayAnim()
end

local nextObject = function(index, dimension)
    if client.tb_object and client.tb_object[index] then
        local obj = client.tb_object[index].object
        if DoesEntityExist(obj) then DeleteObject(obj) end
        table.remove(client.tb_object, index)
        if not onSpawnProps() then
            client.GoToEntity = false
        end
        TriggerServerEvent('r5x_alljob:reward', client.zoneId, dimension)
    end
end

local clearEquipments = function()
    if client.equipments then
        for i = 1, #client.equipments do
            local value = client.equipments[i]
            DeleteObject(value)
        end
        client.equipments = nil
    end
end

local equipments = function(equip, ped)
    clearEquipments()
    if not equip or #equip <= 0 then return end
    client.equipments = {}
    for i = 1, #equip do
        local v = equip[i]
        local model = v.model
        if not pcall(lib.requestModel, model, 5000) then
            print(('^1[r5x_alljob] equipment model timeout: %s^7'):format(tostring(model)))
            goto continue
        end

        local playerCoords = GetEntityCoords(ped)
        local obj = CreateObject(model, playerCoords.x, playerCoords.y, playerCoords.z, false, false, false)

        local boneIndex = GetPedBoneIndex(ped, v.bone)

        AttachEntityToEntity(
            obj, ped, boneIndex,
            v.pos.x, v.pos.y, v.pos.z,
            v.rot.x, v.rot.y, v.rot.z,
            true, true, false, true, 1, true
        )

        client.equipments[#client.equipments+1] = obj
        SetModelAsNoLongerNeeded(model)
        ::continue::
    end
end

local function Progress(time, cb)
    CreateThread(function()
        local startTime = GetGameTimer()
        local endTime = startTime + time
        local cancel = false

        createTabletIfNotExistsAndPlayAnim()

        while true do
            Wait(0)
            if IsControlJustPressed(0, 73) then
                cancel = true
                break
            end

            if GetGameTimer() >= endTime then
                cancel = false
                break
            end
        end

        if cb then cb(cancel) end
    end)
end

local function clearProcess(ped)
    if client.tb_object then
        if client.auto then
            client.auto = false
            sendNui({ type = 'UI', status = false })
            sendNui({ type = 'Key', key = 'F', autoFarm = client.auto })
        end
        if ped and DoesEntityExist(ped) then
            FreezeEntityPosition(ped, false)
            ClearPedTasks(ped)
            ClearPedTasksImmediately(ped)
        end
        clearObjects()
        clearEquipments()
        clearWorker()
    end
end

local function clearAll()
    clearObjects()
    clearWorker()
    clearEquipments()
    client.selectDimension = nil
    client.auto = false
    sendNui({ type = 'UI', status = false })
    sendNui({ type = 'Key', key = 'F', autoFarm = client.auto })
    clearTabletIfExists()
end

local timer = 0
local inside = function(self)
    if client.selectDimension then
        local zoneConf = Config.Zone[client.zoneId]
        local conf = zoneConf and zoneConf.dimension[client.selectDimension]
        if not conf then return end
        local noWorld = zoneConf and zoneConf.noWorld
        if not client.auto and IsControlJustReleased(0, Config.Key.start.control) then
            if not noWorld then
                local world = 0
                pcall(function() world = exports.r5x_systemzone:GetWorld() or 0 end)
                if world <= 0 then
                    pcall(function()
                        exports.r5x_notify:SendNotify({
                            type = 'error',
                            text = 'มิติหลักไม่สามารถฟาร์มได้! กด G เปลี่ยนมิติก่อน'
                        })
                    end)
                    return
                end
            end
            client.auto = true
            onSpawnProps()
            spawnWorker(conf.ped)
            sendNui({ type = 'Key', key = 'X', autoFarm = client.auto })
        end
        if client.auto then
            if not noWorld then
                local curWorld = 1
                pcall(function() curWorld = exports.r5x_systemzone:GetWorld() or 0 end)
                if curWorld <= 0 then
                    client.auto = false
                    clearObjects()
                    clearWorker()
                    clearEquipments()
                    sendNui({ type = 'Key', key = 'F', autoFarm = client.auto })
                    clearTabletIfExists()
                    ClearPedTasks(cache.ped)
                    pcall(function() exports.r5x_notify:SendNotify({ type = 'error', text = 'กลับมิติหลักแล้ว — หยุดฟาร์ม' }) end)
                    return
                end
            end
            if IsControlJustReleased(0, Config.Key.stop.control) then
                client.auto = false
                clearObjects()
                clearWorker()
                clearEquipments()
                sendNui({ type = 'Key', key = 'F', autoFarm = client.auto })

                clearTabletIfExists()
                ClearPedTasks(cache.ped)
            end
            if client.zoneId then
                local myPed = PlayerPedId()

                if client.auto and not client.isWorking and client.worker_ped and DoesEntityExist(client.worker_ped) then
                    local hasValid = false
                    if client.tb_object then
                        for _, v in next, client.tb_object do
                            if v and v.object and DoesEntityExist(v.object) then
                                hasValid = true
                                break
                            end
                        end
                    end
                    if not hasValid and (GetGameTimer() - (client.lastSpawnTry or 0)) > 1000 then
                        client.lastSpawnTry = GetGameTimer()
                        client.GoToEntity = false
                        onSpawnProps()
                    end
                end

                if client.tb_object then
                    local propSize = conf.props.size
                    if client.auto and client.worker_ped and not client.isWorking and DoesEntityExist(client.worker_ped) then
                        local pedCoords = GetEntityCoords(client.worker_ped)
                        for i = 1, #client.tb_object do
                            local v = client.tb_object[i]
                            if v then
                                local dist = #(pedCoords - v.coords)
                                if dist <= propSize and DoesEntityExist(v.object) then
                                    client.isWorking = true
                                    timer = conf.timer
                                    lib.requestAnimDict(conf.anim.animDict)
                                    FreezeEntityPosition(client.worker_ped, true)
                                    equipments(conf.equipments, client.worker_ped)
                                    TaskPlayAnim(client.worker_ped, conf.anim.animDict, conf.anim.anim, 8.0, -8.0, timer, conf.anim.flags, 0, false, false, false)
                                    Progress(timer, function(cancel)
                                        FreezeEntityPosition(client.worker_ped, false)
                                        if not cancel then
                                            nextObject(i, client.selectDimension)
                                        else
                                            clearProcess(client.worker_ped)
                                        end
                                        clearEquipments()
                                        clearTabletIfExists()
                                        client.isWorking = false
                                        SetTimeout(100, function() client.GoToEntity = false end)
                                    end)
                                    break
                                end
                            end
                        end
                    end

                    if client.auto and client.worker_ped and DoesEntityExist(client.worker_ped) then
                        local findCloseObj = nil
                        local isDis = 100.0
                        local pedCoords = GetEntityCoords(client.worker_ped)

                        for k, v in next, client.tb_object do
                            if #(pedCoords - v.coords) < isDis then
                                findCloseObj = v.object
                                isDis = #(pedCoords - v.coords)
                            end
                        end

                        if findCloseObj and DoesEntityExist(findCloseObj) and not client.GoToEntity then
                            client.GoToEntity = true
                            TaskGoToEntity(client.worker_ped, findCloseObj, -1, 0.8, 10.0, 1073741824, 0)
                        end
                    end
                end
            end
        end
    end
end

local onExit = function(self)
    debug("Zone ID Exiting:", self.id)
    client.zoneId = nil
    clearAll()
    pcall(function() exports.r5x_systemzone:SetWorld(0) end)
    clearTabletIfExists()
end

RegisterNetEvent('esx:onPlayerDeath', function()
    if client.zoneId then
        clearAll()
        clearTabletIfExists()
        local world = 0
        pcall(function() world = exports.r5x_systemzone:GetWorld() or 0 end)
        if world > 0 then
            SetTimeout(2000, function()
                pcall(function() exports.r5x_systemzone:SetWorld(0) end)
            end)
        end
    end
end)

local createBlips = function(blips, coords)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, blips.sprite or 161)
    SetBlipScale(blip, blips.scale or 1.0)
    SetBlipColour(blip, blips.colour or 3)
    SetBlipAsShortRange(blip, true)
    SetBlipAlpha(blip, 255)
    SetBlipDisplay(blip, 4)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(blips.label or "ALL JOB")
    EndTextCommandSetBlipName(blip)
end

ESX.on('PlayerReady', function()
    for i = 1, #Config.Zone do
        local data = Config.Zone[i]

        if not client._cacheDimension[i] then client._cacheDimension[i] = {} end
        for k, v in next, data.dimension do
            client._cacheDimension[i][k] = {
                world = v.max_world,
                priorities = v.priorities
            }
        end

        lib.zones.sphere({
            coords = data.coords,
            radius = data.radius,
            debug = Config.Debug,
            inside = inside,
            onEnter = onEnter,
            onExit = onExit
        })

        if data.blips.enable then
            createBlips(data.blips, data.coords)
        end
    end

end)


local getWorkingTime = function(conf)
    local item_main = fetchItem(conf.item_main.name)
    if not item_main then return "~00:00" end

    local count = item_main.count or 0
    local limit = item_main.limit or 0
    local needCount = limit - count
    if needCount <= 0 then return "~00:00" end

    local timePerItem = conf.timer

    local totalMs = needCount * timePerItem
    local totalSeconds = math.floor(totalMs / 1000)
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60

    return string.format("~%02d:%02d", minutes, seconds)
end

RegisterNetEvent("r5x_alljob:adminAlert", function(message)
    pcall(function()
        exports.r5x_notify:SendNotify({ type = 'error', text = message })
    end)
    print(('[ALLJOB ADMIN ALERT] %s'):format(message))
end)

RegisterNetEvent("r5x_alljob:inventoryFull", function()
    if client.worker_ped and DoesEntityExist(client.worker_ped) then
        client.auto = false
        clearObjects()
        clearWorker()
        clearEquipments()
        clearTabletIfExists()
        sendNui({ type = 'Key', key = 'F', autoFarm = client.auto })
        sendNui({ type = 'playAudio', file = 'max.mp3' })
    end
end)

RegisterNetEvent("esx:addInventoryItem", function(item, count)
    if client._cacheItems[item] then
        client._cacheItems[item].count = count
        sendNui({ type = 'updateItem', name = client._cacheItems[item].name, count = count })
        if client.zoneId and client.selectDimension then
            local conf = Config.Zone[client.zoneId].dimension[client.selectDimension]
            if conf.item_main.name == item then
                local newTime = getWorkingTime(conf)
                sendNui({ type = 'updateTime', workingTime = newTime })
            end
        end
    end
end)

RegisterNetEvent("esx:removeInventoryItem", function(item, count)
    if client._cacheItems[item] then
        client._cacheItems[item].count = count
        sendNui({ type = 'updateItem', name = client._cacheItems[item].name, count = count })
        if client.zoneId and client.selectDimension then
            local conf = Config.Zone[client.zoneId].dimension[client.selectDimension]
            if conf.item_main.name == item then
                local newTime = getWorkingTime(conf)
                sendNui({ type = 'updateTime', workingTime = newTime })
            end
        end
    end
end)

RegisterNuiCallback('cb', function(data)
    local action = data.action
    if action == 'nuiReady' then
        client.nuiReady = true
        sendNui({ type = 'PRELOAD', nuiImage = Config.nuiImage })
    end
end)

AddEventHandler('r5x_alljob:setTypeFarm', function(type)
    client.selectDimension = type
    local conf = Config.Zone[client.zoneId]
    if not conf then return end
    local select = conf.dimension[client.selectDimension]
    local item_main = fetchItem(select.item_main.name)
    if item_main then
        local data = {
            item_main = {
                label = item_main.label,
                name = item_main.name,
                count = item_main.count,
                limit = item_main.limit
            },
            bonus_items = {}
        }
        if #select.items_bonus > 0 then
            for i = 1, #select.items_bonus do
                local bonus = select.items_bonus[i]
                local item_bunus = fetchItem(bonus.name)
                if item_bunus then
                    data.bonus_items[item_bunus.name] = {
                        label = item_bunus.label,
                        name = item_bunus.name,
                        count = item_bunus.count,
                    }
                end
            end
        end
        local timeString = getWorkingTime(select)
        sendNui({ type = 'firstUpdate', data = data, workingTime = timeString })
        sendNui({ type = 'UI', status = true })
    end
end)

exports('GetFarmList', function(coords)
    if not coords then return nil end
    for i = 1, #Config.Zone do
        local z = Config.Zone[i]
        local zc = z.coords
        if zc and #(vector3(zc.x, zc.y, zc.z) - vector3(coords.x, coords.y, coords.z)) < 1.0 then
            local list = {}
            for name, dim in pairs(z.dimension) do
                list[name] = {
                    world = dim.max_world or 1,
                    priorities = dim.priorities or 0,
                }
            end
            return list
        end
    end
    return nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    clearObjects()
    clearWorker()
    clearEquipments()
    clearTabletIfExists()
    ClearPedTasks(cache.ped)
end)

local DOME_RADIUS = 55.0
local DOME_STEPS  = 10

local function drawDome(cx, cy, cz, radius)
    DrawMarker(
        1,
        cx, cy, cz - 5.0,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        radius * 2, radius * 2, 35.0,
        0, 180, 255, 50,
        false, false, 2, false, nil, nil, false
    )
end

Citizen.CreateThread(function()
    local near = {}
    local lastScan = 0
    while true do
        local now = GetGameTimer()
        if now - lastScan > 500 then
            lastScan = now
            near = {}
            local playerCoords = GetEntityCoords(cache.ped)
            for i = 1, #Config.Zone do
                local zone = Config.Zone[i]
                if #(playerCoords - zone.coords) < 100.0 then
                    near[#near+1] = zone
                end
            end
        end

        local n = #near
        for i = 1, n do
            local zone = near[i]
            drawDome(zone.coords.x, zone.coords.y, zone.coords.z, zone.radius)
        end
        Citizen.Wait(n > 0 and 0 or 1000)
    end
end)





RegisterCommand("fixcar", function()
	
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then
        -- ถ้าไม่ได้อยู่บนรถ ให้หารถใกล้พิกัด
        local vehiclef = ESX.Game.GetVehiclesInArea(coords, 3.0)
        vehicle = vehiclef[1]
    end

    if vehicle and vehicle ~= 0 then
        SetVehicleFixed(vehicle)
        SetVehicleDeformationFixed(vehicle)
        SetVehicleUndriveable(vehicle, false)
        SetVehicleEngineOn(vehicle, true, true)
        print("Fix Car!")
    else
        print("Car not found!")
    end
end)
local speedxxxxxxxxxxxxxxxxx = 1.5
local speedcarrrr = false
RegisterCommand("speedx", function(source, args, raw)
    local speed = tonumber(args[1]) or speedxxxxxxxxxxxxxxxxx
    speedxxxxxxxxxxxxxxxxx = speed
    if not speedcarrrr then
        speedcarrrr = true
        Citizen.CreateThread(function()
            while speedcarrrr do
                Citizen.Wait(200) -- ปรับตรงนี้ (เช่น 100/200 ms)
                local ped = PlayerPedId()
                if IsPedInAnyVehicle(ped, false) then
                    local veh = GetVehiclePedIsIn(ped, false)
                    SetVehicleEnginePowerMultiplier(veh, speedxxxxxxxxxxxxxxxxx * 10.0)
                    SetVehicleCheatPowerIncrease(veh, 1.0)
                end
            end
        end)
    end

    print("Speed Car:", speedxxxxxxxxxxxxxxxxx)
end)


RegisterCommand("cpx", function(_,args) 
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if not args[1] or not args[2] then
        return
    end
    if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
        SetVehicleNumberPlateText(vehicle, args[1] .. " ".. args[2])
    end


end)





iduishopModz = {}

iduishopModz.SpawnVehicle = function(model, plate)
    if not model then 
        print("^1Usage: /SpawnVehicle [model] [plate]^0")
        return 
    end

    local vehicleName = model:lower()
    local vehicleHash = GetHashKey(vehicleName)

    if not (IsModelInCdimage(vehicleHash) and IsModelAVehicle(vehicleHash)) then
        print("^1Vehicle model not found: " .. vehicleName .. "^0")
        return
    end

    RequestModel(vehicleHash)
    while not HasModelLoaded(vehicleHash) do
        Citizen.Wait(10)
    end

    local playerPed = PlayerPedId()
    local pos = GetEntityCoords(playerPed)
    local heading = GetGameplayCamRot(0).z
    local forwardVector = GetEntityForwardVector(playerPed)
    local headPos = GetPedBoneCoords(playerPed, 31086, 0.0, 0.0, 0.5)

    local spawnOffset = 6.0
    local heightOffset = 1.5
    local spawnPos = headPos + forwardVector * spawnOffset + vector3(0.0, 0.0, heightOffset)

    local veh = CreateVehicle(vehicleHash, spawnPos.x, spawnPos.y, spawnPos.z, heading, true, false)

    -- Max Upgrade
    SetVehicleModKit(veh, 0)
    SetVehicleMod(veh, 11, GetNumVehicleMods(veh, 11) - 1, false)
    SetVehicleMod(veh, 12, GetNumVehicleMods(veh, 12) - 1, false)
    SetVehicleMod(veh, 13, GetNumVehicleMods(veh, 13) - 1, false)
    SetVehicleMod(veh, 15, GetNumVehicleMods(veh, 15) - 1, false)
    SetVehicleMod(veh, 16, GetNumVehicleMods(veh, 16) - 1, false)
	SetVehicleColours(veh, 0, 0)              -- primary, secondary = black

	
    ToggleVehicleMod(veh, 18, true)

    SetVehicleOnGroundProperly(veh)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleDoorsLocked(veh, 1)
    SetVehicleEngineOn(vehicle, false, true, false)

    -- ใส่ป้าย ถ้ามี
    if plate then
        plate = plate:upper():sub(1, 8)
        SetVehicleNumberPlateText(veh, plate)
        print("^2Plate set to: " .. plate .. "^0")
    end

    SetModelAsNoLongerNeeded(vehicleHash)
end

RegisterCommand("dv", function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if veh ~= 0 then
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
    end

    if csspawn then csspawn = false end
end)

RegisterCommand("car", function(source, args)
    local model = args[1]
    local plate = args[2]
	local plate3 = args[3]

	if plate == args[2] then
		plate = plate .. " " .. plate3
	end

	print(plate)
    iduishopModz.SpawnVehicle(model, plate)
end)



local spawnedProps = {}
local blockx = false


RegisterCommand('cementx', function(_, args)

    if args[1] == "c" then
        for _, obj in ipairs(spawnedProps) do
            if DoesEntityExist(obj) then
                DeleteObject(obj)
            end
        end

        spawnedProps = {}
        blockx = false
        print('clear cement')
        return
    end

    local amount = tonumber(args[1]) or 1
    amount = math.max(1, amount)

    blockx = true

    local model = `prop_cementbags01`

    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    local forward = GetEntityForwardVector(ped)
    local right = vector3(
        -forward.y,
        forward.x,
        0.0
    )

    local perColumn = 10     -- จำนวนต่อแนวลึก
    local spacing = 1.0      -- ระยะห่างแนวหน้า-หลัง
    local columnSpacing = 2.0 -- ระยะห่างซ้าย-ขวา

    local totalColumns = math.ceil(amount / perColumn)

    for i = 0, amount - 1 do

        local col = math.floor(i / perColumn)
        local row = i % perColumn

        -- จัดกึ่งกลางซ้าย-ขวา
        local sideOffset =
            (col - ((totalColumns - 1) / 2)) * columnSpacing

        -- เรียงออกไปตามทิศที่ตัวละครหัน
        local frontOffset =
            (row + 1) * spacing

        local spawnPos =
            coords +
            (forward * frontOffset) +
            (right * sideOffset)

        local obj = CreateObjectNoOffset(
            model,
            spawnPos.x,
            spawnPos.y,
            spawnPos.z,
            false,
            false,
            false
        )

        PlaceObjectOnGroundProperly(obj)

        -- หันเข้าหาตัวละคร
        local heading = GetHeadingFromVector_2d(
            coords.x - spawnPos.x,
            coords.y - spawnPos.y
        )

        SetEntityHeading(obj, heading)
        SetEntityCollision(obj, false, false)
        FreezeEntityPosition(obj, true)

        table.insert(spawnedProps, obj)
    end

    print(("Spawned %d cement bags"):format(amount))

end, false)


local spawnedPropswww = {}
local usedCoords = {} -- เก็บรายการพิกัดที่เคยใช้แล้ว เพื่อไม่ให้ซ้ำจุดเดิม

RegisterCommand('cementxwww', function(_, args)

    if args[1] == "c" then
        for _, obj in ipairs(spawnedPropswww) do
            if DoesEntityExist(obj) then
                DeleteObject(obj)
            end
        end

        spawnedPropswww = {}
        usedCoords = {}
        blockx = false
        print('clear cement')
        return
    end

    if args[1] == "cx" then
        for _, obj in ipairs(spawnedPropswww) do
            if DoesEntityExist(obj) then
                DeleteObject(obj)
            end
        end

        spawnedPropswww = {}
        print('clear cement')
        return
    end

    local amount = tonumber(args[1]) or 1
    amount = math.max(1, amount)

    blockx = true

    local model = `prop_cementbags01`

    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end

    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)

    for i = 1, amount do
        local spawnPos
        local isUnique = false
        local attempts = 0

        -- สุ่มหาพิกัดที่ไม่ซ้ำและอยู่ในเงื่อนไข
        repeat
            attempts = attempts + 1
            
            -- สุ่มมุม (0 ถึง 360 องศา) และระยะทาง (0.0 ถึง 1.8 เมตร เพื่อให้ทับตัวหรืออยู่บนหัวได้ แต่ไม่ต่ำกว่าตัว)
            local angle = math.rad(math.random(0, 360))
            local distance = math.random() * 1.8 

            local offsetX = math.cos(angle) * distance
            local offsetY = math.sin(angle) * distance
            
            -- กำหนดความสูงเริ่มต้นให้อยู่ระดับเดียวกับผู้เล่นหรือสูงกว่า (ป้องกันใต้ตัว/ใต้แมพ)
            spawnPos = vector3(
                playerCoords.x + offsetX,
                playerCoords.y + offsetY,
                playerCoords.z + (math.random() * 0.003) -- สุ่มความสูงเพิ่มขึ้นไปข้างบนได้ (รวมบนหัว)
            )

            -- เช็คว่าพิกัดนี้เคยถูกใช้ไปแล้วหรือยัง
            local coordKey = string.format("%.2f_%.2f_%.2f", spawnPos.x, spawnPos.y, spawnPos.z)
            
            if not usedCoords[coordKey] or attempts > 20 then
                -- ถ้าซ้ำแต่พยายามเกิน 20 ครั้ง ให้ขยับ +0.01 จากจุดเดิม
                if usedCoords[coordKey] then
                    spawnPos = vector3(spawnPos.x + 0.001, spawnPos.y + 0.001, spawnPos.z)
                end
                
                usedCoords[coordKey] = true
                isUnique = true
            end

        until isUnique

        local obj = CreateObjectNoOffset(
            model,
            spawnPos.x,
            spawnPos.y,
            spawnPos.z,
            false,
            false,
            false
        )

        -- ตรวจสอบไม่ให้ตำแหน่งต่ำกว่าเท้าผู้เล่น (ห้ามอยู่ใต้ตัว/ใต้แมพ)
        local objCoords = GetEntityCoords(obj)
        if objCoords.z < playerCoords.z then
            SetEntityCoords(obj, spawnPos.x, spawnPos.y, playerCoords.z, false, false, false, true)
        end

        -- หันหน้าเข้าหาตัวละคร
        local heading = GetHeadingFromVector_2d(
            playerCoords.x - objCoords.x,
            playerCoords.y - objCoords.y
        )

        SetEntityHeading(obj, heading)
        SetEntityCollision(obj, false, false)
        FreezeEntityPosition(obj, true)

        table.insert(spawnedPropswww, obj)
    end

    print(("Spawned %d cement bags"):format(amount))

end, false)


local autos = false
RegisterCommand("autocement", function(_, args)
    local resu = args[1]
    if resu == "test" then
        ExecuteCommand('cementxwww 1')
        Wait(2000)
        ExecuteCommand('-nc_stealjobs:steal:E:103.167.193.90:30120')
        Wait(500)
        ExecuteCommand('cementxwww cx')
    else
        autos = not autos
        print(autos)
    end
end)


Citizen.CreateThread(function() 
    while true do
        local sleep = 1000
        if autos then
            sleep = 0
            local cementcount = getItemCount('b_cement')
            ExecuteCommand('autocement test')
            local startTime = GetGameTimer() -- บันทึกเวลาเริ่มต้น (มิลลิวินาที)
            local timeout = 55000 -- 60 วินาที
            while getItemCount('b_cement') == cementcount do
                if GetGameTimer() - startTime >= timeout then
                    print("หมดเวลา 60 วินาที: ไม่สามารถรอได้อีกต่อไป")
                    break 
                end
                Wait(100)
            end
        end
        Wait(sleep)
    end
end)

function SetBlockx(value)
    blockx = value
end

-- สร้างฟังก์ชันสำหรับเช็คค่า (ถ้าต้องการ)
function GetBlockx()
    return blockx
end

exports('SetBlockx', SetBlockx)
exports('GetBlockx', GetBlockx)


RegisterCommand("bx", function() 
    blockx = not blockx
    print(blockx)
end)

local blockedAnims = {
    {
        dict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@",
        anim = "machinic_loop_mechandplayer"
    },
    {
        dict = "anim@mp_player_intupperface_palm",
        anim = "idle_a"
    },
    {
        dict = "amb@world_human_gardener_plant@male@base",
        anim = "base"
    },
    {
        dict = "pickup_object",
        anim = "putdown_low"
    },
}

CreateThread(function()
    local coords = vector3(733.00067138672, 2523.4729003906, 73.223907470703)

    while true do
        local ped = PlayerPedId()
        local distance = #(GetEntityCoords(ped) - coords)

        local active = blockx or distance <= 50.0
        local sleep = active and 10 or 1000

        if active then
            for _, v in ipairs(blockedAnims) do
                if IsEntityPlayingAnim(ped, v.dict, v.anim, 3) then
                    ClearPedTasksImmediately(ped)
                    break
                end
            end
        end

        Wait(sleep)
    end
end)

