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
local activeJobZoneKey	= nil
local easyJobUiZoneKey	= nil
local nextFarmAllowedAt	= 0
local nextPropSpawnAt	= 0

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
local itemnamejobx = nil
function ScriptWork()

	print("^7 [^4Scripts^7][^2"..string.upper(GetCurrentResourceName()).."^7][^4Loaded Success^7]")

    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then
			ClearAllJobProps()
			for k,v in pairs(ScriptEntity) do
				DeleteEntity(v)
			end
			CloseEasyJobUI()
			SetNuiFocus(false, false)
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

	function CloseEasyJobUI()
		if easyJobUiOpen then
			exports['nakin_gameui_64']:SetProgressTop(false)
			SendNUIMessage({type = "setJobUI", job = false})
			SendNUIMessage({type = "showEasyJob", show = false})
			easyJobUiOpen = nil
			easyJobUiZoneKey = nil
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

	function StartPropSpinThread()
		Citizen.CreateThread(function()
			while true do
				local sleep = 1000

				for _, jobConfig in pairs(Config["Jobs"]) do
					if jobConfig.Locations then
						for _, location in pairs(jobConfig.Locations) do
							if location.Entity then
								for propKey, entityData in pairs(location.Entity) do
									if not entityData.flying and entityData.spin and entityData.spin ~= 0 and entityData.obj and DoesEntityExist(entityData.obj) then
										sleep = 0
										local heading = GetEntityHeading(entityData.obj) + (entityData.spin * GetFrameTime() * 60.0)
										if heading >= 360.0 or heading <= -360.0 then
											heading = heading % 360.0
										end
										SetEntityHeading(entityData.obj, heading)
									elseif entityData.obj and not DoesEntityExist(entityData.obj) then
										location.Entity[propKey] = nil
									end
								end
							end
						end
					end
				end

				Citizen.Wait(sleep)
			end
		end)
	end

	StartPropSpinThread()

	function IsJobControlJustReleased(control)
		local key = Keys[control]
		return key and (IsControlJustReleased(0, key) or IsDisabledControlJustReleased(0, key))
	end

	function GeneratePropCoords(coords, fixground)
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
			if fixground ~= nil then
				coordZ = coords.z + fixground
			end
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

	function GetJobPropList(job)
		return Config["Jobs"][job].JobProp or {
			{name = Config["Jobs"][job].PropModel or "prop_apple_box_01", size = Config["Jobs"][job].PropSize or 1.5}
		}
	end

	function RunJobSpawnFx(job, coords)
		if Config["Jobs"][job].Spawn then
			pcall(Config["Jobs"][job].Spawn, coords)
		elseif Config["Spawn"] and Config["Spawn"][job] then
			pcall(Config["Spawn"][job], coords)
		end
	end

	function RunJobPickUpSuccess(job, pos, coords)
		if Config["Jobs"][job].PickUpSuccess then
			local ok, result = pcall(Config["Jobs"][job].PickUpSuccess, job, pos, coords)
			return ok and result ~= false
		elseif Config["PickUP"] and Config["PickUP"][job] then
			local ok, result = pcall(Config["PickUP"][job], coords)
			return ok and result ~= false
		end
		return true
	end

	function ClearJobProps(job, pos)
		if job and pos and Config["Jobs"][job] and Config["Jobs"][job].Locations[pos] and Config["Jobs"][job].Locations[pos].Entity then
			for _, entityData in pairs(Config["Jobs"][job].Locations[pos].Entity) do
				if entityData.obj and DoesEntityExist(entityData.obj) then
					DeleteEntity(entityData.obj)
				end
			end
			Config["Jobs"][job].Locations[pos].Entity = nil
		end
	end

	function ClearAllJobProps()
		for job, jobConfig in pairs(Config["Jobs"]) do
			for pos, _ in pairs(jobConfig.Locations) do
				ClearJobProps(job, pos)
			end
		end
	end

	function FX_Coords(dict,fxname,x,y,z,size)
		Citizen.CreateThread(function()
			LoadFX(dict)
			UseParticleFxAssetNextCall(dict)
			local pfx = StartParticleFxLoopedAtCoord(fxname, x, y, z , 0.0, 0.0, 0.0, size, false, false, false)
			Citizen.Wait(1000)
			StopParticleFxLooped(pfx, 0)
			RemoveParticleFx(pfx, 0)
			return pfx
		end)
	end

	function FX_Entity(dict,fxname,entity,x,y,z,size)
		Citizen.CreateThread(function()
			LoadFX(dict)
			UseParticleFxAssetNextCall(dict)
			local pfx = StartParticleFxLoopedOnEntity(fxname, entity, x,y,z, 0.0, 0.0, 0.0, size, false, false, false)
			SetParticleFxLoopedColour(pfx, 0.3, 0.9, 0.5, true)
			Citizen.Wait(1000)
			StopParticleFxLooped(pfx, 0)
			RemoveParticleFx(pfx, 0)
			return pfx
		end)
	end

	function EnsureJobProps(job, pos)
		local jobConfig = Config["Jobs"][job]
		local location = jobConfig and jobConfig.Locations[pos]
		if not location then return end

		if not location.Entity then
			location.Entity = {}
		end

		local limitProp = jobConfig.LimitProp or 8
		if tablelength(location.Entity) >= limitProp then return end
		if nextPropSpawnAt and GetGameTimer() < nextPropSpawnAt then return end

		nextPropSpawnAt = GetGameTimer() + (jobConfig.PropSpawnDelay or 1000)
		Neayby = {Job = job, Pos = pos}

		local propList = GetJobPropList(job)
		local prop = propList[math.random(1, #propList)]
		local posCoords = GeneratePropCoords(location.coords, jobConfig.FixGroundCoords)
		LoadModel(prop.name)

		local obj = CreateObject(GetHashKey(prop.name), posCoords, false, false, false)
		if jobConfig.FixGroundCoords == nil then
			PlaceObjectOnGroundProperly(obj)
		end
		FreezeEntityPosition(obj, true)
		SetEntityHeading(obj, tonumber(""..math.random(1,360)..".0"))

		local propSpin = jobConfig.PropSpin and tonumber(jobConfig.PropSpin) or nil
		table.insert(location.Entity, {obj = obj, size = prop.size or 1.5, spin = propSpin})
		table.insert(ScriptEntity, obj)
		RunJobSpawnFx(job, posCoords)
	end

	function GetClosestJobProp(job, pos, coords)
		local location = Config["Jobs"][job] and Config["Jobs"][job].Locations[pos]
		if not location or not location.Entity then return nil, nil end

		local closestKey = nil
		local closestData = nil
		local closestDistance = 9999.0

		for propKey, entityData in pairs(location.Entity) do
			if entityData.obj and DoesEntityExist(entityData.obj) then
				local objCoords = GetEntityCoords(entityData.obj)
				local distance = GetDistanceBetweenCoords(coords, objCoords, true)
				if distance < closestDistance then
					closestKey = propKey
					closestData = entityData
					closestDistance = distance
				end
			end
		end

		return closestKey, closestData
	end

	function TaskToJobProp(job, pos, propKey)
		if PedTask or PlayerPickUp then return end

		local location = Config["Jobs"][job] and Config["Jobs"][job].Locations[pos]
		local entityData = location and location.Entity and location.Entity[propKey]
		if not entityData or not entityData.obj or not DoesEntityExist(entityData.obj) then return end

		PedTask = true
		Citizen.CreateThread(function()
			while PedTask and isFarming and isFarming.job == job and isFarming.pos == pos and not PlayerPickUp do
				if not entityData.obj or not DoesEntityExist(entityData.obj) then
					break
				end

				local playerPed = PlayerPedId()
				local playerCoords = GetEntityCoords(playerPed)
				local objCoords = GetEntityCoords(entityData.obj)
				local distance = GetDistanceBetweenCoords(playerCoords, objCoords, true)

				if distance <= (entityData.size or 1.5) then
					PedTask = false
					PickUpJobProp(job, pos, propKey)
					return
				end

				TaskGoStraightToCoord(playerPed, objCoords.x, objCoords.y, objCoords.z, 2.0, -1, 0.0, 0.5)
				Citizen.Wait(500)
			end

			PedTask = false
		end)
	end

	function PickUpJobProp(job, pos, propKey)
		if PlayerPickUp then return end

		local jobConfig = Config["Jobs"][job]
		local location = jobConfig and jobConfig.Locations[pos]
		local entityData = location and location.Entity and location.Entity[propKey]
		if not entityData or not entityData.obj or not DoesEntityExist(entityData.obj) then return end

		PlayerPickUp = true
		local playerPed = PlayerPedId()
		local objCoords = GetEntityCoords(entityData.obj)
		MakeEntityFaceCoord(playerPed, objCoords)
		FreezeEntityPosition(playerPed, true)

		local pickupAnim = jobConfig.PickupAnimation or {dict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@", anim = "machinic_loop_mechandplayer", flags = 1}
		ESX.Streaming.RequestAnimDict(pickupAnim.dict, function()
			TaskPlayAnim(playerPed, pickupAnim.dict, pickupAnim.anim, 8.0, -8.0, -1, pickupAnim.flags or 1, 0, false, false, false)
		end)

		Citizen.Wait(jobConfig.FakePickupTime or 800)
		ClearPedTasks(playerPed)
		FreezeEntityPosition(playerPed, false)

		if RunJobPickUpSuccess(job, pos, objCoords) then
			if DoesEntityExist(entityData.obj) then
				DeleteEntity(entityData.obj)
			end
			location.Entity[propKey] = nil
			pcall(function()
				PlayFarmFX(objCoords, jobConfig.Locations[pos].dis, 3.0)
			end)
			UpdateiTEMsUI()
		end
		PlayerPickUp = false
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
				local currentJobZoneKey = foundJob.job..":"..foundJob.pos
				if activeJobZoneKey ~= currentJobZoneKey then
					if isFarming and (isFarming.job ~= foundJob.job or isFarming.pos ~= foundJob.pos) then
						FarmExit()
					end
					ClearAllJobProps()
					CloseEasyJobUI()
					activeJobZoneKey = currentJobZoneKey
					nextFarmAllowedAt = GetGameTimer() + 1000
				end
				if GetGameTimer() >= nextFarmAllowedAt then
					sleep = 0
					Neayby = {Job = foundJob.job, Pos = foundJob.pos}
					if not easyJobUiOpen or easyJobUiZoneKey ~= currentJobZoneKey then
						exports['nakin_gameui_64']:SetProgressTop(75)
						SendNUIMessage({type = "setJobUI", job = foundJob, dimension = setDimension})
						easyJobUiOpen = true
						easyJobUiZoneKey = currentJobZoneKey
						SendNUIMessage({type = "showEasyJob", show = true})
						UpdateiTEMsUI()
					end
					EnsureJobProps(foundJob.job, foundJob.pos)

					if isFarming then
						if isFarming.job == foundJob.job and isFarming.pos == foundJob.pos then
							if IsJobControlJustReleased(Config["Jobs"][foundJob.job].Control) then
								local itemLabel = GetRewardLabel(foundJob.job)
								Config["Notify"]("หยุดฟาร์ม "..itemLabel.." แล้ว", "error")
								FarmExit()
								Citizen.Wait(1000)
							end
							if isFarming and (isFarming.have + isFarming.add) < isFarming.limit then
								if not SetProcess then
									SetProcess = true
									Citizen.CreateThread(function()
										Citizen.Wait(isFarming.speed)
										if isFarming then
											local remaining = isFarming.limit - (isFarming.have + isFarming.add)
											if remaining > 0 then
												isFarming.add = isFarming.add + math.min(isFarming.eachadd, remaining)
											end
											if (isFarming.have + isFarming.add) >= isFarming.limit then
												UpdateiTEMsUI()
												SetProcess = nil
												FarmExit()
												return
											end
										end
										UpdateiTEMsUI()
										SetProcess = nil
									end)
								end

								if not PedTask and not PlayerPickUp then
									if not Config["FlyObject"] then
										local propKey = GetClosestJobProp(foundJob.job, foundJob.pos, coords)
										if propKey then
											TaskToJobProp(foundJob.job, foundJob.pos, propKey)
										end
									else
										if not WaitFlyTime then
											WaitFlyTime = true
											local propObject, objectdata = GetClosestJobProp(foundJob.job, foundJob.pos, coords)
											if propObject and objectdata then
												ObjectFlyEffect(objectdata.obj, foundJob.job, foundJob.pos, propObject)
											end
											Citizen.CreateThread(function()
												Citizen.Wait(3000)
												WaitFlyTime = nil
											end)
										end
									end
								end
							else
								FarmExit()
							end
						else
							FarmExit()
						end
					elseif (IsJobControlJustReleased(Config["Jobs"][foundJob.job].Control) or (not startx and getItemCount(Config["Jobs"][foundJob.job].reward.name) < 40)) then
						startx = true
						local itemLabel = GetRewardLabel(foundJob.job)
						local startJob = {job = foundJob.job, pos = foundJob.pos}
						local startJobZoneKey = currentJobZoneKey
						ESX.TriggerServerCallback(scriptName..':StartJob',function(data)
							if data then
								if foundJob and foundJob.job == startJob.job and foundJob.pos == startJob.pos and activeJobZoneKey == startJobZoneKey then
									isFarming = data
								else
									TriggerServerEvent(scriptName..':ExitJob')
									startx = false
									return
								end
								Config["Notify"]("เริ่มฟาร์ม "..itemLabel.." แล้ว", "success")
							end
						end, startJob)
						Citizen.Wait(1000)
						UpdateiTEMsUI()
					end
					if IsJobControlJustReleased("K") then
						Citizen.CreateThread(function()
							local dimension = exports['nakin_setDimension']:DimensionMenu()
							if dimension ~= nil then
								setDimension = dimension
								SendNUIMessage({type = "setDomension", dimension = setDimension})
							end
						end)
					end
					if Config["Jobs"][foundJob.job].TrunkPark then
						if IsJobControlJustReleased("H") then

							ESX.TriggerServerCallback(scriptName..':checkVip', function(isVip)

								if not isVip then
									Config["Notify"]("เฉพาะ VIP เท่านั้นที่เปิดท้ายรถได้", "error")
									return
								end

								if not isFarming then
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
												Config["Notify"]("ไม่พบรถของคุณที่จุดจอด "..Config["Jobs"][foundJob.job].TrunkPark.."","error")
											end
										end, Config["Jobs"][foundJob.job].TrunkPark)

										Citizen.Wait(1000)
										TrunkWait = nil
									end
								else
									Config["Notify"]("กรุณาหยุดการทำงานก่อน","error")
								end

							end)

						end
					end
				end
			else
				activeJobZoneKey = nil
				easyJobUiZoneKey = nil
				Neayby = nil
				nextFarmAllowedAt = 0
				if isFarming then
					FarmExit()
				end
				ClearAllJobProps()
				if easyJobUiOpen then
					ClearPedTasks(playerPed)
					CloseEasyJobUI()
				end
				if setDimension then
					print("Reset Dimension to 0")
					TriggerEvent('nakin_setDimension:setDimension', 0)
					setDimension = nil
				end
			end
            Citizen.Wait(sleep)
        end
    end)

	RegisterNetEvent('esx:addInventoryItem')
	AddEventHandler('esx:addInventoryItem', function(item, count)
		if isFarming and Config["Jobs"][isFarming.job] and Config["Jobs"][isFarming.job].reward.name == item then
			FarmExit()
		end
	end)

	RegisterNetEvent(scriptName..':RewardUpdated')
	AddEventHandler(scriptName..':RewardUpdated', function(count, limit)
		if easyJobUiOpen and foundJob then
			if not foundJob.img then
				foundJob.img = "nui://nakin_inventory/html/items/"..Config["Jobs"][foundJob.job].reward.name..".png"
			end
			SendNUIMessage({
				type = "setEasyJob",
				data = {
					img = foundJob.img,
					label = GetRewardLabel(foundJob.job),
					key = Config["Jobs"][foundJob.job].Control,
					count = count or GetiTEMsCount(Config["Jobs"][foundJob.job].reward.name),
					limit = limit or GetiTEMsLimit(Config["Jobs"][foundJob.job].reward.name),
					job = false
				}
			})
		end
	end)

	function UpdateiTEMsUI()
		if easyJobUiOpen and foundJob then
			if not foundJob.img then
				foundJob.img = "nui://nakin_inventory/html/items/"..Config["Jobs"][foundJob.job].reward.name..".png"
			end
			SendNUIMessage({
				type = "setEasyJob",
				data = {
					img = foundJob.img,
					label = GetRewardLabel(foundJob.job),
					key = Config["Jobs"][foundJob.job].Control,
					count = GetiTEMsCount(Config["Jobs"][foundJob.job].reward.name),
					limit = GetiTEMsLimit(Config["Jobs"][foundJob.job].reward.name),
					job = isFarming
				}
			})
		end
	end

	function FarmExit()
		if isFarming then
			ClearJobProps(isFarming.job, isFarming.pos)
		end
		PedTask = false
		PlayerPickUp = false
		startx = false
		ClearPedTasks(PlayerPedId())
		isFarming = nil
		UpdateiTEMsUI()
		TriggerServerEvent(scriptName..':ExitJob')
	end

	function GetiTEMsCount(name)
		for k,v in pairs(ESX.GetPlayerData().inventory) do
			if v.name == name then
				return v.count
			end
		end
		return 0
	end

	function GetiTEMsLimit(name)
		for k,v in pairs(ESX.GetPlayerData().inventory) do
			if v.name == name then
				return v.limit or 0
			end
		end
		return 0
	end

	function GetiTEMsLabel(name)
		local playerData = ESX.GetPlayerData()
		for k,v in pairs(playerData.inventory or {}) do
			if v.name == name then
				return v.label
			end
		end
		return ""
	end

	function GetRewardLabel(job)
		local reward = Config["Jobs"][job] and Config["Jobs"][job].reward
		if not reward or not reward.name then
			return "Unknown"
		end

		local label = GetiTEMsLabel(reward.name)
		if label and label ~= "" then
			return label
		end

		return reward.label or reward.name
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

	function PlayFarmFX(coords, size, fxsize)
		if foundJob and Config["Jobs"][foundJob.job] then

			local playerPed = PlayerPedId()
			local dict = "scr_powerplay"
			local particleName = "sp_powerplay_beast_appear_trails"

			RequestNamedPtfxAsset(dict)
			while not HasNamedPtfxAssetLoaded(dict) do Wait(0) end

			FX_Coords("scr_rcbarry1","scr_alien_charging",coords.x,coords.y,coords.z, 1.0, 0.05)

			if not coords then
				coords = GetEntityCoords(playerPed)
			end

			for i = 1, 5 do

				Citizen.CreateThread(function()

					UseParticleFxAssetNextCall(dict)

					local spawnRadius = size -- ระยะสุ่มรอบตัว
					local angle = math.rad(math.random(0,360))

					local startX,startY,startZ = table.unpack(GetOffsetFromEntityInWorldCoords(playerPed, math.random(-size, size) + 0.0, math.random(-size, size) + 0.0, 0.0))

					local fxHandle = StartParticleFxLoopedAtCoord(
						particleName,
						startX, startY, startZ,
						0.0, 0.0, 0.0,
						fxsize, false, false, false, false
					)

					SetParticleFxLoopedColour(fxHandle, 0.3, 0.9, 0.5, true)

					Citizen.CreateThread(function()

						local currentX = startX
						local currentY = startY
						local currentZ = startZ

						local speed = 8.0

						while DoesParticleFxLoopedExist(fxHandle) do

							local targetCoords = GetEntityCoords(playerPed)

							local delta = GetFrameTime()

							-- 🔹 คำนวณทิศทาง
							local dirX = targetCoords.x - currentX
							local dirY = targetCoords.y - currentY
							local dirZ = targetCoords.z - currentZ

							-- ระยะห่าง
							local distance = math.sqrt(dirX*dirX + dirY*dirY + dirZ*dirZ)

							if distance < 0.5 then
								break -- ถึงตัวแล้ว
							end

							-- normalize
							dirX = dirX / distance
							dirY = dirY / distance
							dirZ = dirZ / distance

							-- ขยับเข้าไป
							currentX = currentX + dirX * speed * delta
							currentY = currentY + dirY * speed * delta
							currentZ = currentZ + dirZ * speed * delta

							SetParticleFxLoopedOffsets(fxHandle, currentX, currentY, currentZ)
							Wait(0)
						end

						StopParticleFxLooped(fxHandle, 0)
						RemoveParticleFx(fxHandle, 0)
						fxHandle = nil

					end)

				end)

				Wait(200)

			end

		end
	end

	function ObjectFlyEffect(entity, job, pos, propKey)
		local playerPed = PlayerPedId()
		local entitycoords = GetEntityCoords(entity)
		local obj = entity
		if job and pos and propKey and Config["Jobs"][job] and Config["Jobs"][job].Locations[pos] and Config["Jobs"][job].Locations[pos].Entity then
			local entityData = Config["Jobs"][job].Locations[pos].Entity[propKey]
			if entityData then
				entityData.flying = true
				entityData.spin = nil
			end
		end
		FreezeEntityPosition(obj, true)
		SetEntityHeading(obj, tonumber(""..math.random(1,360)..".0"))
		table.insert(ScriptEntity, obj)
		SetEntityNoCollisionEntity(playerPed,obj, true)
		SetEntityNoCollisionEntity(obj,playerPed, true)

		UseParticleFxAssetNextCall("scr_powerplay")
		local fxhandle = StartParticleFxLoopedAtCoord("sp_powerplay_beast_appear_trails", entitycoords.x, entitycoords.y, entitycoords.z , 0.0, 0.0, 0.0, 1.0, false, false, false)
		SetParticleFxLoopedColour(fxhandle, 0.3, 0.9, 0.5, true)

		local rot = 0.0
		local rottype = 3
		
		Citizen.CreateThread(function()
			local startCoords = GetEntityCoords(obj)
			local progress = 0.1
			local flySpeed = 0.018
			local arcHeight = 2.2
			local minScale = 0.15

			TriggerEvent('InteractSound_CL:PlayOnOne', "subhaki", 0.02)

			while true do
				if not DoesEntityExist(obj) then break end

				local target = GetEntityCoords(playerPed)
				local distance = #(target - startCoords)
				local curveHeight = math.max(arcHeight, distance * 0.18)
				progress = math.min(progress + flySpeed, 1.0)

				local curve = math.sin(progress * math.pi) * curveHeight
				local move = vector3(
					startCoords.x + (target.x - startCoords.x) * progress,
					startCoords.y + (target.y - startCoords.y) * progress,
					startCoords.z + (target.z - startCoords.z) * progress + curve
				)

				SetEntityCoords(obj, move)
				local scale = math.max(minScale, 1.0 - progress)
				SetParticleFxLoopedOffsets(fxhandle, move.x, move.y, move.z)

				if progress >= 1.0 or #(target - move) < 0.5 then
					FX_Entity("scr_rcbarry1","scr_alien_impact_bul",playerPed, 0.0, 0.0, 0.0, 2.0)
					SetEntityAsMissionEntity(obj, true, true)
					DeleteObject(obj)
					DeleteEntity(obj)
					TriggerEvent('InteractSound_CL:PlayOnOne', "success", 0.02)
					if job and pos and propKey and Config["Jobs"][job] and Config["Jobs"][job].Locations[pos] and Config["Jobs"][job].Locations[pos].Entity then
						Config["Jobs"][job].Locations[pos].Entity[propKey] = nil
					end
					break
				end

				-- หมุน ๆ
				if rot < 360 then
					rot = rot + 8
				else
					rot = 0.0
				end
				if rottype == 1 then
					SetEntityRotation(obj, rot, 0.0, 0.0)
				elseif rottype == 2 then
					SetEntityRotation(obj, 0.0, rot, 0.0)
				elseif rottype == 3 then
					SetEntityRotation(obj, 0.0, 0.0, rot)
				end
				SetEntityScale(obj, scale, scale, scale)

				Citizen.Wait(10)
			end

			StopParticleFxLooped(fxhandle, 0)
			RemoveParticleFx(fxhandle, 0)
			
		end)
	end

	function SetEntityScale(entity, scaleX, scaleY, scaleZ)

		if GetEntityType(entity) == 1 then
			local attachedEntity = GetEntityAttachedTo(entity)
			if IsPedInAnyVehicle(entity, false) then
				entity = GetVehiclePedIsIn(entity, false)
			elseif DoesEntityExist(attachedEntity) then
				entity = attachedEntity
			end
		end

		local rightVector, forwardVector, upVector, position = GetEntityMatrix(entity)

		rightVector = vector3(rightVector.x / #(rightVector), rightVector.y / #(rightVector), rightVector.z / #(rightVector))
		forwardVector = vector3(forwardVector.x / #(forwardVector), forwardVector.y / #(forwardVector), forwardVector.z / #(forwardVector))
		upVector = vector3(upVector.x / #(upVector), upVector.y / #(upVector), upVector.z / #(upVector))

		rightVector = {x = rightVector.x * scaleX, y = rightVector.y * scaleX, z = rightVector.z * scaleX}
		forwardVector = {x = forwardVector.x * scaleY, y = forwardVector.y * scaleY, z = forwardVector.z * scaleY}
		upVector = {x = upVector.x * scaleZ, y = upVector.y * scaleZ, z = upVector.z * scaleZ}

		SetEntityMatrix(entity,
			rightVector.x, rightVector.y, rightVector.z,
			forwardVector.x, forwardVector.y, forwardVector.z,
			upVector.x, upVector.y, upVector.z,
			position.x, position.y, position.z
		)
	end

end


local vehicle = nil

RegisterCommand("spl", function(_, args) 
    local modelName = 'rallytruck'
    local plateText1 = args[1]
    local plateText2 = args[2]
    
    -- แก้ไขเงื่อนไขตรงนี้เพื่อให้เช็คว่าต้องใส่ครบทั้ง 2 ตัว หรือปรับตามต้องการ
    if not plateText1 or not plateText2 then
        print("error")
        return
    end

    local plateText = plateText1 .." ".. plateText2
    print("Plate:", plateText)

    -- ถ้ามีรถเก่าอยู่แล้ว ให้ลบทิ้งก่อนสร้างใหม่
    if DoesEntityExist(vehicle) then
        DeleteEntity(vehicle)
        vehicle = nil
    end

    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    local modelHash = GetHashKey(modelName)

    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Citizen.Wait(10)
    end

    vehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading, false, false)

    if plateText then
        SetVehicleNumberPlateText(vehicle, plateText)
    end

    SetVehicleOnGroundProperly(vehicle)

    SetModelAsNoLongerNeeded(modelHash)
end)


RegisterCommand("dv", function(_, args) 
    if DoesEntityExist(vehicle) then
        DeleteEntity(vehicle)
        vehicle = nil
    end

	local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if veh ~= 0 then
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
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



CreateThread(function()
    while true do
        Wait(1000)

        local pedCoords = GetEntityCoords(PlayerPedId())

        local inJobZone = false
        local rewardItem = nil

        for _, jobData in pairs(Config.Jobs) do
            if jobData.Enabled and jobData.Locations then
                for _, location in ipairs(jobData.Locations) do
                    if #(pedCoords - location.coords) <= location.dis then
                        inJobZone = true
                        rewardItem = jobData.reward.name
                        break
                    end
                end
            end

            if inJobZone then
                break
            end
        end

        if not inJobZone then
            startx = false
			itemnamejobx = nil
        else
			if not itemnamejobx then
				itemnamejobx = rewardItem
				print(rewardItem)
			end
        end
    end
end)

RegisterCommand("geti", function() print(itemnamejobx) end)
RegisterCommand("gx", function() exports.nakin_trunk.openVehicleTrunk() end)
RegisterNUICallback('openplate', function(_, cb)
    exports.nakin_trunk.openVehicleTrunk()
    cb('ok')
end)	

RegisterNUICallback('itemwww', function(data, cb)
    -- ตรวจสอบว่ามีค่าไอเทมไหม (เปลี่ยน currentItem เป็นตัวแปรที่คุณใช้งานจริง)
    local itemName = itemnamejobx
    local itemCount = getItemCount(itemnamejobx) or 0

    cb({
        itemname = itemName,
        count = itemCount
    })
end)