-- ==========================================
-- PROGRAM: BACOFY (ORIGINAL UI + RAW WORKING)
-- ==========================================

local speaker = peripheral.find("speaker")
local indexURL = "https://raw.githubusercontent.com/BacofyNetwork/Bacofy/main/Music/songlist.txt"

local currentSongs = {}
local vol = 0.5
local currentIdx = 1
local isPlaying = false
local w, h = term.getSize()

local function getList(url)
    local res = http.get(url .. "?t=" .. os.epoch("utc"))
    if not res then return {} end
    local list = {}
    for line in res.readAll():gmatch("[^\r\n]+") do
        local l, n = line:match("^(.*),(.*)$")
        if l then table.insert(list, {url=l:gsub("%s+",""), name=n:match("^%s*(.-)%s*$")}) end
    end
    res.close()
    return list
end

local function drawUI()
    term.setBackgroundColor(colors.black)
    term.clear()
    
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.blue)
    term.clearLine()
    local header = "BACOFY MUSIC"
    term.setCursorPos(math.floor((w - #header) / 2) + 1, 1)
    term.setTextColor(colors.white)
    term.write(header)

    term.setBackgroundColor(colors.black)
    for i, item in ipairs(currentSongs) do
        if i > h - 3 then break end
        term.setCursorPos(2, 2 + i)
        if i == currentIdx and isPlaying then
            term.setTextColor(colors.lime)
            term.write("> " .. item.name)
        else
            term.setTextColor(colors.white)
            term.write(i .. ". " .. item.name)
        end
    end

    term.setCursorPos(1, h)
    term.setBackgroundColor(colors.gray)
    term.clearLine()
    term.setTextColor(colors.white)
    term.write(" VOL: " .. math.floor(vol*100) .. "% | [P] PLAY | [R] REFRESH")
end

local function playSong(url)
    if not speaker then 
        term.setCursorPos(1, h-1)
        term.setTextColor(colors.red)
        term.write("FEHLER: Kein Speaker gefunden!")
        return 
    end
    
    local res = http.get({ url = url, binary = true })
    if not res then 
        -- HIER IST DER DEBUGGER: Wenn der Link kaputt ist, sagt er es dir jetzt!
        term.setCursorPos(1, h-2)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.red)
        term.clearLine()
        term.write("404 FEHLER: Kann Link nicht laden!")
        term.setCursorPos(1, h-1)
        term.write(string.sub(url, 1, w)) -- Zeigt den kaputten Link an
        return 
    end
    
    isPlaying = true
    while isPlaying do
        -- Die originalen, funktionierenden 16384 Chunks!
        local chunk = res.read(16384) 
        if not chunk then break end
        
        local buffer = {}
        for i = 1, #chunk do
            local val = string.byte(chunk, i)
            if val > 127 then val = val - 256 end
            table.insert(buffer, val)
        end
        
        while isPlaying and not speaker.playAudio(buffer, vol) do
            os.pullEvent("speaker_audio_empty")
        end
        os.sleep(0)
    end
    res.close()
    
    if isPlaying then 
        currentIdx = (currentIdx % #currentSongs) + 1
        os.queueEvent("start_music")
    end
end

currentSongs = getList(indexURL)
drawUI()

parallel.waitForAny(
    function()
        while true do
            local _, _, x, y = os.pullEvent("mouse_click")
            if y >= 3 and y < h then
                local idx = y - 2
                if currentSongs[idx] then
                    currentIdx = idx
                    isPlaying = false
                    os.queueEvent("start_music")
                end
            elseif y == h then
                if x <= 10 then
                    vol = (vol + 0.1 > 1) and 0.1 or vol + 0.1
                elseif x > 12 and x < 24 then
                    isPlaying = not isPlaying
                    if isPlaying then os.queueEvent("start_music") end
                elseif x >= 25 then
                    currentSongs = getList(indexURL)
                end
            end
            drawUI()
        end
    end,
    function()
        while true do
            local _, key = os.pullEvent("key")
            if key == keys.r then 
                currentSongs = getList(indexURL)
                drawUI()
            elseif key == keys.p then
                isPlaying = not isPlaying
                if isPlaying then os.queueEvent("start_music") end
            end
        end
    end,
    function()
        while true do
            os.pullEvent("start_music")
            if currentSongs[currentIdx] then playSong(currentSongs[currentIdx].url) end
        end
    end,
    function()
        while true do
            os.sleep(30)
            local newList = getList(indexURL)
            if newList and #newList > #currentSongs then
                currentSongs = newList
                drawUI()
            end
        end
    end
)