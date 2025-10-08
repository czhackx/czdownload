Config.PoisonDMG = 0 -- damage
Config.PoisonTime = 0 -- ทำดาเมททุกกี่วินาที
Config.itemFood['fruit_juice'].time = 1
Config.itemFood['fruit_juice'].stress = 1000000000
Config.itemFood['hamburger'].time = 1
Config.itemFood['hamburger'].hungry = 10000000000



function resetd(h)
    TriggerServerEvent("status:sv:useItemStatus", h and "hamburger" or "fruit_juice")
end

exports('resetd', resetd)