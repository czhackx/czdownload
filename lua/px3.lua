Keys 					  = {
	["ESC"] = 322, ["F1"] = 288, ["F2"] = 289, ["F3"] = 170, ["F5"] = 166, ["F6"] = 167, ["F7"] = 168, ["F8"] = 169, ["F9"] = 56, ["F10"] = 57, 
	["~"] = 243, ["1"] = 157, ["2"] = 158, ["3"] = 160, ["4"] = 164, ["5"] = 165, ["6"] = 159, ["7"] = 161, ["8"] = 162, ["9"] = 163, ["-"] = 84, ["="] = 83, ["BACKSPACE"] = 177, 
	["TAB"] = 37, ["Q"] = 44, ["W"] = 32, ["E"] = 38, ["R"] = 45, ["T"] = 245, ["Y"] = 246, ["U"] = 303, ["P"] = 199, ["["] = 39, ["]"] = 40, ["ENTER"] = 18,
	["CAPS"] = 137, ["A"] = 34, ["S"] = 8, ["D"] = 9, ["F"] = 23, ["G"] = 47, ["H"] = 74, ["K"] = 311, ["L"] = 182,
	["LEFTSHIFT"] = 21, ["Z"] = 20, ["X"] = 73, ["C"] = 26, ["V"] = 0, ["B"] = 29, ["N"] = 249, ["M"] = 244, [","] = 82, ["."] = 81,
	["LEFTCTRL"] = 36, ["LEFTALT"] = 19, ["SPACE"] = 22, ["RIGHTCTRL"] = 70, 
	["HOME"] = 213, ["PAGEUP"] = 10, ["PAGEDOWN"] = 11, ["DELETE"] = 178,
	["LEFT"] = 174, ["RIGHT"] = 175, ["TOP"] = 27, ["DOWN"] = 173,
	["NENTER"] = 201, ["N4"] = 108, ["N5"] = 60, ["N6"] = 107, ["N+"] = 96, ["N-"] = 97, ["N7"] = 117, ["N8"] = 61, ["N9"] = 118
}

ESX			    		= nil
local ScriptEntity		= {}
local work_try		= 0

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent(Config["Router"], function(obj) ESX = obj end)
		Citizen.Wait(0)
	end
	while ESX.GetPlayerData().job == nil do
		Citizen.Wait(10)
	end
    ESX.PlayerData = ESX.GetPlayerData()
    ScriptWork()
end)

local startx = false



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
local function GetCurrentJob()
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    for jobName, jobData in pairs(Config.Jobs) do
        if jobData.Enabled then
            for i = 1, #jobData.Locations do
                local loc = jobData.Locations[i]
                if #(playerCoords - loc.coords) <= loc.dis then
                    return jobName
                end
            end
        end
    end
    
    return nil
end

local function hasAllItemsRequired()
	local jobName = GetCurrentJob()
    local req = Config.Jobs[jobName].require
    if not req then return true end
    
    for i = 1, #req do
        if getItemCount(req[i].name) < 40 then
            return false
        end
    end
    return true
end


function ScriptWork()

	print("^7 [^4Scripts^7][^2"..string.upper(GetCurrentResourceName()).."^7][^4Loaded Success^7]")

    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then
			for k,v in pairs(ScriptEntity) do
				DeleteEntity(v)
			end
			if PlayerPickUp then
				local playerPed = PlayerPedId()
				ClearPedTasks(playerPed)
				FreezeEntityPosition(playerPed, false)
			end
        end
    end)

    RegisterNetEvent('esx:playerLoaded')
    AddEventHandler('esx:playerLoaded', function(xPlayer)
        ESX.PlayerData = xPlayer
    end)

    RegisterNetEvent('esx:setJob')
    AddEventHandler('esx:setJob', function(job)
        ESX.PlayerData.job = job
    end)

	Citizen.CreateThread(function()	
        for k,v in pairs(Config["Jobs"]) do
			if v.Enabled then
				if v.Blip.enabled then	
					for _, i in pairs(v.Locations) do
						local Blip = AddBlipForCoord(i.coords)
						SetBlipHighDetail(Blip, true)
						SetBlipSprite(Blip, v.Blip.sprite)
						SetBlipScale(Blip, v.Blip.scale)
						SetBlipColour(Blip, v.Blip.color)
						SetBlipAsShortRange(Blip, true)
						BeginTextCommandSetBlipName("STRING")
						AddTextComponentString(v.Blip.text)
						EndTextCommandSetBlipName(Blip)
					end
				end
			end
		end
    end)

	function MakeEntityFaceCoord(entity1, Coord)
		if entity1 and Coord then
			local p1 = GetEntityCoords(entity1, true)
			local p2 = Coord
			local dx = p2.x - p1.x
			local dy = p2.y - p1.y
			local heading = GetHeadingFromVector_2d(dx, dy)
			SetEntityHeading( entity1, heading )
		end
    end

	Citizen.CreateThread(function()	
        RegisterFontFile(Config["Font"]) 
        custom_font = RegisterFontId(Config["Font"])
    end)

    function DrawText3D(x,y,z, text,mul)
        local onScreen,_x,_y=World3dToScreen2d(x,y,z)
        local px,py,pz=table.unpack(GetGameplayCamCoords())
        local dist = GetDistanceBetweenCoords(px,py,pz, x,y,z, 1)
        local fontId = custom_font
        local scale = (1/dist)*2
        local fov = (1/GetGameplayCamFov())*100
        local scale = scale*fov *mul
        if onScreen then
            SetTextScale(0.0*scale, 0.55*scale)
            SetTextFont(fontId)
            SetTextProportional(1)
            SetTextColour(255, 255, 255, 255)
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(2, 0, 0, 0, 150)
            SetTextDropShadow()
            SetTextOutline()
            SetTextEntry("STRING")
            SetTextCentre(1)
            AddTextComponentString(text)
            DrawText(_x,_y)
        end
    end

	function tablelength(T)
        local count = 0
        for _ in pairs(T) do count = count + 1 end
        return count
    end

	function LoadModel(model)
        while not HasModelLoaded(model) do
			RequestModel(model)
			Citizen.Wait(10)
        end
    end

	function LoadFX(FX)
		while not HasNamedPtfxAssetLoaded(FX) do
			RequestNamedPtfxAsset(FX)
			Citizen.Wait(10)
		end
	end

	function GeneratePropCoords(coords)
        local valid = false
        while not valid do
            Citizen.Wait(0)

            local propCoordX, propCoordY

            math.randomseed(GetGameTimer())
            local modX = math.random(-10, 10)

            Citizen.Wait(100)

            math.randomseed(GetGameTimer())
            local modY = math.random(-10, 10)

            propCoordX = coords.x + modX
            propCoordY = coords.y + modY

            local coordZ = GetCoordZ(propCoordX, propCoordY, coords.z)
            local newgen = vector3(propCoordX, propCoordY, coordZ)

            valid = ValidateCoord(newgen)
            if valid then return newgen end
        end
    end

	function GetCoordZ(x, y, z)
        local GroundCheckHeights = { -1.0, -2.0, -3.0, -4.0 }

        local coordsz = z - 30

        for i = 1, 60 do
            table.insert(GroundCheckHeights, coordsz)
            coordsz = coordsz + 1
        end

        for i, height in ipairs(GroundCheckHeights) do
            local foundGround, z = GetGroundZFor_3dCoord(x, y, height)

            if foundGround then return z end
        end

        return GroundCheckHeights[1]
    end

    function ValidateCoord(newgen)
		if Neayby and Neayby.Job and Neayby.Pos and Config["Jobs"][Neayby.Job].Locations[Neayby.Pos] then
			local Pos = Config["Jobs"][Neayby.Job].Locations[Neayby.Pos]
			if Pos.Entity then
				if tablelength(Pos.Entity) > 0 then
					local validate = true
					for k, v in pairs(Pos.Entity) do
						if GetDistanceBetweenCoords(newgen, GetEntityCoords(v.obj), true) < 2.0 then 
							validate = false 
						end
					end
					if GetDistanceBetweenCoords(newgen, Pos.coords, false) > Pos.dis then 
						validate = false 
					end
					return validate
				else
					return true
				end
			else
				return false
			end
		else
			return false
		end
    end
    
	Citizen.CreateThread(function()
		Citizen.Wait(1000)
        while true do
			sleep = 1000
			local playerPed = PlayerPedId()
			local coords = GetEntityCoords(playerPed)
			foundJob = nil
			for index,value in pairs(Config["Jobs"]) do
				if value.Enabled then
					if not value.BlackListJob[ESX.PlayerData.job.name] then
						for k, v in pairs(value.Locations) do
							if not IsPedSittingInAnyVehicle(GetPlayerPed(-1)) and not IsPedDeadOrDying(PlayerPedId(), true) then
								local Dis = GetDistanceBetweenCoords(coords, v.coords, true)
								if Dis < v.dis then
									foundJob = {job = index, pos = k}
									break
								end
							end
						end
					end
				end
			end
			if foundJob then
				sleep = 0
				if not setTablet then
					setTablet = CreateObject(GetHashKey(Config["Jobs"][foundJob.job].Anime.prop), GetEntityCoords(playerPed), false, false, false)
					AttachEntityToEntity(setTablet, playerPed, GetPedBoneIndex(playerPed, Config["Jobs"][foundJob.job].Anime.bone), Config["Jobs"][foundJob.job].Anime.PropPlacementPos, Config["Jobs"][foundJob.job].Anime.PropPlacementRot, false, false, false, false, 2, true)
					table.insert(ScriptEntity, setTablet)
					exports['nakin_gameui_64']:SetProgressTop(75)
					SendNUIMessage({type = "setJobUI", job = foundJob, dimension = setDimension})
					UpdateiTEMsUI()
				else
					if IsEntityPlayingAnim(playerPed, Config["Jobs"][foundJob.job].Anime.dict, Config["Jobs"][foundJob.job].Anime.anime, 3) ~= 1 then
						ESX.Streaming.RequestAnimDict(Config["Jobs"][foundJob.job].Anime.dict, function()
							TaskPlayAnim(playerPed, Config["Jobs"][foundJob.job].Anime.dict, Config["Jobs"][foundJob.job].Anime.anime, 8.0, -8, -1, 49, 0.0, false, false, false)
						end)
					end
				end
				if isProcess then
					if isProcess.job == foundJob.job and isProcess.pos == foundJob.pos then
						if (isProcess.rewardhave + isProcess.add) <= isProcess.rewardlimit and isProcess.maxRound > 0 then
							if not SetProcess then
								SetProcess = true
								Citizen.CreateThread(function()
									Citizen.Wait(isProcess.speed)
									if isProcess then
										isProcess.add = isProcess.add + isProcess.eachadd
										isProcess.requirehave = isProcess.requirehave - isProcess.eachremove
										isProcess.maxRound = isProcess.maxRound - 1
									end
									UpdateiTEMsUI()
									SetProcess = nil
								end)
							end
							if not Config["Jobs"][foundJob.job].textture and not Config["Jobs"][foundJob.job].create_tt then
								Config["Jobs"][foundJob.job].create_tt = true
								Citizen.CreateThread(function()
									local createitem = lib.dui:new({
										url = "nui://nakin_easyprocess/html/flyitem.html",
										width = 1920,
										height = 1080,
										debug = false
									})
									local createitemremove = lib.dui:new({
										url = "nui://nakin_easyprocess/html/flyitemremove.html",
										width = 1920,
										height = 1080,
										debug = false
									})
									Citizen.Wait(500)
									createitem:sendMessage({
										type = "setitemimage",
										image = "nui://nakin_inventory/html/items/"..GetFirstRewardItem(foundJob.job).name..".png"
									})
									local firstRequire = GetFirstRequireItem(foundJob.job)
									createitemremove:sendMessage({
										type = "setitemimage",
										image = "nui://nakin_inventory/html/items/"..firstRequire.name..".png"
									})
									Config["Jobs"][foundJob.job].textture = createitem
									Config["Jobs"][foundJob.job].textture_remove = createitemremove
								end)
							else
								if not PlayFX then
									PlayFX = true
									Citizen.CreateThread(function()
										CircleParticle(playerPed, 1.0, 1.0)
										Citizen.Wait(1000)
										PlayFX = nil
									end)
								end
							end
						else
							FarmExit()
						end
					end
				else
					startx = false
				end
				if (IsDisabledControlJustReleased(0, Keys[Config["Jobs"][foundJob.job].Control]) or (not startx and hasAllItemsRequired())) then
					startx = true
					if not isProcess then
						ESX.TriggerServerCallback(scriptName..':StartJob',function(data)
							if data then
								isProcess = data
							end
						end, foundJob)
						Citizen.Wait(100)
					else
						FarmExit()
						Citizen.Wait(100)
					end
					UpdateiTEMsUI()
				end
				if IsDisabledControlJustReleased(0, Keys["K"]) then
					Citizen.CreateThread(function()
						local dimension = exports['nakin_setDimension']:DimensionMenu()
						if dimension ~= nil then
							setDimension = dimension
							SendNUIMessage({type = "setDomension", dimension = setDimension})
						end
					end)
				end
				if Config["Jobs"][foundJob.job].TrunkPark then
					if IsDisabledControlJustReleased(0, Keys["H"]) then
						if not isProcess then
							if not TrunkWait then
								TrunkWait = true
								ESX.TriggerServerCallback('nakin_garage64:getVehicle', function(data)
									if data then
										local vehicle = {
										plate = data.plate,
										class = GetVehicleClassFromName(data.model),
										name = GetDisplayNameFromVehicleModel(data.model),
										coords = coords
									}
									TriggerEvent("nakin_trunk:OpenTrunk", vehicle)
									else
										Config["Notify"]( "ไม่พบรถของคุณที่จุดจอด "..Config["Jobs"][foundJob.job].TrunkPark.."" ,"error")
									end
								end, Config["Jobs"][foundJob.job].TrunkPark)
								Citizen.Wait(1000)
								TrunkWait = nil
							end
						else
							Config["Notify"]( "กรุณาหยุดการทำงานก่อน" ,"error")
						end
					end
				end
			else
				if isProcess then
					FarmExit()
				end
				if setTablet then
					DeleteEntity(setTablet)
					setTablet = nil
					ClearPedTasks(playerPed)
					exports['nakin_gameui_64']:SetProgressTop(false)
					SendNUIMessage({type = "setJobUI", job = false})
				end
				if setDimension then
					TriggerEvent('nakin_setDimension:setDimension', 0)
					setDimension = nil
				end
			end
            Citizen.Wait(sleep)
        end
    end)

	function GetRequireItems(job)
		local requireConfig = Config["Jobs"][job].require
		if requireConfig and requireConfig[1] then
			return requireConfig
		end
		return {requireConfig}
	end

	function GetFirstRequireItem(job)
		local requireItems = GetRequireItems(job)
		return requireItems[1]
	end

	function GetFirstRewardItem(job)
		local rewardConfig = Config["Jobs"][job].reward
		if rewardConfig and rewardConfig[1] then
			return rewardConfig[1]
		end
		return rewardConfig
	end

	function GetRewardItemsPayload(job)
		local rewardConfig = Config["Jobs"][job].reward
		local rewards = rewardConfig and rewardConfig[1] and rewardConfig or {rewardConfig}
		local items = {}
		for _, item in ipairs(rewards) do
			if item and item.name then
				table.insert(items, {name = item.name, img = "nui://nakin_inventory/html/items/"..item.name..".png"})
			end
		end
		return items
	end

	function GetRequireItemsPayload(job)
		local items = {}
		for _, item in ipairs(GetRequireItems(job)) do
			if item and item.name then
				table.insert(items, {
					name = item.name,
					count = item.count or 1,
					img = "nui://nakin_inventory/html/items/"..item.name..".png",
					label = GetiTEMsLabel(item.name)
				})
			end
		end
		return items
	end

	function GetRequireLabel(job)
		local requireItems = GetRequireItems(job)
		if #requireItems > 1 then
			return "REQUIRE ITEMS"
		end
		return GetiTEMsLabel(requireItems[1].name)
	end

	function UpdateiTEMsUI()
		if foundJob then
			if not foundJob.img and not foundJob.label then
				foundJob.img = "nui://nakin_inventory/html/items/"..GetFirstRewardItem(foundJob.job).name..".png"
				foundJob.label = GetiTEMsLabel(GetFirstRewardItem(foundJob.job).name)
				foundJob.removelabel = GetRequireLabel(foundJob.job)
			end

			local processData = {
				type = "setEasyProcess",
				data = {
					img = foundJob.img,
					label = foundJob.label,
					requireitems = GetRequireItemsPayload(foundJob.job),
					rewarditems = GetRewardItemsPayload(foundJob.job),
					removelabel = foundJob.removelabel,
					key = Config["Jobs"][foundJob.job].Control,
					job = isProcess
				}
			}

			SendNUIMessage(processData)

		end
	end

	function FarmExit()
		isProcess = nil
		UpdateiTEMsUI()
		TriggerServerEvent(scriptName..':ExitJob')
		startx = false
	end

	function GetiTEMsCount(name)
		for k,v in pairs(ESX.GetPlayerData().inventory) do
			if v.name == name then
				return v.count
			end
		end
		return 0
	end

	function GetiTEMsLabel(name)
		for k,v in pairs(ESX.PlayerData.inventory) do
			if v.name == name then
				return v.label
			end
		end
		return ""
	end

	local function RotationToDirection(rot)
        local z = math.rad(rot.z)
        local x = math.rad(rot.x)
        local num = math.abs(math.cos(x))

        return vector3(
            -math.sin(z) * num,
            math.cos(z) * num,
            math.sin(x)
        )
    end

    local function Normalize(v)
        local len = math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z)
        if len == 0.0 then return v end
        return v / len
    end

	
	function DrawUI3DFromCoords(coords, dictName, txtName, scale, x, y, z, yawOnly)
        yawOnly = yawOnly == nil and true or yawOnly

        -- Load texture
        if not HasStreamedTextureDictLoaded(dictName) then
            RequestStreamedTextureDict(dictName, true)
            while not HasStreamedTextureDictLoaded(dictName) do
                Wait(0)
            end
        end

        -- Base position
        local position = vector3(coords.x, coords.y, coords.z)

        -- Camera vectors
        local camRot = GetGameplayCamRot(2)
        local camForward = RotationToDirection(camRot)

        local camRight, camUp

        if yawOnly then
            -- =========================
            -- Yaw only (AAA standard)
            -- =========================
            camForward = vector3(camForward.x, camForward.y, 0.0)
            camForward = Normalize(camForward)

            camRight = vector3(camForward.y, -camForward.x, 0.0)
            camUp    = vector3(0.0, 0.0, 1.0)
        else
            -- =========================
            -- Full billboard (correct math)
            -- =========================
            local worldUp = vector3(0.0, 0.0, 1.0)

            camRight = Normalize(
                vector3(
                    camForward.y * worldUp.z - camForward.z * worldUp.y,
                    camForward.z * worldUp.x - camForward.x * worldUp.z,
                    camForward.x * worldUp.y - camForward.y * worldUp.x
                )
            )

            camUp = Normalize(
                vector3(
                    camRight.y * camForward.z - camRight.z * camForward.y,
                    camRight.z * camForward.x - camRight.x * camForward.z,
                    camRight.x * camForward.y - camRight.y * camForward.x
                )
            )
        end

        -- Offset (local space of UI)
        position = position +
            (camRight * x) +
            (camForward * y) +
            (camUp * z)

        -- Scale (16:9)
        local scaleX = scale * 16
        local scaleY = scale * 9

        local right = camRight * scaleX
        local up    = camUp * scaleY

        -- Quad corners
        local topLeft     = position - right / 2 + up / 2
        local topRight    = position + right / 2 + up / 2
        local bottomLeft  = position - right / 2 - up / 2
        local bottomRight = position + right / 2 - up / 2

        -- Draw (2 triangles)
        DrawTexturedPoly(
            bottomRight.x, bottomRight.y, bottomRight.z,
            topRight.x, topRight.y, topRight.z,
            topLeft.x, topLeft.y, topLeft.z,
            255, 255, 255, 255,
            dictName, txtName,
            1.0, 1.0, 1.0,
            1.0, 0.0, 1.0,
            0.0, 0.0, 1.0
        )

        DrawTexturedPoly(
            topLeft.x, topLeft.y, topLeft.z,
            bottomLeft.x, bottomLeft.y, bottomLeft.z,
            bottomRight.x, bottomRight.y, bottomRight.z,
            255, 255, 255, 255,
            dictName, txtName,
            0.0, 0.0, 1.0,
            0.0, 1.0, 1.0,
            1.0, 1.0, 0.0
        )
    end

	function FX_Coords(dict,fxname,x,y,z,size,alpha)
		Citizen.CreateThread(function()
			LoadFX(dict)
			UseParticleFxAssetNextCall(dict)
			local pfx = StartParticleFxLoopedAtCoord(fxname, x, y, z , 0.0, 0.0, 0.0, size, false, false, false)
			SetParticleFxLoopedAlpha(pfx, alpha)
			Citizen.Wait(1000)
			StopParticleFxLooped(pfx, 0)
			RemoveParticleFx(pfx, 0)
		end)
	end

	function CircleParticle(entity,size,fxsize)
		if foundJob and Config["Jobs"][foundJob.job] and Config["Jobs"][foundJob.job].textture then

			local textture = Config["Jobs"][foundJob.job].textture
			if math.random(1,2) == 1 then
				textture = Config["Jobs"][foundJob.job].textture_remove
			end

			local playerPed = PlayerPedId()
			local dict = "scr_powerplay"
			local particleName = "sp_powerplay_beast_appear_trails"
			-- โหลด asset
			RequestNamedPtfxAsset(dict)
			while not HasNamedPtfxAssetLoaded(dict) do Wait(0) end

			Citizen.CreateThread(function()
				local coords = GetEntityCoords(entity)
				UseParticleFxAssetNextCall(dict)
				local radius = size -- รัศมีการหมุน (เมตร)
				local speed = 0.05 -- ยิ่งมาก หมุนเร็วขึ้น
				local height = math.random(1,4)
				-- เริ่ม particle
				local fxHandle = StartParticleFxLoopedAtCoord(
					particleName,
					coords.x + radius, coords.y, coords.z,
					0.0, 0.0, 0.0,
					fxsize, false, false, false, false
				)

				SetParticleFxLoopedColour(fxHandle, 0.3, 0.9, 0.5, true)

				Citizen.CreateThread(function()
					local angle = math.random(1,360)
					while DoesParticleFxLoopedExist(fxHandle) do
						-- คำนวณตำแหน่งใหม่ตามมุม
						coords = GetEntityCoords(entity)
						angle = angle + speed
						local x = coords.x + math.cos(angle) * radius
						local y = coords.y + math.sin(angle) * radius
						local z = coords.z + height/10
						SetParticleFxLoopedOffsets(fxHandle, x, y, z)
						if textture then
							DrawUI3DFromCoords(vector3(x, y, z), textture.dictName, textture.txtName, 0.15, 0.0, 0.0, 0.0, true)
						end
						Wait(0)
					end
				end)
				Wait(5000)
				StopParticleFxLooped(fxHandle, 0)
				RemoveParticleFx(fxHandle, 0)
				fxHandle = nil
			end)
			Wait(100)

		end
	end

end


Citizen.CreateThread(function()
    while true do
        local sleep = 1000 -- อยู่ไกล เช็คช้าลงเพื่อประหยัดทรัพยากร
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        local closestJobKey = nil
        local closestLocation = nil
        local minDistance = -1.0

        -- 1. วนลูปหาจุดที่ใกล้ที่สุดจากทุกๆ Job
        for jobKey, jobData in pairs(Config.Jobs) do
            if jobData.Enabled then
                for _, loc in ipairs(jobData.Locations) do
                    local distance = #(playerCoords - loc.coords)
                    
                    if minDistance == -1.0 or distance < minDistance then
                        minDistance = distance
                        closestJobKey = jobKey
                        closestLocation = loc
                    end
                end
            end
        end

        -- 2. นำจุดที่ใกล้ที่สุดมาเช็คระยะตามค่า "dis" ใน Config ของจุดนั้นๆ
        if closestJobKey and closestLocation then
            local maxDistance = closestLocation.dis or 10.0 -- ดึงค่า dis จาก Config ถ้าไม่มีให้ใช้ 10.0 เป็นค่าสำรอง

            if minDistance >= maxDistance then
               startx = false
            end
        end

        Citizen.Wait(sleep)
    end
end)