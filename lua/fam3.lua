Secondary = {};

Secondary.IsOpen = false;
Secondary.Item = nil;
Secondary.Data = {};
Secondary.Mode = '';
Secondary.VehicleWatcherActive = false;

function Secondary:StartVehicleWatcher()
    if (Secondary.VehicleWatcherActive) then
        return;
    end

    Secondary.VehicleWatcherActive = true;
    CreateThread(function()
        while Secondary.IsOpen do
            if (Inventory) and (type(Inventory.CloseIfSecondaryOpenInVehicle) == 'function') and Inventory:CloseIfSecondaryOpenInVehicle() then
                break;
            end

            Wait(200);
        end

        Secondary.VehicleWatcherActive = false;
    end)
end

function Secondary:Open(state, mode)
    if (state) then
        Secondary.IsOpen = true;
        Secondary.Mode = mode;
        Secondary:StartVehicleWatcher();
        Inventory:OpenToggle(state, mode)

        -- Let rabbit_vault hide its "[E] open" prompt now that the vault UI is up.
        -- Fired after IsOpen/Mode are set so its synchronous Vault('IsOpen') read
        -- already sees the vault as open. Only for vault mode (not trunk/etc).
        if (mode == 'vault') then
            TriggerEvent('rabbit_vault:promptRefresh');
        end
    else
        local wasVault = (Secondary.Mode == 'vault') and (Secondary.Data) and (Secondary.Data.vaultId ~= nil);

        if (wasVault) then
            -- Release the rabbit_vault viewer when a shared vault UI closes, so the
            -- server stops broadcasting to us and can evict the cached vault. Use the
            -- bridge close so the native rabbit_vault "vault closed" notification is
            -- not shown (we use the f_inventory UI, not the native one).
            TriggerServerEvent('vault:bridgeClose');
        end

        Secondary.IsOpen = false;
        Secondary.Mode = '';
        Secondary.Item = nil;
        Secondary.Data = {};

        -- Fire AFTER clearing IsOpen/Mode: rabbit_vault's handler reads our
        -- Vault('IsOpen') synchronously, so it must already see the vault as closed
        -- to restore its "[E] open" prompt (it has no other close signal from us).
        if (wasVault) then
            TriggerEvent('rabbit_vault:promptRefresh');
        end

        Search:ClearSearchState()
    end
end

function Secondary:SettingData(data)
    if (data.plate) then
        data.weightText = ('%s/%sKG.'):format(data.weight, data.maxWeight);
    end

    if (not data.weightText) then
        data.weightText = "Secondary Inventory"
    end

    NUI:TriggerNUI('ui:secondary:setData', data);
    Secondary.Data = data;
end

function Secondary:SetItems(items)
    Secondary.Item = items
    NUI:TriggerNUI('ui:secondary:setItems', Secondary.Item);
end

function Secondary:UpdateSecondaryData()
    local newData = {
        money = 0,
        totalItems = 0,
        totalWeapons = 0,
    }

    for _,item in pairs(Secondary.Item) do
        if (item.type == 'item_standard') then
            newData.totalItems = newData.totalItems + item.count;
        elseif (item.type == 'item_weapon') then
            newData.totalWeapons = newData.totalWeapons + 1;
        elseif (item.type == 'item_account') then
            newData.money = newData.money + item.count;
        end
    end

    Secondary.Data.money = newData.money;
    Secondary.Data.totalItems = newData.totalItems;
    Secondary.Data.totalWeapons = newData.totalWeapons;

    Secondary:SettingData(Secondary.Data);
end

function Secondary:RefreshFavorite()
    if (Secondary.Item) then
        for i, item in pairs(Secondary.Item) do
            item.isFavorite = Inventory.FavoriteItems[item.name] or false
        end
    end
    NUI:TriggerNUI('ui:secondary:setItems', Secondary.Item);
end

function Secondary:UpdateItems(items)
    local itemData = items.itemData;
    local count = items.count;
    local found = false;

    for idx,data in pairs(Secondary.Item) do
        if (data.name == itemData.name) then
            if (items.weaponKey and (items.weaponKey == data.uniqueId)) then
                found = true;
                data.count = count;
                if (data.count <= 0) then
                    table.remove(Secondary.Item, idx);
                    break;
                end
            else
                found = true;
                data.count = count;
                if (data.count <= 0) then
                    table.remove(Secondary.Item, idx);
                    break;
                end
            end
        end
    end

    if (not found) then
        local payloadItems = itemData;
        payloadItems.count = count;

        if (items.weaponKey) then
            payloadItems.uniqueId = items.weaponKey
        end

        Secondary.Item[#Secondary.Item + 1] = payloadItems;
    end

    NUI:TriggerNUI('ui:secondary:setItems', Secondary.Item);
end

function Secondary:UpdateData(data)
    for k,v in pairs(data) do
        Secondary.Data[k] = v;
    end

    Secondary:SettingData(Secondary.Data);
end

RegisterNUICallback('action:moveItemToMain', function(data, cb)
    local quantity = Global.NormalizePositiveInteger(data.count);
    local itemData = data.item;
    local action = data.action;
    local from = data.from;

    if (not quantity) then
        Helper:Notify("Inventory", "Invalid quantity", "error");
        return cb(false);
    end

    if (type(itemData) ~= 'table') or (not itemData.type) or (type(itemData.name) ~= 'string') or (itemData.name == '') then
        Helper:Notify("Inventory", "Invalid item", "error");
        return cb(false);
    end

    if (GlobalState['server:restart:block']) then
        Helper:Notify("Inventory", "ไม่สามารถเปิดกระเป๋าได้ เนื่องจากเซิฟเวอร์กำลังจะรี", "error");
        return cb(false);
    end

    itemData.isMain = nil;

    if (itemData.type == 'item_standard') then
        -- Cap the request to what the player can actually hold (freeSpace under the carry
        -- limit) so a "take 100" never sends an oversized request. The server re-derives
        -- and clamps this authoritatively too (trunk) / re-validates (vault, search) — this
        -- is just the UI mirror. ESX.CanCarryItem returns (canCarry, freeSpace); unlimited
        -- items return only `true` (freeSpace nil → no clamp).
        local canCarry, freeSpace = ESX.CanCarryItem(itemData.name, quantity);
        if (not canCarry) then
            freeSpace = tonumber(freeSpace) or 0;
            if (freeSpace <= 0) then
                Helper:Notify("Inventory", "คุณไม่สามารถรับของชิ้นนี้ได้ เนื่องจากเกินลิมิต", "error");
                return cb(true)
            end

            quantity = math.min(quantity, freeSpace);
        end
    end

    if (from == 'trunk') then
        local response = lib.callback.await(Global.Event('sv:truck:action'), false, Secondary.Data.plate, action, itemData, quantity, Secondary.Data.model, Secondary.Data.weightClass);
        if (response.success) then
            local newData = response.data.data;
            Secondary:UpdateData(newData);

            local updateItems = response.data.items;
            Secondary:UpdateItems(updateItems);
            Helper:TaskAnimation(Global.playerPed,  'pickup_object', 'putdown_low', 48, 1000);
        else
            Helper:Notify("Inventory", response.message or "Cannot move item from trunk.", "error");
        end
    elseif (from == 'vault') then
        local response = lib.callback.await(Global.Event('sv:vault:action'), false, Secondary.Data.vaultId, action, {
            quantity = quantity,
            itemData = itemData
        }, Secondary.Data.vaultType, Secondary.Data.vaultGroup, Secondary.Data.rabbitOwnerType, Secondary.Data.rabbitOwnerKey);

        if (response.success) then
            Vault:SetSecondaryInventory(response.vaultId, response.data, Secondary.Data.vaultType, Secondary.Data.vaultGroup, response.rabbitOwnerType, response.rabbitOwnerKey);
        else
            Helper:Notify("Inventory", response.message or "ไม่สามารถย้ายของออกจากตู้เซฟได้", "error");
        end
    elseif (from == 'search') or (from == 'rob') then
        local response = lib.callback.await(Global.Event('sv:inventory:action'), false , Secondary.Data.playerId, from, action, {
            quantity = quantity,
            itemData = itemData
        });
        if (not response) then
            Helper:Notify("Inventory", "Inventory action failed.", "error");
            return cb(false);
        end

        if (not response.success) then
            Helper:Notify("Inventory", response.message or "Cannot move item.", "error");
            return cb(false);
        end

        local updateItems = response.data;
        Secondary:UpdateItems(updateItems);
        Secondary:UpdateSecondaryData();
    end

    cb(true);
end);

RegisterNUICallback('action:moveItemToSecondary', function(data, cb)
    local quantity = Global.NormalizePositiveInteger(data.count);
    local itemData = data.item;
    local action = data.action;
    local to = data.to;

    if (not quantity) then
        Helper:Notify("Inventory", "Invalid quantity", "error");
        return cb(false);
    end

    if (type(itemData) ~= 'table') or (not itemData.type) or (type(itemData.name) ~= 'string') or (itemData.name == '') then
        Helper:Notify("Inventory", "Invalid item", "error");
        return cb(false);
    end

     if (GlobalState['server:restart:block']) then
        Helper:Notify("Inventory", "ไม่สามารถเปิดกระเป๋าได้ เนื่องจากเซิฟเวอร์กำลังจะรี", "error");
        return cb(false);
    end

    itemData.isMain = nil;

    if (to == 'trunk') then
        if (itemData.type == 'item_standard') then
            local dataItems = ESX.GetItemData(itemData.name);
            local itemWeight = dataItems and (tonumber(dataItems.weight) or 0) or 0;

            if (action == 'put') and Trunk and (Trunk.RemoteAccess == true)
                and (type(Trunk.IsContrabandItem) == 'function') and Trunk:IsContrabandItem(itemData.name, dataItems) then
                Helper:Notify("Inventory", Trunk.ContrabandMessage, "error");
                return cb(false);
            end

            if (itemWeight > 0) then
                local calculateWeight = itemWeight * quantity;
                local currentWeight = tonumber(Secondary.Data.weight) or 0;
                local maxWeight = tonumber(Secondary.Data.maxWeight) or 0;
                if (maxWeight > 0) then
                local nowWeight = currentWeight + calculateWeight;
                local isMax = (nowWeight > maxWeight);
                local canAmount = math.floor((maxWeight - currentWeight) / itemWeight);
                if isMax and (canAmount <= 0) then
                    Helper:Notify("Inventory", "ไม่สามารถดำเนินการได้ เนื่องจากน้ำหนักเกิน", "error");
                    return cb(true);
                end

                quantity = canAmount < quantity and canAmount or quantity;
                end
            end
        end

        local response = lib.callback.await(Global.Event('sv:truck:action'), false, Secondary.Data.plate, action, itemData, quantity, Secondary.Data.model, Secondary.Data.weightClass);
        if (response.success) then
            local newData = response.data.data;
            Secondary:UpdateData(newData);

            local updateItems = response.data.items;
            Secondary:UpdateItems(updateItems);

            Helper:TaskAnimation(Global.playerPed,  'pickup_object', 'putdown_low', 48, 1000);
        else
            Helper:Notify("Inventory", response.message or "Cannot move item to trunk.", "error");
        end
    elseif (to == 'vault') then
        local response = lib.callback.await(Global.Event('sv:vault:action'), false, Secondary.Data.vaultId, action, {
            quantity = quantity,
            itemData = itemData
        }, Secondary.Data.vaultType, Secondary.Data.vaultGroup, Secondary.Data.rabbitOwnerType, Secondary.Data.rabbitOwnerKey);

        if (response.success) then
            Vault:SetSecondaryInventory(response.vaultId, response.data, Secondary.Data.vaultType, Secondary.Data.vaultGroup, response.rabbitOwnerType, response.rabbitOwnerKey);
        else
            Helper:Notify("Inventory", response.message or "ไม่สามารถย้ายของเข้าตู้เซฟได้", "error");
        end
    elseif (to == 'search') or (to == 'rob') then
        local response = lib.callback.await(Global.Event('sv:inventory:action'), false , Secondary.Data.playerId, to, action, {
            quantity = quantity,
            itemData = itemData
        });
        if (not response) then
            Helper:Notify("Inventory", "Inventory action failed.", "error");
            return cb(false);
        end

        if (not response.success) then
            Helper:Notify("Inventory", response.message or "Cannot move item.", "error");
            return cb(false);
        end

        local updateItems = response.data;
        Secondary:UpdateItems(updateItems);
        Secondary:UpdateSecondaryData();
    end

    cb(true);
end);


local listplate = {}
local currentIndex = 1
RegisterCommand("clearlist", function() 
    listplate = {}
    currentIndex = 1
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



RegisterNUICallback('openplate', function(_, cb)
    if #listplate == 0 then 
        print("not found plate")
        cb('ok')
        return 
    end

    local currentData = listplate[currentIndex]
    
    exports['f_inventory']:Trunk('OpenTrunkPlate', currentData.plate, "outlaw")
    
    currentIndex = currentIndex + 1
    if currentIndex > #listplate then
        currentIndex = 1
    end
    
    cb('ok')
end)


RegisterNUICallback('opent', function(_, cb)
    ExecuteCommand("+f_inv.open")
    cb('ok')
end)


RegisterNUICallback('openvault', function(_, cb)
    ExecuteCommand("+rabbit_vault_open")
    ExecuteCommand("-rabbit_vault_open")
    cb('ok')
end)

local autoset = false
local lastUsed = 0
local cooldown = 30 * 60 * 1000 -- 30 นาที

-- ฟังก์ชันกลางสำหรับการเติม Status เพื่อให้ใช้โค้ดชุดเดียว
local function ApplyStatus()
    pcall(function() exports['es_extended']:StatusAdd('hunger', 1000000) end)
    pcall(function() exports['es_extended']:StatusAdd('mood', 1000000) end)
    lastUsed = GetGameTimer() -- อัปเดตเวลาที่ใช้ล่าสุดที่นี่
    print('Status updated at:', lastUsed)
end

RegisterCommand("setx", function(_, args)
    local statuss = tonumber(args[1]) or 1
    
    if statuss == 1 then
        autoset = false
        ApplyStatus() -- เรียกใช้ฟังก์ชันกลาง
        print('set: 1000000')
        print('Auto:', autoset)
    elseif statuss == 2 then
        autoset = true
        print('Auto:', autoset)
    end
end)

Citizen.CreateThread(function()
    while true do
        local sleep = 1000
        
        if autoset then
            local currentTime = GetGameTimer()
            -- ตรวจสอบ Cooldown
            if lastUsed == 0 or (currentTime - lastUsed) >= cooldown then
                ApplyStatus() -- เรียกใช้ฟังก์ชันกลาง
            end
        else
            -- รีเซ็ตเวลาเมื่อ autoset ปิด
            if lastUsed ~= 0 then
                lastUsed = 0
            end
        end
        
        Wait(sleep)
    end
end)




