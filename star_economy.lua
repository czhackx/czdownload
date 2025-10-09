print("inject")

-- ประกาศฟังก์ชันก่อน
local function sellPumpkin()
    -- วาปผู้เล่นไปตำแหน่งขายฟักทอง
    SetEntityCoords(PlayerPedId(), -2188.2722, -408.5604, 13.1789)
    Wait(1500)
    
    -- ส่ง event ไป server
    TriggerServerEvent('star_economy:sv:sellall')
    Wait(500)
    
    -- เรียกใช้ export ของ star_shop
    exports['star_shop']:BuyPumpkinCards()
end

-- ส่งออกฟังก์ชันนี้ให้ resource อื่นเรียกใช้
exports('sellPumpkin', sellPumpkin)
