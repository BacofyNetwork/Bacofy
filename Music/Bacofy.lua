-- ==========================================
-- PROGRAM: BACOFY PRO (Search & Controls)
-- ==========================================

local speaker = peripheral.find("speaker")
local indexURL = "https://raw.githubusercontent.com/BacofyNetwork/Bacofy/main/Music/songlist.txt"

local allSongs = {}
local filteredSongs = {}
local vol = 0.5
local currentIdx = 1
local isPlaying = false
local searchQuery = ""
local w, h = term.getSize()

-- Lädt die Liste von GitHub
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

-- Such-Filter Funktion
local function filterSongs()
    filteredSongs = {}
    if searchQuery == "" then
        for i, s in ipairs(allSongs) do table.insert(filteredSongs, s) end
    else
        local q = string.lower(searchQuery)
        for i, s in ipairs(allSongs) do
            if string.find(string.lower(s.name), q) then
                table.insert(filteredSongs, s)
            end
        end
    end
end

-- UI
local function drawUI()
    term.setBackgroundColor(colors.black)
    term.clear()
    
    -- Suchleiste
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.blue)
    term.clearLine()
    term.setTextColor(colors.yellow)
    term.write(" Suche: ")
    term.setTextColor(colors.white)
    term.write(searchQuery .. "_")

    -- Song Liste
    term.setBackgroundColor(colors.black)
    if #filteredSongs == 0 then
        term.setCursorPos(2, 3)
        term.setTextColor(colors.red)
        term.write("Keine Songs gefunden.")
    else
        for i, item in ipairs(filteredSongs) do
            if i > h - 3 then break end
            term.setCursorPos(2, 2 + i)
            
            local isCurrent = (allSongs[currentIdx] and item.url == allSongs[currentIdx].url and isPlaying)
            
            if isCurrent then
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
    
    local playIcon = isPlaying and "[||]" or "[ >]"
    term.write(" [|<] " .. playIcon .. " [>|] | VOL: " .. math.floor(vol*100) .. "% | [R] REF")
end

-- AUDIO ENGINE
local function playSong(url)
    if not speaker then return end
    local res = http.get({ url = url, binary = true })
    if not res then return end
    
    isPlaying = true
    while isPlaying do
        local chunk = res.read(4096) 
        if chunk == nil or chunk == "" then break end
        
        local buffer = {}
        if type(chunk) == "string" then
            for i = 1, #chunk do
                local val = string.byte(chunk, i)
                if val > 127 then val = val - 256 end
                table.insert(buffer, val)
            end
        elseif type(chunk) == "number" then
            local val = chunk
            if val > 127 then val = val - 256 end
            table.insert(buffer, val)
            for i = 2, 4096 do
                local b = res.read()
                if not b then break end
                if b > 127 then b = b - 256 end
                table.insert(buffer, b)
            end
        end
        
        while isPlaying and not speaker.playAudio(buffer, vol) do
            os.pullEvent("speaker_audio_empty")
        end
        os.sleep(0)
    end
    res.close()
    
    -- Auto-Play Nächstes Lied
    if isPlaying then 
        currentIdx = currentIdx + 1
        if currentIdx > #allSongs then currentIdx = 1 end
        os.queueEvent("start_music")
    end
end

-- INITIAL LOAD
allSongs = getList(indexURL)
filterSongs()
drawUI()

-- EVENT LOOP
parallel.waitForAny(
    function()
        while true do
            local event, p1, p2, p3 = os.pullEvent()
            
            if event == "char" then
                searchQuery = searchQuery .. p1
                filterSongs()
                drawUI()
            
            elseif event == "key" then
                if p1 == keys.backspace and #searchQuery > 0 then
                    searchQuery = string.sub(searchQuery, 1, -2)
                    filterSongs()
                    drawUI()
                end
                
            elseif event == "mouse_click" then
                local x, y = p2, p3
                
                if y >= 3 and y < h then
                    local idx = y - 2
                    if filteredSongs[idx] then
                        for i, s in ipairs(allSongs) do
                            if s.url == filteredSongs[idx].url then
                                currentIdx = i
                                break
                            end
                        end
                        isPlaying = false
                        os.queueEvent("start_music")
                    end
                
                elseif y == h then
                    if x >= 2 and x <= 5 then           -- ZURÜCK
                        if #allSongs > 0 then
                            currentIdx = currentIdx - 1
                            if currentIdx < 1 then currentIdx = #allSongs end
                            isPlaying = false
                            os.queueEvent("start_music")
                        end
                    elseif x >= 7 and x <= 10 then      -- PLAY/PAUSE
                        isPlaying = not isPlaying
                        if isPlaying then os.queueEvent("start_music") end
                    elseif x >= 12 and x <= 15 then     -- VOR
                        if #allSongs > 0 then
                            currentIdx = currentIdx + 1
                            if currentIdx > #allSongs then currentIdx = 1 end
                            isPlaying = false
                            os.queueEvent("start_music")
                        end
                    elseif x >= 18 and x <= 26 then     -- LAUTSTÄRKE (Gefixt!)
                        vol = vol + 0.1
                        if vol > 1.0 then 
                            vol = 0.1 
                        end
                    elseif x >= 29 then                 -- REFRESH
                        allSongs = getList(indexURL)
                        filterSongs()
                    end
                end
                drawUI()
            end
        end
    end,
    function()
        while true do
            os.pullEvent("start_music")
            if allSongs[currentIdx] then playSong(allSongs[currentIdx].url) end
        end
    end,
    function()
        while true do
            os.sleep(30)
            local newList = getList(indexURL)
            if newList and #newList > #allSongs then
                allSongs = newList
                filterSongs()
                drawUI()
            end
        end
    end
)