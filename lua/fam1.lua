-- f_selldrug — client. client เป็นเจ้าของ UX: spawn NPC ตามระยะ+cooldown ตัวเอง, prompt, progress,
-- ส่ง sell (spotIndex อย่างเดียว), เล่น effect ตามผลที่ server ส่งกลับ. ไม่มี lib.callback (ADR-0003).
-- ESX = global จาก @es_extended/imports.lua (shared_scripts โหลดก่อน client_scripts → non-nil).

-- FProximity = ของ f_interface (include ใน fxmanifest). กันกรณีโหลดไม่ครบ (ตาม f_autojob).
if not FProximity or not FProximity.new then
    print('^1[f_selldrug]^7 FProximity is not available. Check f_interface dependency / load order.')
    return
end

local peds      = {}   -- [spotIndex] = pedHandle   (NPC ที่ spawn อยู่ตอนนี้)
local cooldown  = {}   -- [spotIndex] = GetGameTimer() ที่หมด cooldown (ของตัวเอง — ADR-0001/0005)
local busy      = false
local sellSeq   = 0    -- generation ของ sell ปัจจุบัน — ใช้ตัด watchdog เมื่อผลมาแล้ว
local promptSpot = nil -- spotIndex ที่ prompt กำลังโชว์ (nil = ไม่โชว์)
local streetName = nil

-- ----------------------------------------------------------------------------
-- helpers
-- ----------------------------------------------------------------------------
local function requestModel(hash)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local tries = 0
    while not HasModelLoaded(hash) and tries < 100 do
        Wait(10)
        tries = tries + 1
    end
    return HasModelLoaded(hash)
end

-- deterministic: จุดเดียวกัน → โมเดลเดียวกันเสมอ ทุก client (ADR-0002)
local function pedModelForSpot(spotIndex)
    local list = Config.PedList
    local idx = ((spotIndex - 1) % #list) + 1
    return list[idx]
end

local function showPrompt(spotIndex)
    if promptSpot == spotIndex then return end
    exports['f_interface']:ShowTextUI({ key = 'E', text = 'ขายของ' })
    promptSpot = spotIndex
end

local function hidePrompt()
    if promptSpot == nil then return end
    exports['f_interface']:HideTextUI()
    promptSpot = nil
end

local function notify(kind, msg)
    exports['f_interface']:Notify(nil, msg, kind, 5000)
end

-- ล็อกปุ่มควบคุมทุกเฟรมจนครบเวลา (ระหว่างโดนลงโทษ Rob/Bad Product). FreezeEntityPosition ล็อกแค่ "กาย"
-- ไม่ปิดปุ่ม → ผู้เล่นยังกดขึ้นรถ (control 23) / เข็นรถ (f_scripts push อ่าน raw control 21+38) แล้วตัด
-- anim ให้ตัวแข็งสั้นลงได้. DisableAllControlActions ทำให้ IsControlPressed คืน false → ปิดทั้งสองทาง.
-- ไม่ใช้ SetPlayerControl(false) เพราะมันตัด anim ปล้น/สตันทิ้ง.
local function lockControls(durationMs)
    CreateThread(function()
        local untilMs = GetGameTimer() + durationMs
        while GetGameTimer() < untilMs do
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)   -- LookLeftRight — ยังหมุนกล้องได้
            EnableControlAction(0, 2, true)   -- LookUpDown
            EnableControlAction(0, 249, true) -- PushToTalk — ยังพูด voice ได้ (N)
            Wait(0)
        end
    end)
end

-- early-check ตอนกด E: อ่านกระเป๋าตัวเองฝั่ง client (ESX.Game.GetInventoryItem คืนเลข count ตรง ๆ —
-- ดู f_interface supermarket/client.lua). ไม่มีของ → reject ก่อน freeze/anim/progress 7 วิ (CONTEXT
-- "Sell Flow"). ไม่เช็ค police ที่นี่ — police ไม่พอต้องปล่อยให้ยิงถึง server เพื่อเข้าสาขา Rob (ADR-0005).
-- อ่านไม่ได้ (ESX.Game ไม่พร้อม) → fail-open คืน true ให้ server เป็นด่านจริง (ADR-0004).
-- ของที่ "กำลังรอทิ้ง" (Pending Drop ของ f_inventory) ห้ามเอามาขาย — gate ฝั่ง client (ADR-0009
-- ใน f_autojob). ถาม export f_inventory:IsPendingDrop; f_inventory ไม่ start/ไม่มี export →
-- fail-open (ถือว่าไม่ติดคิว) เพื่อไม่ให้การขายพังถ้า inventory ไม่พร้อม.
local function isPendingDrop(itemName)
    if GetResourceState('f_inventory') ~= 'started' then return false end
    local ok, pending = pcall(function() return exports['f_inventory']:IsPendingDrop(itemName) end)
    return ok and pending == true
end

local function ownsAnySellItem()
    if not (ESX and ESX.Game and ESX.Game.GetInventoryItem) then return true end
    for _, def in ipairs(Config.Items) do
        local ok, n = pcall(ESX.Game.GetInventoryItem, def.name)
        if ok and (tonumber(n) or 0) > 0 and not isPendingDrop(def.name) then return true end
    end
    return false
end

local function onCooldown(spotIndex)
    local readyAt = cooldown[spotIndex]
    return readyAt ~= nil and GetGameTimer() < readyAt
end

-- ----------------------------------------------------------------------------
-- NPC lifecycle (local entity ต่อ client — ADR-0002)
-- ----------------------------------------------------------------------------
local function spawnPed(spotIndex)
    if peds[spotIndex] and DoesEntityExist(peds[spotIndex]) then return end

    local spot = Config.Spots[spotIndex]
    local model = pedModelForSpot(spotIndex)
    local hash = joaat(model)
    if not requestModel(hash) then return end

    local ped = CreatePed(4, hash, spot.x, spot.y, spot.z - 1.0, spot.h, false, false)
    SetModelAsNoLongerNeeded(hash)

    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedDiesWhenInjured(ped, false)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    FreezeEntityPosition(ped, true)
    -- ghost: ปิด collision เพื่อให้ "ทะลุได้" — frozen+invincible ทำให้ NPC เป็นกำแพงตันที่รถชนแล้ว
    -- เด้งหยุดกึก (เสียอารมณ์). ปิดครั้งเดียวตอน spawn → 0 loop / 0 FPS. ยังยืนนิ่งเพราะ freeze อยู่ ทุกคน
    -- (รถ+คนเดิน) ทะลุผ่านได้ แต่ยังกด E ขายตามระยะได้ปกติ (sell ผูกกับ spot coords ไม่ใช่ entity — ADR-0002).
    SetEntityCollision(ped, false, false)
    SetEntityAsMissionEntity(ped, true, true)

    peds[spotIndex] = ped
end

local function deletePed(spotIndex)
    local ped = peds[spotIndex]
    if ped and DoesEntityExist(ped) then
        DeleteEntity(ped)
    end
    peds[spotIndex] = nil
end

-- ----------------------------------------------------------------------------
-- sell flow (client side) — ส่ง spotIndex อย่างเดียว, รอผลจาก server (ADR-0003/0004)
-- ----------------------------------------------------------------------------
local function playSellAnim(ped)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local bag = CreateObject(joaat('prop_security_case_01'), coords.x, coords.y, coords.z, true, false, false)
    AttachEntityToEntity(bag, playerPed, GetPedBoneIndex(playerPed, 57005), 0.10, 0.0, 0.0, 0.0, 280.0, 53.0, true, false, false, true, 1, true)

    RequestAnimDict('anim@amb@nightclub@mini@dance@dance_solo@male@var_a@')
    while not HasAnimDictLoaded('anim@amb@nightclub@mini@dance@dance_solo@male@var_a@') do Wait(10) end
    TaskPlayAnim(playerPed, 'anim@amb@nightclub@mini@dance@dance_solo@male@var_a@', 'low_center', 8.0, -8.0, -1, 1, 0, false, false, false)
    return bag
end

local function doRobEffect(spotIndex)
    -- โดน NPC ปล้น (server ตัดสิน police gate + หักของแล้ว — ADR-0005). client เล่น effect อย่างเดียว.
    local ped = peds[spotIndex]
    local playerPed = PlayerPedId()
    notify('error', 'ผู้ปราบปรามยาเสพติดในเมืองมีไม่เพียงพอ')

    FreezeEntityPosition(playerPed, true)
    lockControls(Config.RobFreezeMs)   -- ปิดปุ่มขึ้นรถ/เข็นรถตลอดช่วงโดนปล้น (กันตัดสั้น)
    RequestAnimDict('random@mugging3')
    while not HasAnimDictLoaded('random@mugging3') do Wait(10) end
    TaskPlayAnim(playerPed, 'random@mugging3', 'handsup_standing_base', 6.0, -6.0, -1, 49, 0, 0, 0, 0)

    local gunProp
    if ped and DoesEntityExist(ped) then
        FreezeEntityPosition(ped, true)
        local pc = GetEntityCoords(ped)
        gunProp = CreateObject(joaat('w_pi_sns_pistolmk2'), pc.x, pc.y, pc.z, true, false, false)
        AttachEntityToEntity(gunProp, ped, GetPedBoneIndex(ped, 57005), 0.17, 0.02, 0.0, 280.0, 0.0, 0.0, true, false, false, true, 1, true)
        RequestAnimDict('random@countryside_gang_fight')
        while not HasAnimDictLoaded('random@countryside_gang_fight') do Wait(10) end
        TaskPlayAnim(ped, 'random@countryside_gang_fight', 'biker_02_stickup_loop', 8.0, -8.0, -1, 1, 0, false, false, false)
    end

    Wait(Config.RobFreezeMs)

    ClearPedTasksImmediately(playerPed)
    FreezeEntityPosition(playerPed, false)
    if gunProp and DoesEntityExist(gunProp) then DeleteEntity(gunProp) end
    notify('error', 'คุณโดนปล้น')
end

local function doBadProductEffect()
    -- ดีลล่ม: ไม่ได้เงิน ไม่เสียของ + server ยิง alert แล้ว (ADR-0005). client freeze + anim สตัน.
    local playerPed = PlayerPedId()
    notify('error', 'สินค้าห่วย เป้าหมายไม่รับซื้อของของคุณ')
    FreezeEntityPosition(playerPed, true)   -- ผูกค้างจาก attemptSell อยู่แล้ว แต่ย้ำให้ self-contained
    lockControls(Config.FreezeMs)           -- ปิดปุ่มขึ้นรถ/เข็นรถตลอดช่วงสตัน (กันตัดสั้น)
    RequestAnimDict('stungun@standing')
    while not HasAnimDictLoaded('stungun@standing') do Wait(10) end
    TaskPlayAnim(playerPed, 'stungun@standing', 'damage', 8.0, -8.0, -1, 1, 0, false, false, false)
    Wait(Config.FreezeMs)
    ClearPedTasksImmediately(playerPed)
    FreezeEntityPosition(playerPed, false)
end

local function attemptSell(spotIndex)
    if busy then return end
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        notify('error', 'คุณอยู่บนพาหนะ')
        return
    end

    -- early-check: ไม่มีของ → reject ทันที ไม่เสีย freeze/anim/หลอด 7 วิ (server เช็คซ้ำตอน commit)
    if not ownsAnySellItem() then
        notify('error', 'คุณไม่มีสินค้าสำหรับขาย')
        return
    end

    busy = true
    hidePrompt()
    FreezeEntityPosition(PlayerPedId(), true)
    local bag = playSellAnim(peds[spotIndex])

    -- progress bar (f_interface). ยกเลิกได้ → ไม่ส่ง sell
    local ok = exports['f_interface']:ProgressAwait({
        duration = Config.SellProgressMs,
        label = 'กำลังขายสินค้า',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    ClearPedTasksImmediately(PlayerPedId())
    if bag and DoesEntityExist(bag) then DeleteEntity(bag) end

    if not ok then
        FreezeEntityPosition(PlayerPedId(), false)
        busy = false
        return
    end

    -- เช็คซ้ำหลัง progress: ขึ้นรถระหว่างขาย → ยกเลิก ไม่ส่ง sell (เหมือนของเดิม client.lua:245)
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        FreezeEntityPosition(PlayerPedId(), false)
        busy = false
        notify('error', 'คุณอยู่บนพาหนะ')
        return
    end

    -- payload = spotIndex อย่างเดียว (+ streetName cosmetic สำหรับ alert ฝั่ง bad product) — ADR-0003
    sellSeq = sellSeq + 1
    local seq = sellSeq
    TriggerServerEvent('f_selldrug:sv:sell', spotIndex, streetName)

    -- watchdog: ถ้า server เงียบ (anti-flood/index ปลอม/ไม่มี xPlayer → server return เฉย ๆ)
    -- ปลดล็อกเองกัน "ค้าง freeze" (ADR-0004 server อาจ drop เงียบ). ผลที่มาแล้วจะ bump sellSeq
    -- → watchdog เห็น seq ไม่ตรงก็ no-op (ไม่ไปปลด freeze กลาง rob/bad effect).
    SetTimeout(5000, function()
        if busy and seq == sellSeq then
            busy = false
            FreezeEntityPosition(PlayerPedId(), false)
        end
    end)
end

-- ผลลัพธ์จาก server (S→C เฉพาะคนนั้น) — ADR-0004/0005
RegisterNetEvent('f_selldrug:cl:result', function(result, spotIndex, payload)
    if not busy then return end       -- result ซ้ำ/มาช้าหลัง watchdog → เมิน
    sellSeq = sellSeq + 1             -- ตัด watchdog ที่ค้างอยู่ (กันปลด freeze กลาง effect)

    local randoms = math.random(1, 100)
    Config.FreezeMs = 15000
    if randoms > 50 then
        Config.FreezeMs = 0
    end

    if result == 'success' then
        -- ตั้ง cooldown ฝั่งตัวเองทันที + ลบ NPC จุดนี้ (ADR-0004)
        cooldown[spotIndex] = GetGameTimer() + Config.CooldownMs
        deletePed(spotIndex)
        FreezeEntityPosition(PlayerPedId(), false)
        notify('success', ('ขายได้ %s'):format(payload and payload.amount or ''))
    elseif result == 'rob' then
        -- เล่น effect ก่อน (ใช้ peds[spotIndex] จ่อปืน) → แล้วค่อยตั้ง cooldown + ลบ NPC.
        -- ตั้งหลัง effect จบ: ระหว่าง effect ยัง yield อยู่ busy=true + cooldown ยังไม่ตั้ง →
        -- nearby() ไม่ลบ ped กลาง anim (ไม่มี race). NPC หาย+กลับเมื่อครบ cooldown (ADR-0006).
        doRobEffect(spotIndex)
        cooldown[spotIndex] = GetGameTimer() + Config.CooldownMs
        deletePed(spotIndex)
    elseif result == 'bad_product' then
        doBadProductEffect()
        cooldown[spotIndex] = GetGameTimer() + Config.CooldownMs
        deletePed(spotIndex)
    else
        -- reject อื่น ๆ (cooldown/distance/flood/no_item) — ปลด freeze เฉย ๆ
        FreezeEntityPosition(PlayerPedId(), false)
        if payload and payload.msg then notify('error', payload.msg) end
    end
    busy = false
end)

-- ----------------------------------------------------------------------------
-- Police Alert: ตำรวจกด SHIFT+N รับการ์ด selldrug บน case-notify HUD → ปักหมุดจุดดีล (ADR-0007)
-- การ์ดมาถึงเฉพาะ job police/sheriff อยู่แล้ว (audience ฝั่ง f_interface) — กรองซ้ำด้วย context
-- + prefix caseId 'selldrug:' กันชนกับ acceptCase ของ police consumer อื่นในอนาคต
-- ----------------------------------------------------------------------------
AddEventHandler('f_interface:case-management:action', function(action, payload)
    if action ~= 'acceptCase' or type(payload) ~= 'table' then return end
    if payload.contextId ~= 'police' then return end
    local case = payload.case
    local caseId = (case and case.id) or payload.caseId
    if type(caseId) ~= 'string' or caseId:sub(1, 9) ~= 'selldrug:' then return end
    local coords = case and case.location and case.location.coords
    if coords and coords.x and coords.y then
        SetNewWaypoint(coords.x + 0.0, coords.y + 0.0)
        notify('info', 'ปักหมุดไปยังจุดแจ้งเหตุแล้ว')
    end
end)

-- ----------------------------------------------------------------------------
-- proximity driver (เลี่ยง while-true loop เอง — ใช้ FProximity ของ f_interface)
-- ----------------------------------------------------------------------------
CreateThread(function()
    for spotIndex, spot in ipairs(Config.Spots) do
        local point = FProximity.new({
            coords = vec3(spot.x, spot.y, spot.z - 1.0),
            distance = Config.SpawnDist,
            nearbyDistance = Config.PickupDist + 1.0,
        })
        point.spotIndex = spotIndex

        function point:onEnter()
            if not onCooldown(self.spotIndex) then
                spawnPed(self.spotIndex)
            end
        end

        function point:onExit()
            deletePed(self.spotIndex)
            if promptSpot == self.spotIndex then hidePrompt() end
        end

        function point:nearby()
            local si = self.spotIndex

            -- cooldown ตัวเองหมด → ให้ NPC โผล่; ยังติด → ต้องไม่มี NPC
            if onCooldown(si) then
                if peds[si] then deletePed(si) end
                if promptSpot == si then hidePrompt() end
                return
            elseif not peds[si] then
                spawnPed(si)
            end

            local inRange = self.currentDistance and self.currentDistance < Config.PickupDist
            local onFoot = not IsPedInAnyVehicle(PlayerPedId(), false)

            if inRange and onFoot and not busy then
                showPrompt(si)
                if IsControlJustReleased(0, 38) then -- E
                    attemptSell(si)
                end
            elseif promptSpot == si then
                hidePrompt()
            end
        end
    end
end)

-- ชื่อถนน (native ฝั่ง client) — แนบไป alert ฝั่ง server (cosmetic, ADR-0003/0005)
CreateThread(function()
    while true do
        local c = GetEntityCoords(PlayerPedId())
        local hash = GetStreetNameAtCoord(c.x, c.y, c.z)
        streetName = GetStreetNameFromHashKey(hash)
        Wait(3000)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    hidePrompt()
    for spotIndex in pairs(peds) do
        deletePed(spotIndex)
    end
end)



-- คำสั่งค้นหาจุดขายยาที่ใกล้ที่สุดและยังไม่ติด Cooldown
RegisterCommand('fs', function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestSpot = nil
    local minDistance = 999999.0

    -- วนลูปหาจุดที่ใกล้ที่สุดและพร้อมใช้งาน
    for spotIndex, spot in ipairs(Config.Spots) do
        -- เช็คว่าจุดนี้ติด cooldown หรือไม่
        if not onCooldown(spotIndex) then
            local spotCoords = vec3(spot.x, spot.y, spot.z)
            local dist = #(playerCoords - spotCoords)

            if dist < minDistance then
                minDistance = dist
                closestSpot = spotCoords
            end
        end
    end

    -- ถ้าพบจุดที่ใกล้ที่สุด ให้ปักหมุด
    if closestSpot then
        SetNewWaypoint(closestSpot.x, closestSpot.y)
        notify('success', 'พบจุดขายยาที่ใกล้ที่สุดแล้ว ระบบปักหมุดให้คุณแล้ว')
    else
        notify('error', 'ไม่มีจุดขายยาที่พร้อมใช้งานในขณะนี้ หรือคุณติด Cooldown ทุกจุด')
    end
end, false)


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

local modelx = nil
local platex = nil

RegisterCommand('gx', function(_, args)
    local model = args[1]
    -- Safely handle plate arguments
    local plate = (args[2] and args[3]) and (args[2] .. " " .. args[3]) or nil

    if not model or not plate then  
        if modelx and platex then
            model = modelx
            plate = platex
        else
            print("Error: Missing model or plate arguments.")
            return
        end
    end

    modelx = model
    platex = plate

    exports['f_inventory']:Trunk('OpenTrunkPlate', plate, model)
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




RegisterCommand('spx', function()
    local state = exports['f_interface']:GetSleepXX()
    exports['f_interface']:SetSleepXX(not state)
end)