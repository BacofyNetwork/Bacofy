-- ==========================================
-- PROGRAM: BACOFY PRO (English & Red Design)
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
    term.setBackgroundColor(colors.red) -- Red header
    term.clearLine()
    
    if view == "MASTER" then
        term.setTextColor(colors.white)
        term.write(" Bacofy Pro")
        
        term.setCursorPos(w - 7, 1)
        term.setTextColor(colors.lightGray)
        term.write("[R] REF")
    elseif view == "PLAYLIST" then
        term.setTextColor(colors.white)
        term.write(" [< BACK]")
        
        -- Fixed Overlap: Limit playlist name length
        term.setCursorPos(11, 1)
        term.setTextColor(colors.yellow)
        term.write("PL: " .. string.sub(selectedPlaylist, 1, w - 20))

        term.setCursorPos(w - 7, 1)
        term.setTextColor(colors.lightGray)
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
    term.setBackgroundColor(colors.black) -- Removed gray bar
    term.clearLine()
    term.setTextColor(colors.gray)
    term.write(string.rep("-", w))

    -- ==========================================
    -- ZONE 3: LIST AREA (Line 4 to h-3)
    -- ==========================================
    local listStart = 4
    local listEnd = h - 3
    
    for y = listStart, listEnd do
        term.setCursorPos(1, y)
        term.setBackgroundColor(colors.black) -- Black list background
        term.clearLine()
    end
    
    if view == "MASTER" then
        term.setTextColor(colors.white)
        for i, item in ipairs(playlists) do
            if i > (listEnd - listStart + 1) then break end
            term.setCursorPos(2, (listStart - 1) + i)
            
            -- Sketch-Look: Ein Balken.
            term.setBackgroundColor(colors.red) 
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
                term.setBackgroundColor(colors.lime) -- Green for active song
                term.setTextColor(colors.black)
                term.write(" [ > " .. i .. ". " .. string.sub(item.name, 1, w - 10) .. " ] ")
            else
                term.setBackgroundColor(colors.red) -- Red for idle song
                term.setTextColor(colors.white)
                term.write(" [   " .. i .. ". " .. string.sub(item.name, 1, w - 10) .. " ] ")
            end
        end
    end

    -- Visual Separation Dots
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.gray)
    term.setCursorPos(2, h-3)
    term.write(" . . . . . ")

    -- ==========================================
    -- ZONE 4: CONTROLS (Line h-2 to h-1) (Now Gray)
    -- ==========================================
    local textColorsOnGray = colors.white
    local textColorsOnRedButtons = colors.red -- Original button color logic

    -- Controls Line (h-2) (Media Buttons)
    term.setCursorPos(cx - 9, h - 2) -- Center the cluster
    term.setBackgroundColor(colors.gray) -- Gray control bar
    term.clearLine()
    
    local playIcon = isPlaying and "||" or "> "
    
    term.setTextColor(textColorsOnRedButtons) -- Maintain red for buttons
    term.write("<<")
    
    term.setTextColor(colors.black) -- Original color logic
    term.write("  ")
    term.setTextColor(textColorsOnRedButtons)
    term.write(playIcon)
    
    term.setTextColor(colors.black)
    term.write("  ")
    term.setTextColor(textColorsOnRedButtons)
    term.write("[]")
    
    term.setTextColor(colors.black)
    term.write("  ")
    term.setTextColor(textColorsOnRedButtons)
    term.write(">>")

    -- Volume Line (h-1) (Separated Volume)
    term.setCursorPos(cx - 9, h - 1) -- Center the cluster
    term.setBackgroundColor(colors.gray) -- Gray control bar
    term.clearLine()
    
    term.setTextColor(textColorsOnRedButtons) -- Maintain red for buttons
    term.write("[-]  ")
    
    term.setTextColor(colors.white) -- Original color logic
    term.write("VOL: ")
    term.setBackgroundColor(colors.gray) -- Keep number area gray
    term.write(tostring(math.floor(vol * 100)))
    term.setBackgroundColor(colors.gray) -- Rest gray
    
    term.setTextColor(textColorsOnRedButtons) -- Maintain red for buttons
    term.write("  [+]")

    -- ==========================================
    -- ZONE 5: INFO Line (Line h) (Still Red)
    -- ==========================================
    term.setCursorPos(1, h)
    term.setBackgroundColor(colors.red) -- Info Line still red
    term.setTextColor(colors.white) 
    term.clearLine()
    
    local currentName = (allSongs[currentIdx] and allSongs[currentIdx].name) or "IDLE"
    term.write(" PLAYING: " .. string.sub(currentName, 1, w - 11))
end

-- ==========================================
-- AUDIO STREAMING ENGINE (UNCHANGED)
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
-- INITIAL LOAD (UNCHANGED)
-- ==========================================
playlists = getList(masterURL)
drawUI()

-- ==========================================
-- MAIN EVENT LOOPS (UNCHANGED)
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
                
            -- Mouse Clicks (Zones updated for gray bars)
            elseif event == "mouse_click" then
                local x, y = p2, p3
                
                -- HEADER ZONE
                if y == 1 then
                    if x > w - 8 then
                        playlists = getList(masterURL)
                    elseif x <= 9 and view == "PLAYLIST" then
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
                    
                -- MEDIA CONTROLS (Line h-2)
                elseif y == h - 2 then
                    -- Zone cluster is cx-9 to cx+14
                    local clusterStart = cx - 9
                    if x >= clusterStart and x <= clusterStart+1 then           -- [<<] Prev
                        if #allSongs > 0 then
                            currentIdx = currentIdx - 1
                            if currentIdx < 1 then currentIdx = #allSongs end
                            isPlaying = false
                            os.queueEvent("start_music")
                        end
                        
                    elseif x >= clusterStart+4 and x <= clusterStart+5 then      -- [> / ||] Play/Pause
                        isPlaying = not isPlaying
                        if isPlaying and #allSongs > 0 then
                            os.queueEvent("start_music")
                        end
                        
                    elseif x >= clusterStart+8 and x <= clusterStart+9 then      -- [[]] Stop
                        isPlaying = false
                        
                    elseif x >= clusterStart+12 and x <= clusterStart+13 then     -- [>>] Next
                        if #allSongs > 0 then
                            currentIdx = currentIdx + 1
                            if currentIdx > #allSongs then currentIdx = 1 end
                            isPlaying = false
                            os.queueEvent("start_music")
                        end
                    end

                -- VOLUME CONTROLS (Line h-1)
                elseif y == h - 1 then
                    -- Zone cluster is cx-9 to cx+14
                    local clusterStart = cx - 9
                    if x >= clusterStart and x <= clusterStart+2 then           -- [-] Vol Down
                        vol = vol - 0.1
                        if vol < 0.1 then vol = 1.0 end
                    elseif x >= clusterStart+11 and x <= clusterStart+14 then     -- [+] Vol Up
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