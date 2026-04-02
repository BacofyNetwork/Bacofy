-- ==========================================
-- PROGRAM: BACOFY ULTIMATE (Single List)
-- DESCRIPTION: RAW HQ Player + Auto-Refresh
-- ==========================================

local speaker = peripheral.find("speaker")
local indexURL = "https://raw.githubusercontent.com/BacofyNetwork/Bacofy/main/Music/songlist.txt"

local currentSongs = {}
local vol = 0.5
local currentIdx = 1
local isPlaying = false
local w, h = term.getSize()

-- FETCH SONG LIST
local function getList(url)
    local res = http.get(url .. "?t=" .. os.epoch("utc"))
    if not res then return {} end
    local list = {}
    local content = res.readAll()
    res.close()
    
    for line in content:gmatch("[^\r\n]+") do
        local l, n = line:match("^(.*),(.*)$")
        if l then 
            table.insert(list, {
                url = l:gsub("%s+", ""), 
                name = n:match("^%s*(.-)%s*$")
            }) 
        end
    end
    return list
end

-- DRAW INTERFACE
local function drawUI()
    term.setBackgroundColor(colors.black)
    term.clear()
    
    -- Header
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.blue)
    term.clearLine()
    local header = "BACOFY MUSIC"
    term.setCursorPos(math.floor((w - #header) / 2) + 1, 1)
    term.setTextColor(colors.white)
    term.write(header)

    -- Song List
    term.setBackgroundColor(colors.black)
    if #currentSongs == 0 then
        term.setCursorPos(2, 3)
        term.setTextColor(colors.red)
        term.write("No songs found!")
    else
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
    end

    -- Footer
    term.setCursorPos(1, h)
    term.setBackgroundColor(colors.gray)
    term.clearLine()
    term.setTextColor(colors.white)
    local status = isPlaying and "[STOP]" or "[PLAY]"
    term.write(" " .. status .. " | VOL: " .. math.floor(vol*100) .. "% | [R] REFRESH")
end

-- AUDIO ENGINE (RAW)
local function playSong(url)
    if not speaker then return end
    local res = http.get({ url = url, binary = true })
    if not res then return end
    
    isPlaying = true
    while isPlaying do
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

-- INITIAL LOAD
currentSongs = getList(indexURL)
drawUI()

-- EVENT LOOP
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
                if x <= 8 then
                    isPlaying = not isPlaying
                    if isPlaying then os.queueEvent("start_music") end
                elseif x > 10 and x < 20 then
                    vol = (vol >= 1) and 0.1 or vol + 0.1
                elseif x > 20 then
                    currentSongs = getList(indexURL)
                    drawUI()
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
            end
        end
    end,
    function()
        while true do
            os.pullEvent("start_music")
            if currentSongs[currentIdx] then playSong(currentSongs[currentIdx].url) end
        end
    end,
    -- ==========================================
    -- NEU: BACKGROUND AUTO-REFRESH
    -- ==========================================
    function()
        while true do
            -- Checkt alle 30 Sekunden im Hintergrund
            os.sleep(30) 
            local newList = getList(indexURL)
            
            -- Updatet die UI nur, wenn wirklich neue Lieder da sind
            if newList and #newList > #currentSongs then
                currentSongs = newList
                drawUI()
            end
        end
    end
)