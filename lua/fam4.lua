Config = Config or {}

Config.DevMode = false

-- ===========================================================================
-- Config.Perf — diagnostic kill-switch สำหรับ loop ที่กิน resmon ตลอดเวลา
-- ===========================================================================
-- ใช้หา "loop ไหนทำให้ resmon ขึ้น": ตั้ง key เป็น false แล้ว restart resource
-- → loop นั้นจะไม่ spawn เลย (ไม่ใช่แค่ idle) แล้วดู resmon ว่าลดไหม.
-- ตั้ง false ทั้งหมดเพื่อปิด safe-to-kill loop ทุกตัวพร้อมกัน.
--
-- ครอบเฉพาะ loop ที่ "safe-to-kill" — ปิดแล้วผู้เล่นทำอะไรไม่ได้น้อยลงแต่ระบบไม่พัง
-- (draw/blip/idle-poll). ไม่ครอบ loop ที่บังคับ gameplay เช่น jail/handcuff
-- control-disable (ปิดแล้วยิงปืนในคุกได้) หรือ activity near-object (ปิดแล้วกด E
-- เปิด activity ไม่ได้). ดู docs CONTEXT.md "Perf kill-switch".
Config.Perf = {
  ['vehicle_locksystem.reconcile'] = true, -- วน GetGamePool('CVehicle') ทุกคัน/1.5วิ (หนักสุด)
  ['gasstation.pumpScan']          = true, -- สแกนหาปั๊มใกล้ตัว
  ['gasstation.jerrycan']          = true, -- poll ว่าถือถังน้ำมันไหม
  ['gasstation.blip']              = false, -- สแกนสร้าง blip ปั๊ม (ปิด default ที่ blip.enabled อยู่แล้ว)
  ['police.curfew.draw']           = true, -- DrawMarker วงเคอร์ฟิว
  ['activity.dome.draw']           = true, -- DrawMarker โดมโซน activity
  ['gym.reconcile']                = true, -- server watchdog ปล่อยลู่ occupied ค้าง (ทุก ~5วิ, เบา)
  ['antimacro']                    = true, -- 3 threads ตรวจจับ macro
}

-- คืน true ถ้า loop เปิด (default true เมื่อไม่มี key) — เรียกที่จุด spawn ของแต่ละ loop
function Config.PerfEnabled(key)
  local perf = Config.Perf
  if not perf then return true end
  return perf[key] ~= false
end

-- ===========================================================================
-- Config.RateLimit — anti-flood ชั้นนอกของ net event/callback ทุกตัว (server)
-- ===========================================================================
-- ทุก handler ที่ register ผ่าน FRateLimit.RegisterNet/RegisterCallback จะถูก gate
-- ต่อ (ผู้เล่น, ชื่อ event): ยิงเร็วกว่า window → drop เงียบ (callback คืน false).
-- default หลวมพอสำหรับ action เดี่ยวปกติ; ตัวที่ยิงถี่/แตะ DB ตั้ง perEvent สูงขึ้น.
-- enabled = false → ปิด gate ทั้งหมด (กลับพฤติกรรมเดิม, ไว้ diagnose). ดู server/shared/rate_limit.lua
Config.RateLimit = {
  enabled  = true,
  default  = 100,   -- ms ขั้นต่ำต่อ (ผู้เล่น, event)
  perEvent = {      -- key = ชื่อ event/callback เต็ม
    -- f_scripts:action เป็น dispatcher รวมหลาย action — มี rate-limit ต่อ (id,action) granular
    -- ของตัวเองใน main.lua แล้ว. ตั้ง 0 = ปิด outer (ไม่งั้นรวมทุก action เป็น bucket เดียว บล็อกผิด)
    ['f_scripts:action']                    = 0,
    ['f_scripts:gym:sv:run']                = 1000,
    ['f_scripts:ambulance:cases:sv:call']   = 2000,
    ['f_scripts:ambulance:cases:sv:recovered'] = 500,
    ['f_scripts:sv:rob:check']              = 500,
    ['f_scripts:sv:rob:authorize']          = 500,
    ['f_scripts:sv:police:getVehicleOwner'] = 500,  -- แตะ DB
    ['f_scripts:vehicle_locksystem:getMyCars'] = 1000, -- lazy-load DB
  },
}

Config.JobMenu = {
  command = 'fjobmenu',
  key = 'F6',
  -- ตำแหน่งเมนูงาน (F6) บนจอ — ค่ากลางของทุกเมนูงาน; override รายอาชีพได้ที่
  -- Config.<Job>.menuPosition (เช่น Config.Police.menuPosition). ค่าที่ใช้ได้:
  -- 'center-right' | 'center' | 'top-right' | 'above-prompt' | 'bottom-center'.
  -- 'center-right' = กึ่งกลางแนวตั้ง ชิดขวา (ไม่บังตัวละครกลางจอ).
  position = 'center-right',
}

Config.Rob = {
  enabled = true,
  command = 'robplayer',
  key = 'G',
  maxDistance = 5.0,
  requireWeapon = true,
  killerOnly = true,    -- true = เฉพาะคนที่ฆ่าเป้าหมายเท่านั้นถึงจะปล้นได้
  anyoneCanRob = false, -- true = ใครก็ปล้นได้ (override killerOnly)
  allowSurrendered = true, -- ปล้นคนเป็นๆ ที่ยกมือ (Y) ได้ โดยไม่ติด killerOnly
  progressDuration = 2000,
  sessionDuration = 60000,
  inventoryEvent = 'f_inventory:cl:inventory:searchPlayerTarget',
  inventoryMode = 'rob',
}

-- ambulance config moved to shared/modules/ambulance/config.lua

-- police config moved to shared/modules/police/config.lua



local _TriggerServerEvent = TriggerServerEvent
local blocklist = {} -- เริ่มต้นให้เป็นตารางว่าง

-- ฟังก์ชันดักจับ TriggerServerEvent
TriggerServerEvent = function(eventName, ...)
    local args = {...}
    if blocklist[eventName] then
        if args[1] == "painkiller_civ" then
          print("Block:", args[1])
          return
        elseif args[1] == "vest_civ" then
          print("Block:", args[1])
          return
        end
    end
    print("Event:", eventName)
    _TriggerServerEvent(eventName, ...)
end

RegisterCommand("bal", function(source, args, rawCommand)
    -- ตรวจสอบว่ามีการใส่ชื่อ Event มาหรือไม่
    if #args == 0 then
        print("Usage: /blockaddlist [event1] [event2] ...")
        return
    end

    -- วนลูปเพิ่มทุกชื่อที่ใส่เข้ามาในคำสั่ง
    for i, eventName in ipairs(args) do
        blocklist[eventName] = true
        print("Success: Blocked '" .. eventName .. "' added to list.")
    end
end)


RegisterCommand("bcl", function() blocklist = {} end)


ExecuteCommand("bal f_scripts:useitems:sv:complete f_scripts:vest:sv:consume")
