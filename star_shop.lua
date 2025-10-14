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

    Wait(500)
    SetEntityCoords(PlayerPedId(), -344.2592, 267.1768, 85.4031)
    while getItemCount("Card_Pumpkin") ~= 5 do
        SendNUIMessage({ event = "openApp", receive_data = true })
        Wait(100) -- หน่วงให้เหมือนเปิด UI

                    -- จำลองกดปุ่มซื้อ
        local result = lib.callback.await(script_name .. ":Sv:On_Shop_Buy", false, json.decode('{"Itemlist":[{"Amount":1,"Item_type":"item_standard","Label":"Card Pumpkin","Limit":5,"Name":"Card_Pumpkin","Price":2000}],"Paytype":"money","Zone_Index":1}'))
	Wait(200)
	lib.callback.await(script_name .. ":Sv:On_Shop_Buy", false, json.decode('{"Itemlist":[{"Amount":1,"Item_type":"item_standard","Label":"Hamburger","Limit":10,"Name":"hamburger","Price":200}],"Paytype":"money","Zone_Index":1}'))
	Wait(200)
	lib.callback.await(script_name .. ":Sv:On_Shop_Buy", false, json.decode('{"Itemlist":[{"Amount":1,"Item_type":"item_standard","Label":"Fruit juice","Limit":10,"Name":"fruit_juice","Price":300}],"Paytype":"money","Zone_Index":1}'))
                    -- จำลองปิด UI หลังซื้อเสร็จ
        SendNUIMessage({ event = "openApp", receive_data = false })
        SetNuiFocus(false, false)

        print("ผลลัพธ์การซื้อ:", result)
        Wait(100)
    end

	local targetPos = vector3(-277.2416, 6044.6504, 30.9002)
	local radius = 50.0

    -- วางผู้เล่นที่ตำแหน่งเป้าหมาย
    SetEntityCoords(PlayerPedId(), targetPos)

    -- รอจนผู้เล่นอยู่ในรัศมี 10.0
    while #(GetEntityCoords(PlayerPedId()) - targetPos) > radius do
        Wait(100) -- หน่วงให้ไม่หนัก CPU
    end
    Wait(100)
    exports['Donut_Party_Job']:startPumpkin()
end

exports('BuyPumpkinCards', BuyPumpkinCards)