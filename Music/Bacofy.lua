-- ==========================================
-- PROGRAM: BACOFY PRO (The Sketch Edition)
-- ==========================================

local speaker = peripheral.find("speaker")
local baseURL = "https://raw.githubusercontent.com/BacofyNetwork/Bacofy/main/Music/"
local masterURL = baseURL .. "master.txt"

-- STATE VARIABLES
local playlists = {}
local currentSongs = {} -- All songs in loaded playlist
local filteredSongs = {} -- Songs after search filter
local view = "MASTER" -- "MASTER" or "PLAYLIST"
local selectedPlaylist = "" -- viewed PL name
local viewedPlaylistSongs = {} -- songs in viewed PL
local searchQuery = ""
local vol = 0.5
local isPlaying = false

-- AUDIO TRACKING STATE (Kritisch für das "Grüne Licht")
local allSongs = {} -- The actual playing queue (flattened playlist)
local currentIdx = 1 -- Index in playing queue
local playedPlaylistName = "" -- Which playlist is currently playing

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

-- Helper: Load Playlist Songs (RAW links & names)
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
-- UI DRAW ENGINE (IMPLEMENTING THE SKETCH)
-- ==========================================
local function drawUI()
    -- Reset Terminal
    term.setBackgroundColor(colors.black)
    term.clear()
    
    -- ==========================================
    -- ZONE 1: TOP HEADER (GRAY, Line 1)
    -- ==========================================
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.gray)
    term.clearLine()
    term.setTextColor(colors.white)
    term.write(" Bacofy Pro")
    
    term.setCursorPos(w - #("Refresh ") + 1, 1)
    term.setTextColor(colors.cyan) -- Blau laut Sketch
    term.write("Refresh")
    
    -- ==========================================
    -- ZONE 2: SEARCHBAR (GRAY, Line 2)
    -- ==========================================
    term.setCursorPos(1, 2)
    term.clearLine()
    term.setTextColor(colors.lightGray)
    term.write(" > search: ") -- "<Searchbar>" laut Sketch
    term.setTextColor(colors.white)
    term.write(searchQuery .. "_")
    
    -- ==========================================
    -- ZONE 3: LIST AREA (RED, Lines 3 to h-4)
    -- ==========================================
    -- Wir berechnen die Höhe des roten Bereichs.
    -- Er endet über dem Fake Progress Bar (h-3) und Controls (h-2 bis h).
    local listEndLine = h - 4
    for y = 3, listEndLine do
        term.setCursorPos(1, y)
        term.setBackgroundColor(colors.red) -- Roter Hintergrund
        term.clearLine()
    end
    
    term.setTextColor(colors.white)
    
    -- Handle View-spezifischen Listen-Inhalt
    if view == "MASTER" then
        for i, item in ipairs(playlists) do
            if i > (listEndLine - 3 + 1) then break end
            term.setCursorPos(2, 2 + i)
            
            -- Sketch-Vorgabe: "blau" für inaktive (Cyan ist besser lesbar)
            term.setBackgroundColor(colors.cyan)
            term.setTextColor(colors.black)
            -- Sketch-Look: Ein Balken
            term.write(" [ Playlist: " .. string.sub(item, 1, w - 16) .. " ] ")
        end
    elseif view == "PLAYLIST" then
        -- Sketch-Vorgabe: [BACK] Button, um zur Playlist Liste zu kommen
        term.setCursorPos(1, 1)
        term.setBackgroundColor(colors.blue)
        term.setTextColor(colors.white)
        term.write(" [< BACK] ")
        -- Playlist Name im Header
        term.setTextColor(colors.yellow)
        term.write(" PL: " .. string.sub(selectedPlaylist, 1, w - 12))
        
        -- Songs in der Liste (Cyan idle, Lime playing)
        for i, item in ipairs(filteredSongs) do
            if i > (listEndLine - 3 + 1) then break end
            term.setCursorPos(2, 2 + i)
            
            -- LOGIK FÜR DAS GRÜNE LICHT (Sketch-Vorgabe)
            -- Es leuchtet nur dann grün, wenn wir die Playlist betrachten,
            -- aus der das aktuelle Lied stammt.
            local turnLime = false
            if isPlaying and allSongs[currentIdx] and playedPlaylistName == selectedPlaylist then
                if item.url == allSongs[currentIdx].url then
                    turnLime = true
                end
            end
            
            if turnLime then
                term.setBackgroundColor(colors.lime) -- Grün für "Active"
                term.setTextColor(colors.black)
                term.write(" [ > " .. i .. ". " .. string.sub(item.name, 1, w - 10) .. " ] ")
            else
                term.setBackgroundColor(colors.cyan) -- Blau für "Rest bleibt blau" (Cyan)
                term.setTextColor(colors.black)
                term.write(" [   " .. i .. ". " .. string.sub(item.name, 1, w - 10) .. " ] ")
            end
        end
    end

    -- ==========================================
    -- VISUELLE LÜCKE LAUT SKIZZE (Dots)
    -- ==========================================
    term.setBackgroundColor(colors.red)
    term.setCursorPos(2, h-3)
    term.clearLine()
    term.write(" . . . . . ")

    -- ==========================================
    -- ZONE 4: LOWER CONTROL AREA (YELLOW/LIME, h-2 to h)
    -- ==========================================
    -- Sketch: Fake Progress Bar auf Line h-2 (oder h-3)
    local pbLine = h - 2
    term.setCursorPos(1, pbLine)
    term.setBackgroundColor(colors.lime) -- "Gelb" laut Sketch (Lime ist besser)
    term.setTextColor(colors.black)
    term.clearLine()
    
    -- Sketch: "<song Progress bar>". Da CC RAW nicht spulen kann, ist es ein Fake Balken.
    -- Wir malen einen Balken über die Breite.
    term.write(" [ --- RAW STREAM --- ] ")

    -- Sketch: Controls Line h-1
    local ctrlLine = h - 1
    term.setCursorPos(1, ctrlLine)
    term.setBackgroundColor(colors.lime)
    term.setTextColor(colors.black)
    term.clearLine()
    
    local pIcon = isPlaying and "[||]" or "[ >]"
    -- Sketch-Tasten: [-] [|<] [||>] [>|] [+]
    term.write("  [ - ]   [|<]     " .. pIcon .. "     [>|]   [ + ]")

    -- Sketch: Infobar Line h
    term.setCursorPos(1, h)
    term.setBackgroundColor(colors.lime)
    term.clearLine()
    
    local currentName = (allSongs[currentIdx] and allSongs[currentIdx].name) or "IDLE"
    term.write(" NOW PLAYING: " .. string.sub(currentName, 1, w - 16))
end

-- ==========================================
-- AUDIO STREAMING ENGINE
-- ==========================================
local function playSong(url)
    if not speaker then return end
    local res = http.get({ url = url, binary = true })
    if not res then return end
    
    isPlaying = true
    -- UI Update für NOW PLAYING Status
    term.redirect(term.native()) -- Verhindert, dass Audio Loop UI zerschießt
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
    
    -- Auto-Play Nächstes Lied
    if isPlaying then 
        currentIdx = currentIdx + 1
        if currentIdx > #allSongs then currentIdx = 1 end
        os.queueEvent("start_music")
    end
end

-- ==========================================
-- INITIAL LOAD & APP START
-- ==========================================
playlists = getList(masterURL)
allSongs = {} -- Keine Lieder beim Start
drawUI()

-- ==========================================
-- MAIN EVENT LOOPS (PARALLEL)
-- ==========================================
parallel.waitForAny(
    function() -- Eingabe Loop (Suche, Backspace, Maus-Clicks)
        while true do
            local event, p1, p2, p3 = os.pullEvent()
            
            -- WENN MAN TIPPt (Suche in Songs)
            if event == "char" and view == "PLAYLIST" then
                searchQuery = searchQuery .. p1
                -- Filter anwenden
                filteredSongs = {}
                for _, s in ipairs(currentSongs) do 
                    if s.name:lower():find(searchQuery:lower()) then table.insert(filteredSongs, s) end 
                end
                drawUI()
            
            -- LÖSCHEN TASTE (Backspace)
            elseif event == "key" and p1 == keys.backspace and view == "PLAYLIST" and #searchQuery > 0 then
                searchQuery = searchQuery:sub(1, -2)
                -- Filter updaten
                filteredSongs = {}
                for _, s in ipairs(currentSongs) do 
                    if s.name:lower():find(searchQuery:lower()) then table.insert(filteredSongs, s) end 
                end
                drawUI()
                
            -- MAUS KLICKS (Zones berechnen nach Sketch)
            elseif event == "mouse_click" then
                local x, y = p2, p3
                
                -- TOP BAR Zone (Refresh)
                if y == 1 then
                    if x > w - 10 then
                        -- Refresh Button (Cyan)
                        playlists = getList(masterURL)
                    elseif x <= 8 and view == "PLAYLIST" then
                        -- [< BACK] Button
                        view = "MASTER"
                    end
                
                -- LIST AREA Zones (Roter Bereich, y 3 bis h-4)
                elseif y >= 3 and y <= h - 4 then
                    local idx = y - 2
                    
                    if view == "MASTER" then
                        if playlists[idx] then
                            -- Playlist laden
                            selectedPlaylist = playlists[idx]
                            currentSongs = loadPlaylist(selectedPlaylist)
                            filteredSongs = currentSongs
                            searchQuery = "" -- Suche leeren
                            view = "PLAYLIST"
                        end
                    elseif view == "PLAYLIST" then
                        -- Song in gefilterter Liste anklicken
                        if filteredSongs[idx] then
                            -- Sucht das Lied in der "echten" Queue
                            for i, s in ipairs(currentSongs) do
                                if s.url == filteredSongs[idx].url then
                                    currentIdx = i
                                    allSongs = currentSongs -- Lade PL in die Queue
                                    break
                                end
                            end
                            isPlaying = false
                            playedPlaylistName = selectedPlaylist -- TRACK ACTIVE PL
                            os.queueEvent("start_music")
                        end
                    end
                    
                -- LOWER CONTROL AREA Zones (Yellow/Lime, y h-1 bis h)
                elseif y == h - 1 then
                    -- Sketch: [-] [|<] [||>] [>|] [+]
                    -- Zones auf Basis CC Grid 51 width (ungefähr)
                    if x >= 2 and x <= 6 then           -- VOL DOWN
                        vol = vol - 0.1
                        if vol < 0.1 then vol = 1.0 end
                    elseif x >= 8 and x <= 12 then      -- [|<] (Vorheriges Lied)
                        if #allSongs > 0 then
                            currentIdx = currentIdx - 1
                            if currentIdx < 1 then currentIdx = #allSongs end
                            isPlaying = false
                            os.queueEvent("start_music")
                        end
                    elseif x >= 15 and x <= 25 then     -- [||>] (Play/Pause)
                        isPlaying = not isPlaying
                        if isPlaying and #allSongs > 0 then
                            os.queueEvent("start_music")
                        end
                    elseif x >= 28 and x <= 32 then     -- [>|] (Nächstes Lied)
                        if #allSongs > 0 then
                            currentIdx = currentIdx + 1
                            if currentIdx > #allSongs then currentIdx = 1 end
                            isPlaying = false
                            os.queueEvent("start_music")
                        end
                    elseif x >= 34 and x <= 38 then     -- VOL UP
                        vol = vol + 0.1
                        if vol > 1.0 then vol = 0.1 end
                    end
                end
                drawUI()
            end
        end
    end,
    -- Audio Thread
    function()
        while true do
            os.pullEvent("start_music")
            if allSongs[currentIdx] then playSong(allSongs[currentIdx].url) end
        end
    end,
    -- Auto-Refresh (Alle 30 Sekunden im Hintergrund)
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
                    -- Filter updaten falls nötig
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