script_name("Diamond Menu")
script_author("Tony Donalds")
script_version("1.0.0.0")

local imgui = require 'imgui'
local inicfg = require 'inicfg'

local has_events, sampev = pcall(require, 'lib.samp.events')
if not has_events then
    has_events, sampev = pcall(require, 'samp.events')
end

local has_vkeys, vkeys = pcall(require, 'vkeys')

local function getStructElement(ptr, offset, size)
    if not ptr or ptr == 0 then return 0 end
    local ok, val = pcall(readMemory, ptr + offset, size, false)
    return (ok and val) and val or 0
end

local function ensureDirectoryExists(path)
    if doesDirectoryExist and createDirectory then
        if not doesDirectoryExist(path) then
            createDirectory(path)
        end
    end
end

local workingDir = getWorkingDirectory()
ensureDirectoryExists(workingDir .. '\\config')
ensureDirectoryExists(workingDir .. '\\config\\DiamondMenu')
ensureDirectoryExists(workingDir .. '\\config\\DiamondMenu\\Settings')

local configSubPath       = 'config/DiamondMenu/Settings/'
local configFile          = configSubPath .. 'Autovester.ini'
local modesConfigFile     = configSubPath .. 'vester_modes.ini'
local vstConfigFile       = configSubPath .. 'vst_vehicles.ini'
local autofindConfigFile  = configSubPath .. 'Autofind.ini'
local keybindsConfigFile  = configSubPath .. 'Keybinds.ini'
local backupConfigFile    = configSubPath .. 'Backup.ini'

-- ============================================================================
-- AUTO-UPDATER CONFIGURATION (Tony-HZG)
-- ============================================================================
local SCRIPT_VERSION_NUM = 1000
local SCRIPT_VERSION_STR = "1.0.0.0"
local VERSION_CHECK_URL  = "https://raw.githubusercontent.com/Tony-HZG/DiamondMenu/main/version.json"

local UP = {
    modalOpen    = false,
    animAlpha    = 0.0,
    status       = "idle",
    onlineVer    = 1000,
    onlineVerStr = "1.0.0.0",
    downloadUrl  = ""
}

local function checkUpdateProcess(isManual)
    UP.status = "checking"
    lua_thread.create(function()
        if not isManual then wait(2000) end
        
        local queryUrl = VERSION_CHECK_URL .. "?t=" .. os.time()
        local tempVerPath = getWorkingDirectory() .. "\\config\\DiamondMenu\\Settings\\check_ver.tmp"
        local isDone = false
        local timeoutClock = os.clock() + 3.0

        downloadUrlToFile(queryUrl, tempVerPath, function(id, status, p1, p2)
            if status == 6 then
                isDone = true
                local ok = pcall(function()
                    local f = io.open(tempVerPath, "r")
                    if f then
                        local raw = f:read("*a")
                        f:close()
                        os.remove(tempVerPath)

                        local onlineVer    = tonumber(raw:match('"version":%s*(%d+)'))
                        local onlineVerStr = raw:match('"version_str":%s*"(.-)"')
                        local downloadUrl  = raw:match('"url":%s*"(.-)"')

                        if onlineVer and downloadUrl then
                            UP.onlineVer    = onlineVer
                            UP.downloadUrl  = downloadUrl
                            UP.onlineVerStr = onlineVerStr or tostring(onlineVer)

                            if onlineVer > SCRIPT_VERSION_NUM then
                                UP.status = "available"
                                if not isManual then
                                    sampAddChatMessage(string.format("{00C8FF}Diamond Menu: {FFFFFF}New update found ({00FF88}v%s{FFFFFF})! Open Home tab to install.", UP.onlineVerStr), -1)
                                end
                            else
                                UP.status = "latest"
                            end
                        else
                            UP.status = "error"
                        end
                    else
                        UP.status = "error"
                    end
                end)
                if not ok then UP.status = "error" end
            elseif status == 7 or status == 8 then
                isDone = true
                UP.status = "error"
            end
        end)

        while not isDone do
            wait(50)
            if os.clock() > timeoutClock then
                if UP.status == "checking" then
                    UP.status = "error"
                end
                break
            end
        end
    end)
end

local function executeScriptDownload()
    if UP.downloadUrl == "" then return end
    UP.status = "downloading"
    lua_thread.create(function()
        local isDone = false
        local timeoutClock = os.clock() + 4.0
        local queryDlUrl = UP.downloadUrl .. "?t=" .. os.time()

        downloadUrlToFile(queryDlUrl, thisScript().path, function(dId, dStatus)
            if dStatus == 6 then
                isDone = true
                sampAddChatMessage("{00C8FF}Diamond Menu: {00FF88}Updated successfully! Restarting...", -1)
                wait(500)
                thisScript():reload()
            elseif dStatus == 7 or dStatus == 8 then
                isDone = true
                UP.status = "error"
            end
        end)

        while not isDone do
            wait(50)
            if os.clock() > timeoutClock then
                if UP.status == "downloading" then
                    UP.status = "error"
                    sampAddChatMessage("{00C8FF}Diamond Menu: {FF4444}Download timed out. Please retry.", -1)
                end
                break
            end
        end
    end)
end

local defConfig = {
    settings = {
        enabled      = false,
        autoaccept   = false,
        price        = 200,
        vob          = 46,
        vcd          = 12.0,
        accept_price = 200,
        accept_vob   = 46,
        vester_mode  = "Everyone"
    }
}

local cfg = inicfg.load(defConfig, configFile) or defConfig
if not cfg.settings then cfg.settings = defConfig.settings end

if cfg.settings.enabled == nil then cfg.settings.enabled = false end
if cfg.settings.autoaccept == nil then cfg.settings.autoaccept = false end
cfg.settings.price        = math.floor(tonumber(cfg.settings.price) or 200)
cfg.settings.vob          = math.floor(tonumber(cfg.settings.vob) or 46)
cfg.settings.vcd          = tonumber(cfg.settings.vcd) or 12.0
cfg.settings.accept_price = math.floor(tonumber(cfg.settings.accept_price) or 200)
cfg.settings.accept_vob   = math.floor(tonumber(cfg.settings.accept_vob) or 46)
cfg.settings.vester_mode  = cfg.settings.vester_mode or "Everyone"

if cfg.settings.price < 200 or cfg.settings.price > 1000 then cfg.settings.price = 200 end
if cfg.settings.vob < 0 or cfg.settings.vob > 100 then cfg.settings.vob = 46 end
if cfg.settings.vcd < 0 or cfg.settings.vcd > 20 then cfg.settings.vcd = 12.0 end
if cfg.settings.accept_price < 200 or cfg.settings.accept_price > 1000 then cfg.settings.accept_price = 200 end
if cfg.settings.accept_vob < 0 or cfg.settings.accept_vob > 49 then cfg.settings.accept_vob = 46 end
inicfg.save(cfg, configFile)

local af_defConfig = { settings = { level = 5 } }
local af_cfg = inicfg.load(af_defConfig, autofindConfigFile) or af_defConfig
if not af_cfg.settings then af_cfg.settings = af_defConfig.settings end
af_cfg.settings.level = math.floor(tonumber(af_cfg.settings.level) or 5)
if af_cfg.settings.level < 1 or af_cfg.settings.level > 5 then af_cfg.settings.level = 5 end
inicfg.save(af_cfg, autofindConfigFile)

local bk_defConfig = {
    settings = {
        enabled = true,
        mode    = "Gang",
        key     = 222,
        alt     = 0,
        ctrl    = 0,
        shift   = 0
    }
}
local bk_cfg = inicfg.load(bk_defConfig, backupConfigFile) or bk_defConfig
if not bk_cfg.settings then bk_cfg.settings = bk_defConfig.settings end

local AF_COOLDOWNS = { [1] = 125, [2] = 85, [3] = 65, [4] = 35, [5] = 20 }
local AF_TAG = "{00C8FF}Diamond Menu: {327ED8}AutoFind: {FFFFFF}"

local AF = {
    active       = false,
    modeCmd      = "/find",
    targetId     = nil,
    targetName   = nil,
    targetLost   = false,
    lastFindTime = 0,
    font         = nil,
    input_target = imgui.ImBuffer(64),
    ui_level     = imgui.ImFloat(af_cfg.settings.level)
}

local KB = {
    list           = {},
    recordingIndex = nil,
    waitRelease    = false,
    lastTrigger    = 0
}

local BK = {
    enabled     = (bk_cfg.settings.enabled ~= false),
    mode        = bk_cfg.settings.mode or "Gang",
    key         = tonumber(bk_cfg.settings.key) or 222,
    alt         = (bk_cfg.settings.alt == 1 or bk_cfg.settings.alt == true),
    ctrl        = (bk_cfg.settings.ctrl == 1 or bk_cfg.settings.ctrl == true),
    shift       = (bk_cfg.settings.shift == 1 or bk_cfg.settings.shift == true),
    recording   = false,
    waitRelease = false,
    lastTrigger = 0,
    isActive    = false
}

local EC = {
    cache   = {},
    pending = nil
}

local BK_LOCATIONS = {
    { name = "Saints Hospital. Market",       x = 1178.0, y = -1324.0, z = 14.0 },
    { name = "County Hospital. Jefferson",    x = 2033.0, y = -1405.0, z = 17.0 },
    { name = "Maximus Club. Idlewood",        x = 1834.0, y = -1682.0, z = 13.5 },
    { name = "Pizza Stacks. Idlewood",        x = 2105.0, y = -1806.0, z = 13.5 },
    { name = "Downtown LS Bank",              x = 1457.0, y = -1011.0, z = 26.8 },
    { name = "Rodeo Bank",                    x = 595.0,  y = -1245.0, z = 18.0 },
    { name = "Dice Casino. Marina",           x = 833.0,  y = -1585.0, z = 13.5 },
    { name = "Star Tower Ground. Downtown LS",x = 1544.0, y = -1353.0, z = 15.0 },
    { name = "Star Tower Roof. Downtown LS",  x = 1544.0, y = -1353.0, z = 329.0 },
    { name = "East Beach Stadium",            x = 2782.0, y = -1774.0, z = 48.0 },
    { name = "LV Abandoned Airstrip",         x = 398.0,  y = 2542.0,  z = 16.5 },
    { name = "Visitation Transport. Playa",   x = 2782.0, y = -2455.0, z = 13.6 },
    { name = "Castille Island",               x = 198.0,  y = -2065.0, z = 6.0  },
    { name = "Glen Park BM",                  x = 1965.0, y = -1198.0, z = 20.0 },
    { name = "PD HQ. Pershing Square",        x = 1554.0, y = -1675.0, z = 16.0 },
    { name = "PD Garage. Pershing Square",    x = 1568.0, y = -1693.0, z = 6.0  },
    { name = "LSPD - Sub Station. Marina",    x = 827.0,  y = -1350.0, z = 13.5 }
}

local function saveBkConfig()
    bk_cfg.settings.enabled = BK.enabled
    bk_cfg.settings.mode    = BK.mode
    bk_cfg.settings.key     = BK.key
    bk_cfg.settings.alt     = BK.alt and 1 or 0
    bk_cfg.settings.ctrl    = BK.ctrl and 1 or 0
    bk_cfg.settings.shift   = BK.shift and 1 or 0
    inicfg.save(bk_cfg, backupConfigFile)
end

local KEY_NAMES = {
    [8] = "Backspace", [9] = "Tab", [13] = "Enter", [19] = "Pause", [20] = "Caps",
    [27] = "Esc", [32] = "Space", [33] = "PageUp", [34] = "PageDown", [35] = "End",
    [36] = "Home", [37] = "Left", [38] = "Up", [39] = "Right", [40] = "Down",
    [45] = "Insert", [46] = "Delete",
    [96] = "Num 0", [97] = "Num 1", [98] = "Num 2", [99] = "Num 3", [100] = "Num 4",
    [101] = "Num 5", [102] = "Num 6", [103] = "Num 7", [104] = "Num 8", [105] = "Num 9",
    [106] = "Num *", [107] = "Num +", [109] = "Num -", [110] = "Num .", [111] = "Num /",
    [112] = "F1", [113] = "F2", [114] = "F3", [115] = "F4", [116] = "F5", [117] = "F6",
    [118] = "F7", [119] = "F8", [120] = "F9", [121] = "F10", [122] = "F11", [123] = "F12",
    [144] = "NumLock", [145] = "ScrollLock",
    [186] = ";", [187] = "=", [188] = ",", [189] = "-", [190] = ".", [191] = "/", [192] = "`",
    [219] = "[", [220] = "\\", [221] = "]", [222] = "'", [226] = "\\"
}

for i = 48, 57 do KEY_NAMES[i] = string.char(i) end
for i = 65, 90 do KEY_NAMES[i] = string.char(i) end

local function getKeyTitle(k, alt, ctrl, shift)
    if not k or k == 0 then return "Unbound" end
    local parts = {}
    if ctrl then table.insert(parts, "Ctrl") end
    if alt then table.insert(parts, "Alt") end
    if shift then table.insert(parts, "Shift") end

    local name = nil
    if has_vkeys and vkeys and vkeys.id_to_name then
        local vName = vkeys.id_to_name(k)
        if vName and vName ~= "" then
            name = vName:gsub("^VK_", "")
        end
    end

    if not name or name == "" then
        name = KEY_NAMES[k] or ("Key " .. tostring(k))
    end

    table.insert(parts, name)
    return table.concat(parts, " + ")
end

local function getPlayerCurrentLocationName()
    if not doesCharExist(PLAYER_PED) then return "San Andreas" end
    local px, py, pz = getCharCoordinates(PLAYER_PED)

    local closestDist = 135.0
    local foundName = nil

    for _, loc in ipairs(BK_LOCATIONS) do
        local dx = px - loc.x
        local dy = py - loc.y
        local dz = pz - loc.z
        local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
        if dist < closestDist then
            closestDist = dist
            foundName = loc.name
        end
    end

    if foundName then return foundName end

    if getNameOfZone then
        local ok, gxt = pcall(getNameOfZone, px, py, pz)
        if ok and gxt and gxt ~= "" then
            if getText then
                local okTxt, txt = pcall(getText, gxt)
                if okTxt and txt and txt ~= "" then
                    return txt
                end
            end
            return gxt
        end
    end

    return "San Andreas"
end

local function loadKeybinds()
    local data = inicfg.load({ binds = { count = 0 } }, keybindsConfigFile)
    local list = {}
    if data and data.binds and data.binds.count then
        local cnt = tonumber(data.binds.count) or 0
        for i = 1, cnt do
            local raw = data.binds[tostring(i)] or data.binds[i]
            if raw and raw ~= "" then
                local cmd, en, k, a, c, s = raw:match("^(.-)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)$")
                if cmd then
                    table.insert(list, {
                        buf   = imgui.ImBuffer(cmd, 128),
                        en    = (en == "1"),
                        key   = tonumber(k) or 0,
                        alt   = (a == "1"),
                        ctrl  = (c == "1"),
                        shift = (s == "1")
                    })
                end
            end
        end
    end
    return list
end

local function saveKeybinds()
    local toSave = { binds = { count = #KB.list } }
    for i, item in ipairs(KB.list) do
        local text = item.buf.v:match("^%s*(.-)%s*$")
        toSave.binds[tostring(i)] = string.format("%s|%d|%d|%d|%d|%d", text, item.en and 1 or 0, item.key or 0, item.alt and 1 or 0, item.ctrl and 1 or 0, item.shift and 1 or 0)
    end
    inicfg.save(toSave, keybindsConfigFile)
end

KB.list = loadKeybinds()

local S = {
    isEnabled          = cfg.settings.enabled,
    isAutoAccept       = cfg.settings.autoaccept,
    lastVestTime       = 0,
    playerCooldowns    = {},
    pedStreamTime      = {},
    lastPruneTime      = 0,
    VEST_RANGE_SQ      = 16.0,
    menuOpen           = imgui.ImBool(false),
    themeApplied       = false,
    currentTab         = 1,
    discordModalOpen   = false,
    discordAnimAlpha   = 0.0,
    resetModalOpen     = false,
    resetAnimAlpha     = 0.0,
    lastFrameTime      = os.clock(),
    activeAction       = nil,
    actionStartTime    = 0,
    refreshReopenTime  = 0,
    ui_price           = imgui.ImFloat(cfg.settings.price),
    ui_vob             = imgui.ImFloat(cfg.settings.vob),
    ui_vcd             = imgui.ImFloat(cfg.settings.vcd),
    ui_accept_price    = imgui.ImFloat(cfg.settings.accept_price),
    ui_accept_vob      = imgui.ImFloat(cfg.settings.accept_vob),
    vesterMode         = cfg.settings.vester_mode,
    input_name         = imgui.ImBuffer(64),
    input_hex          = imgui.ImBuffer(16),
    input_extra        = imgui.ImBuffer(1024),
    input_family       = imgui.ImBuffer(64),
    editingIndex       = nil,
    dummyOpen          = imgui.ImBool(true),
    vesterModalOpen    = false,
    vesterModalAlpha   = 0.0,
    activeSubWindow    = nil,
    subWindowAlpha     = 0.0,
    pointOverModalOpen = false,
    pointOverAnimAlpha = 0.0,
    silentGuardCheck   = false,
    silentPointAudit   = false,
    silentPointInfo    = false,
    silentStatsAudit   = false,
    statsAuditDeadline = 0,
    statsLinesCaught   = 0,
    auditFoundBodyguard = false,
    checkBodyguardOnAvest = false,
    vstVehicles        = {},
    silentVstRefresh   = false,
    silentVstTime      = 0,
    isManualRefresh    = false,
    isVstActive        = false,
    targetSpawnIndex   = nil,
    targetSpawnTime    = 0,
    lastChatLine       = ""
}

local modeEntries = {
    gangs = {},
    factions = {},
    unofficial = {}
}

local function loadVesterModes()
    local data = inicfg.load({
        gangs      = { count = 0 },
        factions   = { count = 0 },
        unofficial = { count = 0 }
    }, modesConfigFile)

    local res = { gangs = {}, factions = {}, unofficial = {} }
    for _, key in ipairs({"gangs", "factions", "unofficial"}) do
        if data and data[key] and data[key].count then
            local cnt = tonumber(data[key].count) or 0
            for i = 1, cnt do
                local raw = data[key][tostring(i)] or data[key][i]
                if raw and raw ~= "" then
                    local name, hex, extra, fam = raw:match("^(.-)|(.-)|(.-)|(.*)$")
                    if not name then
                        name, hex, extra = raw:match("^(.-)|(.-)|(.*)$")
                        fam = ""
                    end
                    if name then
                        table.insert(res[key], { name = name, hex = hex or "", extra = extra or "", family = fam or "" })
                    end
                end
            end
        end
    end
    return res
end

local function saveVesterModes()
    local toSave = {
        gangs      = { count = #modeEntries.gangs },
        factions   = { count = #modeEntries.factions },
        unofficial = { count = #modeEntries.unofficial }
    }
    for _, key in ipairs({"gangs", "factions", "unofficial"}) do
        for i, item in ipairs(modeEntries[key]) do
            toSave[key][tostring(i)] = string.format("%s|%s|%s|%s", item.name or "", item.hex or "", item.extra or "", item.family or "")
        end
    end
    inicfg.save(toSave, modesConfigFile)
end

modeEntries = loadVesterModes()

local function hexToImVec4(hexStr, defaultVec4)
    if not hexStr or hexStr == "" then return defaultVec4 end
    local clean = hexStr:gsub("#", ""):gsub("%s+", "")
    if #clean == 6 then
        local r = tonumber(clean:sub(1, 2), 16)
        local g = tonumber(clean:sub(3, 4), 16)
        local b = tonumber(clean:sub(5, 6), 16)
        if r and g and b then
            return imgui.ImVec4(r / 255, g / 255, b / 255, 1.0)
        end
    end
    return defaultVec4
end

local function isValidSingleName(name)
    if not name or name == "" then return false end
    local f, l = name:match("^([A-Za-z]+)_([A-Za-z]+)$")
    return (f ~= nil and l ~= nil)
end

local function areAllFullNamesValid(text)
    if not text or text:match("^%s*$") then return true end
    local count = 0
    for singleName in text:gmatch("[^%s,]+") do
        count = count + 1
        if not isValidSingleName(singleName) then
            return false
        end
    end
    return count > 0
end

local function loadVstVehicles()
    local data = inicfg.load({ storage = { count = 0 } }, vstConfigFile)
    local list = {}
    if data and data.storage and data.storage.count then
        local cnt = tonumber(data.storage.count) or 0
        for i = 1, cnt do
            local raw = data.storage[tostring(i)] or data.storage[i]
            if raw and raw ~= "" then
                local name, sp = raw:match("^(.-)|(%d+)$")
                if name then
                    table.insert(list, { name = name, spawned = (sp == "1") })
                else
                    table.insert(list, { name = raw, spawned = false })
                end
            end
        end
    end
    return list
end

local function saveVstVehicles(list)
    local toSave = { storage = { count = #list } }
    for i, item in ipairs(list) do
        toSave.storage[tostring(i)] = string.format("%s|%d", item.name, item.spawned and 1 or 0)
    end
    inicfg.save(toSave, vstConfigFile)
end

local function parseVehicleStorage(text)
    local list = {}
    for line in text:gmatch("[^\r\n]+") do
        local clean = line:gsub("{.-}", "")
        local veh = clean:match("Vehicle:%s*(.-)%s*|") or clean:match("Vehicle:%s*(.+)")
        local status = clean:match("Status:%s*(.-)%s*|") or clean:match("Status:%s*(%a+)")
        if veh and veh ~= "" then
            veh = veh:match("^%s*(.-)%s*$")
            if veh ~= "" and veh:lower() ~= "name" and veh:lower() ~= "model" then
                local isSpawned = false
                if status then
                    local s = status:lower():match("^%s*(.-)%s*$")
                    if s:find("spawn") or (s ~= "stored" and s ~= "dead" and s ~= "destroyed") then
                        isSpawned = true
                    end
                end
                table.insert(list, { name = veh, spawned = isSpawned })
            end
        end
    end
    return list
end

S.vstVehicles = loadVstVehicles()

local function getChatInputPos()
    local posX, posY = 30, 265
    local handled = false
    pcall(function()
        if sampGetInputInfoPtr then
            local inputPtr = sampGetInputInfoPtr()
            if inputPtr and inputPtr ~= 0 then
                local editBox = getStructElement(inputPtr, 0x8, 4)
                if editBox and editBox ~= 0 then
                    local ex = getStructElement(editBox, 0x8, 4)
                    local ey = getStructElement(editBox, 0xC, 4)
                    local eh = getStructElement(editBox, 0x14, 4) or 25
                    if ex and ey and ex >= 0 and ey >= 0 and ex < 5000 and ey < 5000 then
                        posX = ex
                        posY = ey + eh + 4
                        handled = true
                    end
                end
            end
        end
    end)
    if not handled then
        local sw, sh = getScreenResolution()
        posX = 30
        posY = math.floor(sh * 0.25) + 35
    end
    return posX, posY
end

local function isChatOpen()
    if sampIsChatInputActive then
        local ok, res = pcall(sampIsChatInputActive)
        if ok and res ~= nil then return res end
    end
    if sampGetInputInfoPtr then
        local ok, ptr = pcall(sampGetInputInfoPtr)
        if ok and ptr and ptr ~= 0 then
            local editBox = getStructElement(ptr, 0x8, 4)
            return editBox ~= 0
        end
    end
    return false
end

local function getCurrentChatInput()
    if sampGetChatInputText then
        local ok, text = pcall(sampGetChatInputText)
        if ok and text and text ~= "" then
            return text
        end
    end
    if sampGetInputInfoPtr then
        local ok, ptr = pcall(sampGetInputInfoPtr)
        if ok and ptr and ptr ~= 0 then
            local okMem, str = pcall(readString, ptr + 0x10, 128)
            if okMem and str then
                return str
            end
        end
    end
    return ""
end

local function triggerSilentVstRefresh(manual)
    S.isManualRefresh = (manual == true)
    S.silentVstRefresh = true
    S.silentVstTime = os.clock()
    sampSendChat("/vst")
end

local function syncConfig()
    cfg.settings.enabled      = S.isEnabled
    cfg.settings.autoaccept   = S.isAutoAccept
    cfg.settings.price        = math.floor(math.max(200, math.min(1000, S.ui_price.v)))
    cfg.settings.vob          = math.floor(math.max(0, math.min(100, S.ui_vob.v)))
    cfg.settings.vcd          = math.max(0.0, math.min(20.0, S.ui_vcd.v))
    cfg.settings.accept_price = math.floor(math.max(200, math.min(1000, S.ui_accept_price.v)))
    cfg.settings.accept_vob   = math.floor(math.max(0, math.min(49, S.ui_accept_vob.v)))
    cfg.settings.vester_mode  = S.vesterMode

    S.ui_price.v        = cfg.settings.price
    S.ui_vob.v          = cfg.settings.vob
    S.ui_vcd.v          = cfg.settings.vcd
    S.ui_accept_price.v = cfg.settings.accept_price
    S.ui_accept_vob.v   = cfg.settings.accept_vob

    inicfg.save(cfg, configFile)
end

local function syncAfConfig()
    af_cfg.settings.level = math.floor(math.max(1, math.min(5, AF.ui_level.v + 0.5)))
    AF.ui_level.v = af_cfg.settings.level
    inicfg.save(af_cfg, autofindConfigFile)
end

local function isPlayerPausedSafe(id)
    if sampIsPlayerPaused then
        local ok, res = pcall(sampIsPlayerPaused, id)
        if ok then return res end
    end
    return false
end

local function isLocalSpawned()
    if sampIsLocalPlayerSpawned then
        local ok, res = pcall(sampIsLocalPlayerSpawned)
        if ok and res ~= nil then return res end
    end
    return doesCharExist(PLAYER_PED) and not isCharDead(PLAYER_PED)
end

local function resolvePlayer(param)
    param = param:match("^%s*(.-)%s*$")
    if tonumber(param) then
        local id = tonumber(param)
        if sampIsPlayerConnected(id) then
            return id, sampGetPlayerNickname(id)
        end
        return nil, nil, "Player with ID " .. id .. " is not connected."
    end

    local matches = {}
    local query = param:lower()
    local maxId = 1000
    if sampGetMaxPlayerId then
        local ok, m = pcall(sampGetMaxPlayerId, true)
        if ok and m then maxId = m end
    end

    for i = 0, maxId do
        if sampIsPlayerConnected(i) then
            local nick = sampGetPlayerNickname(i)
            if nick and nick:lower():sub(1, #query) == query then
                table.insert(matches, { id = i, name = nick })
            end
        end
    end

    if #matches == 0 then
        return nil, nil, "No player found starting with '" .. param .. "'."
    elseif #matches > 1 then
        for _, p in ipairs(matches) do
            if p.name:lower() == query then return p.id, p.name end
        end
        return nil, nil, "Multiple players found starting with '" .. param .. "'. Please type the full name or ID."
    end
    return matches[1].id, matches[1].name
end

local function handleAfCommand(cmd, arg)
    arg = arg:match("^%s*(.-)%s*$")
    if arg == "" then
        if AF.active and AF.modeCmd == cmd then
            AF.active = false
            sampAddChatMessage(AF_TAG .. "{FF0000}OFF", -1)
            return
        end
        if AF.targetName then
            AF.active = true
            AF.modeCmd = cmd
            AF.lastFindTime = 0
            sampAddChatMessage(AF_TAG .. "{00FF00}ON {FFFFFF}(Resumed tracking " .. AF.targetName .. " via " .. cmd .. ").", -1)
            return
        end
        sampAddChatMessage(AF_TAG .. "Usage: " .. (cmd == "/find" and "/af" or "/afco") .. " [ID/Name]", -1)
        return
    end

    local id, name, err = resolvePlayer(arg)
    if not id then
        sampAddChatMessage(AF_TAG .. "{FF4444}" .. err, -1)
        return
    end

    AF.targetId = id
    AF.targetName = name
    AF.targetLost = false
    AF.active = true
    AF.modeCmd = cmd
    AF.lastFindTime = 0
    sampAddChatMessage(AF_TAG .. "{00FF00}ON {FFFFFF}- Tracking: {FFFF00}" .. name .. " {FFFFFF}[ID: " .. id .. "] (" .. cmd .. ")", -1)
end

local function handleEasyCall(mode, arg)
    arg = arg:match("^%s*(.-)%s*$")
    if mode == "call" then
        if arg == "" then
            sampAddChatMessage("{00C8FF}Diamond Menu: {FFFFFF}Usage: /pcall [ID/Part of Name]", -1)
            return
        end
        local id, name, err = resolvePlayer(arg)
        if not id then
            sampAddChatMessage("{00C8FF}Diamond Menu: {FF4444}" .. tostring(err), -1)
            return
        end
        local cachedNum = EC.cache[name:lower()]
        if cachedNum then
            sampSendChat("/call " .. cachedNum)
        else
            EC.pending = { type = "call", targetId = id, targetName = name, time = os.clock() }
            sampSendChat("/number " .. id)
        end
    elseif mode == "sms" then
        local target, msg = arg:match("^(%S+)%s+(.+)$")
        if not target or not msg or msg == "" then
            sampAddChatMessage("{00C8FF}Diamond Menu: {FFFFFF}Usage: /pm [ID/Part of Name] [Message]", -1)
            return
        end
        local id, name, err = resolvePlayer(target)
        if not id then
            sampAddChatMessage("{00C8FF}Diamond Menu: {FF4444}" .. tostring(err), -1)
            return
        end
        local cachedNum = EC.cache[name:lower()]
        if cachedNum then
            sampSendChat(string.format("/sms %s %s", cachedNum, msg))
        else
            EC.pending = { type = "sms", targetId = id, targetName = name, msg = msg, time = os.clock() }
            sampSendChat("/number " .. id)
        end
    end
end

local function lerpAnim(current, target, speed, dt)
    return current + (target - current) * math.min(1.0, speed * dt)
end

local function drawLoadingWheel(radius, thickness, color)
    local pos = imgui.GetCursorScreenPos()
    local drawList = imgui.GetWindowDrawList()
    local center = imgui.ImVec2(pos.x + radius + 4, pos.y + radius + 1)
    local num_segments = 20
    local startAngle = os.clock() * 7.0
    local angleLength = math.pi * 1.5

    drawList:PathClear()
    for i = 0, num_segments do
        local a = startAngle + (i / num_segments) * angleLength
        drawList:PathLineTo(imgui.ImVec2(center.x + math.cos(a) * radius, center.y + math.sin(a) * radius))
    end
    drawList:PathStroke(color, false, thickness)
    imgui.Dummy(imgui.ImVec2(radius * 2 + 8, radius * 2 + 2))
end

local function getAccurateArmor(ped, id)
    local netArmor = 0
    if sampGetPlayerArmor then
        local ok, arm = pcall(sampGetPlayerArmor, id)
        if ok and arm then netArmor = arm end
    end

    local pedArmor = 0
    if ped and doesCharExist(ped) then
        if getCharArmour then
            local ok, arm = pcall(getCharArmour, ped)
            if ok and arm then pedArmor = arm end
        end
        local ptr = getCharPointer(ped)
        if ptr and ptr ~= 0 then
            local ok, raw = pcall(readMemory, ptr + 0x548, 4, false)
            if ok and raw then
                local fArm = representIntAsFloat(raw)
                if fArm and fArm >= 0 and fArm <= 100 then
                    pedArmor = math.max(pedArmor, math.floor(fArm + 0.5))
                end
            end
        end
    end
    return math.max(netArmor, pedArmor)
end

local function triggerStatsJobAudit(isManualAvest)
    S.checkBodyguardOnAvest = isManualAvest or false
    S.silentStatsAudit      = true
    S.statsAuditDeadline    = os.clock() + 2.0
    S.statsLinesCaught      = 0
    S.auditFoundBodyguard   = false
    sampSendChat("/stats")
end

local function toggleAutoVesterFast()
    if not S.isEnabled then
        S.isEnabled = true
        syncConfig()
        sampAddChatMessage("{00C8FF}Diamond Menu: {327ED8}AutoVester: {00FF00}ON", -1)
        triggerStatsJobAudit(true)
    else
        S.isEnabled = false
        syncConfig()
        sampAddChatMessage("{00C8FF}Diamond Menu: {327ED8}AutoVester: {FF0000}OFF", -1)
    end
end

local function triggerPointAuditSequence()
    lua_thread.create(function()
        wait(2500)
        S.silentPointAudit = true
        sampSendChat("/nextpoint")
    end)
end

local function handleServerChat(text)
    local clean = text:gsub("{.-}", "")
    local lower = clean:lower()

    if EC.pending and (os.clock() - EC.pending.time <= 4.0) then
        local num = clean:match("%(%s*([%-%d]+)%s*%)")
        if num then
            EC.cache[EC.pending.targetName:lower()] = num
            if EC.pending.type == "call" then
                sampSendChat("/call " .. num)
            elseif EC.pending.type == "sms" then
                sampSendChat(string.format("/sms %s %s", num, EC.pending.msg))
            end
            EC.pending = nil
            return false
        end
        if lower:find("does not have a phone") or lower:find("doesn't have a phone") or lower:find("no phone") or lower:find("not connected") or lower:find("invalid player") then
            sampAddChatMessage("{00C8FF}Diamond Menu: {FF4444}Player does not have a phone or is offline.", -1)
            EC.pending = nil
            return false
        end
    end

    if lower:find("no family has capped the point") or lower:find("point is not ready to be capped") then
        S.silentPointInfo = false
        return false
    end

    if lower:find("quit your job") or lower:find("quit your secondary job") then
        lua_thread.create(function()
            wait(250)
            triggerStatsJobAudit(false)
        end)
        return nil
    end

    if lower:find("you are now a bodyguard") then
        lua_thread.create(function()
            wait(50)
            S.isEnabled = true
            syncConfig()
            sampAddChatMessage("{00C8FF}Diamond Menu: {327ED8}AutoVester: {00FF00}ON", -1)
        end)
        return nil
    end

    if clean:find("Welcome to Horizon Roleplay,") then
        triggerPointAuditSequence()
    end

    if S.silentPointAudit then
        if clean:find("Next available point:") or (clean:find("Name:") and clean:find("Owner:")) then
            return false
        elseif clean:find("Captured By:") and clean:find("Hours:") then
            S.silentPointAudit = false
            local hours = clean:match("Hours:%s*(%d+)")
            if hours and tonumber(hours) == 0 then
                lua_thread.create(function()
                    wait(600)
                    S.silentPointInfo = true
                    sampSendChat("/pointinfo")
                end)
            end
            return false
        end
    end

    if S.silentPointInfo then
        if clean:find("Point Info:") or clean:find("Capper:") or clean:find("Time left:") or clean:find("Family:") then
            lua_thread.create(function()
                wait(500)
                S.silentGuardCheck = true
                sampSendChat("/guard")
            end)
            return false
        end
    end

    if S.silentGuardCheck then
        if clean:find("You are not a bodyguard") then
            S.silentGuardCheck = false
            return false
        elseif lower:find("/guard") and lower:find("usage") then
            S.silentGuardCheck = false
            S.isEnabled = true
            syncConfig()
            sampAddChatMessage("{00C8FF}Diamond Menu: {327ED8}AutoVester: {00FF00}ON {FF0000}(point)", -1)
            return false
        end
    end

    if lower:find("captured the point") or lower:find("taken the point") or lower:find("point has been captured") or lower:find("successfully captured") then
        S.pointOverModalOpen = true
    end

    if S.silentStatsAudit then
        local isBorder = clean:match("____+") or clean:match("%-%-%-%-+") or clean:match("====+") or
                         clean:match("~~~~+") or clean:match("%*%*%*%*+") or clean:match("¯¯¯¯+") or
                         clean:match("————+") or clean:match("────+") or clean:match("━━━━+") or
                         clean:match("════+") or clean:match("^%s*[_%-%=~%*¯—─━═]+%s*$")

        local isStatsContent = clean:find("%(Level:") or clean:find("%(Family:") or clean:find("%(Total wealth:") or
                               clean:find("%(Respect points:") or clean:find("%(Crimes:") or clean:find("%(Rope:") or
                               clean:find("%(Wanted Level:") or clean:find("%(Job:") or clean:find("%(Job 2:") or
                               clean:find("%(Playing hours:") or clean:find("%(Gender:") or clean:find("%(Age:") or
                               clean:find("%(Phone number:") or clean:find("%(Cash:") or clean:find("%(Bank balance:") or
                               clean:find("%(Insurance:") or clean:find("%(Married to:") or clean:find("%(Upgrades:") or
                               clean:find("%(Spawn armor:") or clean:find("%(Health:") or clean:find("%(Armor:") or
                               clean:find("%(Radio:") or clean:find("%(Arrests:") or clean:find("%(Materials:") or
                               clean:find("%(Pot:") or clean:find("%(Crack:") or clean:find("%(Packages:") or
                               clean:find("%(Crates:") or clean:find("%(Cigars:") or clean:find("%(Sprunk:") or
                               clean:find("%(Spray:") or clean:find("%(Seeds:") or clean:find("%(Blindfolds:") or
                               clean:find("%(Ref Tokens:") or clean:find("%(Donator:")

        if isBorder or isStatsContent then
            S.statsLinesCaught = S.statsLinesCaught + 1

            if clean:find("%(Job:") and clean:find("%(Job 2:") then
                local job1 = clean:match("%(Job:%s*(.-)%s*%[") or clean:match("%(Job:%s*(.-)%)")
                local job2 = clean:match("%(Job 2:%s*(.-)%s*%[") or clean:match("%(Job 2:%s*(.-)%)")
                local hasBodyguard = false
                if job1 and job1:lower():find("bodyguard") then hasBodyguard = true end
                if job2 and job2:lower():find("bodyguard") then hasBodyguard = true end
                S.auditFoundBodyguard = hasBodyguard
            end

            if isBorder and S.statsLinesCaught >= 6 then
                S.silentStatsAudit = false
                local hasBodyguard = S.auditFoundBodyguard

                if S.checkBodyguardOnAvest then
                    S.checkBodyguardOnAvest = false
                    if not hasBodyguard then
                        S.isEnabled = false
                        syncConfig()
                        sampAddChatMessage("{00C8FF}Diamond Menu: {327ED8}AutoVester: {FF0000}OFF {FFFFFF}(You do not have the Bodyguard job)", -1)
                    end
                else
                    if not hasBodyguard and S.isEnabled then
                        S.isEnabled = false
                        syncConfig()
                        sampAddChatMessage("{00C8FF}Diamond Menu: {327ED8}AutoVester: {FF0000}OFF {FFFFFF}(You do not have the Bodyguard job)", -1)
                    end
                end
            end

            return false
        end
    end

    if #S.vstVehicles > 0 then
        for _, veh in ipairs(S.vstVehicles) do
            if lower:find(veh.name:lower(), 1, true) then
                if lower:find("spawned") and not lower:find("despawn") then
                    veh.spawned = true
                    saveVstVehicles(S.vstVehicles)
                elseif lower:find("despawn") or lower:find("stored") then
                    veh.spawned = false
                    saveVstVehicles(S.vstVehicles)
                end
            end
        end
    end

    if not S.isAutoAccept then return end

    local price = clean:match("wants to protect you for %$(%d+)")
    if price then
        local numPrice = tonumber(price)
        local allowedPrice = tonumber(cfg.settings.accept_price) or 200

        if numPrice and numPrice <= allowedPrice and numPrice >= 200 then
            local _, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
            local myArmor = getAccurateArmor(PLAYER_PED, myId)
            local maxAllowedArmor = tonumber(cfg.settings.accept_vob) or 46

            if myArmor <= maxAllowedArmor then
                sampSendChat("/accept bodyguard")
            end
        end
    end
end

if has_events and sampev then
    function sampev.onServerMessage(color, text)
        local res = handleServerChat(text)
        if res == false then
            return false
        end
    end

    function sampev.onSendCommand(command)
        local num = command:match("^/vst%s+(%d+)$") or command:match("^/vst(%d+)$")
        if num then
            local idx = tonumber(num)
            if idx and idx >= 1 then
                S.targetSpawnIndex = idx
                S.targetSpawnTime  = os.clock()
                sampSendChat("/vst")
                return false
            end
        end
    end

    function sampev.onShowDialog(dialogId, style, title, b1, b2, text)
        if EC.pending and (os.clock() - EC.pending.time <= 4.0) then
            local cleanDialog = text:gsub("{.-}", "")
            local num = cleanDialog:match("%(%s*([%-%d]+)%s*%)") or cleanDialog:match("(%d%d%d+)")
            if num then
                EC.cache[EC.pending.targetName:lower()] = num
                if EC.pending.type == "call" then
                    sampSendChat("/call " .. num)
                elseif EC.pending.type == "sms" then
                    sampSendChat(string.format("/sms %s %s", num, EC.pending.msg))
                end
                EC.pending = nil
                sampSendDialogResponse(dialogId, 0, -1, "")
                return false
            end
        end

        local cleanTitle = title:gsub("{.-}", "")
        if cleanTitle:lower():find("vehicle storage") then
            local parsed = parseVehicleStorage(text)
            if #parsed > 0 then
                S.vstVehicles = parsed
                saveVstVehicles(S.vstVehicles)
            end

            if S.targetSpawnIndex ~= nil then
                local chosenIdx = S.targetSpawnIndex
                S.targetSpawnIndex = nil

                if chosenIdx >= 1 and chosenIdx <= #parsed then
                    sampSendDialogResponse(dialogId, 1, chosenIdx - 1, "")
                    local vehName = parsed[chosenIdx].name
                    sampAddChatMessage(string.format("{00C8FF}Diamond Menu: {FFFFFF}(De)spawning vehicle #{FFFF00}%d{FFFFFF} ({00FF88}%s{FFFFFF})...", chosenIdx, vehName), -1)
                else
                    sampSendDialogResponse(dialogId, 0, -1, "")
                    sampAddChatMessage(string.format("{00C8FF}Diamond Menu: {FF5555}Vehicle slot #{FFFF00}%d{FF5555} does not exist (You have %d vehicles).", chosenIdx, #parsed), -1)
                end
                return false
            end

            if S.silentVstRefresh then
                S.silentVstRefresh = false
                sampSendDialogResponse(dialogId, 0, -1, "")
                if S.isManualRefresh then
                    sampAddChatMessage(string.format("{00C8FF}Diamond Menu: {FFFFFF}Updated {00FF88}%d{FFFFFF} vehicle(s) from storage.", #S.vstVehicles), -1)
                    S.isManualRefresh = false
                end
                return false
            end
        end
    end
end

local function isPlayerAllowedByMode(ped, id)
    if S.vesterMode == "Everyone" then
        return true
    end

    local targetCategory = nil
    if S.vesterMode == "Gangs" then targetCategory = "gangs"
    elseif S.vesterMode == "Factions" then targetCategory = "factions"
    elseif S.vesterMode == "Unofficial Gangs" then targetCategory = "unofficial"
    end

    if not targetCategory or #modeEntries[targetCategory] == 0 then
        return false
    end

    local skin = getCharModel(ped)
    local pColor = sampGetPlayerColor(id)
    local pName = sampGetPlayerNickname(id)

    for _, entry in ipairs(modeEntries[targetCategory]) do
        local matchesHex = false
        local cleanHex = entry.hex:gsub("#", ""):gsub("%s+", "")
        if cleanHex ~= "" then
            local numHex = tonumber(cleanHex, 16)
            if numHex then
                local pRgb = bit.band(pColor, 0xFFFFFF)
                if pRgb == numHex or bit.rshift(pColor, 8) == numHex then
                    matchesHex = true
                end
            end
        else
            matchesHex = true
        end

        if targetCategory == "unofficial" then
            local matchesMember = false

            if entry.family and entry.family ~= "" then
                local cleanFam = entry.family:gsub("%s+", ""):lower()
                local _, pLastName = pName:match("^([A-Za-z]+)_([A-Za-z]+)$")
                if pLastName and pLastName:lower() == cleanFam then
                    matchesMember = true
                end
            end

            if not matchesMember and entry.extra and entry.extra ~= "" then
                for singleName in entry.extra:gmatch("[^%s,]+") do
                    if singleName:lower() == pName:lower() then
                        matchesMember = true
                        break
                    end
                end
            end

            if (not entry.family or entry.family == "") and (not entry.extra or entry.extra == "") then
                matchesMember = true
            end

            if matchesMember and matchesHex then
                return true
            end
        else
            local matchesSkin = false
            if entry.extra and entry.extra ~= "" then
                for sId in entry.extra:gmatch("%d+") do
                    if tonumber(sId) == skin then
                        matchesSkin = true
                        break
                    end
                end
            else
                matchesSkin = true
            end

            if matchesSkin and matchesHex then
                return true
            end
        end
    end

    return false
end

local function findNearestTarget()
    if not doesCharExist(PLAYER_PED) then return nil end

    local fading = false
    pcall(function() fading = isFading() end)
    if fading then return nil end

    local myX, myY, myZ = getCharCoordinates(PLAYER_PED)
    local closestDistSq = S.VEST_RANGE_SQ
    local targetId = nil
    local now = os.clock()
    local threshold = tonumber(cfg.settings.vob) or 46

    local peds = getAllChars()
    for i = 1, #peds do
        local ped = peds[i]
        if ped ~= PLAYER_PED and doesCharExist(ped) and not isCharDead(ped) then
            local pX, pY, pZ = getCharCoordinates(ped)
            local dx, dy, dz = myX - pX, myY - pY, myZ - pZ
            local distSq = dx * dx + dy * dy + dz * dz

            if distSq < closestDistSq then
                local found, id = sampGetPlayerIdByCharHandle(ped)
                if found and sampIsPlayerConnected(id) then
                    if not isPlayerPausedSafe(id) then
                        if isPlayerAllowedByMode(ped, id) then
                            if not S.pedStreamTime[id] then
                                S.pedStreamTime[id] = now
                            end

                            if (now - S.pedStreamTime[id] >= 1.5) then
                                if not S.playerCooldowns[id] or (now - S.playerCooldowns[id] >= 3.0) then
                                    local accurateArmor = getAccurateArmor(ped, id)
                                    if accurateArmor <= threshold then
                                        closestDistSq = distSq
                                        targetId = id
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return targetId
end

local function applyDiamondTheme()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4

    style.WindowRounding    = 8.0
    style.FrameRounding     = 4.0
    style.ItemSpacing       = imgui.ImVec2(8, 5)
    style.ItemInnerSpacing  = imgui.ImVec2(6, 4)
    style.ScrollbarSize     = 8.0

    colors[clr.WindowBg]          = ImVec4(0.04, 0.06, 0.10, 0.97)
    colors[clr.PopupBg]           = ImVec4(0.06, 0.08, 0.13, 0.98)
    colors[clr.Border]            = ImVec4(0.00, 0.80, 1.00, 0.65)
    colors[clr.Separator]         = ImVec4(0.00, 0.60, 0.90, 0.35)

    if clr.ChildWindowBg then colors[clr.ChildWindowBg] = ImVec4(0.06, 0.08, 0.14, 0.85) end
    if clr.ChildBg then colors[clr.ChildBg] = ImVec4(0.06, 0.08, 0.14, 0.85) end

    colors[clr.Text]              = ImVec4(0.92, 0.96, 1.00, 1.00)
    colors[clr.TextDisabled]      = ImVec4(0.40, 0.50, 0.65, 1.00)

    colors[clr.FrameBg]           = ImVec4(0.08, 0.12, 0.20, 0.90)
    colors[clr.FrameBgHovered]    = ImVec4(0.12, 0.18, 0.30, 1.00)
    colors[clr.FrameBgActive]     = ImVec4(0.15, 0.24, 0.38, 1.00)

    colors[clr.CheckMark]         = ImVec4(0.00, 0.90, 1.00, 1.00)
    colors[clr.SliderGrab]        = ImVec4(0.00, 0.80, 1.00, 1.00)
    colors[clr.SliderGrabActive]  = ImVec4(0.40, 0.95, 1.00, 1.00)

    colors[clr.Button]            = ImVec4(0.08, 0.15, 0.26, 0.90)
    colors[clr.ButtonHovered]     = ImVec4(0.13, 0.25, 0.42, 1.00)
    colors[clr.ButtonActive]      = ImVec4(0.00, 0.70, 0.95, 1.00)

    colors[clr.Header]            = ImVec4(0.10, 0.20, 0.34, 0.85)
    colors[clr.HeaderHovered]     = ImVec4(0.15, 0.30, 0.48, 1.00)
    colors[clr.HeaderActive]      = ImVec4(0.00, 0.65, 0.90, 1.00)
end

local vesterModeCycle = {
    "Everyone",
    "Gangs",
    "Factions",
    "Unofficial Gangs"
}

-- ============================================================================
-- SCRIPT TERMINATE CLEANUP (Fixes Ctrl+R cursor lock bug)
-- ============================================================================
function onScriptTerminate(scr, quitGame)
    if scr == thisScript() then
        showCursor(false)
        pcall(function() sampSetCursorMode(0) end)
        imgui.ShowCursor = false
        imgui.Process = false
    end
end

function main()
    while not isSampAvailable() do wait(100) end

    -- Reset cursor state immediately upon script startup/reload
    showCursor(false)
    pcall(function() sampSetCursorMode(0) end)
    imgui.ShowCursor = false
    imgui.Process = false

    if renderCreateFont then
        pcall(function() AF.font = renderCreateFont("Arial", 12, 5) end)
    end

    local function toggleMenu()
        S.menuOpen.v = not S.menuOpen.v 
        if S.menuOpen.v then 
            S.currentTab = 1
        else
            S.vesterModalOpen = false
            S.activeSubWindow = nil
            S.discordModalOpen = false
            S.resetModalOpen = false
            S.editingIndex = nil
            KB.recordingIndex = nil
            BK.recording = false
            UP.modalOpen = false
        end
    end

    sampRegisterChatCommand("diamondmenu", toggleMenu)
    sampRegisterChatCommand("dmenu", toggleMenu)
    sampRegisterChatCommand("dm", toggleMenu)

    sampRegisterChatCommand("reloaddiamondmenu", function()
        S.activeAction = "reload"
        S.actionStartTime = os.clock()
        sampAddChatMessage("{00C8FF}Diamond Menu: {FFFFFF}Reloading configuration...", -1)
    end)

    sampRegisterChatCommand("refreshvst", function()
        triggerSilentVstRefresh(true)
        sampAddChatMessage("{00C8FF}Diamond Menu: {FFFFFF}Refreshing vehicle storage list...", -1)
    end)

    sampRegisterChatCommand("pcall", function(arg) handleEasyCall("call", arg) end)
    sampRegisterChatCommand("pm", function(arg) handleEasyCall("sms", arg) end)

    sampRegisterChatCommand("vestermode", function()
        local nextIndex = 1
        for i, m in ipairs(vesterModeCycle) do
            if S.vesterMode == m then
                nextIndex = (i % #vesterModeCycle) + 1
                break
            end
        end

        S.vesterMode = vesterModeCycle[nextIndex]
        syncConfig()

        if S.vesterMode == "Everyone" then
            sampAddChatMessage("{00C8FF}Diamond Menu: {FFFFFF}Everyone", -1)
        else
            local catKey = "gangs"
            if S.vesterMode == "Factions" then catKey = "factions"
            elseif S.vesterMode == "Unofficial Gangs" then catKey = "unofficial"
            end

            local list = modeEntries[catKey]
            if #list == 0 then
                sampAddChatMessage(string.format("{00C8FF}Diamond Menu: {FFFFFF}%s: {AAAAAA}(No groups added)", S.vesterMode), -1)
            else
                local groupNames = {}
                for _, item in ipairs(list) do
                    local cleanHex = item.hex:gsub("#", ""):gsub("%s+", "")
                    if #cleanHex == 6 then
                        table.insert(groupNames, string.format("{%s}%s{FFFFFF}", cleanHex, item.name or ""))
                    else
                        table.insert(groupNames, string.format("{00FF88}%s{FFFFFF}", item.name or ""))
                    end
                end
                sampAddChatMessage(string.format("{00C8FF}Diamond Menu: {FFFFFF}%s: %s", S.vesterMode, table.concat(groupNames, ", ")), -1)
            end
        end
    end)

    local function toggleAutoAccept()
        S.isAutoAccept = not S.isAutoAccept
        syncConfig()
        if S.isAutoAccept then
            sampAddChatMessage("{00C8FF}Diamond Menu: {327ED8}AutoAcceptVest: {00FF00}ON", -1)
        else
            sampAddChatMessage("{00C8FF}Diamond Menu: {327ED8}AutoAcceptVest: {FF0000}OFF", -1)
        end
    end

    sampRegisterChatCommand("av", toggleAutoAccept)
    sampRegisterChatCommand("aav", toggleAutoAccept)

    sampRegisterChatCommand("aob", function(param)
        local val = tonumber(param)
        if val and val >= 0 and val <= 49 then
            cfg.settings.accept_vob = math.floor(val)
            S.ui_accept_vob.v = cfg.settings.accept_vob
            syncConfig()
            sampAddChatMessage(string.format("{00C8FF}Diamond Menu: {FFFFFF}[AutoAccept] Armor threshold set to: {FFFF00}%d AP{FFFFFF}.", cfg.settings.accept_vob), -1)
        else
            sampAddChatMessage("{00C8FF}Diamond Menu: {FFFFFF}[AutoAccept] Usage: {FFFF00}/aob [0-49]{FFFFFF}.", -1)
        end
    end)

    sampRegisterChatCommand("ap", function(param)
        local price = tonumber(param)
        if price and price >= 200 and price <= 1000 then
            cfg.settings.accept_price = math.floor(price)
            S.ui_accept_price.v = cfg.settings.accept_price
            syncConfig()
            sampAddChatMessage(string.format("{00C8FF}Diamond Menu: {FFFFFF}[AutoAccept] Accept price limit set to: {00FF88}$%d{FFFFFF}.", cfg.settings.accept_price), -1)
        else
            sampAddChatMessage("{00C8FF}Diamond Menu: {FFFFFF}[AutoAccept] Usage: {FFFF00}/ap [200-1000]{FFFFFF}.", -1)
        end
    end)

    sampRegisterChatCommand("avest", toggleAutoVesterFast)

    sampRegisterChatCommand("vob", function(param)
        local val = tonumber(param)
        if val and val >= 0 and val <= 100 then
            cfg.settings.vob = math.floor(val)
            S.ui_vob.v = cfg.settings.vob
            syncConfig()
            sampAddChatMessage(string.format("{00C8FF}Diamond Menu: {FFFFFF}[AutoVester] Armor threshold set to: {FFFF00}%d AP", S.ui_vob.v), -1)
        else
            sampAddChatMessage("{00C8FF}Diamond Menu: {FFFFFF}[AutoVester] Usage: {FFFF00}/vob [0-100].", -1)
        end
    end)

    sampRegisterChatCommand("vp", function(param)
        local price = tonumber(param)
        if price and price >= 200 and price <= 1000 then
            cfg.settings.price = math.floor(price)
            S.ui_price.v = cfg.settings.price
            syncConfig()
            sampAddChatMessage(string.format("{00C8FF}Diamond Menu: {FFFFFF}[AutoVester] Vest price set to: {00FF88}$%d{FFFFFF}.", S.ui_price.v), -1)
        else
            sampAddChatMessage("{00C8FF}Diamond Menu: {FFFFFF}[AutoVester] Usage: {FFFF00}/vp [200-1000]", -1)
        end
    end)

    sampRegisterChatCommand("vcd", function(param)
        local cd = tonumber(param)
        if cd and cd >= 0 and cd <= 20 then
            cfg.settings.vcd = cd
            S.ui_vcd.v = cfg.settings.vcd
            syncConfig()
            sampAddChatMessage(string.format("{00C8FF}Diamond Menu: {FFFFFF}[AutoVester] Cooldown set to: {FFFF00}%.1fs{FFFFFF}.", cfg.settings.vcd), -1)
        else
            sampAddChatMessage("{00C8FF}Diamond Menu: {FFFFFF}[AutoVester] Usage: {FFFF00}/vcd [0-20]", -1)
        end
    end)

    sampRegisterChatCommand("af", function(arg) handleAfCommand("/find", arg) end)
    sampRegisterChatCommand("afco", function(arg) handleAfCommand("/cohort", arg) end)
    sampRegisterChatCommand("afcd", function(lvl)
        lvl = tonumber(lvl)
        if lvl and AF_COOLDOWNS[lvl] then
            AF.ui_level.v = lvl
            syncAfConfig()
            sampAddChatMessage(AF_TAG .. "{FFFFFF}Detective Level set to {FFFF00}" .. lvl .. " {FFFFFF}(" .. AF_COOLDOWNS[lvl] .. "s CD).", -1)
        else
            sampAddChatMessage(AF_TAG .. "Usage: /afcd [1-5]", -1)
        end
    end)

    sampAddChatMessage("{00C8FF}Diamond Menu by Tony Donalds (v" .. SCRIPT_VERSION_STR .. ")", -1)

    checkUpdateProcess(false)

    lua_thread.create(function()
        wait(2500)
        while sampIsDialogActive and sampIsDialogActive() do wait(1000) end
        wait(1000)
        triggerSilentVstRefresh(false)
    end)

    while true do
        wait(0)
        local now = os.clock()

        if S.silentStatsAudit and now > S.statsAuditDeadline then
            S.silentStatsAudit = false
            S.checkBodyguardOnAvest = false
        end

        if EC.pending and (now - EC.pending.time > 4.0) then
            EC.pending = nil
        end

        isVstActive = false
        S.isVstActive = false
        if isChatOpen() then
            local inputText = getCurrentChatInput()
            if inputText and inputText ~= "" then
                local low = inputText:lower():gsub("^%s+", "")
                if low:match("^/vst$") or low:match("^/vst%s") or low:match("^/vst%d") then
                    S.isVstActive = true
                end
            end
        end

        local wantsUi = S.menuOpen.v or S.discordAnimAlpha > 0.01 or S.resetAnimAlpha > 0.01 or S.vesterModalAlpha > 0.01 or S.subWindowAlpha > 0.01 or S.pointOverAnimAlpha > 0.01 or S.isVstActive or UP.animAlpha > 0.01
        imgui.Process = wantsUi

        local wantsCursor = S.menuOpen.v or S.discordModalOpen or S.resetModalOpen or S.vesterModalOpen or (S.activeSubWindow ~= nil) or S.pointOverModalOpen or UP.modalOpen
        imgui.ShowCursor = wantsCursor

        if S.silentVstRefresh and (now - S.silentVstTime >= 5.0) then
            S.silentVstRefresh = false
            S.isManualRefresh  = false
        end

        if S.targetSpawnIndex and (now - S.targetSpawnTime >= 5.0) then
            targetSpawnIndex = nil
            S.targetSpawnIndex = nil
        end

        if not has_events and sampGetChatString then
            local ok, lineText = pcall(function()
                return sampGetChatString(99)
            end)
            if ok and lineText and lineText ~= S.lastChatLine then
                lastChatLine = lineText
                S.lastChatLine = lineText
                handleServerChat(lineText)
            end
        end

        if now - S.lastPruneTime >= 5.0 then
            lastPruneTime = now
            S.lastPruneTime = now
            for id, _ in pairs(S.pedStreamTime) do
                if not sampIsPlayerConnected(id) then
                    pedStreamTime = nil
                    S.pedStreamTime[id] = nil
                    S.playerCooldowns[id] = nil
                end
            end
        end

        if S.activeAction == "reload" then
            if now - S.actionStartTime >= 3.0 then
                cfg = inicfg.load(defConfig, configFile) or defConfig
                S.ui_price.v        = cfg.settings.price
                S.ui_vob.v          = cfg.settings.vob
                S.ui_vcd.v          = cfg.settings.vcd
                S.ui_accept_price.v = cfg.settings.accept_price
                S.ui_accept_vob.v   = cfg.settings.accept_vob
                S.vesterMode        = cfg.settings.vester_mode or "Everyone"
                S.isEnabled         = cfg.settings.enabled
                S.isAutoAccept      = cfg.settings.autoaccept

                af_cfg = inicfg.load(af_defConfig, autofindConfigFile) or af_defConfig
                AF.ui_level.v = af_cfg.settings.level or 5

                bk_cfg = inicfg.load(bk_defConfig, backupConfigFile) or bk_defConfig
                BK.enabled = (bk_cfg.settings.enabled ~= false)
                BK.mode    = bk_cfg.settings.mode or "Gang"
                BK.key     = tonumber(bk_cfg.settings.key) or 222
                BK.alt     = (bk_cfg.settings.alt == 1 or bk_cfg.settings.alt == true)
                BK.ctrl    = (bk_cfg.settings.ctrl == 1 or bk_cfg.settings.ctrl == true)
                BK.shift   = (bk_cfg.settings.shift == 1 or bk_cfg.settings.shift == true)

                KB.list = loadKeybinds()
                S.playerCooldowns   = {}
                S.pedStreamTime     = {}
                S.vstVehicles       = loadVstVehicles()
                modeEntries         = loadVesterModes()
                collectgarbage("collect")
                S.activeAction      = nil
                S.menuOpen.v        = false
                S.currentTab        = 1
                sampAddChatMessage("{00C8FF}Diamond Menu: {FFFFFF}Configuration reloaded successfully.", -1)
                triggerSilentVstRefresh(false)
            end

        elseif S.activeAction == "refresh" then
            if now - S.actionStartTime >= 2.0 then
                S.menuOpen.v = false
                S.currentTab = 1
                S.refreshReopenTime = now + 1.0
                S.activeAction = "waiting_reopen"
            end
        elseif S.activeAction == "waiting_reopen" then
            if now >= S.refreshReopenTime then
                cfg = inicfg.load(defConfig, configFile) or defConfig
                S.ui_price.v        = cfg.settings.price
                S.ui_vob.v          = cfg.settings.vob
                S.ui_vcd.v          = cfg.settings.vcd
                S.ui_accept_price.v = cfg.settings.accept_price
                S.ui_accept_vob.v   = cfg.settings.accept_vob
                S.vesterMode        = cfg.settings.vester_mode or "Everyone"
                S.isEnabled         = cfg.settings.enabled
                S.isAutoAccept      = cfg.settings.autoaccept

                af_cfg = inicfg.load(af_defConfig, autofindConfigFile) or af_defConfig
                AF.ui_level.v = af_cfg.settings.level or 5

                bk_cfg = inicfg.load(bk_defConfig, backupConfigFile) or bk_defConfig
                BK.enabled = (bk_cfg.settings.enabled ~= false)
                BK.mode    = bk_cfg.settings.mode or "Gang"
                BK.key     = tonumber(bk_cfg.settings.key) or 222
                BK.alt     = (bk_cfg.settings.alt == 1 or bk_cfg.settings.alt == true)
                BK.ctrl    = (bk_cfg.settings.ctrl == 1 or bk_cfg.settings.ctrl == true)
                BK.shift   = (bk_cfg.settings.shift == 1 or bk_cfg.settings.shift == true)

                KB.list = loadKeybinds()
                S.playerCooldowns   = {}
                S.pedStreamTime     = {}
                S.vstVehicles       = loadVstVehicles()
                modeEntries         = loadVesterModes()

                collectgarbage("collect")

                if raknetNewBitStream and raknetSendRpc and raknetDeleteBitStream then
                    pcall(function()
                        local bs = raknetNewBitStream()
                        raknetSendRpc(155, bs)
                        raknetDeleteBitStream(bs)
                    end)
                end

                S.activeAction      = nil
                S.currentTab        = 1
                S.menuOpen.v        = true
                sampAddChatMessage("{00C8FF}Diamond Menu: {FFFFFF}Configuration refreshed successfully.", -1)
                triggerSilentVstRefresh(false)
            end
        end

        if S.isEnabled and isLocalSpawned() then
            local effectiveCooldown = math.max(0.15, tonumber(cfg.settings.vcd) or 12.0)
            if now - S.lastVestTime >= effectiveCooldown then
                local targetId = findNearestTarget()
                if targetId ~= nil then
                    sampSendChat(string.format("/guard %d %d", targetId, tonumber(cfg.settings.price) or 200))
                    S.lastVestTime = now
                    S.playerCooldowns[targetId] = now
                end
            end
        end

        if AF.active and AF.targetName then
            if not AF.targetLost then
                if not sampIsPlayerConnected(AF.targetId) or sampGetPlayerNickname(AF.targetId) ~= AF.targetName then
                    AF.targetLost = true
                end
            end

            if AF.targetLost then
                if math.floor(os.clock()) % 2 == 0 and AF.font then
                    local posX, posY = 200, 400
                    if convertGameScreenCoordsToWindowScreenCoords then
                        posX, posY = convertGameScreenCoordsToWindowScreenCoords(165.0, 385.0)
                    end
                    local text = "Waiting " .. AF.targetName .. " to log in back."
                    pcall(renderFontDrawText, AF.font, text, posX, posY, 0xFFFF2222)
                end

                local maxId = 1000
                if sampGetMaxPlayerId then
                    local ok, m = pcall(sampGetMaxPlayerId, true)
                    if ok and m then maxId = m end
                end

                for i = 0, maxId do
                    if sampIsPlayerConnected(i) and sampGetPlayerNickname(i) == AF.targetName then
                        sampAddChatMessage(AF_TAG .. "{00FF00}" .. AF.targetName .. " {FFFFFF}logged back in! Old ID: {FFFF00}" .. tostring(AF.targetId) .. " {FFFFFF}| New ID: {00FF88}" .. i, -1)
                        AF.targetId = i
                        AF.targetLost = false
                        AF.lastFindTime = 0
                        break
                    end
                end
            else
                local cd = AF_COOLDOWNS[af_cfg.settings.level] or 20
                if os.clock() - AF.lastFindTime >= cd then
                    sampSendChat(AF.modeCmd .. " " .. AF.targetId)
                    AF.lastFindTime = os.clock()
                end
            end
        end

        if KB.recordingIndex ~= nil then
            if KB.waitRelease then
                local anyDown = false
                for k = 1, 255 do
                    if k ~= 1 and k ~= 2 and k ~= 4 and k ~= 16 and k ~= 17 and k ~= 18 then
                        if isKeyDown(k) then
                            anyDown = true
                            break
                        end
                    end
                end
                if not anyDown then
                    KB.waitRelease = false
                end
            else
                for k = 1, 255 do
                    if k ~= 1 and k ~= 2 and k ~= 4 and k ~= 16 and k ~= 17 and k ~= 18 then
                        if isKeyDown(k) or wasKeyPressed(k) then
                            if k == 27 then
                                KB.recordingIndex = nil
                            else
                                local targetItem = KB.list[KB.recordingIndex]
                                if targetItem then
                                    targetItem.key   = k
                                    targetItem.alt   = isKeyDown(18)
                                    targetItem.ctrl  = isKeyDown(17)
                                    targetItem.shift = isKeyDown(16)
                                    saveKeybinds()
                                end
                                KB.recordingIndex = nil
                            end
                            break
                        end
                    end
                end
            end
        end

        if BK.recording then
            if BK.waitRelease then
                local anyDown = false
                for k = 1, 255 do
                    if k ~= 1 and k ~= 2 and k ~= 4 and k ~= 16 and k ~= 17 and k ~= 18 then
                        if isKeyDown(k) then
                            anyDown = true
                            break
                        end
                    end
                end
                if not anyDown then
                    BK.waitRelease = false
                end
            else
                for k = 1, 255 do
                    if k ~= 1 and k ~= 2 and k ~= 4 and k ~= 16 and k ~= 17 and k ~= 18 then
                        if isKeyDown(k) or wasKeyPressed(k) then
                            if k == 27 then
                                BK.recording = false
                            else
                                BK.key   = k
                                BK.alt   = isKeyDown(18)
                                BK.ctrl  = isKeyDown(17)
                                BK.shift = isKeyDown(16)
                                saveBkConfig()
                                BK.recording = false
                            end
                            break
                        end
                    end
                end
            end
        end

        if not sampIsChatInputActive() and not (sampIsDialogActive and sampIsDialogActive()) and not S.menuOpen.v and not KB.recordingIndex and not BK.recording then
            if now - BK.lastTrigger >= 1.0 and BK.enabled and BK.key and BK.key ~= 0 then
                local altOk = not BK.alt or isKeyDown(18)
                local ctrlOk = not BK.ctrl or isKeyDown(17)
                local shiftOk = not BK.shift or isKeyDown(16)
                if altOk and ctrlOk and shiftOk and wasKeyPressed(BK.key) then
                    BK.lastTrigger = now
                    if not BK.isActive then
                        BK.isActive = true
                        local loc = getPlayerCurrentLocationName()
                        if BK.mode == "Gang" then
                            sampSendChat("/fbackup")
                        else
                            sampSendChat("/backup")
                        end
                        sampSendChat(string.format("/pr I need urgent backup! Currently at %s!", loc))
                    else
                        BK.isActive = false
                        sampSendChat("/nobackup")
                    end
                end
            end

            if now - KB.lastTrigger >= 0.25 then
                for _, b in ipairs(KB.list) do
                    if b.en and b.key and b.key ~= 0 then
                        local altOk = not b.alt or isKeyDown(18)
                        local ctrlOk = not b.ctrl or isKeyDown(17)
                        local shiftOk = not b.shift or isKeyDown(16)
                        if altOk and ctrlOk and shiftOk and wasKeyPressed(b.key) then
                            local text = b.buf.v:match("^%s*(.-)%s*$")
                            if text ~= "" then
                                sampSendChat(text)
                                KB.lastTrigger = now
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end

function imgui.OnDrawFrame()
    local noScrollFlags = imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse

    if S.isVstActive then
        local posX, posY = getChatInputPos()
        imgui.SetNextWindowPos(imgui.ImVec2(posX, posY), imgui.Cond.Always, imgui.ImVec2(0.0, 0.0))
        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.0, 0.0, 0.0, 0.0))
        imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.0, 0.0, 0.0, 0.0))
        imgui.PushStyleVar(imgui.StyleVar.WindowRounding, 0.0)
        imgui.PushStyleVar(imgui.StyleVar.WindowPadding, imgui.ImVec2(0, 0))
        imgui.PushStyleVar(imgui.StyleVar.ItemSpacing, imgui.ImVec2(4, 2))

        local vstFlags = imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoSavedSettings + imgui.WindowFlags.NoInputs + noScrollFlags

        if imgui.Begin("##VSTOverlayDisplay", nil, vstFlags) then
            if #S.vstVehicles > 0 then
                for i, veh in ipairs(S.vstVehicles) do
                    imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), string.format("- %d.", i))
                    imgui.SameLine(0, 4)
                    if veh.spawned then
                        imgui.TextColored(imgui.ImVec4(0.20, 1.00, 0.15, 1.00), tostring(veh.name))
                    else
                        imgui.TextColored(imgui.ImVec4(1.00, 1.00, 1.00, 1.00), tostring(veh.name))
                    end
                end
            else
                imgui.TextColored(imgui.ImVec4(1.00, 0.75, 0.20, 1.00), "Couldn't read vehicles automatically.")
                imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), "Please type /refreshvst to load your cars.")
            end
            imgui.End()
        end
        imgui.PopStyleVar(3)
        imgui.PopStyleColor(2)
    end

    if not S.menuOpen.v and S.discordAnimAlpha <= 0.01 and S.resetAnimAlpha <= 0.01 and S.vesterModalAlpha <= 0.01 and S.subWindowAlpha <= 0.01 and S.pointOverAnimAlpha <= 0.01 and UP.animAlpha <= 0.01 then return end

    if not S.themeApplied then
        applyDiamondTheme()
        S.themeApplied = true
    end

    local now = os.clock()
    local dt = math.min(now - S.lastFrameTime, 0.1)
    S.lastFrameTime = now

    local targetDiscord = S.discordModalOpen and 1.0 or 0.0
    S.discordAnimAlpha = lerpAnim(S.discordAnimAlpha, targetDiscord, 14.0, dt)

    local targetReset = S.resetModalOpen and 1.0 or 0.0
    S.resetAnimAlpha = lerpAnim(S.resetAnimAlpha, targetReset, 14.0, dt)

    local targetVester = S.vesterModalOpen and 1.0 or 0.0
    S.vesterModalAlpha = lerpAnim(S.vesterModalAlpha, targetVester, 14.0, dt)

    local targetSubWin = (S.activeSubWindow ~= nil) and 1.0 or 0.0
    S.subWindowAlpha = lerpAnim(S.subWindowAlpha, targetSubWin, 14.0, dt)

    local targetPointOver = S.pointOverModalOpen and 1.0 or 0.0
    S.pointOverAnimAlpha = lerpAnim(S.pointOverAnimAlpha, targetPointOver, 14.0, dt)

    local targetUp = UP.modalOpen and 1.0 or 0.0
    UP.animAlpha = lerpAnim(UP.animAlpha, targetUp, 14.0, dt)

    local sw, sh = getScreenResolution()
    local maxDimAlpha = math.max(S.discordAnimAlpha, S.resetAnimAlpha, S.vesterModalAlpha, S.subWindowAlpha, S.pointOverAnimAlpha, UP.animAlpha)

    if maxDimAlpha > 0.01 then
        imgui.SetNextWindowPos(imgui.ImVec2(0, 0), imgui.Cond.Always)
        imgui.SetNextWindowSize(imgui.ImVec2(sw, sh), imgui.Cond.Always)
        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.0, 0.0, 0.0, 0.70 * maxDimAlpha))
        imgui.Begin("##ScreenDimmerBackdrop", S.dummyOpen, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoInputs + noScrollFlags)
        imgui.End()
        imgui.PopStyleColor()
    end

    -- ========================================================================
    -- MODAL: UPDATE MANAGER
    -- ========================================================================
    if UP.animAlpha > 0.01 then
        imgui.PushStyleVar(imgui.StyleVar.Alpha, UP.animAlpha)
        imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(420, 165), imgui.Cond.Always)
        imgui.Begin("Update Manager##UpdateManagerModal", S.dummyOpen, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoCollapse + noScrollFlags)

        imgui.Spacing()
        local winW = 420

        if UP.status == "checking" then
            local headerText = "Checking for Updates..."
            imgui.SetCursorPosX((winW - imgui.CalcTextSize(headerText).x) / 2)
            imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), headerText)
            imgui.Separator()
            imgui.Spacing()
            imgui.Spacing()
            imgui.SetCursorPosX((winW - 20) / 2)
            drawLoadingWheel(8, 2.0, 0xFF00E5FF)
            imgui.Spacing()
            local subMsg = "Checking for new version..."
            imgui.SetCursorPosX((winW - imgui.CalcTextSize(subMsg).x) / 2)
            imgui.TextDisabled(subMsg)

        elseif UP.status == "latest" then
            local headerText = "Diamond Menu is Up to Date!"
            imgui.SetCursorPosX((winW - imgui.CalcTextSize(headerText).x) / 2)
            imgui.TextColored(imgui.ImVec4(0.00, 1.00, 0.40, 1.00), headerText)
            imgui.Separator()
            imgui.Spacing()
            local msg = string.format("You are running the latest version: v%s", SCRIPT_VERSION_STR)
            imgui.SetCursorPosX((winW - imgui.CalcTextSize(msg).x) / 2)
            imgui.Text(msg)
            local sub = "No new updates are currently available."
            imgui.SetCursorPosX((winW - imgui.CalcTextSize(sub).x) / 2)
            imgui.TextDisabled(sub)
            imgui.Spacing()
            imgui.Spacing()

            local btnW = 90
            imgui.SetCursorPosX((winW - btnW) / 2)
            if imgui.Button("Close##UpCloseLatest", imgui.ImVec2(btnW, 24)) then
                UP.modalOpen = false
            end

        elseif UP.status == "available" then
            local headerText = "New Update Available!"
            imgui.SetCursorPosX((winW - imgui.CalcTextSize(headerText).x) / 2)
            imgui.TextColored(imgui.ImVec4(1.00, 0.85, 0.00, 1.00), headerText)
            imgui.Separator()
            imgui.Spacing()
            local msg = string.format("Version v%s is ready to download! (Current: v%s)", UP.onlineVerStr, SCRIPT_VERSION_STR)
            imgui.SetCursorPosX((winW - imgui.CalcTextSize(msg).x) / 2)
            imgui.Text(msg)
            local sub = "Click 'Update Now' to automatically install and restart."
            imgui.SetCursorPosX((winW - imgui.CalcTextSize(sub).x) / 2)
            imgui.TextDisabled(sub)
            imgui.Spacing()

            local bUpdateW = 105
            local bCancelW = 85
            local spacing = 15
            local totalW = bUpdateW + bCancelW + spacing
            imgui.SetCursorPosX((winW - totalW) / 2)

            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.08, 0.50, 0.25, 0.90))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.12, 0.70, 0.35, 1.00))
            if imgui.Button("Update Now##DoUpdate", imgui.ImVec2(bUpdateW, 24)) then
                executeScriptDownload()
            end
            imgui.PopStyleColor(2)

            imgui.SameLine(0, spacing)
            if imgui.Button("Cancel##CancelUp", imgui.ImVec2(bCancelW, 24)) then
                UP.modalOpen = false
            end

        elseif UP.status == "downloading" then
            local headerText = "Installing Update..."
            imgui.SetCursorPosX((winW - imgui.CalcTextSize(headerText).x) / 2)
            imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), headerText)
            imgui.Separator()
            imgui.Spacing()
            imgui.Spacing()
            imgui.SetCursorPosX((winW - 20) / 2)
            drawLoadingWheel(8, 2.0, 0xFF00E5FF)
            imgui.Spacing()
            local subMsg = "Downloading file and reloading Diamond Menu..."
            imgui.SetCursorPosX((winW - imgui.CalcTextSize(subMsg).x) / 2)
            imgui.TextDisabled(subMsg)

        else
            local headerText = "Update Check Failed"
            imgui.SetCursorPosX((winW - imgui.CalcTextSize(headerText).x) / 2)
            imgui.TextColored(imgui.ImVec4(1.00, 0.25, 0.25, 1.00), headerText)
            imgui.Separator()
            imgui.Spacing()
            local msg = "Failed to check for updates. Please try again."
            imgui.SetCursorPosX((winW - imgui.CalcTextSize(msg).x) / 2)
            imgui.Text(msg)
            local sub = "Unable to reach update server."
            imgui.SetCursorPosX((winW - imgui.CalcTextSize(sub).x) / 2)
            imgui.TextDisabled(sub)
            imgui.Spacing()

            local bRetryW = 90
            local bCloseW = 85
            local spacing = 15
            local totalW = bRetryW + bCloseW + spacing
            imgui.SetCursorPosX((winW - totalW) / 2)

            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.08, 0.40, 0.65, 0.85))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.12, 0.60, 0.90, 1.00))
            if imgui.Button("Retry##UpRetryBtn", imgui.ImVec2(bRetryW, 24)) then
                checkUpdateProcess(true)
            end
            imgui.PopStyleColor(2)

            imgui.SameLine(0, spacing)
            if imgui.Button("Close##UpCloseErr", imgui.ImVec2(bCloseW, 24)) then
                UP.modalOpen = false
            end
        end

        imgui.End()
        imgui.PopStyleVar()
    end

    if S.pointOverAnimAlpha > 0.01 then
        imgui.PushStyleVar(imgui.StyleVar.Alpha, S.pointOverAnimAlpha)
        imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(400, 160), imgui.Cond.Always)
        imgui.Begin("Point Alert##PointOverModal", S.dummyOpen, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoCollapse + noScrollFlags)

        imgui.Spacing()
        imgui.Spacing()
        local alertText = "POINT IS OVER!"
        local textW = imgui.CalcTextSize(alertText).x
        imgui.SetCursorPosX((400 - textW) / 2)
        imgui.TextColored(imgui.ImVec4(1.00, 0.00, 0.00, 1.00), alertText)

        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        local subNotice = "The point capture phase has officially concluded."
        local subW = imgui.CalcTextSize(subNotice).x
        imgui.SetCursorPosX((400 - subW) / 2)
        imgui.TextDisabled(subNotice)

        imgui.Spacing()
        imgui.Spacing()
        
        local btnWidth = 100
        local btnHeight = 25
        imgui.SetCursorPosX((400 - btnWidth) / 2)
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.08, 0.45, 0.25, 0.90))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.12, 0.65, 0.35, 1.00))
        if imgui.Button("GGs##PointOverClose", imgui.ImVec2(btnWidth, btnHeight)) then
            S.pointOverModalOpen = false
            sampSendChat("/g ggs")
        end
        imgui.PopStyleColor(2)

        imgui.End()
        imgui.PopStyleVar()
    end

    if S.discordAnimAlpha > 0.01 then
        imgui.PushStyleVar(imgui.StyleVar.Alpha, S.discordAnimAlpha)
        imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(340, 130), imgui.Cond.Always)
        imgui.Begin("Author Contact##CustomModal", S.dummyOpen, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoCollapse + noScrollFlags)
        imgui.Spacing()
        imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), "Author Contact Information:")
        imgui.Separator()
        imgui.Spacing()
        imgui.Text("Discord Name:")
        imgui.SameLine()
        imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), "Tony")
        imgui.Text("Discord:")
        imgui.SameLine()
        imgui.TextColored(imgui.ImVec4(0.00, 0.90, 1.00, 1.00), "ooooaaaa12")
        imgui.Spacing()
        imgui.SetCursorPosX(130)
        if imgui.Button("Close##ModalDisc", imgui.ImVec2(80, 22)) then S.discordModalOpen = false end
        imgui.End()
        imgui.PopStyleVar()
    end

    if S.resetAnimAlpha > 0.01 then
        imgui.PushStyleVar(imgui.StyleVar.Alpha, S.resetAnimAlpha)
        imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(440, 120), imgui.Cond.Always)
        imgui.Begin("Confirm Reset##CustomModal", S.dummyOpen, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoCollapse + noScrollFlags)
        imgui.Spacing()
        imgui.TextColored(imgui.ImVec4(1.00, 0.00, 0.00, 1.00), "Are you sure you want to restore default configuration?")
        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        local btnW = 85
        local spacing = 15
        local totalW = btnW * 2 + spacing
        imgui.SetCursorPosX((imgui.GetWindowWidth() - totalW) / 2)

        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.55, 0.10, 0.10, 0.85))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.75, 0.15, 0.15, 1.00))
        if imgui.Button("Reset", imgui.ImVec2(btnW, 22)) then
            S.ui_price.v        = 200.0
            S.ui_vob.v          = 46.0
            S.ui_vcd.v          = 12.0
            S.ui_accept_price.v = 200.0
            S.ui_accept_vob.v   = 46.0
            S.vesterMode        = "Everyone"
            S.isEnabled         = false
            S.isAutoAccept      = false
            syncConfig()

            AF.ui_level.v       = 5.0
            AF.active           = false
            AF.targetName       = nil
            AF.targetId         = nil
            AF.targetLost       = false
            syncAfConfig()

            BK.enabled  = true
            BK.mode     = "Gang"
            BK.key      = 222
            BK.alt      = false
            BK.ctrl     = false
            BK.shift    = false
            BK.isActive = false
            saveBkConfig()

            KB.list = {}
            saveKeybinds()

            S.playerCooldowns   = {}
            S.pedStreamTime     = {}
            collectgarbage("collect")
            sampAddChatMessage("{00C8FF}Diamond Menu: {FFFFFF}All settings have been reset to default.", -1)
            S.resetModalOpen    = false
        end
        imgui.PopStyleColor(2)

        imgui.SameLine(0, spacing)
        if imgui.Button("Cancel", imgui.ImVec2(btnW, 22)) then S.resetModalOpen = false end
        imgui.End()
        imgui.PopStyleVar()
    end

    if S.vesterModalAlpha > 0.01 then
        imgui.PushStyleVar(imgui.StyleVar.Alpha, S.vesterModalAlpha)
        imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(520, 235), imgui.Cond.Always)
        
        imgui.Begin("Configure Vestermodes##ModalWindow", S.dummyOpen, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoCollapse + noScrollFlags)

        imgui.Spacing()
        imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), "Active Targeting Mode:")
        imgui.SameLine()
        imgui.TextColored(imgui.ImVec4(0.00, 1.00, 0.40, 1.00), S.vesterMode)
        imgui.SameLine()
        imgui.TextDisabled("(Switch via /vestermode)")
        imgui.Separator()
        imgui.Spacing()

        local modes = {
            { name = "Gangs", key = "gangs", desc = "Configure gang skins & colors" },
            { name = "Factions", key = "factions", desc = "Configure faction skins & colors" },
            { name = "Unofficial Gangs", key = "unofficial", desc = "Configure unofficial members & family last name" }
        }

        for _, m in ipairs(modes) do
            if imgui.Button("Configure " .. m.name .. "##ConfigBtn", imgui.ImVec2(200, 25)) then
                S.vesterModalOpen = false
                S.activeSubWindow = m.key
                S.editingIndex = nil
                S.input_name.v = ""
                S.input_hex.v = ""
                S.input_extra.v = ""
                S.input_family.v = ""
            end

            imgui.SameLine()
            imgui.SetCursorPosY(imgui.GetCursorPosY() + 3)
            imgui.TextDisabled(m.desc)
            imgui.Spacing()
        end

        imgui.Separator()
        imgui.Spacing()
        imgui.SetCursorPosX((520 - 90) / 2)
        if imgui.Button("Close##VesterModalClose", imgui.ImVec2(90, 24)) then
            S.vesterModalOpen = false
        end

        imgui.End()
        imgui.PopStyleVar()
    end

    if S.subWindowAlpha > 0.01 and S.activeSubWindow then
        imgui.PushStyleVar(imgui.StyleVar.Alpha, S.subWindowAlpha)
        local titles = {
            gangs = "Gangs Configuration",
            factions = "Factions Configuration",
            unofficial = "Unofficial Gangs Configuration"
        }

        local categoryLabels = {
            gangs = "Gangs",
            factions = "Factions",
            unofficial = "Unofficial Gangs"
        }

        local isUnofficial = (S.activeSubWindow == "unofficial")

        imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(520, 560), imgui.Cond.Always)
        
        local subWindowOpen = imgui.ImBool(true)
        if imgui.Begin(titles[S.activeSubWindow] .. "##MovableWindow", subWindowOpen, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoCollapse + noScrollFlags) then
            local headerText = S.editingIndex and ("Edit Existing " .. categoryLabels[S.activeSubWindow] .. ":") or ("Add New " .. categoryLabels[S.activeSubWindow] .. ":")
            imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), headerText)
            imgui.Separator()
            imgui.Spacing()

            imgui.Text("Name of " .. categoryLabels[S.activeSubWindow]:gsub("s$", "") .. ":")
            imgui.PushItemWidth(-1)
            imgui.InputText("##SubNameInput", S.input_name)
            imgui.PopItemWidth()

            imgui.Text("Hex Code (Color):")
            imgui.PushItemWidth(-1)
            imgui.InputText("##SubHexInput", S.input_hex)
            imgui.PopItemWidth()
            if imgui.IsItemHovered() then
                imgui.PushStyleColor(imgui.Col.PopupBg, imgui.ImVec4(0.0, 0.0, 0.0, 0.95))
                imgui.BeginTooltip()
                imgui.Text("Format: Hex color code (e.g. 00FF00 or #00FF00).")
                imgui.EndTooltip()
                imgui.PopStyleColor()
            end

            if isUnofficial then
                imgui.Text("Family Last Name (Optional):")
                imgui.PushItemWidth(-1)
                imgui.InputText("##SubFamilyNameInput", S.input_family)
                imgui.PopItemWidth()
                if imgui.IsItemHovered() then
                    imgui.PushStyleColor(imgui.Col.PopupBg, imgui.ImVec4(0.0, 0.0, 0.0, 0.95))
                    imgui.BeginTooltip()
                    imgui.Text("Automatically vests anyone with this last name (e.g. Donalds vests Tony_Donalds, etc.).")
                    imgui.EndTooltip()
                    imgui.PopStyleColor()
                end

                imgui.Text("Members Fullnames (separated by spaces):")
                imgui.PushItemWidth(-1)
                imgui.InputText("##SubMemberNameInput", S.input_extra)
                imgui.PopItemWidth()

                local trimmed = S.input_extra.v:match("^%s*(.-)%s*$")
                if trimmed ~= "" and not areAllFullNamesValid(trimmed) then
                    imgui.TextColored(imgui.ImVec4(1.00, 0.00, 0.00, 1.00), "Invalid format! Every name must be FirstName_LastName (letters and underscore only).")
                end

                if imgui.IsItemHovered() then
                    imgui.PushStyleColor(imgui.Col.PopupBg, imgui.ImVec4(0.0, 0.0, 0.0, 0.95))
                    imgui.BeginTooltip()
                    imgui.Text("Format: Add specific members separated by space (e.g. Tony_Donalds Carlos_Santana).")
                    imgui.EndTooltip()
                    imgui.PopStyleColor()
                end
            else
                imgui.Text("Skins ID:")
                imgui.PushItemWidth(-1)
                imgui.InputText("##SubSkinsInput", S.input_extra)
                imgui.PopItemWidth()

                if imgui.IsItemHovered() then
                    imgui.PushStyleColor(imgui.Col.PopupBg, imgui.ImVec4(0.0, 0.0, 0.0, 0.95))
                    imgui.BeginTooltip()
                    imgui.Text("Format: Enter Skin IDs separated by a space (e.g. 105 106 107).")
                    imgui.EndTooltip()
                    imgui.PopStyleColor()
                end
            end

            imgui.Spacing()

            if S.editingIndex then
                imgui.SetCursorPosX(imgui.GetWindowWidth() - 190)
                if imgui.Button("Cancel##CancelEdit", imgui.ImVec2(85, 24)) then
                    S.editingIndex = nil
                    S.input_name.v = ""
                    S.input_hex.v = ""
                    S.input_extra.v = ""
                    S.input_family.v = ""
                end
                imgui.SameLine()
                if imgui.Button("Save##SaveEdit", imgui.ImVec2(85, 24)) then
                    local gName = S.input_name.v:match("^%s*(.-)%s*$")
                    local gHex = S.input_hex.v:match("^%s*(.-)%s*$")
                    local gExtra = S.input_extra.v:match("^%s*(.-)%s*$")
                    local gFam = S.input_family.v:match("^%s*(.-)%s*$")

                    if isUnofficial and (gExtra ~= "" and not areAllFullNamesValid(gExtra)) then
                        sampAddChatMessage("{00C8FF}Diamond Menu: {FF0000}Cannot save! All names must follow FirstName_LastName format.", -1)
                    elseif gName ~= "" and (gExtra ~= "" or gHex ~= "" or gFam ~= "") then
                        modeEntries[S.activeSubWindow][S.editingIndex] = { name = gName, hex = gHex, extra = gExtra, family = gFam }
                        saveVesterModes()
                        S.editingIndex = nil
                        S.input_name.v = ""
                        S.input_hex.v = ""
                        S.input_extra.v = ""
                        S.input_family.v = ""
                        local cleanHex = gHex:gsub("#", "")
                        sampAddChatMessage(string.format("{00C8FF}Diamond Menu: {FFFFFF}Updated {%s}%s{FFFFFF} successfully.", (cleanHex ~= "" and cleanHex or "00FF88"), gName), -1)
                    end
                end
            else
                imgui.SetCursorPosX(imgui.GetWindowWidth() - 100)
                if imgui.Button("Add##AddSubBtn", imgui.ImVec2(85, 24)) then
                    local gName = S.input_name.v:match("^%s*(.-)%s*$")
                    local gHex = S.input_hex.v:match("^%s*(.-)%s*$")
                    local gExtra = S.input_extra.v:match("^%s*(.-)%s*$")
                    local gFam = S.input_family.v:match("^%s*(.-)%s*$")

                    if isUnofficial and (gExtra ~= "" and not areAllFullNamesValid(gExtra)) then
                        sampAddChatMessage("{00C8FF}Diamond Menu: {FF0000}Cannot add! All names must follow FirstName_LastName format.", -1)
                    elseif gName ~= "" and (gExtra ~= "" or gHex ~= "") then
                        table.insert(modeEntries[S.activeSubWindow], { name = gName, hex = gHex, extra = gExtra, family = gFam })
                        saveVesterModes()
                        S.input_name.v = ""
                        S.input_hex.v = ""
                        S.input_extra.v = ""
                        S.input_family.v = ""
                        local cleanHex = gHex:gsub("#", "")
                        sampAddChatMessage(string.format("{00C8FF}Diamond Menu: {FFFFFF}Added {%s}%s{FFFFFF} to %s list.", (cleanHex ~= "" and cleanHex or "00FF88"), gName, titles[S.activeSubWindow]), -1)
                    else
                        sampAddChatMessage("{00C8FF}Diamond Menu: {FF5555}Please provide a Name and at least valid data or Hex.", -1)
                    end
                end
            end

            imgui.Spacing()
            imgui.Separator()
            imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), "Current Saved " .. categoryLabels[S.activeSubWindow] .. ":")
            imgui.Spacing()

            imgui.BeginChild("##CurrentSubListTable", imgui.ImVec2(0, 180), true, noScrollFlags)
            if #modeEntries[S.activeSubWindow] > 0 then
                for idx, item in ipairs(modeEntries[S.activeSubWindow]) do
                    local itemColor = hexToImVec4(item.hex, imgui.ImVec4(0.00, 0.85, 1.00, 1.00))
                    imgui.TextColored(itemColor, string.format("%d. %s", idx, item.name or "Unnamed"))

                    imgui.SameLine(0, 15)
                    if imgui.Button("Edit##Ed" .. idx, imgui.ImVec2(45, 18)) then
                        S.editingIndex = idx
                        S.input_name.v = item.name or ""
                        S.input_hex.v = item.hex or ""
                        S.input_extra.v = item.extra or ""
                        S.input_family.v = item.family or ""
                    end

                    imgui.SameLine(0, 6)
                    if imgui.Button("Remove##Rem" .. idx, imgui.ImVec2(55, 18)) then
                        if S.editingIndex == idx then
                            S.editingIndex = nil
                            S.input_name.v = ""
                            S.input_hex.v = ""
                            S.input_extra.v = ""
                            S.input_family.v = ""
                        end
                        table.remove(modeEntries[S.activeSubWindow], idx)
                        saveVesterModes()
                        break
                    end
                end
            else
                imgui.TextDisabled("No " .. categoryLabels[S.activeSubWindow]:lower() .. " added yet. Fill the inputs above and click Add.")
            end
            imgui.EndChild()

            imgui.Spacing()
            imgui.SetCursorPosX((520 - 90) / 2)
            if imgui.Button("Close##ConfigCloseBottom", imgui.ImVec2(90, 22)) then
                S.activeSubWindow = nil
                S.editingIndex = nil
            end

            imgui.End()
        end

        if not subWindowOpen.v then
            S.activeSubWindow = nil
            S.editingIndex = nil
        end
        imgui.PopStyleVar()
    end

    if not S.menuOpen.v then return end

    imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(580, 560), imgui.Cond.Always)
    imgui.Begin("##DiamondMainWindow", S.menuOpen, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + noScrollFlags)

    imgui.TextColored(imgui.ImVec4(0.00, 0.90, 1.00, 1.00), "DIAMOND MENU")
    imgui.SameLine(535)
    if imgui.Button("X", imgui.ImVec2(35, 20)) then
        if not S.activeSubWindow and not S.vesterModalOpen and not S.pointOverModalOpen and not UP.modalOpen then
            S.menuOpen.v = false
            S.currentTab = 1
            KB.recordingIndex = nil
            BK.recording = false
        end
    end

    imgui.Separator()

    local tabs = {
        {name = "Home", w = 55},
        {name = "Vester", w = 65},
        {name = "AutoFind", w = 75},
        {name = "Keybinds", w = 75},
        {name = "Backup", w = 68},
        {name = "+ Slot #5", w = 72}
    }

    for i, tab in ipairs(tabs) do
        if S.currentTab == i then
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.00, 0.85, 1.00, 1.00))
            if imgui.Button(tab.name, imgui.ImVec2(tab.w, 22)) then S.currentTab = i end
            imgui.PopStyleColor()
        else
            if imgui.Button(tab.name, imgui.ImVec2(tab.w, 22)) then S.currentTab = i end
        end
        if i < #tabs then imgui.SameLine() end
    end

    imgui.Spacing()

    imgui.BeginChild("##TableSurroundingFrame", imgui.ImVec2(564, 478), true, noScrollFlags)

    -- ================= TAB 1: HOME =================
    if S.currentTab == 1 then
        if imgui.BeginChild("##HomeInfoTable", imgui.ImVec2(548, 68), true, noScrollFlags) then
            -- Line 1: Title & Upper-right Update Button
            imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), "Diamond Menu by Tony Donalds")
            imgui.SameLine(440)
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.08, 0.40, 0.65, 0.85))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.12, 0.60, 0.90, 1.00))
            if imgui.Button("Update##HomeUpdateBtn", imgui.ImVec2(95, 22)) then
                UP.modalOpen = true
                checkUpdateProcess(true)
            end
            imgui.PopStyleColor(2)

            -- Line 2: Contact text & Discord button inline on the line
            imgui.Spacing()
            imgui.TextColored(imgui.ImVec4(0.70, 0.75, 0.85, 1.00), "Contact via Discord for support:")
            imgui.SameLine(0, 8)
            if imgui.Button("Discord##HomeDiscordBtn", imgui.ImVec2(80, 20)) then
                S.discordModalOpen = true
            end
            imgui.EndChild()
        end

        imgui.Spacing()

        if imgui.BeginChild("##HomeActionTable", imgui.ImVec2(548, 382), true, noScrollFlags) then
            imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), "Configuration Management:")
            imgui.Spacing()

            if imgui.BeginChild("##CardReloadTable", imgui.ImVec2(532, 100), true, noScrollFlags) then
                imgui.SetCursorPosY(37)
                if S.activeAction == "reload" then
                    drawLoadingWheel(8, 2.0, 0xFF00E5FF)
                    imgui.SameLine()
                    imgui.TextColored(imgui.ImVec4(0.00, 0.90, 1.00, 1.00), "Reloading...")
                else
                    if imgui.Button("Reload Config", imgui.ImVec2(105, 26)) then
                        if not S.activeAction then
                            S.activeAction = "reload"
                            S.actionStartTime = os.clock()
                        end
                    end
                end
                imgui.SameLine(125)
                imgui.SetCursorPosY(20)
                imgui.BeginGroup()
                imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), "Reload Configuration")
                imgui.Spacing()
                imgui.TextColored(imgui.ImVec4(0.92, 0.96, 1.00, 1.00), "Forces a clean re-read of your saved settings from the Settings folder.")
                imgui.EndGroup()
                imgui.EndChild()
            end

            imgui.Spacing()

            if imgui.BeginChild("##CardRefreshTable", imgui.ImVec2(532, 100), true, noScrollFlags) then
                imgui.SetCursorPosY(37)
                if S.activeAction == "refresh" or S.activeAction == "waiting_reopen" then
                    drawLoadingWheel(8, 2.0, 0xFF00E5FF)
                    imgui.SameLine()
                    imgui.TextColored(imgui.ImVec4(0.00, 0.90, 1.00, 1.00), "Refreshing...")
                else
                    if imgui.Button("Refresh Config", imgui.ImVec2(105, 26)) then
                        if not activeAction then
                            activeAction = "refresh"
                            S.activeAction = "refresh"
                            S.actionStartTime = os.clock()
                        end
                    end
                end
                imgui.SameLine(125)
                imgui.SetCursorPosY(20)
                imgui.BeginGroup()
                imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), "Quick State Refresh")
                imgui.Spacing()
                imgui.TextColored(imgui.ImVec4(0.92, 0.96, 1.00, 1.00), "Flushes Lua memory cache to keep the menu smooth & responsive.")
                imgui.EndGroup()
                imgui.EndChild()
            end

            imgui.Spacing()

            if imgui.BeginChild("##CardResetTable", imgui.ImVec2(532, 100), true, noScrollFlags) then
                imgui.SetCursorPosY(37)
                if imgui.Button("Reset Config", imgui.ImVec2(105, 26)) then
                    if not S.activeAction then
                        S.resetModalOpen = true
                    end
                end
                imgui.SameLine(125)
                imgui.SetCursorPosY(20)
                imgui.BeginGroup()
                imgui.TextColored(imgui.ImVec4(1.00, 0.35, 0.35, 1.00), "Restore Default Settings")
                imgui.Spacing()
                imgui.TextColored(imgui.ImVec4(0.92, 0.96, 1.00, 1.00), "Restores all configurations back to original factory defaults.")
                imgui.EndGroup()
                imgui.EndChild()
            end

            imgui.EndChild()
        end

    -- ================= TAB 2: VESTER =================
    elseif S.currentTab == 2 then
        if imgui.BeginChild("##AutoVesterGiveCard", imgui.ImVec2(548, 252), true, noScrollFlags) then
            imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), "AutoVester (/avest):")
            imgui.SameLine(160)
            if S.isEnabled then
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.05, 0.45, 0.25, 0.85))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.08, 0.60, 0.35, 1.00))
                if imgui.Button("AutoVester: ON", imgui.ImVec2(115, 20)) then
                    toggleAutoVesterFast()
                end
                imgui.PopStyleColor(2)
            else
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.45, 0.12, 0.12, 0.85))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.60, 0.18, 0.18, 1.00))
                if imgui.Button("AutoVester: OFF", imgui.ImVec2(115, 20)) then
                    toggleAutoVesterFast()
                end
                imgui.PopStyleColor(2)
            end

            imgui.SameLine(425)
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.00, 0.85, 1.00, 1.00))
            if imgui.Button("Vestermode##OpenBtn", imgui.ImVec2(110, 20)) then
                if not S.activeSubWindow then
                    S.vesterModalOpen = true
                end
            end
            imgui.PopStyleColor()

            imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), "Vest Price (/vp):")
            imgui.PushItemWidth(-1)
            if imgui.SliderFloat("##VestPrice", S.ui_price, 200.0, 1000.0, "$%.0f") then
                syncConfig()
            end
            imgui.PopItemWidth()
            if imgui.Button("$200 (Rec)", imgui.ImVec2(80, 19)) then S.ui_price.v = 200.0; syncConfig() end
            imgui.SameLine()
            if imgui.Button("$500", imgui.ImVec2(55, 19)) then S.ui_price.v = 500.0; syncConfig() end
            imgui.SameLine()
            if imgui.Button("$1000", imgui.ImVec2(55, 19)) then S.ui_price.v = 1000.0; syncConfig() end

            imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), "Armor Threshold (/vob):")
            imgui.PushItemWidth(-1)
            if imgui.SliderFloat("##ArmorThreshold", S.ui_vob, 0.0, 100.0, "%.0f AP") then
                syncConfig()
            end
            imgui.PopItemWidth()
            if imgui.Button("46 AP (Rec)", imgui.ImVec2(85, 19)) then S.ui_vob.v = 46.0; syncConfig() end
            imgui.SameLine()
            if imgui.Button("100 AP", imgui.ImVec2(65, 19)) then S.ui_vob.v = 100.0; syncConfig() end

            imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), "Command Cooldown (/vcd):")
            imgui.PushItemWidth(-1)
            if imgui.SliderFloat("##Cooldown", S.ui_vcd, 0.0, 20.0, "%.1f sec") then
                syncConfig()
            end
            imgui.PopItemWidth()
            if imgui.Button("12.0s (Rec)##vcd", imgui.ImVec2(85, 19)) then S.ui_vcd.v = 12.0; syncConfig() end
            imgui.SameLine()
            if imgui.Button("15.0s##vcd", imgui.ImVec2(65, 19)) then S.ui_vcd.v = 15.0; syncConfig() end

            imgui.EndChild()
        end

        imgui.Spacing()

        if imgui.BeginChild("##AutoAcceptReceiveCard", imgui.ImVec2(548, 205), true, noScrollFlags) then
            imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), "Auto-Accept (/av):")
            imgui.SameLine(180)
            if S.isAutoAccept then
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.05, 0.45, 0.25, 0.85))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.08, 0.60, 0.35, 1.00))
                if imgui.Button("AutoAccept: ON", imgui.ImVec2(115, 20)) then
                    S.isAutoAccept = false
                    syncConfig()
                    sampAddChatMessage("{00C8FF}Diamond Menu: {327ED8}AutoAcceptVest: {FF0000}OFF", -1)
                end
                imgui.PopStyleColor(2)
            else
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.45, 0.12, 0.12, 0.85))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.60, 0.18, 0.18, 1.00))
                if imgui.Button("AutoAccept: OFF", imgui.ImVec2(115, 20)) then
                    S.isAutoAccept = true
                    syncConfig()
                    sampAddChatMessage("{00C8FF}Diamond Menu: {327ED8}AutoAcceptVest: {00FF00}ON", -1)
                end
                imgui.PopStyleColor(2)
            end

            imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), "Accept Price Limit (/ap):")
            imgui.PushItemWidth(-1)
            if imgui.SliderFloat("##AcceptPrice", S.ui_accept_price, 200.0, 1000.0, "$%.0f") then
                syncConfig()
            end
            imgui.PopItemWidth()
            if imgui.Button("$200 (Rec)##Acc", imgui.ImVec2(80, 19)) then S.ui_accept_price.v = 200.0; syncConfig() end
            imgui.SameLine()
            if imgui.Button("$500##Acc", imgui.ImVec2(55, 19)) then S.ui_accept_price.v = 500.0; syncConfig() end
            imgui.SameLine()
            if imgui.Button("$1000##Acc", imgui.ImVec2(55, 19)) then S.ui_accept_price.v = 1000.0; syncConfig() end

            imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), "Accept Armor Threshold (/aob):")
            imgui.PushItemWidth(-1)
            if imgui.SliderFloat("##AcceptThreshold", S.ui_accept_vob, 0.0, 49.0, "%.0f AP") then
                syncConfig()
            end
            imgui.PopItemWidth()
            if imgui.Button("25 AP##Acc", imgui.ImVec2(60, 19)) then S.ui_accept_vob.v = 25.0; syncConfig() end
            imgui.SameLine()
            if imgui.Button("46 AP (Rec)##Acc", imgui.ImVec2(85, 19)) then S.ui_accept_vob.v = 46.0; syncConfig() end

            imgui.EndChild()
        end

    -- ================= TAB 3: AUTOFIND =================
    elseif S.currentTab == 3 then
        if imgui.BeginChild("##AutoFindTargetCard", imgui.ImVec2(548, 160), true, noScrollFlags) then
            imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), "AutoFind Controller:")
            imgui.SameLine(160)
            if AF.active then
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.05, 0.45, 0.25, 0.85))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.08, 0.60, 0.35, 1.00))
                if imgui.Button("AutoFind: ON", imgui.ImVec2(115, 20)) then
                    AF.active = false
                    sampAddChatMessage(AF_TAG .. "{FF0000}OFF", -1)
                end
                imgui.PopStyleColor(2)
            else
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.45, 0.12, 0.12, 0.85))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.60, 0.18, 0.18, 1.00))
                if imgui.Button("AutoFind: OFF", imgui.ImVec2(115, 20)) then
                    if AF.targetName then
                        AF.active = true
                        AF.lastFindTime = 0
                        sampAddChatMessage(AF_TAG .. "{00FF00}ON {FFFFFF}(Resumed tracking " .. AF.targetName .. ").", -1)
                    else
                        sampAddChatMessage(AF_TAG .. "Enter a player name or ID below first.", -1)
                    end
                end
                imgui.PopStyleColor(2)
            end

            imgui.SameLine(365)
            imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), "Mode:")
            imgui.SameLine()
            if AF.modeCmd == "/find" then
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.00, 0.65, 0.90, 0.90))
                if imgui.Button("/find##ModeFindBtn", imgui.ImVec2(65, 20)) then AF.modeCmd = "/cohort" end
                imgui.PopStyleColor()
            else
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.55, 0.35, 0.05, 0.90))
                if imgui.Button("/cohort##ModeCoBtn", imgui.ImVec2(65, 20)) then AF.modeCmd = "/find" end
                imgui.PopStyleColor()
            end

            imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), "Player Target (ID / Part of Name):")
            imgui.PushItemWidth(420)
            imgui.InputText("##AfTargetInputBox", AF.input_target)
            imgui.PopItemWidth()
            imgui.SameLine()
            if imgui.Button("Track##TrackTargetBtn", imgui.ImVec2(112, 20)) then
                local val = AF.input_target.v:match("^%s*(.-)%s*$")
                if val ~= "" then
                    handleAfCommand(AF.modeCmd, val)
                end
            end

            imgui.Spacing()

            imgui.Text("Active Target:")
            imgui.SameLine()
            if AF.targetName then
                if AF.targetLost then
                    imgui.TextColored(imgui.ImVec4(1.00, 0.20, 0.20, 1.00), tostring(AF.targetName) .. " [Disconnected - Waiting for reconnect...]")
                else
                    imgui.TextColored(imgui.ImVec4(0.20, 1.00, 0.20, 1.00), string.format("%s [ID: %s] (%s)", AF.targetName, tostring(AF.targetId), AF.modeCmd))
                end
                imgui.SameLine(460)
                if imgui.Button("Clear##ClearAfTarget", imgui.ImVec2(75, 18)) then
                    AF.active = false
                    AF.targetName = nil
                    AF.targetId = nil
                    AF.targetLost = false
                end
            else
                imgui.TextDisabled("None (Inactive)")
            end

            imgui.EndChild()
        end

        imgui.Spacing()

        if imgui.BeginChild("##AutoFindSettingsCard", imgui.ImVec2(548, 115), true, noScrollFlags) then
            local curLvl = math.floor(AF.ui_level.v + 0.5)
            if curLvl < 1 then curLvl = 1 elseif curLvl > 5 then curLvl = 5 end

            imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), "Detective Level & Cooldown (/afcd):")
            imgui.SameLine(330)
            imgui.TextColored(imgui.ImVec4(0.00, 1.00, 0.40, 1.00), string.format("Level %d (%ds CD)", curLvl, AF_COOLDOWNS[curLvl] or 20))

            imgui.Spacing()

            imgui.PushItemWidth(-1)
            if imgui.SliderFloat("##AfLevelSlider", AF.ui_level, 1.0, 5.0, "Detective Level %.0f") then
                syncAfConfig()
            end
            imgui.PopItemWidth()

            imgui.Spacing()

            local lvlPresets = {
                { lvl = 1, label = "Lvl 1 (125s)" },
                { lvl = 2, label = "Lvl 2 (85s)" },
                { lvl = 3, label = "Lvl 3 (65s)" },
                { lvl = 4, label = "Lvl 4 (35s)" },
                { lvl = 5, label = "Lvl 5 (20s)" }
            }

            for idx, p in ipairs(lvlPresets) do
                if imgui.Button(p.label .. "##AfPreset" .. p.lvl, imgui.ImVec2(100, 20)) then
                    AF.ui_level.v = p.lvl
                    syncAfConfig()
                end
                if idx < #lvlPresets then imgui.SameLine() end
            end

            imgui.EndChild()
        end

        imgui.Spacing()

        if imgui.BeginChild("##AutoFindGuideCard", imgui.ImVec2(548, 183), true, noScrollFlags) then
            imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), "How to use AutoFind:")
            imgui.Separator()
            imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(0.00, 0.90, 1.00, 1.00), "/af [ID/Name]")
            imgui.SameLine(135)
            imgui.TextColored(imgui.ImVec4(0.92, 0.96, 1.00, 1.00), "- Finds target player on chosen cooldown repeatedly.")

            imgui.TextColored(imgui.ImVec4(0.00, 0.90, 1.00, 1.00), "/af (alone)")
            imgui.SameLine(135)
            imgui.TextColored(imgui.ImVec4(0.92, 0.96, 1.00, 1.00), "- Toggles tracking ON/OFF for your last targeted player.")

            imgui.TextColored(imgui.ImVec4(0.00, 0.90, 1.00, 1.00), "/afco [ID/Name]")
            imgui.SameLine(135)
            imgui.TextColored(imgui.ImVec4(0.92, 0.96, 1.00, 1.00), "- Uses /cohort command instead of /find on cooldown.")

            imgui.TextColored(imgui.ImVec4(0.00, 0.90, 1.00, 1.00), "/afcd [1-5]")
            imgui.SameLine(135)
            imgui.TextColored(imgui.ImVec4(0.92, 0.96, 1.00, 1.00), "- Sets detective level cooldown (Saved to config).")

            imgui.Spacing()
            imgui.TextColored(imgui.ImVec4(1.00, 0.75, 0.20, 1.00), "Smart Features:")
            imgui.TextColored(imgui.ImVec4(0.85, 0.88, 0.95, 1.00), "1. If target quits, blinking text beside radar waits for reconnect.")
            imgui.TextColored(imgui.ImVec4(0.85, 0.88, 0.95, 1.00), "2. Upon reconnecting, announces old/new ID and resumes tracking.")
            imgui.TextColored(imgui.ImVec4(0.85, 0.88, 0.95, 1.00), "3. Multi-match prevention prompts you if duplicate prefixes exist.")

            imgui.EndChild()
        end

    -- ================= TAB 4: KEYBINDS =================
    elseif S.currentTab == 4 then
        if imgui.BeginChild("##KeybindsManagementCard", imgui.ImVec2(548, 465), true, noScrollFlags) then
            imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), "Custom Keybinds Manager:")
            imgui.SameLine(360)
            if imgui.Button("+ Add Bind##AddKbBtn", imgui.ImVec2(100, 20)) then
                table.insert(KB.list, {
                    buf   = imgui.ImBuffer("", 128),
                    en    = true,
                    key   = 0,
                    alt   = false,
                    ctrl  = false,
                    shift = false
                })
                saveKeybinds()
            end

            imgui.SameLine(470)
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.45, 0.12, 0.12, 0.85))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.65, 0.18, 0.18, 1.00))
            if imgui.Button("Clear All##ClrBinds", imgui.ImVec2(68, 20)) then
                KB.list = {}
                KB.recordingIndex = nil
                saveKeybinds()
            end
            imgui.PopStyleColor(2)

            imgui.Separator()
            imgui.Spacing()

            imgui.BeginChild("##KeybindsScrollArea", imgui.ImVec2(532, 385), false, 0)
            if #KB.list == 0 then
                imgui.Spacing()
                imgui.TextDisabled("No keybinds created yet. Click '+ Add Bind' above to start.")
            else
                local toRemove = nil
                for idx, b in ipairs(KB.list) do
                    imgui.PushID(idx)

                    if b.en then
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.05, 0.45, 0.25, 0.85))
                        if imgui.Button("ON##KbTgl", imgui.ImVec2(36, 22)) then
                            b.en = false
                            saveKeybinds()
                        end
                        imgui.PopStyleColor()
                    else
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.40, 0.12, 0.85))
                        if imgui.Button("OFF##KbTgl", imgui.ImVec2(36, 22)) then
                            b.en = true
                            saveKeybinds()
                        end
                        imgui.PopStyleColor()
                    end

                    imgui.SameLine(0, 8)
                    imgui.PushItemWidth(260)
                    if imgui.InputText("##KbCmdInput", b.buf) then
                        saveKeybinds()
                    end
                    imgui.PopItemWidth()

                    imgui.SameLine(0, 8)
                    local isListening = (KB.recordingIndex == idx)
                    local keyTitle = isListening and "[ Press Key... ]" or ("[" .. getKeyTitle(b.key, b.alt, b.ctrl, b.shift) .. "]")
                    if isListening then
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.60, 0.45, 0.05, 0.90))
                        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.0, 1.0, 0.0, 1.0))
                    else
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.08, 0.20, 0.35, 0.85))
                        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.00, 0.85, 1.00, 1.00))
                    end

                    if imgui.Button(keyTitle .. "##KeyBtn", imgui.ImVec2(165, 22)) then
                        if KB.recordingIndex == idx then
                            KB.recordingIndex = nil
                        else
                            KB.recordingIndex = idx
                            KB.waitRelease = true
                        end
                    end
                    imgui.PopStyleColor(2)

                    imgui.SameLine(0, 8)
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.45, 0.10, 0.10, 0.80))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.70, 0.15, 0.15, 1.00))
                    if imgui.Button("X##KbDel", imgui.ImVec2(28, 22)) then
                        toRemove = idx
                    end
                    imgui.PopStyleColor(2)

                    imgui.PopID()
                    imgui.Spacing()
                end

                if toRemove then
                    if KB.recordingIndex == toRemove then KB.recordingIndex = nil end
                    table.remove(KB.list, toRemove)
                    saveKeybinds()
                end
            end
            imgui.EndChild()

            imgui.EndChild()
        end

    -- ================= TAB 5: BACKUP =================
    elseif S.currentTab == 5 then
        if imgui.BeginChild("##BackupManagementCard", imgui.ImVec2(548, 465), true, noScrollFlags) then
            imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), "Emergency Backup System:")
            imgui.SameLine(190)
            if BK.enabled then
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.05, 0.45, 0.25, 0.85))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.08, 0.60, 0.35, 1.00))
                if imgui.Button("Enabled: ON##BkEn", imgui.ImVec2(110, 20)) then
                    BK.enabled = false
                    BK.isActive = false
                    saveBkConfig()
                end
                imgui.PopStyleColor(2)
            else
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.45, 0.12, 0.12, 0.85))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.60, 0.18, 0.18, 1.00))
                if imgui.Button("Enabled: OFF##BkEn", imgui.ImVec2(110, 20)) then
                    BK.enabled = true
                    BK.isActive = false
                    saveBkConfig()
                end
                imgui.PopStyleColor(2)
            end

            imgui.SameLine(335)
            imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), "Mode:")
            imgui.SameLine()
            if BK.mode == "Gang" then
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.55, 0.15, 0.25, 0.90))
                if imgui.Button("Gang (/fbackup)##BkModeBtn", imgui.ImVec2(130, 20)) then
                    BK.mode = "Faction"
                    BK.isActive = false
                    saveBkConfig()
                end
                imgui.PopStyleColor()
            else
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.08, 0.35, 0.60, 0.90))
                if imgui.Button("Faction (/backup)##BkModeBtn", imgui.ImVec2(130, 20)) then
                    BK.mode = "Gang"
                    BK.isActive = false
                    saveBkConfig()
                end
                imgui.PopStyleColor()
            end

            imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), "Activation Keybind:")
            imgui.SameLine(140)

            local bkKeyTitle = BK.recording and "[ Press Any Key... ]" or ("[" .. getKeyTitle(BK.key, BK.alt, BK.ctrl, BK.shift) .. "]")
            if BK.recording then
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.60, 0.45, 0.05, 0.90))
                imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.0, 1.0, 0.0, 1.0))
            else
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.08, 0.20, 0.35, 0.85))
                imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.00, 0.85, 1.00, 1.00))
            end

            if imgui.Button(bkKeyTitle .. "##BkBindBtn", imgui.ImVec2(165, 22)) then
                BK.recording = not BK.recording
                if BK.recording then
                    BK.waitRelease = true
                end
            end
            imgui.PopStyleColor(2)

            imgui.SameLine(320)
            imgui.TextDisabled("Current Location: " .. getPlayerCurrentLocationName())

            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), "Registered Landmarks (Auto-detects when within range):")
            imgui.Spacing()

            imgui.BeginChild("##BkLocationsListFrame", imgui.ImVec2(532, 330), true, 0)
            for idx, loc in ipairs(BK_LOCATIONS) do
                imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), string.format("%d.", idx))
                imgui.SameLine(32)
                imgui.Text(loc.name)
            end
            imgui.EndChild()

            imgui.EndChild()
        end

    else
        if imgui.BeginChild("##ReservedSlotFrame", imgui.ImVec2(548, 465), true, noScrollFlags) then
            imgui.TextColored(imgui.ImVec4(0.00, 0.85, 1.00, 1.00), string.format("MODULE SLOT #%d", S.currentTab - 4))
            imgui.Separator()
            imgui.TextDisabled("This slot is reserved for your next incoming mod.")
            imgui.EndChild()
        end
    end

    imgui.EndChild()
    imgui.End()
end