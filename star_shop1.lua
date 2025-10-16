print("inject")

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
local script_name = GetCurrentResourceName()



local function BuyPumpkinCards()

    SetEntityCoords(PlayerPedId(), -344.2592, 267.1768, 85.4031)
    Wait(300)
    local current = getItemCount("Card_Pumpkin") or 0
    local max = 5
    local needed = math.max(0, max - current)

    

    local data = { 
        
        
        Itemlist = {
            { Amount = needed,Item_type = "item_standard",Label = "Card Pumpkin",Limit = 5,Name = "Card_Pumpkin",Price = 2000},
        },
        Paytype = "money",
        Zone_Index = 1

    }
    local datax = { 
        
        
        Itemlist = {
            { Amount = 1,Item_type = "item_standard",Label = "Fruit juice",Limit = 10,Name = "fruit_juice",Price = 300},
            { Amount = 1,Item_type = "item_standard",Label = "Hamburger",Limit = 10,Name = "hamburger",Price = 200}
        },
        Paytype = "money",
        Zone_Index = 1

    }

    lib.callback.await(script_name .. ":Sv:On_Shop_Buy", false, data)
    lib.callback.await(script_name .. ":Sv:On_Shop_Buy", false, datax)

	local targetPos = vector3(-277.2416, 6044.6504, 30.9002)
	local radius = 50.0

    -- วางผู้เล่นที่ตำแหน่งเป้าหมาย
    SetEntityCoords(PlayerPedId(), targetPos)

    -- รอจนผู้เล่นอยู่ในรัศมี 10.0
    while #(GetEntityCoords(PlayerPedId()) - targetPos) > radius do
        Wait(100) -- หน่วงให้ไม่หนัก CPU
    end
    Wait(500)
    exports['Donut_Party_Job']:startPumpkin()
end

exports('BuyPumpkinCards', BuyPumpkinCards)