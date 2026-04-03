-- ==========================================
-- PROGRAM: BACOFY PRO (English & Clean UI)
-- ==========================================

local speaker = peripheral.find("speaker")
local baseURL = "https://raw.githubusercontent.com/BacofyNetwork/Bacofy/main/Music/"
local masterURL = baseURL .. "master.txt"

-- STATE VARIABLES
local playlists = {}
local currentSongs = {} 
local filteredSongs = {} 
local view = "MASTER"
local selectedPlaylist = "" 
local searchQuery = ""
local vol = 0.5
local isPlaying = false

-- AUDIO TRACKING STATE
local allSongs = {} 
local currentIdx = 1 
local playedPlaylistName = "" 

local w, h = term.getSize()

-- Helper: Get List from URL (Text)
local function getList(url)
    local res = http.get(url .. "?t=" .. os.epoch("utc"))
    if not res then return {} end
    local t = {}
    for line in res.readAll():gmatch("[^\r\n]+") do table.insert(t, line) end
    res.close()
    return t
end

-- Helper: Load Playlist Songs
local function loadPlaylist(name)
    local url = baseURL .. name .. ".txt"
    local res = http.get(url .. "?t=" .. os.epoch("utc"))
    local songs = {}
    if res then
        for line in res.readAll():gmatch("[^\r\n]+") do
            local l, n = line:match("^(.*),(.*)$")
            if l then table.insert(songs, {url=l:gsub("%s+",""), name=n:match("^%s*(.-)%s*$")}) end
        end
        res.close()
    end
    return songs
end

-- ==========================================
-- UI DRAW ENGINE
-- ==========================================
local function drawUI()
    term.setBackgroundColor(colors.black)
    term.clear()
    
    -- ==========================================
    -- ZONE 1: HEADER (Line 1 & 2)
    -- ==========================================
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.black)
    term.clearLine()
    
    if view == "MASTER" then
        term.setTextColor(colors.white)
        term.write(" Bacofy Pro")
        
        term.setCursorPos(w - 7, 1)
        term.setTextColor(colors.cyan)
        term.write("[R] REF")
    elseif view == "PLAYLIST" then
        term.setTextColor(colors.cyan)
        term.write(" [< BACK]")
        
        -- Fixed Overlap: Limit playlist name length
        term.setCursorPos(11, 1)
        term.setTextColor(colors.yellow)
        term.write("PL: " .. string.sub(selectedPlaylist, 1, w - 20))

        term.setCursorPos(w - 7, 1)
        term.setTextColor(colors.cyan)
        term.write("[R] REF")
    end
    
    -- Search Bar
    term.setCursorPos(1, 2)
    term.setBackgroundColor(colors.black)
    term.clearLine()
    term.setTextColor(colors.lightGray)
    term.write(" Search: ")
    term.setTextColor(colors.white)
    term.write(searchQuery .. "_")
    
    -- ==========================================
    -- ZONE 2: TOP SEPARATOR (Line 3)
    -- ==========================================
    term.setCursorPos(1, 3)
    term.setBackgroundColor(colors.gray) -- Dark gray bar
    term.clearLine()

    -- ==========================================
    -- ZONE 3: LIST AREA (Line 4 to h-3)
    -- ==========================================
    local listStart = 4
    local listEnd = h - 3
    
    for y = listStart, listEnd do
        term.setCursorPos(1, y)
        term.setBackgroundColor(colors.lime) 
        term.clearLine()
    end
    
    if view == "MASTER" then
        for i, item in ipairs(playlists) do
            if i > (listEnd - listStart + 1) then break end
            term.setCursorPos(2, (listStart - 1) + i)
            
            term.setBackgroundColor(colors.cyan) 
            term.setTextColor(colors.white)
            term.write(" [ Playlist: " .. string.sub(item, 1, w - 16) .. " ] ")
        end
        
    elseif view == "PLAYLIST" then
        for i, item in ipairs(filteredSongs) do
            if i > (listEnd - listStart + 1) then break end
            term.setCursorPos(2, (listStart - 1) + i)
            
            local isCurrentSong = false
            if isPlaying and allSongs[currentIdx] and playedPlaylistName == selectedPlaylist then
                if item.url == allSongs[currentIdx].url then
                    isCurrentSong = true
                end
            end
            
            if isCurrentSong then
                term.setBackgroundColor(colors.yellow) 
                term.setTextColor(colors.black)
                term.write(" [ > " .. i .. ". " .. string.sub(item.name, 1, w - 10) .. " ] ")
            else
                term.setBackgroundColor(colors.cyan) 
                term.setTextColor(colors.white)
                term.write(" [   " .. i .. ". " .. string.sub(item.name, 1, w - 10) .. " ] ")
            end
        end
    end

    -- ==========================================
    -- ZONE 4: BOTTOM SEPARATOR (Line h-2)
    -- ==========================================
    term.setCursorPos(1, h - 2)
    term.setBackgroundColor(colors.gray) -- Dark gray bar
    term.clearLine()

    -- ==========================================
    -- ZONE 5: CONTROLS (Line h-1 to h)
    -- ==========================================
    local textColorsOnRed = colors.white
    local textColorsOnRedButtons = colors.lightGray 

    -- Buttons Line (h-1)
    term.setCursorPos(1, h - 1)
    term.setBackgroundColor(colors.red) 
    term.setTextColor(textColorsOnRedButtons) 
    term.clearLine()
    
    local pIcon = isPlaying and "[||]" or "[ >]"
    term.write("  [ - ]   [|<]     " .. pIcon .. "     [>|]   [ + ]")

    -- Info Line (h)
    term.setCursorPos(1, h)
    term.setBackgroundColor(colors.red) 
    term.setTextColor(textColorsOnRed) 
    term.clearLine()
    
    local currentName = (allSongs[currentIdx] and allSongs[currentIdx].name) or "IDLE"
    term.write(" PLAYING: " .. string.sub(currentName, 1, w - 11))
end

-- ==========================================
-- AUDIO STREAMING ENGINE
-- ==========================================
local function playSong(url)
    if not speaker then return end
    local res = http.get({ url = url, binary = true })
    if not res then return end
    
    isPlaying = true
    term.redirect(term.native()) 
    drawUI()
    
    while isPlaying do
        local chunk = res.read(16384) 
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
    
    if isPlaying then 
        currentIdx = currentIdx + 1
        if currentIdx > #allSongs then currentIdx = 1 end
        os.queueEvent("start_music")
    end
end

-- ==========================================
-- INITIAL LOAD
-- ==========================================
playlists = getList(masterURL)
drawUI()

-- ==========================================
-- MAIN EVENT LOOPS
-- ==========================================
parallel.waitForAny(
    function() 
        while true do
            local event, p1, p2, p3 = os.pullEvent()
            
            -- Search Input
            if event == "char" and view == "PLAYLIST" then
                searchQuery = searchQuery .. p1
                filteredSongs = {}
                for _, s in ipairs(currentSongs) do 
                    if s.name:lower():find(searchQuery:lower()) then table.insert(filteredSongs, s) end 
                end
                drawUI()
            
            -- Backspace (Delete)
            elseif event == "key" and p1 == keys.backspace and view == "PLAYLIST" and #searchQuery > 0 then
                searchQuery = searchQuery:sub(1, -2)
                filteredSongs = {}
                for _, s in ipairs(currentSongs) do 
                    if s.name:lower():find(searchQuery:lower()) then table.insert(filteredSongs, s) end 
                end
                drawUI()
                
            -- Mouse Clicks
            elseif event == "mouse_click" then
                local x, y = p2, p3
                
                -- HEADER ZONE
                if y == 1 then
                    if x > w - 8 then
                        -- Refresh Button
                        playlists = getList(masterURL)
                    elseif x <= 9 and view == "PLAYLIST" then
                        -- Back Button
                        view = "MASTER"
                    end
                
                -- LIST ZONE (Line 4 to h-3)
                elseif y >= 4 and y <= h - 3 then
                    local idx = y - 3
                    
                    if view == "MASTER" then
                        if playlists[idx] then
                            selectedPlaylist = playlists[idx]
                            currentSongs = loadPlaylist(selectedPlaylist)
                            filteredSongs = currentSongs
                            searchQuery = "" 
                            view = "PLAYLIST"
                        end
                    elseif view == "PLAYLIST" then
                        if filteredSongs[idx] then
                            for i, s in ipairs(currentSongs) do
                                if s.url == filteredSongs[idx].url then
                                    currentIdx = i
                                    allSongs = currentSongs 
                                    break
                                end
                            end
                            isPlaying = false
                            playedPlaylistName = selectedPlaylist 
                            os.queueEvent("start_music")
                        end
                    end
                    
                -- CONTROLS ZONE (Line h-1)
                elseif y == h - 1 then
                    if x >= 1 and x <= 7 then           -- VOL DOWN [-]
                        vol = vol - 0.1
                        if vol < 0.1 then vol = 1.0 end
                        
                    elseif x >= 8 and x <= 14 then      -- PREVIOUS [|<]
                        if #allSongs > 0 then
                            currentIdx = currentIdx - 1
                            if currentIdx < 1 then currentIdx = #allSongs end
                            isPlaying = false
                            os.queueEvent("start_music")
                        end
                        
                    elseif x >= 16 and x <= 26 then     -- PLAY/PAUSE [||]
                        isPlaying = not isPlaying
                        if isPlaying and #allSongs > 0 then
                            os.queueEvent("start_music")
                        end
                        
                    elseif x >= 28 and x <= 34 then     -- NEXT [>|]
                        if #allSongs > 0 then
                            currentIdx = currentIdx + 1
                            if currentIdx > #allSongs then currentIdx = 1 end
                            isPlaying = false
                            os.queueEvent("start_music")
                        end
                        
                    elseif x >= 36 and x <= 42 then     -- VOL UP [+]
                        vol = vol + 0.1
                        if vol > 1.0 then vol = 0.1 end
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
            if view == "MASTER" then
                local newList = getList(masterURL)
                if #newList > #playlists then
                    playlists = newList
                    drawUI()
                end
            elseif view == "PLAYLIST" then
                local newList = loadPlaylist(selectedPlaylist)
                if #newList > #currentSongs then
                    currentSongs = newList
                    filteredSongs = {}
                    for _, s in ipairs(currentSongs) do 
                        if s.name:lower():find(searchQuery:lower()) then table.insert(filteredSongs, s) end 
                    end
                    drawUI()
                end
            end
        end
    end
)