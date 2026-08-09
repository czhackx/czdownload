Config.Function = Config.Function or {}

Citizen.CreateThread(function()
    while not Config
       or not Config.Painkiller
       or not Config.Aed
       or not Config.Armor do
        Wait(100)
    end

    for _, category in pairs(Config) do
		if type(category) == "table" then
			for _, item in pairs(category) do
				if type(item) == "table" and item.Remove ~= nil then
					item.Remove = false
				end
			end
		end
	end

	print('Remove All false')	print('Remove All false')	print('Remove All false')	print('Remove All false')
end)