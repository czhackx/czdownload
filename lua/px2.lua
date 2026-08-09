ESX			    		= nil
local Keys = {
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

function ScriptWork()

	print("^7 [^4Scripts^7][^2"..string.upper(GetCurrentResourceName()).."^7][^4Loaded Success^7]")

	function MakeEntityFaceCoord(entity1, Coord)
		local p1 = GetEntityCoords(entity1, true)
		local p2 = Coord
		local dx = p2.x - p1.x
		local dy = p2.y - p1.y
		local heading = GetHeadingFromVector_2d(dx, dy)
		SetEntityHeading( entity1, heading )
	end

	Citizen.CreateThread(function()
        while true do
            Sleep = 0
            if IsDisabledControlJustReleased(0, Keys[Config["General"]["Key"]]) then
				local Ped = PlayerPedId()
				if not IsPedSittingInAnyVehicle(Ped) then
					local PedCoords = GetEntityCoords(Ped)
					local Target = ESX.Game.GetClosestVehicle(PedCoords)
					if Target then
						local TargetCoords = GetEntityCoords(Target)
						if #(PedCoords - TargetCoords) < Config["General"]["Dis"] then
							MakeEntityFaceCoord(Ped, TargetCoords)
							local plate = ESX.Math.Trim(GetVehicleNumberPlateText(Target)) or nil
							local class = GetVehicleClass(Target)
							local name = GetDisplayNameFromVehicleModel(GetEntityModel(Target))
							SetEntityDrawOutline(Target, true)
							SetEntityDrawOutlineColor(255,255,255,255)
							local success = exports['nakin_gameui_64']:ToggleProgressBar({text = "เปิด "..plate.."",time = 1000})
							SetEntityDrawOutline(Target, false)
							if success then
								local TargetCoords = GetEntityCoords(Target)
								if #(PedCoords - TargetCoords) < Config["General"]["Dis"] then
									MakeEntityFaceCoord(Ped, TargetCoords)
									local vehicle = {plate = plate,class = class, name = name, coords = TargetCoords}
									TriggerEvent(scriptName..":OpenTrunk", vehicle)
								end
							end
						end
					end
				end
            end
            Citizen.Wait(Sleep)
        end
    end)

	RegisterNetEvent(scriptName..":OpenTrunk")
	AddEventHandler(scriptName..":OpenTrunk", function(vehicle)
		-- if GlobalState.curStatusServer then
		-- 	pcall(function ()
		-- 		exports['nakin_allnotify']:AddNotify({
		-- 			type = "error",
		-- 			text = "ขณะนี้เซิร์ฟเวอร์อยู่ระหว่างกระบวนการรีสตาร์ท",
		-- 			time = 5000,
		-- 		})
		-- 	end)
		-- 	return
		-- end
		ESX.TriggerServerCallback(scriptName..':OpenTrunk',function(trunk)
			if trunk then
				if trunk.plate and trunk.items and trunk.maxweight and trunk.weight then
					TriggerEvent("nakin_inventory:openTrunkInventory", {
						plate = trunk.plate,
						items = trunk.items,
						maxweight = trunk.maxweight,
						weight = trunk.weight,
					})
				end
			end
		end, vehicle)
	end)

	RegisterNetEvent(scriptName..":SendToTrunk")
	AddEventHandler(scriptName..":SendToTrunk", function(parkid, itemname, count)
		if not Waiting then
			Waiting = true
			if itemname and count then
				local vehicle = exports['nakin_garage64']:GetVehiclePark(parkid)
				if vehicle then
					local vehicledta = {
						plate = vehicle.plate,
						class = GetVehicleClassFromName(vehicle.model),
						name = GetDisplayNameFromVehicleModel(vehicle.model),
					}
					local item = ESX.Game.GetItemData(itemname)
					if vehicledta and item and count then
						TriggerServerEvent(scriptName..":RegisterPlate", vehicledta)
						exports['nakin_gameui_64']:ToggleProgressBar({text = "กำลังเก็บ "..item.label.." "..count.." ชิ้น เข้าหลังรถ",time = 3000}) 
						if ESX.Game.CheckHasItem(item.name,count) then
							TriggerServerEvent(scriptName..":OnPut",{
								item = item,
								number = count
							}, true)
							Citizen.Wait(1000)
							TriggerServerEvent(scriptName..":DisableActivePlate")
						end
					end
				else
					exports['nakin_allnotify']:AddNotify({type = "error", text = "ไม่พบรถของคุณในจุดจอดรถที่ "..parkid..""})
				end
			end
			Waiting = false
		end
	end)
end




local listplate = {}

RegisterCommand("clearlist", function() 
    listplate = {}  
    print("clearlist")
end)

-- ฟังก์ชันเช็คว่าทะเบียนมีอยู่แล้วหรือไม่
local function PlateExists(plate)
    for _, v in ipairs(listplate) do
        if v.plate == plate then
            return true
        end
    end
    return false
end

RegisterCommand('addp', function(source, args, rawCommand)
    local input = table.concat(args, " ")
    local plates = {}

    -- แยกด้วยคอมม่า (,)
    for s in string.gmatch(input, "([^,]+)") do
        local plate = s:match("^%s*(.-)%s*$")
        table.insert(plates, plate)
    end

    -- เพิ่มเฉพาะที่ยังไม่มี
    for _, plate in ipairs(plates) do
        if not PlateExists(plate) then
            table.insert(listplate, { plate = plate })
            print("เพิ่มทะเบียนสำเร็จ: " .. plate)
        else
            print("ทะเบียนนี้มีอยู่แล้ว: " .. plate)
        end
    end
end)

local currentIndex = 1

function gx(plate)
    local ped = PlayerPedId()
    local vehicle = {
        plate = plate,
        class = 17,
        name = "RALLYTRUCK",
        coords = GetEntityCoords(ped)
    }

    ESX.TriggerServerCallback(scriptName .. ":OpenTrunk", function(trunk)
        if type(trunk) ~= "table" or not trunk.plate then
            return
        end
        TriggerEvent("nakin_inventory:openTrunkInventory", {
            plate = trunk.plate,
            items = trunk.items or {},
            maxweight = trunk.maxweight or 0,
            weight = trunk.weight or 0

        })
    end, vehicle)

end


exports('openVehicleTrunk', function()
    if #listplate == 0 then 
        print("not found plate")
        cb('ok')
        return 
    end

    local currentData = listplate[currentIndex]
    
    gx(currentData.plate)
    
    currentIndex = currentIndex + 1
    if currentIndex > #listplate then
        currentIndex = 1
    end
end)