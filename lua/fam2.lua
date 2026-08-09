-- client/function/animals.lua
-- state + event handlers + loop threads ของสัตว์ (พอร์ตจาก client.lua เดิม)
RabbitFarmClient = RabbitFarmClient or {}

local S = RabbitFarmClient
S.Animals = {}
S.Deletes = {}
S.AIState = {}   -- สถานะ AI ต่อสัตว์ (lastPos/lastMoveAt/tier/leashing) — แยกจาก object สัตว์
S.animal_limit = 0
S.animal_key = nil
S.lastZone = nil   -- คอกล่าสุดก่อน teardown — กู้ตอน resume (server ไม่เก็บ zone) กัน Ghost (ADR 0003)
S.IS_BUSY = false
S.loopEpoch = 0   -- generation ของ loop — bump ทุกครั้งที่ start → gen เก่า self-exit (กัน race restart; tests S14/S15)
S.IS_PAUSED = false

local S_CL = RabbitFarm.CL
local S_SV = RabbitFarm.SV

-- gate การโต: โตเฉพาะตอนอยู่ในมิติฟาร์ม (เดิม Channel ~= "หลัก") — อ่าน statebag ในเครื่อง
local function inFarmChannel()
	return RabbitFarm.Channel.isAllowed(LocalPlayer.state.activityChannel)
end

-- คอก (AnimalZone) ที่ใกล้ผู้เล่นสุด — ใช้เป็น fallback ตอน resume แล้วยืน "นอกคอก" (เช่นที่ NPC เลือกมิติ
-- ซึ่งห่างคอกใกล้สุด ~9.6m > รัศมี 6m). คืน key หรือ nil ถ้าไกลฟาร์มจริง (resume ปกติอยู่ในช่องฟาร์มแล้ว
-- จึงไม่เข้าเคส nil). มีไว้กัน Ghost: ถ้า LoadAnimals ทิ้ง payload เพราะหาโซนไม่ได้ → server ถือสัตว์ค้าง
local function nearestZoneWithinFarm()
	local plyCoords = GetEntityCoords(cache.ped)
	local bestKey, bestDist
	for key, v in pairs(Config["AnimalZones"]) do
		local d = #(plyCoords - v.coords)
		if not bestDist or d < bestDist then bestKey, bestDist = key, d end
	end
	if bestKey and bestDist <= (Config["Farm"].radius or 125.0) then return bestKey end
	return nil
end

-- grow% (derived) จาก Active time + lv — source of truth เดียว ตรงกับ server/feed-gate/harvest-gate (ADR 0006)
local function animalGrow(v)
	return RabbitFarm.Grow.growAt(v.itemName, v.activeTime or 0, v.age or 1)
end

-- ── pre-check: รับ reward "ขั้นต่ำ" (min × multiplier) ไหวไหม ก่อนยิง harvest ──
-- มิเรอร์ตรรกะ multiplier ของ giveRewards ฝั่ง server — ข้าม reward แบบ percent (ไม่การันตี)
-- คืน ok(boolean), failLabel(string|nil). error ระหว่างเช็ค → fail-open (ปล่อยให้ server ตัดสิน)
local function canCarryRewards(itemName)
	local cfg = Config["Animals"][itemName]
	if not cfg or not cfg.rewards then return true end

	-- ตัวคูณ: ถือไอเท็มโบนัสตัวไหน → เลือก multiplier สูงสุด (helper ร่วมกับ server)
	local multiplier = RabbitFarm.Reward.multiplierFor(function(item)
		return ESX.Game.CheckHasItem(item, 1)
	end)

	for _, value in pairs(cfg.rewards) do
		if (not value.type or value.type == 'item') and not value.percent then
			local need = math.floor((value.min or 0) * multiplier)
			if need > 0 then
				local ok, canCarry = pcall(ESX.CanCarryItem, value.name, need)
				if ok and canCarry == false then
					return false, (ESX.Game.GetItemLabel(value.name) or value.name)
				end
			end
		end
	end
	return true
end

-- ── นับ slot/จำนวน (client) ─────────────────────────────────────────────────
local function getLimit()
	local amount = 0
	for aKey, val in pairs(S.Animals) do
		if val and val.itemName and not S.Deletes[aKey] then
			amount = amount + Config["Animals"][val.itemName].point
		end
	end
	S.animal_limit = amount < 0 and 0 or amount
end
RabbitFarmClient.getLimit = getLimit

local function getAnimalCount(itemName)
	local amount = 0
	for aKey, val in pairs(S.Animals) do
		if val.itemName == itemName and not S.Deletes[aKey] then
			amount = amount + 1
		end
	end
	return amount
end
RabbitFarmClient.getAnimalCount = getAnimalCount

-- ── ตรวจไอเทมหาย → ลบสัตว์ที่ไม่มีไอเทมรองรับ (เดิม CheckItems) ──────────────
local function checkItems()
	local items = {}
	for aKey, val in pairs(S.Animals) do
		if not S.Deletes[aKey] then
			items[val.itemName] = (items[val.itemName] or 0) + 1
		end
	end

	local removes = {}
	if RabbitFarm.tablelength(items) >= 1 then
		for itemName, amount in pairs(items) do
			if not ESX.Game.CheckHasItem(itemName, amount) then
				local am = ESX.Game.GetInventoryItem(itemName) or 0
				removes[itemName] = amount - am
			end
		end
	end

	if RabbitFarm.tablelength(removes) >= 1 then
		local keys = {}
		for key, val in pairs(removes) do
			local dCount = 1
			for aKey, value in pairs(S.Animals) do
				if dCount <= val and value.itemName == key and not S.Deletes[aKey] then
					dCount = dCount + 1
					keys[aKey] = true
					RabbitFarmClient.deletePed(value.ped)
				end
			end
		end
		TriggerServerEvent(S_SV .. 'RemoveAnimals', keys)
	end
end

RegisterNetEvent(Config["EventRoute"]['removeInventoryItem'], function(item, count)
	if Config["Animals"][item] then
		Citizen.Wait(1000)
		if getAnimalCount(item) >= 1 then
			checkItems()
		end
	end
end)

-- teardown สัตว์ฝั่ง client ตอนออกจากช่องฟาร์ม (channel-watch / picker→Main)
-- server pause เป็นหน้าที่ของ statebag handler (in-place) — ฟังก์ชันนี้ไม่ยุ่ง server แล้ว
-- (เลิก PauseAnimals → pause path เดียว = statebag, ไม่มี race; ADR 0006)
-- idempotent — เรียกซ้ำได้ ไม่ทำงานถ้าไม่มีสัตว์/ pause ไปแล้ว
function RabbitFarmClient.pauseAnimalsLocal(notifyMsg)
	if S.IS_PAUSED then return end
	if not (S.animal_limit and S.animal_limit >= 1) then return end
	S.IS_PAUSED = true
	if S.animal_key then S.lastZone = S.animal_key end   -- จำคอกไว้กู้ตอน resume (server zone-agnostic) — กัน Ghost
	for _, value in pairs(S.Animals) do
		RabbitFarmClient.deletePed(value.ped)
	end
	S.Animals = {}
	S.Deletes = {}   -- ล้าง mark ตาย/เก็บค้าง (กัน leak เมื่อ teardown ถูก epoch ใหม่แทน) — ปลอดภัยเพราะ wipe S.Animals ด้วย
	S.AIState = {}
	S.animal_limit = 0
	S.animal_key = nil
	if notifyMsg then RabbitFarmClient.notify('error', notifyMsg) end
end

-- ── busy + one-shot watchdog (ไม่มี loop อมตะ) ───────────────────────────────
-- ตั้ง IS_BUSY แล้ว arm SetTimeout ยิง "ครั้งเดียว" เมื่อครบ timeout: ถ้ายังค้างด้วย token เดิม
-- (reply จาก server หาย/silent-return) → ปลด IS_BUSY กัน soft-lock ถาวร "เห็นหลอดแต่ป้อนไม่ได้".
-- token กัน timeout เก่ามาปลด session ใหม่. ใช้เฉพาะ feed/harvest (มี round-trip รอ reply) — spawn/
-- LoadAnimals ตั้ง IS_BUSY แล้ว reset ใน handler เดียวกันทันที จึงไม่ต้องมี watchdog (มิเรอร์ server isPlayerBusy)
-- timeout = Config.Action.busyTimeoutSec ไม่งั้น derive = max(feed,harvest)+grace 5s (>action จริง = ไม่ false-reset)
local busyToken = 0
local function setBusy()
	S.IS_BUSY = true
	busyToken = busyToken + 1
	local myToken = busyToken
	local act = Config["Action"] or {}
	local timeoutMs = (act.busyTimeoutSec and act.busyTimeoutSec * 1000)
		or (math.max(act.feedDuration or 3000, act.harvestDuration or 5000) + 5000)
	SetTimeout(timeoutMs, function()
		if S.IS_BUSY and busyToken == myToken then
			S.IS_BUSY = false
			RabbitFarmClient.notify('error', 'รีเซ็ตสถานะค้าง ลองทำอีกครั้ง')
		end
	end)
end
local farmauto = true
-- ── start loops (collision / interaction / grow / far-distance) ──────────────
local function startAnimalLoops()
	-- เรียกทุกครั้ง = เริ่ม generation ใหม่ (bump epoch) → thread ของ gen เก่าเห็น epoch ไม่ตรง → exit เอง.
	-- กัน race "thread ตายไม่พร้อมกัน → flag ค้าง → restart ไม่ได้" ตอน animal_limit ข้าม 0 (tests S14/S15).
	-- ไม่ reset S.Deletes (กันปลด mark สัตว์ที่กำลังลบ → getLimit เฟ้อ); teardown จริงล้าง Deletes ตอน animal_limit หมด
	if not (S.animal_limit and S.animal_limit >= 1) then return end
	S.loopEpoch = (S.loopEpoch or 0) + 1
	local e = S.loopEpoch

	-- 1) กันสัตว์ชนกัน
	Citizen.CreateThread(function()
		while S.animal_limit and S.animal_limit >= 1 and S.loopEpoch == e do
			for aKey, animal in pairs(S.Animals) do
				if animal and DoesEntityExist(animal.ped) and not S.Deletes[aKey] then
					for xKey, otherAnimal in pairs(S.Animals) do
						if not S.Deletes[xKey] and otherAnimal and animal.ped ~= otherAnimal.ped
							and DoesEntityExist(otherAnimal.ped) and DoesEntityExist(animal.ped) then
							SetEntityNoCollisionEntity(animal.ped, otherAnimal.ped, false)
						end
					end
				end
			end
			Citizen.Wait(1000)
		end
	end)

	-- 2) AI + interaction (feed/harvest) + แถบหัว
	Citizen.CreateThread(function()
		local stop = false
		local curPrompt = nil
		local function clearPrompt()
			if curPrompt then
				RabbitFarmClient.hidePrompt('animal')
				curPrompt = nil
			end
		end
		local function setPrompt(text)
			if curPrompt ~= text then
				RabbitFarmClient.showPrompt(text, 'animal')
				curPrompt = text
			end
		end

		while S.animal_limit and S.animal_limit >= 1 and S.loopEpoch == e do
			local waitTime = 1000
			local zone = Config["AnimalZones"][S.animal_key]
			local needPrompt = nil
			for aKey, value in pairs(S.Animals) do
				if value and not S.Deletes[aKey] and zone then
					local playerCoords = GetEntityCoords(cache.ped)
					local pedCoords = GetEntityCoords(value.ped)
					local distance = #(playerCoords - pedCoords)
						local maxLv = RabbitFarm.Grow.maxLevel(value.itemName)   -- hoist: ใช้ซ้ำหลายเช็ค (loop นี้ waitTime=0 = ทุกเฟรมเมื่อใกล้สัตว์)
					-- Confinement + กู้คืน stuck ย้ายไป thread เฉพาะ (5) ด้านล่าง

					if distance < 100 and animalGrow(value) >= 100 then
						if not stop then
							stop = value.ped
							ClearPedTasks(value.ped)
						end
						waitTime = 0
						pedCoords = GetEntityCoords(value.ped)
						distance = #(playerCoords - pedCoords)
						if not S.IS_BUSY and distance <= 100.0 and value.age >= maxLv then
							needPrompt = 'เก็บผลผลิต'
							if (IsControlJustReleased(0, 38) or farmauto) then
								farmauto = false
								stop = false
								if not ESX.Game.CheckHasItem(value.itemName, 1) then
									RabbitFarmClient.notify('error', string.format("ไม่มี %s", ESX.Game.GetItemLabel(value.itemName)))
								else
									local canCarry, failLabel = canCarryRewards(value.itemName)
									if not canCarry then
										RabbitFarmClient.notify('error', string.format("กระเป๋าเต็ม รับ %s ไม่ได้", failLabel))
									else
										setBusy()
										clearPrompt()   -- ซ่อนปุ่ม E ระหว่างทำ progress
										FreezeEntityPosition(value.ped, true)
										local done = RabbitFarmClient.progressOnAnimal(value.ped, {
											duration = 2000,
											label = "กำลังเก็บสัตว์",
											canCancel = true,
											disable = { move = false, car = true, mouse = false, combat = false },
											-- ไม่ใส่ anim: ท่าคุกเข่า (machinic_loop) ล็อก locomotion ทำให้เดินไม่ได้ระหว่างเก็บ
										})
										FreezeEntityPosition(value.ped, false)
										-- เช็ค progress จบจริงก่อนยิง event (กัน bypass: บาร์อื่นวิ่งอยู่ → progress คืน false)
										if not done then
											S.IS_BUSY = false
											RabbitFarmClient.notify('error', 'ยกเลิกการเก็บ')
										else
											TriggerServerEvent(S_SV .. 'Harvest', aKey)
											-- ไม่ลบ ped แบบ optimistic — ปล่อยให้ server event 'Harvest' ลบ (กัน desync ถ้า server reject)
										end
									end
								end
								Citizen.Wait(1000)
								farmauto = true
							end
						elseif not S.IS_BUSY and distance <= 100.0 then
							needPrompt = 'ให้อาหาร'
							if (IsControlJustReleased(0, 38) or farmauto) then
								farmauto = false
								stop = false
								local feed = Config["Animals"][value.itemName].feed
								if ESX.Game.CheckHasItem(feed, 1) then
									setBusy()
									clearPrompt()   -- ซ่อนปุ่ม E ระหว่างทำ progress
									local es = Config["EatingSound"]
									if es and es.enabled then RabbitFarmClient.playSound('rf_eating', es.url, es.volume, true) end
									FreezeEntityPosition(value.ped, true)
									local fdone = RabbitFarmClient.progressOnAnimal(value.ped, {
										duration = 2000,
										label = "กำลังให้อาหาร",
										canCancel = true,
										disable = { move = false, car = true, mouse = false, combat = false },
										-- ไม่ใส่ anim: ท่าคุกเข่า (machinic_loop) ล็อก locomotion ทำให้เดินไม่ได้ระหว่างให้อาหาร
									})
									FreezeEntityPosition(value.ped, false)
									RabbitFarmClient.stopSound('rf_eating')   -- หยุดเสียงกิน (จบ/ยกเลิกก็หยุด)
									if fdone then
										TriggerServerEvent(S_SV .. 'Feed', aKey)
									else
										S.IS_BUSY = false
										RabbitFarmClient.notify('error', 'ยกเลิกการให้อาหาร')
									end
								else
									RabbitFarmClient.notify('error', string.format("ไม่มี %s", ESX.Game.GetItemLabel(feed)))
								end
								Citizen.Wait(1000)
								farmauto = true
							end
						end
					elseif stop and stop == value.ped then
						stop = false
						RabbitFarmClient.taskWander(value.ped, zone)
					end

					if distance <= Config["BarDistance"] then
						waitTime = 0
						local g = animalGrow(value)
						if g < 100 then
							RabbitFarmClient.drawBarOnHead(pedCoords, math.ceil(g), 100,
								Config["ColorBar"].grow.r, Config["ColorBar"].grow.b, Config["ColorBar"].grow.g)
						elseif value.age < maxLv then
							RabbitFarmClient.drawBarOnHead(pedCoords, math.ceil(value.dieTime), Config["Animals"][value.itemName].dieTime,
								Config["ColorBar"].death.r, Config["ColorBar"].death.b, Config["ColorBar"].death.g)
						end
					end
				end
			end
			if needPrompt then setPrompt(needPrompt) else clearPrompt() end
			Citizen.Wait(waitTime)
		end
		-- cleanup เฉพาะ "teardown จริง" (gen นี้ยัง current → ออกเพราะ animal_limit หมด) ไม่ใช่ถูก epoch ใหม่แทน
		if S.loopEpoch == e then
			clearPrompt()
			S.IS_BUSY = true
			S.animal_key = nil
			S.Deletes = {}
			S.Animals = {}
			S.AIState = {}
			Wait(100)
			S.IS_BUSY = false
		end
	end)

	-- 3) การเติบโต + หิว/ตาย + push HUD
	Citizen.CreateThread(function()
		local hungrySoundAt = 0   -- GetGameTimer ครั้งล่าสุดที่เล่นเสียงเตือนหิว (0 = พร้อมเล่นทันที)
		while S.animal_limit and S.animal_limit >= 1 and S.loopEpoch == e do
			local hungryCount = 0
			local inFarm = inFarmChannel()
			-- ใกล้คอกไหม (= ped โผล่, < FarDistance) — dieTime นับตายเฉพาะตอนใกล้ กันตายตอน AFK ไกล (โตยังทั่วฟาร์ม)
			local _pz = Config["AnimalZones"][S.animal_key]
			local nearPen = _pz and #(GetEntityCoords(cache.ped) - _pz.coords) < Config["FarDistance"]
			for aKey, value in pairs(S.Animals) do
				if not S.Deletes[aKey] then
					if S.animal_limit > S.maxLimit then
						RabbitFarmClient.deletePed(value.ped)
						TriggerServerEvent(S_SV .. 'RemoveAnimals', { [aKey] = true })
					end
					-- เดิน Active time เฉพาะตอนอยู่ในฟาร์ม (นอกฟาร์ม = Pause) — ตรงกับ server pausedAt (ADR 0006)
					if inFarm then value.activeTime = (value.activeTime or 0) + 1 end
						local maxLv = RabbitFarm.Grow.maxLevel(value.itemName)   -- hoist: ใช้ 3 เช็คในรอบเดียว (grow thread)
					local g = animalGrow(value)
					if g >= 100 and value.age < maxLv then hungryCount = hungryCount + 1 end
					-- เสียงพร้อมเก็บ (edge-trigger ต่อตัว): ครั้งแรกที่ lv=maxLevel + โตเต็ม
					if value.age >= maxLv and g >= 100 and not value._readyPlayed then
						value._readyPlayed = true
						local rs = Config["ReadySound"]
						if rs and rs.enabled then RabbitFarmClient.playSound('rf_ready_' .. aKey, rs.url, rs.volume) end
					end
					-- Hungry (โตเต็ม ยังไม่ lv3) → นับตาย เฉพาะตอนในฟาร์ม "และใกล้คอก" (ไกล = แช่ ไม่ตาย; กัน AFK ไกล)
					if inFarm and nearPen and g >= 100 and value.age < maxLv and value.dieTime > 0 then
						value.dieTime = value.dieTime - 1
						if value.dieTime <= 0 then
							S.Deletes[aKey] = true   -- มาร์คทันที: HUD ไม่โชว์ผี + กันยิง RemoveAnimals ซ้ำ
							RabbitFarmClient.deletePed(value.ped)
							TriggerServerEvent(S_SV .. 'RemoveAnimals', { [aKey] = true })
						end
					end
				end
			end
			RabbitFarmClient.pushAnimals(S.Animals, S.Deletes, S.animal_limit)

			-- เสียงเตือนหิว: หมูหิวแต่ละตัวร้อง repeatTimes ที — เล่นทันทีตอนเริ่มหิว แล้วซ้ำทุก intervalSec
			local snd = Config["HungrySound"]
			if snd and snd.enabled then
				if hungryCount > 0 then
					local now = GetGameTimer()
					if now - hungrySoundAt >= (snd.intervalSec or 30) * 1000 then
						hungrySoundAt = now
						RabbitFarmClient.playHungry(hungryCount)
					end
				else
					hungrySoundAt = 0   -- หายหิวหมด → ครั้งหน้าหิวเล่นทันที
				end
			end

			Citizen.Wait(1000)
		end
	end)

	-- 4) ped streaming ตามระยะคอก — ไม่เกี่ยว growth (โตทั้งฟาร์มตาม statebag; ADR 0006)
	--    ไกล ≥ FarDistance → ลบ ped (perf); กลับมาใกล้ (hysteresis -10m กัน flap) → spawn คืนจาก S.Animals
	--    การหยุดโต/ออกฟาร์มจริง คุมด้วย statebag (channel-watch >125m → zoneExit) ไม่ใช่ระยะคอก
	Citizen.CreateThread(function()
		local despawned = false
		while S.animal_limit and S.animal_limit >= 1 and S.loopEpoch == e do
			local zone = Config["AnimalZones"][S.animal_key]
			if zone then
				local d = #(GetEntityCoords(cache.ped) - zone.coords)
				if not despawned and d >= Config["FarDistance"] then
					despawned = true
					for _, v in pairs(S.Animals) do RabbitFarmClient.deletePed(v.ped); v.ped = nil end
				elseif despawned and d <= Config["FarDistance"] - 10.0 then
					despawned = false
					for aKey, v in pairs(S.Animals) do
						if not S.Deletes[aKey] and not DoesEntityExist(v.ped) then
							v.ped = RabbitFarmClient.spawnAnimalPed(zone, Config["Animals"][v.itemName].model)
						end
					end
				end
			end
			Citizen.Wait(500)
		end
	end)

	-- 5) Confinement (คุมอยู่ในโซน) + กู้คืนเมื่อ stuck แบบไล่ระดับ — อ่านค่าจูนจาก Config["AnimalAI"]
	Citizen.CreateThread(function()
		local cfg         = Config["AnimalAI"] or {}
		local leashOffset = cfg.leashOffset     or 0.5
		local stuckDist   = cfg.stuckDistance   or 0.5
		local stuckSec    = cfg.stuckSeconds    or 3.0
		local retaskSec   = cfg.retaskSeconds   or 8.0
		local teleSec     = cfg.teleportSeconds or 12.0
		local fallDist    = Config["FallDistance"]

		while S.animal_limit and S.animal_limit >= 1 and S.loopEpoch == e do
			local zone = Config["AnimalZones"][S.animal_key]
			local now = GetGameTimer()
			local playerCoords = GetEntityCoords(cache.ped)

			if zone then
				for aKey, value in pairs(S.Animals) do
					if value and not S.Deletes[aKey] and DoesEntityExist(value.ped) then
						local ped = value.ped
						local pedCoords = GetEntityCoords(ped)
						local nearPlayer = #(playerCoords - pedCoords) < 2.0

						-- baseline state ต่อตัว
						local st = S.AIState[aKey]
						if not st then st = { lastPos = pedCoords, lastMoveAt = now, tier = 0, leashing = false }; S.AIState[aKey] = st end

						-- ข้ามถ้ากำลังโต้ตอบ/freeze/busy → รีเซ็ต baseline กัน false-positive ตอนกลับมา
						if nearPlayer or S.IS_BUSY or IsEntityPositionFrozen(ped) then
							st.lastPos = pedCoords; st.lastMoveAt = now; st.tier = 0; st.leashing = false
						else
							local fromCenter = #(pedCoords - zone.coords)
							local zDiff = math.abs(pedCoords.z - zone.coords.z)

							if zDiff > fallDist or fromCenter > zone.radius + 2.0 then
								-- ตก/หลุดแผนที่/ออกไปไกลมาก → snap จุดสุ่มใกล้ center ทันที
								RabbitFarmClient.teleportToZone(ped, zone)
								st.lastPos = GetEntityCoords(ped); st.lastMoveAt = now; st.tier = 0; st.leashing = false
							else
								-- Confinement นุ่ม: ถึงขอบ → เดินกลับ center (re-task ครั้งเดียวด้วย flag)
								local atEdge = fromCenter > (zone.radius - leashOffset)
								if atEdge and not st.leashing then
									st.leashing = true
									RabbitFarmClient.walkToCenter(ped, zone)
									st.lastPos = pedCoords; st.lastMoveAt = now; st.tier = 0
								elseif st.leashing and fromCenter < (zone.radius - leashOffset - 1.0) then
									st.leashing = false
									RabbitFarmClient.taskWander(ped, zone)
									st.lastPos = pedCoords; st.lastMoveAt = now; st.tier = 0
								end

								-- Stuck recovery ไล่ระดับ (ขณะ leashing ให้เฉพาะ tier3 teleport ช่วย กันไปขัดการเดินกลับ)
								local moved = #(pedCoords - st.lastPos)
								if moved >= stuckDist then
									st.lastPos = pedCoords; st.lastMoveAt = now; st.tier = 0
								else
									local stuckFor = (now - st.lastMoveAt) / 1000.0
									if stuckFor >= teleSec then
										RabbitFarmClient.teleportToZone(ped, zone)
										st.lastPos = GetEntityCoords(ped); st.lastMoveAt = now; st.tier = 0; st.leashing = false
									elseif not st.leashing and stuckFor >= retaskSec and st.tier < 2 then
										RabbitFarmClient.walkToCenter(ped, zone)
										st.tier = 2
									elseif not st.leashing and stuckFor >= stuckSec and st.tier < 1 then
										ClearPedTasks(ped)
										RabbitFarmClient.taskWander(ped, zone)
										st.tier = 1
									end
								end
							end
						end
					end
				end
			end

			Citizen.Wait(1000)
		end
	end)
end
RabbitFarmClient.startAnimalLoops = startAnimalLoops

-- ── server → client events ──────────────────────────────────────────────────
RegisterNetEvent(S_CL .. 'TestDrop', function()
	for _, v in pairs(S.Animals) do RabbitFarmClient.deletePed(v.ped) end
	S.IS_BUSY = false
	S.animal_limit = 0
	S.animal_key = nil
	S.Animals, S.Deletes = {}, {}
	S.AIState = {}
end)

RegisterNetEvent(S_CL .. 'Paused', function()
	S.IS_PAUSED = true
end)

RegisterNetEvent(S_CL .. 'RemoveAnimals', function(keys)
	for key, _ in pairs(keys) do
		S.Deletes[key] = true
		S.AIState[key] = nil
		if S.Animals[key] then
			RabbitFarmClient.deletePed(S.Animals[key].ped)
			S.animal_limit = S.animal_limit - Config["Animals"][S.Animals[key].itemName].point
			if S.animal_limit < 0 then S.animal_limit = 0 end
		end
	end
	RabbitFarmClient.pushAnimals(S.Animals, S.Deletes, S.animal_limit)
	if S.animal_limit <= 0 then RabbitFarmClient.setMenu(false) end
	Wait(300)
	getLimit()
	S.IS_BUSY = false
end)

-- server reject action (feed/harvest) → ปลดล็อกกัน soft-lock (S.IS_BUSY ค้างเมื่อ reject ก่อน success-event)
RegisterNetEvent(S_CL .. 'ActionReset', function()
	S.IS_BUSY = false
end)

-- server ปฏิเสธ Feed เพราะ Active time ยังไม่ถึงรอบ (time-gate ADR 0001) แต่ client โชว์ Hungry ไปแล้ว
-- → เติม dieTime คืนเต็ม กันหมูตายเพราะป้อนไม่ได้ (= กันสร้าง Ghost animal). ไม่แตะ lv/grow
RegisterNetEvent(S_CL .. 'FeedTooSoon', function(key)
	local v = S.Animals[key]
	if v and v.itemName then
		local cfg = Config["Animals"][v.itemName]
		if cfg then v.dieTime = cfg.dieTime end
	end
	S.IS_BUSY = false
end)

RegisterNetEvent(S_CL .. 'Feed', function(key, lv)
	if S.Animals[key] then
		S.Animals[key].age = lv   -- grow derive จาก activeTime+lv → เลื่อน lv = grow รีเซ็ตเอง (ADR 0006)
		Wait(300)
		local zone = Config["AnimalZones"][S.animal_key]
		if zone then
			RabbitFarmClient.taskWander(S.Animals[key].ped, zone)
		end
	end
	Wait(100)
	S.IS_BUSY = false
end)

RegisterNetEvent(S_CL .. 'Harvest', function(key, itemName)
	S.Deletes[key] = true
	S.AIState[key] = nil
	if S.Animals[key] then
		RabbitFarmClient.deletePed(S.Animals[key].ped)
		S.animal_limit = S.animal_limit - Config["Animals"][itemName].point
	end
	RabbitFarmClient.pushAnimals(S.Animals, S.Deletes, S.animal_limit)
	if S.animal_limit <= 0 then RabbitFarmClient.setMenu(false) end
	Wait(300)
	getLimit()
	S.IS_BUSY = false
end)

-- โหลด/กู้/resync สัตว์จาก server — payload บาง { [key]={itemName,activeTime,lv} } (grow derive เอง)
-- idempotent: key เดิม ped ยังอยู่ = อัปเดต activeTime/lv (ใช้ตอน resume ไม่ซ้ำ ped); key ใหม่ = spawn (ADR 0006)
RegisterNetEvent(S_CL .. 'LoadAnimals', function(animals)
	-- ไม่ early-return ด้วย animal_key: resync ตอน resume อาจมาตอน animal_key ถูกล้าง (teardown) → ต้องโหลดได้
	S.IS_PAUSED = false
	S.IS_BUSY = true

	local ok = nil
	for zoneKey, value in pairs(Config["AnimalZones"]) do
		if #(GetEntityCoords(cache.ped) - value.coords) <= value.radius then
			ok = zoneKey
			break
		end
	end
	-- resume re-push อาจมาตอนยืน "นอกคอก" (ที่ NPC เลือกมิติ อยู่นอกทุกโซน) — ห้ามทิ้ง payload
	-- ทิ้ง = server ยังถือสัตว์ แต่ client ว่าง = Ghost animal (ADR 0003). resolve โซนเป้าหมายแทน:
	-- คอกเดิมก่อน teardown (S.lastZone) → fallback คอกใกล้สุดในฟาร์ม. เหลือ nil เฉพาะตอนไกลฟาร์มจริง
	if ok == nil then
		ok = (S.lastZone and Config["AnimalZones"][S.lastZone] and S.lastZone) or nearestZoneWithinFarm()
	end
	if ok == nil then
		S.IS_BUSY = false
		RabbitFarmClient.notify('error', 'คุณอยู่นอกโซนเลี้ยงสัตว์')
		return
	end
	if S.animal_key and S.animal_key ~= ok then
		S.IS_BUSY = false
		RabbitFarmClient.notify('error', 'คุณเลี้ยงสัตว์ที่ Zone อื่นอยู่แล้ว')
		return
	end
	S.animal_key = ok   -- bind zone (กรณี resync หลัง teardown ที่ animal_key ถูกล้าง)

	for key, value in pairs(animals) do
		local itemName = value.itemName
		-- key เดิมมีอยู่แล้ว (resync ตอน resume) → อัปเดต activeTime/lv, ไม่บวก animal_limit ซ้ำ
		-- ถ้า ped หลุด stream (ตาย→bucket 0) → spawn ใหม่ให้ key เดิม (ไม่สร้าง entry ใหม่)
		if S.Animals[key] and not S.Deletes[key] then
			S.Animals[key].activeTime = value.activeTime or 0
			S.Animals[key].age = value.lv
			if not DoesEntityExist(S.Animals[key].ped) then
				local z = Config["AnimalZones"][S.animal_key or ok]
				if z then S.Animals[key].ped = RabbitFarmClient.spawnAnimalPed(z, Config["Animals"][itemName].model) end
			end
			goto continue
		end
		local am = ESX.Game.GetInventoryItem(itemName) or 0
		local farm = Config["Animals"][itemName]
		if getAnimalCount(itemName) + 1 > am then
			S.IS_BUSY = false
			RabbitFarmClient.notify('error', string.format("มี %s ไม่ถึงที่จะเลี้ยงเพิ่ม", ESX.Game.GetItemLabel(itemName)))
			TriggerServerEvent(S_SV .. 'RemoveAnimals', { [key] = true })
			Wait(100)
			goto continue
		end
		S.animal_limit = S.animal_limit + farm.point
		S.animal_key = ok
		local zone = Config["AnimalZones"][S.animal_key]
		local ped = RabbitFarmClient.spawnAnimalPed(zone, farm.model)
		S.Animals[key] = { name = RabbitFarmClient.randomName(), itemName = itemName, ped = ped, activeTime = value.activeTime or 0, age = value.lv, model = farm.model, dieTime = farm.dieTime }
		Citizen.Wait(500)
		::continue::
	end
	Citizen.Wait(1000)
	S.IS_BUSY = false
	-- รับประกัน loop วิ่งหลัง resync/restore (เคส teardown แล้วลูปตาย — เดิม LoadAnimals ไม่สตาร์ตลูป)
	if S.animal_limit and S.animal_limit >= 1 then startAnimalLoops() end
end)

-- spawn สัตว์ใหม่จากการใช้ item (server ยิงมาพร้อม key)
RegisterNetEvent(S_CL .. 'SpawnAnimal', function(itemName, key)
	if S.IS_BUSY then return end
	if ESX.GetPedData('PedDeath') or ESX.GetPedData('PedInVehicle') then
		RabbitFarmClient.notify('error', 'ยังไม่พร้อมเลี้ยงสัตว์')
		return
	end
	S.IS_BUSY = true
	local farm = Config["Animals"][itemName]

	local ok = nil
	for zoneKey, value in pairs(Config["AnimalZones"]) do
		if #(GetEntityCoords(cache.ped) - value.coords) <= value.radius then
			ok = zoneKey
			break
		end
	end
	if ok == nil then
		S.IS_BUSY = false
		RabbitFarmClient.notify('error', 'คุณอยู่นอกโซนเลี้ยงสัตว์')
		return
	end
	if S.animal_key and S.animal_key ~= ok then
		S.IS_BUSY = false
		RabbitFarmClient.notify('error', 'คุณเลี้ยงสัตว์ที่ Zone อื่นอยู่แล้ว')
		return
	end
	RabbitFarmClient.refreshMaxLimit()
	if S.animal_limit >= S.maxLimit then
		S.IS_BUSY = false
		RabbitFarmClient.notify('error', 'คุณเลี้ยงสัตว์เต็ม Slot แล้ว')
		return
	end
	if S.animal_limit + farm.point > S.maxLimit then
		S.IS_BUSY = false
		RabbitFarmClient.notify('error', string.format("ไม่สามารถใช้ %s เพราะจะเกิน Slot", ESX.Game.GetItemLabel(itemName)))
		return
	end
	local am = ESX.Game.GetInventoryItem(itemName) or 0
	if getAnimalCount(itemName) + 1 > am then
		S.IS_BUSY = false
		RabbitFarmClient.notify('error', string.format("มี %s ไม่ถึงที่จะเลี้ยงเพิ่มแล้ว", ESX.Game.GetItemLabel(itemName)))
		return
	end

	-- spawn ped ทันที (เหมือนเดิม) แล้วค่อยโชว์ progress 1s ก่อนยืนยันไป server
	S.animal_limit = S.animal_limit + farm.point
	S.animal_key = ok
	local zone = Config["AnimalZones"][S.animal_key]
	local ped = RabbitFarmClient.spawnAnimalPed(zone, farm.model)
	S.Animals[key] = { name = RabbitFarmClient.randomName(), itemName = itemName, ped = ped, activeTime = 0, age = 1, model = farm.model, dieTime = farm.dieTime }

	RabbitFarmClient.progress({ duration = 1000, label = "กำลังปล่อยสัตว์" })

	TriggerServerEvent(S_SV .. "SpawnAnimal", key)
	S.IS_BUSY = false

	startAnimalLoops()
end)

-- cleanup
AddEventHandler("onResourceStop", function(resource)
	if resource == RabbitFarm.SCRIPT then
		for _, v in pairs(S.Animals) do RabbitFarmClient.deletePed(v.ped) end
	end
end)

Citizen.CreateThread(function() 
    while not Config["Action"] do
        Wait(100)
    end

    -- ปรับแต่งค่า
    Config["Action"].cancelDistance = 100
    Config["Action"].feedDuration = 1000
    Config["Action"].harvestDuration = 1000
    
end)