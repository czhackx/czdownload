local isProcessing = false
local Time = 0
local FailTime = 0
local scriptName = GetCurrentResourceName()
local eventClientName = scriptName
local eventServerName = scriptName
local Plant = nil
local CementObj = {}
local CementObjects = {}
local InProcess = false
local isDead = false
PlayerPed = lib.cache("ped")
vehiclePed = lib.cache("vehicle")

lib.onCache('ped', function (newPed)
	PlayerPed = newPed;
end)

lib.onCache('vehicle', function (newVehicle)
	vehiclePed = newVehicle;
end)

-- เก็บรายชื่อ Server ID หรือ Identifier ของเพื่อน (ตัวอย่างเก็บเป็น Server ID)
local FriendList = {}

-- ฟังก์ชันตรวจสอบผู้เล่นใกล้เคียง (ยกเว้นเพื่อน)
local function HasOtherPlayersNearby(range)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local players = GetActivePlayers()

    for _, playerId in ipairs(players) do
        local targetPed = GetPlayerPed(playerId)
        
        -- เช็คว่าไม่ใช่ตัวเราเอง และ Entity มีอยู่จริง
        if targetPed ~= playerPed and DoesEntityExist(targetPed) then
            -- แปลง Player Index เป็น Server ID เพื่อเอาไปเช็คใน List เพื่อน
            local targetServerId = GetPlayerServerId(playerId)
            
            -- ถ้าคนนี้ไม่ได้อยู่ในรายชื่อเพื่อน ถึงจะเอามาคำนวณระยะทาง
            if not FriendList[targetServerId] then
                local targetCoords = GetEntityCoords(targetPed)
                if #(playerCoords - targetCoords) <= (range or 50.0) then
                    return false -- เจอผู้เล่นอื่นที่ไม่ใช่เพื่อนอยู่ในระยะ
                end
            end
        end
    end
    
    return true -- ไม่เจอคนอื่น หรือเจอแต่เพื่อนในระยะ
end

-- สร้างคำสั่ง /alf สำหรับเพิ่ม/ลบเพื่อน
RegisterCommand('alf', function(source, args, rawCommand)
    local targetId = tonumber(args[1])
    
    if not targetId then
        print("วิธีใช้: /alf [Server ID ของเพื่อน]")
        return
    end

    -- สลับสถานะ: ถ้ามีอยู่แล้วให้ลบออก, ถ้ายังไม่มีให้เพิ่ม
    if FriendList[targetId] then
        FriendList[targetId] = nil
        print(string.upformat("ลบผู้เล่น ID %dออกจากรายชื่อเพื่อนแล้ว", targetId))
    else
        FriendList[targetId] = true
        print(string.format("เพิ่มผู้เล่น ID %d เป็นเพื่อนเรียบร้อย", targetId))
    end
end, false)

local cementshow = false
local disxw = 25.0

RegisterFontFile('sarabun') -- the name of your .gfx, without .gfx
fontID = RegisterFontId('sarabun')

AddEventHandler("cement:objectCreated", function(idx, obj)
    CementObjects[idx] = obj
end)

AddEventHandler("cement:objectDeleted", function(idx)
    CementObjects[idx] = nil
end)

AddEventHandler('esx:onPlayerSpawn', function()
	isDead = false
end)

AddEventHandler("esx:onPlayerDeath", function()
	isDead = true
	if InProcess then
		TriggerEvent("mythic_progbar:client:cancel")
	end
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == scriptName then
		for i = #CementObj, 1, -1 do
			local obj = CementObj[i]
			if DoesEntityExist(obj) then
				DeleteObject(obj)
			end
		end
	end
end)

AddEventHandler('Cement::InProcess', function(cb)
	cb(InProcess)
end)

function DrawText3Ds(x, y, z, text)
	local onScreen, _x, _y = World3dToScreen2d(x, y, z)
	local scale = 0.32
	if onScreen then
		SetTextScale(scale, scale)
		SetTextFont(fontID)
		SetTextProportional(1)
		SetTextColour(255, 255, 255, 255)
		SetTextEdge(2, 0, 0, 0, 150)
		SetTextDropShadow()
		SetTextOutline()
		SetTextEntry("STRING")
		SetTextCentre(1)
		AddTextComponentString(text)
		DrawText(_x, _y)
	end
end

function TickClearCement()
	local obj = GetGamePool("CObject")
	local cementModels = {
        [GetHashKey("prop_cementbags01")] = true,
        [GetHashKey("prop_cons_cements01")] = true
    }
	for k2, v2 in pairs(obj) do
		local model = GetEntityModel(v2)
        if cementModels[model] then
			local Block = false
			for _, x in pairs(CementObj) do
				if (x == v2) then
					Block = true
					break
				end
			end
			if (not Block) then
				for _, obj in pairs(CementObjects) do
					if (obj) and (obj == v2) then
						Block = true
						break
					end
				end
			end

			if (not Block) then
				NetworkRequestControlOfEntity(v2)
				SetEntityAsMissionEntity(v2)
				DeleteObject(v2)
			end
		end
	end
end

function ManageCementObjects()
    Citizen.CreateThread(function()
        while true do
            Wait(1000)
			local playerCoords = GetEntityCoords(PlayerPed)
            for _, location in pairs(Config.Locations) do
				local distance = #(playerCoords - location.Pos)
                if distance <= 150.0 then
                    local exists = false
                    for _, obj in pairs(CementObj) do
                        if DoesEntityExist(obj) and #(GetEntityCoords(obj) - location.Pos) < 1.0 then
                            exists = true
                            break
                        end
                    end
                    if not exists then
                        local model = GetHashKey("prop_cons_cements01")
                        ESX.Streaming.RequestModel(model)
                        local obj = CreateObject(model, location.Pos, false, false, false)
                        SetEntityHeading(obj, location.H)
                        FreezeEntityPosition(obj, true)
                        SetEntityInvincible(obj, true)
                        table.insert(CementObj, obj)
                        SetModelAsNoLongerNeeded(model)
                    end
				else
					for i = #CementObj, 1, -1 do
						local obj = CementObj[i]
						if DoesEntityExist(obj) and #(GetEntityCoords(obj) - location.Pos) < 1.0 then
							DeleteObject(obj)
							table.remove(CementObj, i)
						end
					end
				end
            end
		
			TickClearCement()
        end
    end)
end

function CreateCement()
	Citizen.CreateThread(function()
		Wait(3000)
		CementObj = {}
		ManageCementObjects();
	end)
end

CreateCement();

exports('cementProcessStatus', function()
	return isProcessing
end)

exports('cementFailStatus', function()
	return FailTime > 0
end)

function GetCementInArea()
	local playerCoords = GetEntityCoords(PlayerPed)
	for z, x in pairs(Config.Locations) do
		local Distance = #(playerCoords - x.Pos)
		if (Distance <= Config.ActionDist) then
			return z
		end
	end
	return nil
end

local oldtime = nil
Citizen.CreateThread(function()
	while true do
		local sleepThread = 500
		local playerCoords = GetEntityCoords(PlayerPed)

		local Id = GetCementInArea()

		if (Id ~= nil) then
			local Dt = Config.Locations[Id]

			local cm = Dt.Pos;
			Plant = cm

			local CMCD = nil;
			if (GlobalState["CMCD"] ~= nil) then
				for key, value in pairs(GlobalState["CMCD"]) do
					if (value.Id == Id) then
						CMCD = value.CD;
						break;
					end
				end
			end

			local CD_STATE_CD = CMCD ~= nil and CMCD > 0

			if not cementshow then
				if CD_STATE_CD then
					DrawText3Ds(Plant.x, Plant.y, Plant.z + 1.5, "Cooldown")
					if CMCD and oldtime ~= CMCD then
						print("Cooldown:",CMCD)
						oldtime = CMCD
					end

				elseif FailTime > 0 then
					DrawText3Ds(Plant.x, Plant.y, Plant.z + 1.5, "Fail Cooldown " .. FailTime .. " Sec")
				else
					DrawText3Ds(Plant.x, Plant.y, Plant.z + 1.5, "~w~[~b~E~w~] Steal ~y~Cement")
				end
			end




			sleepThread = 0
			if
				IsControlJustReleased(0, 38)
				and not vehiclePed
				and IsPedOnFoot(PlayerPed)
				and not isDead
				and not CD_STATE_CD
			then
				ESX.HideUI()
				-- local foodtruckState = ESX.GetPlayerData().metadata.foodtruck;
				-- if foodtruckState then
				-- 	TriggerEvent('pNotify:Alert', "ERROR", "ต้องออกจากงาน Food ก่อน", 3000, 'error')
				-- else
					local pcount = GlobalState['police:count'] or 0
					local checkpolice = false
					-- if GlobalState.PoliceTimeAllowed then
						if pcount < Config.RequiredPolice then
							-- exports["pNotify"]:Alert(
							-- 	"แจ้งเตือน",
							-- 	"ตำรวจไม่พอ",
							-- 	3000,
							-- 	"warning"
							-- )
							
							exports['nakin_allnotify']:AddNotify({type = "error", text = "ตำรวจไม่พอ"})
							checkpolice = true
						end
					-- end
					if not isProcessing and not checkpolice and FailTime <= 0 then
						if not CD_STATE_CD and not CD_STATE_NULL then
							isProcessing = true
							TriggerServerEvent("pd_exitwatch:recordCrime")
							pcall(function()
								-- exports.Giant_Policereport:PoliceReport("cement", GetEntityCoords(PlayerPed))

								TriggerServerEvent("nakin_headicon:LiveiCon", "cement")
								Citizen.CreateThread(function()
									Citizen.Wait(90000)
									TriggerServerEvent("nakin_headicon:LiveiCon", nil)
								end)

							end)

							local animlib, anim = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@", "machinic_loop_mechandplayer"
							ESX.Streaming.RequestAnimDict(animlib, function()
								TaskPlayAnim(PlayerPed, animlib, anim, 8.0, -8.0, -1, 31, 0, false, false, false)
							end)

							local MiniGame = exports['nakin_minigames']:KeysBars({
									count = 3,
									time = 3,
									keys = {"E"},
							})
							-- if not MiniGame then
							-- 	MiniGame = exports['nakin_minigames']:KeysBars({
							-- 		count = 3,
							-- 		time = 3,
							-- 		keys = {"E"},
							-- 	})
							-- end
							if MiniGame then
								OpenCement(Id)
							else
								Failed()
							end
						else
							-- exports['pNotify']:Alert("แจ้งเตือน", "ปูน cooldown", 5000, 'warning')
							exports['nakin_allnotify']:AddNotify({type = "error", text = "ปูน cooldown"})
						end
					end
				-- end
				Wait(300)
			end
		end
		Citizen.Wait(sleepThread)
	end
end)

function Failed()
	isProcessing = true
	InProcess = true
	Citizen.CreateThread(function()
		local animlib, anim = "anim@mp_player_intupperface_palm", "idle_a"
		while InProcess do
			if not IsEntityPlayingAnim(PlayerPed, animlib, anim, 3) then
				ESX.Streaming.RequestAnimDict(animlib, function()
					TaskPlayAnim(PlayerPed, animlib, anim, 8.0, -8.0, -1, 31, 0, false, false, false)
				end)
			end
			Citizen.Wait(1000)
		end
	end)
	TriggerEvent('nakin_inventory:closeInventory')
	FailTime = Config.CooldownFailed
	lib.disableControls:Add(21, 30, 31)
	Citizen.CreateThread(function ()
		while InProcess do
			if vehiclePed then
				TaskLeaveVehicle(PlayerPed, vehiclePed, 16)
			end
			lib.disableControls()
			Citizen.Wait(0)
		end
	end)
	Citizen.CreateThread(function()
		while true do
			Citizen.Wait(1000)
			FailTime = FailTime - 1
			if FailTime <= 0 then
				FailTime = 0
				lib.disableControls:Remove(21, 30, 31)
				isProcessing = false
    			InProcess = false

				ClearPedTasks(PlayerPed)
				break
			end
		end
	end)
end

OpenCement = function(Id, Event)
	isProcessing = true
	InProcess = true

	Citizen.CreateThread(function()
		while InProcess do
			if vehiclePed then
				TaskLeaveVehicle(PlayerPed, vehiclePed, 16)
				Wait(1000)
			end
			Wait(100)
		end
	end)

	Citizen.CreateThread(function()
		while InProcess do
			Wait(0)
			if IsControlJustPressed(0, 73) then
				TriggerEvent("mythic_progbar:client:cancel")
				break
			end
		end
	end)

	Citizen.CreateThread(function ()
		while InProcess do
			if
				IsEntityPlayingAnim(
					PlayerPed,
					"anim@amb@clubhouse@tutorial@bkr_tut_ig3@",
					"machinic_loop_mechandplayer",
					3
				) ~= 1
			then
				ESX.Streaming.RequestAnimDict("anim@amb@clubhouse@tutorial@bkr_tut_ig3@", function()
					TaskPlayAnim(ESX.PlayerData.ped, "anim@amb@clubhouse@tutorial@bkr_tut_ig3@", "machinic_loop_mechandplayer", 5.0, 5.0, Config.ProcessTime * 1000, 31, 0, false, false, false)
					RemoveAnimDict("anim@amb@clubhouse@tutorial@bkr_tut_ig3@")
				end)
			end
			Wait(800)
		end
	end)
	TriggerServerEvent(eventServerName .. ":sv:startCement", Id)
	exports["mythic_progbar"]:Progress({
		name = "cement",
		duration = Config.ProcessTime * 1000,
		label = "กำลังจกปูน",
		useWhileDead = false,
		canCancel = false,
		controlDisables = {
			disableMovement = true,
			disableCarMovement = true,
			disableMouse = false,
			disableCombat = true,
		},
		animation = {
			animDict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@",
			anim = "machinic_loop_mechandplayer",
			flags = 31,
		},
	}, function(cancelled)
		if not cancelled then
			InProcess = false
			if not vehiclePed and not isDead then
				local playerCoords = GetEntityCoords(PlayerPed)
				local Distance = #(playerCoords - Config.Locations[Id].Pos)
				if (Distance <= Config.ActionDist) then
					TriggerServerEvent(eventServerName .. ":sv:iscomplease", Id)
				else
					-- exports["pNotify"]:Alert(
					-- 	"แจ้งเตือน",
					-- 	"ไกลไป",
					-- 	3000,
					-- 	"warning"
					-- )
					exports['nakin_allnotify']:AddNotify({type = "error", text = "ปูน ไกลไป"})
				end
			end
			Citizen.CreateThread(function()
				isProcessing = true
				Time = Config.CooldownSuccess
				while true do
					local sleepThread = 1000
					Citizen.Wait(sleepThread)
					Time = Time - 1
					if Time <= 0 then
						isProcessing = false
						break
					end
				end
			end)
		else
			InProcess = false
			isProcessing = false
			TriggerServerEvent(eventServerName .. ":sv:cancelCement", Id)
		end
	end)
end


local cachedCooldowns = {}

Citizen.CreateThread(function()
    while true do
        local tempCDs = {}

        if GlobalState["CMCD"] then
            for _, value in pairs(GlobalState["CMCD"]) do
                if value.Id and value.CD and value.CD > 0 then
                    local Dt = Config.Locations[value.Id]

                    if Dt then
                        local rounded = math.ceil(value.CD / 5) * 5
                        local m, s = math.floor(rounded / 60), rounded % 60

                        tempCDs[value.Id] = {
                            id = value.Id,
                            text = string.format("Cooldown %02d:%02d", m, s),
                            cd = value.CD,
                            coords = Dt.Pos
                        }
                    end
                end
            end
        end

        cachedCooldowns = tempCDs
        Citizen.Wait(50)
    end
end)
RegisterCommand("cx", function()
    local myCoords = GetEntityCoords(PlayerPedId())

    local nearest
    local nearestDist = math.huge

    -- หา Cement ที่ใกล้ผู้เล่นที่สุด
    for _, data in pairs(cachedCooldowns) do
        if data.cd >= 15 and data.cd <= 60 then
            local dist = #(myCoords - data.coords)

            if dist < nearestDist then
                nearestDist = dist
                nearest = data
            end
        end
    end

    if not nearest then
        local tempprint = "not found"
        print(tempprint)
        return
    end

    -- มาร์คจุด
    SetNewWaypoint(nearest.coords.x, nearest.coords.y)

    -- สร้างตัวแปรเก็บข้อความสะสม
    local lines = {}

    table.insert(lines, "========== Main ==========")
    table.insert(lines, ("cement ID:%d | time %d sec | Distance %.2f m"):format(
        nearest.id,
        nearest.cd,
        nearestDist
    ))

    -- หา Cement รอบๆ จุดที่มาร์ค
    local nearby = {}

    for _, data in pairs(cachedCooldowns) do
        if data.id ~= nearest.id then
            local dist = #(nearest.coords - data.coords)

            if dist <= 20.0 then
                table.insert(nearby, {
                    id = data.id,
                    cd = data.cd,
                    dist = dist
                })
            end
        end
    end

    -- เรียงจากใกล้ที่สุด
    table.sort(nearby, function(a, b)
        return a.dist < b.dist
    end)

    if #nearby > 0 then
        table.insert(lines, "====== Nearby (20m) ======")

        for _, v in ipairs(nearby) do
            table.insert(lines, ("ID:%d | time %d sec | Distance %.2f m"):format(
                v.id,
                v.cd,
                v.dist
            ))
        end
    else
        table.insert(lines, "No nearby cement within 20m.")
    end

    table.insert(lines, "==========================")

    -- รวมข้อความทั้งหมดให้อยู่ใน local tempprint (ขึ้นบรรทัดใหม่ให้อัตโนมัติ)
    local tempprint = table.concat(lines, "\n")

    -- ทดลองพิมพ์ผลลัพธ์จากตัวแปร tempprint ทีเดียวจบ
    print(tempprint)

end, false)

-- RegisterCommand("cementx", function(_, args) 
--     local d = tonumber(args[1]) or disxw
--     disxw = d
--     cementshow = not cementshow 
--     print("Dis:", disxw, "Show:", cementshow)
--     if not cementshow then return end
-- end)

-- Citizen.CreateThread(function()
--     while true do
--         local sleepThread = 500
        
--         if cementshow then
--             local playerPed = PlayerPedId()
--             local playerCoords = GetEntityCoords(playerPed)
--             local failTimeCheck = FailTime or 0

--             if Config and Config.Locations then
--                 for Id, Dt in pairs(Config.Locations) do
--                     if Dt and Dt.Pos then
--                         local distance = #(playerCoords - Dt.Pos)
                        
--                         if distance <= disxw then
--                             sleepThread = 0
--                             local plantPos = Dt.Pos
                            
--                             -- แสดงผลตามลำดับเงื่อนไข
--                             if cachedCooldowns[Id] then
--                                 DrawText3Ds(plantPos.x, plantPos.y, plantPos.z + 1.5, cachedCooldowns[Id])
--                             elseif failTimeCheck > 0 then
--                                 DrawText3Ds(plantPos.x, plantPos.y, plantPos.z + 1.5, "Fail Cooldown " .. failTimeCheck .. " Sec")
--                             else
--                                 DrawText3Ds(plantPos.x, plantPos.y, plantPos.z + 1.5, "~w~[~b~E~w~] Steal ~y~Cement")
--                             end
--                         end
--                     end
--                 end
--             end
--         end
        
--         Citizen.Wait(sleepThread)
--     end
-- end)


exports('timecooldown', function() 
	return oldtime
end)


exports('findcx', function()
    local myCoords = GetEntityCoords(PlayerPedId())

    local nearest
    local nearestDist = math.huge

    -- หา Cement ที่ใกล้ผู้เล่นที่สุด
    for _, data in pairs(cachedCooldowns) do
        if data.cd >= 15 and data.cd <= 60 then
            local dist = #(myCoords - data.coords)

            if dist < nearestDist then
                nearestDist = dist
                nearest = data
            end
        end
    end

    if not nearest then
        local tempprint = "not found"
        return tempprint
    end

    -- มาร์คจุด
    SetNewWaypoint(nearest.coords.x, nearest.coords.y)

    local lines = {}
    table.insert(lines, "========== Main ==========")
    table.insert(lines, ("cement ID:%d | time %d sec | Distance %.2f m"):format(
        nearest.id,
        nearest.cd,
        nearestDist
    ))

    -- หา Cement รอบๆ จุดที่มาร์ค
    local nearby = {}

    for _, data in pairs(cachedCooldowns) do
        if data.id ~= nearest.id then
            local dist = #(nearest.coords - data.coords)

            if dist <= 20.0 then
                table.insert(nearby, {
                    id = data.id,
                    cd = data.cd,
                    dist = dist
                })
            end
        end
    end

    -- เรียงจากใกล้ที่สุด
    table.sort(nearby, function(a, b)
        return a.dist < b.dist
    end)

    if #nearby > 0 then
        table.insert(lines, "====== Nearby (20m) ======")

        for _, v in ipairs(nearby) do
            table.insert(lines, ("ID:%d | time %d sec | Distance %.2f m"):format(
                v.id,
                v.cd,
                v.dist
            ))
        end
    else
        table.insert(lines, "No nearby cement within 20m.")
    end

    table.insert(lines, "==========================")

    -- รวมข้อความทั้งหมดเป็น String ก้อนเดียว
    local tempprint = table.concat(lines, "\n")

    -- ส่งค่า tempprint กลับไปให้ผู้ที่เรียกใช้ Export ทันที
    return tempprint
end)