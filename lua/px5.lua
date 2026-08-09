print("111")print("111")print("111")print("111")print("111")print("111")
scriptName = GetCurrentResourceName()
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
		TriggerEvent("esx:getSharedObject", function(obj) ESX = obj end)
		Citizen.Wait(0)
	end
end)

-- RegisterCommand('keyp', function(source, args, rawCommand)
	-- local MiniGame = exports['nakin_minigames']:KeysBars({
	-- 	count = 3,
	-- 	time = 3,
	-- 	keys = {"E"},
	-- })
	-- if MiniGame then
-- 		--print("KeyBar MiniGame Success")
-- 	else
-- 		--print("KeyBar MiniGame Fail")
-- 	end
-- end)

function KeysBars(data)
	if not MiniGame then
		MiniGame = true
		BarSuccess = 0
		local time = data.time*1000
		local percent = 0
		local PressKeys = {"E"}
		if data.keys then
			PressKeys = data.keys
		end
		local SetNew = false
		local KeysBtn
		local StartPress
		local BarSize
		local PlaySuccess = true
		while BarSuccess < data.count do
			if not SetNew then
				SetNew = true
				local keymath = math.random(1, #PressKeys)
				KeysBtn = PressKeys[keymath]
				StartPress = math.random(30,80)
				BarSize = math.random(5,15)
				SendNUIMessage({
					type = "sETBarUI", 
					data = {
						KeysBtn = KeysBtn,
						StartPress = StartPress,
						BarSize = BarSize,
						BarSuccess = BarSuccess,
						SuccessCount = data.count
					}
				})
			end
			if percent < 100 then
				local sec = time / 1000
				percent = percent + (1 / sec)
			else
				PlaySuccess = false
				break
			end
			if percent > (StartPress+BarSize) then
				PlaySuccess = false
				break
			end
			SendNUIMessage({type = "sETBarPercent", percent = percent})
			if percent >= StartPress and percent <= (StartPress+BarSize) then
					BarSuccess = BarSuccess + 1
					percent = 0
					SetNew = false
			end
			if IsControlJustPressed(0, Keys[KeysBtn]) then
				BarSuccess = BarSuccess + 1
				percent = 0
				SetNew = false
			end
			Citizen.Wait(1)
		end
		SendNUIMessage({type = "EndBarUI", status = PlaySuccess})
		MiniGame = false
		return PlaySuccess
	end
end

function calculatePercentage(baseTime, targetTime)
    local percentage = (targetTime / baseTime) * 100
    return percentage
end

-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

-- RegisterCommand('keyinput', function(source, args, rawCommand)
-- 	local MiniGame = exports['nakin_minigames']:GamePassWord(5)
-- 	if MiniGame then
-- 		--print("Password MiniGame Success")
-- 	else
-- 		--print("Password MiniGame Fail")
-- 	end
-- end)

function GamePassWord(passcount)
	if not MiniGame then
		MiniGame = true
		if passcount > 10 then
			passcount = 10
		end
		local keyset = generateinputkey()
		play_password = generate_password(passcount)
		inputindex = 0
		SetNuiFocus(true,true)
		SendNUIMessage({type = "StartsETPassWord", keyset = keyset, play_password = play_password})
		PassWordResult = nil
		while PassWordResult == nil do
			Citizen.Wait(100)
		end
		MiniGame = false
		SetNuiFocus(false,false)
		SendNUIMessage({type = "EndsETPassWord"})
		return PassWordResult
	end
end

RegisterNUICallback('checkpassword', function(data)
	if play_password[inputindex] == tonumber(data.number) then
		if not play_password[inputindex+1] then
			PassWordResult = true
		end
		inputindex = inputindex + 1
		SendNUIMessage({type = "SetPasswordNumber", number = data.number})
	else
		PassWordResult = false
	end
end)

RegisterNUICallback('exit', function()
	PassWordResult = false
	ColorResult = false
end)


function generateinputkey()
	local array = {}
    local used = {}
    local value
    for i = 0, 9 do
        repeat
            value = math.random(0, 9)
        until not used[value]
        array[i] = value
        used[value] = true
    end
    return array
end

function generate_password(length)
    local array = {}
    local used = {}
    local value
    for i = 0, length do
        repeat
            value = math.random(0, 9)
        until not used[value]
        array[i] = value
        used[value] = true
    end
    return array
end

-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

-- RegisterCommand('colorinput', function(source, args, rawCommand)
-- 	local MiniGame = exports['nakin_minigames']:GameColor(3)
-- 	if MiniGame then
-- 		--print("Color MiniGame Success")
-- 	else
-- 		--print("Color MiniGame Fail")
-- 	end
-- end)

function GameColor(count)
	if not MiniGame then
		MiniGame = true
		colorset = generate_colorkey(count)
		colorindex = 1
		SetNuiFocus(true,true)
		SendNUIMessage({type = "StarColorGame", colorset = colorset})
		Citizen.Wait(2000)
		local guidekey = 1
		while guidekey <= count do
			Citizen.Wait(800)
			SendNUIMessage({type = "GuideColor", set = colorset[guidekey]})
			guidekey = guidekey + 1
		end
		Citizen.Wait(1000)
		InputColor = true
		SendNUIMessage({type = "PlayColorNoti"})
		ColorResult = nil
		while ColorResult == nil do
			Citizen.Wait(100)
		end
		MiniGame = false
		InputColor = false
		SetNuiFocus(false,false)
		SendNUIMessage({type = "EndColorGame", fade = ColorResult})
		return ColorResult
	end
end

RegisterNUICallback('checkcolorkey', function(data)
	if InputColor then
		if colorset[colorindex] == tonumber(data.number) then
			SendNUIMessage({type = "GuideColor", set = colorset[colorindex]})
			if not colorset[colorindex+1] then
				ColorResult = true
			end
			colorindex = colorindex + 1
		else
			ColorResult = false
		end
	end
end)

function generate_colorkey(count)
    local array = {}
    for i = 1, count do
		local value = math.random(1, 5)
		array[i] = value
    end
    return array
end

-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

-- RegisterCommand('clickdiff', function(source, args, rawCommand)
-- 	local MiniGame = exports['nakin_minigames']:ClickDifference({
-- 		imgset = "chinese",
-- 		diff = 5,
-- 		time = 30,
-- 	})
-- 	if MiniGame then
-- 		print("ClickDiff MiniGame Success")
-- 	else
-- 		print("ClickDiff MiniGame Fail")
-- 	end
-- end)

local maximg = {
	["chinese"] = 23,
}

function ClickDifference(data)
	if not MiniGame then
		MiniGame = true
		if maximg[data.imgset] then
			data.set = GenerateDifference(data)
			-- print(ESX.DumpTable(data))
			ClickDiffResult = nil
			SendNUIMessage({type = "ClickDiff", data = data})
			SetNuiFocus(true,true)
			while ClickDiffResult == nil do
				Citizen.Wait(0)
				if IsDisabledControlJustPressed(0,73) or IsPedDeadOrDying(PlayerPedId()) then
					ClickDiffResult = false
				end
			end
			SetNuiFocus(false,false)
			MiniGame = false
			return ClickDiffResult
		end
		MiniGame = false
	end
end

function GenerateDifference(data)
	if maximg[data.imgset] then
		local generate = {}
		local diffnumber = {}
		local diffcount = 0
		while diffcount < data.diff do
			local number = math.random(1,maximg[data.imgset])
			if not diffnumber[number] then
				diffnumber[number] = true
				diffcount = diffcount + 1
			end
			Citizen.Wait(0)
		end
		for i = 1, 30 do
			local number = math.random(1,maximg[data.imgset])
			if diffnumber[i] then
				local makediff = number
				while makediff == number do
					local randomdiff = math.random(1,maximg[data.imgset])
					if randomdiff ~= number then
						makediff = randomdiff
					end
					Citizen.Wait(0)
				end
				table.insert(generate, {left = number, right = makediff, diff = true})
			else
				table.insert(generate, {left = number, right = number, diff = false})
			end
		end
		return generate
	end
end

RegisterNUICallback('setclickresult', function(data)
	if data.status ~= nil then
		ClickDiffResult = data.status
	else
		ClickDiffResult = false
	end
end)

-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

-- RegisterCommand('audition', function(source, args, rawCommand)
-- 	local MiniGame = exports['nakin_minigames']:AuditionMinigame({
-- 		count = 8,
-- 		red = 3,
-- 		time = 10,
-- 	})
-- 	if MiniGame then
-- 		print("Audition MiniGame Success")
-- 	else
-- 		print("Audition MiniGame Fail")
-- 	end
-- end)

function AuditionMinigame(data)
	if not MiniGame and data then
		MiniGame = true
		data.arrow = GenerateAudition(data)
		SendNUIMessage({type = "Audition", data = data})
		AuditionResult = nil
		local arrownumber = 1
		while AuditionResult == nil do
			Citizen.Wait(0)
			local press = nil
			if IsControlJustPressed(0, 172) then
				press = 3
			end
			if IsControlJustPressed(0, 173) then
				press = 1
			end
			if IsControlJustPressed(0, 174) then
				press = 2
			end
			if IsControlJustPressed(0, 175) then
				press = 0
			end
			if IsDisabledControlJustPressed(0,73) or IsPedDeadOrDying(PlayerPedId()) then
				AuditionResult = false
			end
			if press then
				if data.arrow[arrownumber] then
					local correct = false
					if data.arrow[arrownumber].arrow == press then
						correct = true
					end
					SendNUIMessage({type = "SetArrow", pos = (arrownumber-1), correct = correct})
					if not correct then
						AuditionResult = false
					end
					if arrownumber >= data.count then
						AuditionResult = true
					end
				end
				arrownumber = arrownumber + 1
			end
		end
		SendNUIMessage({type = "Audition", data = nil})
		MiniGame = false
		return AuditionResult
	end
end

function GenerateAudition(data)
	local arrow = {}
	local redposition = {}
	local redcount = 0
	while redcount < data.red do
		local number = math.random(1,data.count)
		if not redposition[number] then
			redposition[number] = true
			redcount = redcount + 1
		end
		Citizen.Wait(0)
	end
	for i = 1, data.count do
		local number = math.random(1,4)
		local isred = false
		if redposition[i] then
			isred = true
		end
		table.insert(arrow, {arrow = (number-1), red = isred})
	end
	return arrow
end

RegisterNUICallback('setauditionfail', function(data)
	AuditionResult = false
end)

-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
-- ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////


local tempdata = nil
RegisterNUICallback('checkcodown', function(_, cb)
    local cooldownValue = exports.cement.timecooldown()
	while cooldownValue == tempdata do
		cooldownValue = exports.cement.timecooldown()
		Wait(50)
	end
	cooldownValue = tempdata
    cb(cooldownValue)
end)


RegisterNUICallback('cx', function(_, cb)
	local ww = exports.cement.findcx()
	cb(ww)
end)