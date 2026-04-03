-- ==========================================
-- PROGRAM: BACOFY PRO (The Modern Palette Fix)
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
local viewedPlaylistSongs = {} 
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
-- NEUES OPTIMIERTES DESIGN (SKETCH & CONTRAST FIX)
-- ==========================================
local function drawUI()
    -- Reset Terminal
    term.setBackgroundColor(colors.black)
    term.clear()
    
    -- ==========================================
    -- ZONE 1: TOP HEADER (BLACK, Line 1)
    -- ==========================================
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.black) -- Schwarz für modernsten Look
    term.clearLine()
    term.setTextColor(colors.white)
    
    local title = " Bacofy Pro"
    term.write(title)
    
    term.setCursorPos(w - #("Refresh ") + 1, 1)
    term.setTextColor(colors.cyan) -- Blau für Refresh
    term.write("[R] REF")
    
    -- ==========================================
    -- ZONE 2: SEARCHBAR (BLACK, Line 2)
    -- ==========================================
    term.setCursorPos(1, 2)
    term.clearLine()
    term.setTextColor(colors.lightGray)
    term.write(" Suche: ")
    term.setTextColor(colors.white)
    term.write(searchQuery .. "_")
    
    -- ==========================================
    -- ZONE 3: LIST AREA (LIME, Lines 3 to h-4)
    -- ==========================================
    -- Wir berechnen die Höhe des Listen-Bereichs.
    -- Er endet über dem Fake Progress Bar (h-3) und Controls (h-2 bis h).
    local listEndLine = h - 4
    for y = 3, listEndLine do
        term.setCursorPos(1, y)
        term.setBackgroundColor(colors.lime) -- Neue Palette: Grüner (Lime) Listenhintergrund
        term.clearLine()
    end
    
    -- Handle View-spezifischen Listen-Inhalt
    if view == "MASTER" then
        -- Sketch-Vorgabe: [BACK] Button, um zur Playlist Liste zu kommen
        term.setCursorPos(1, 1)
        term.setBackgroundColor(colors.black)
        term.clearLine()
        term.setTextColor(colors.white)
        term.write(" Bacofy Pro") -- Titel
        
        term.setCursorPos(w - #("Refresh ") + 1, 1)
        term.setTextColor(colors.cyan) -- Blau für Refresh
        term.write("[R] REF")

        -- Playlist Liste
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.lime) -- Sicherstellen, dass Bg stimmt

        for i, item in ipairs(playlists) do
            if i > (listEndLine - 3 + 1) then break end
            term.setCursorPos(2, 2 + i)
            
            -- Sketch-Look: Ein Balken. Idle Songs sind Blau (Cyan)
            -- Für maximale Lesbarkeit auf Lime machen wir einen Cyan-Balken mit weißem Text.
            term.setBackgroundColor(colors.cyan) 
            term.setTextColor(colors.white)
            term.write(" [ Playlist: " .. string.sub(item, 1, w - 16) .. " ] ")
        end
        
    elseif view == "PLAYLIST" then
        -- Header updaten für Playlist Ansicht
        term.setCursorPos(1, 1)
        term.setBackgroundColor(colors.black)
        term.clearLine()
        
        -- Sketch-Vorgabe: [BACK] Button
        term.setCursorPos(1, 1)
        term.setTextColor(colors.cyan) -- Blau für Back Button
        term.write(" [< BACK]")
        
        -- Playlist Name im Header
        term.setCursorPos(10, 1)
        term.setTextColor(colors.yellow)
        term.write(" PL: " .. string.sub(selectedPlaylist, 1, w - 21))

        term.setCursorPos(w - #("Refresh ") + 1, 1)
        term.setTextColor(colors.cyan) -- Blau für Refresh
        term.write("[R] REF")

        -- Songs in der Liste (Cyan idle, Lime/Yellow playing)
        for i, item in ipairs(filteredSongs) do
            if i > (listEndLine - 3 + 1) then break end
            term.setCursorPos(2, 2 + i)
            
            -- LOGIK FÜR DAS AKTIVE LIED (Grünes Licht, bzw. Kontrast-Fix)
            local turnYellow = false
            if isPlaying and allSongs[currentIdx] and playedPlaylistName == selectedPlaylist then
                if item.url == allSongs[currentIdx].url then
                    turnYellow = true
                end
            end
            
            if turnYellow then
                -- Sketch-Vorgabe: Das aktive Lied ist anders.
                -- Für maximale Lesbarkeit auf Lime: Ein gelber Balken mit schwarzem Text. Das popt!
                term.setBackgroundColor(colors.yellow) 
                term.setTextColor(colors.black)
                term.write(" [ > " .. i .. ". " .. string.sub(item.name, 1, w - 10) .. " ] ")
            else
                -- Sketch-Vorgabe: Rest bleibt blau (Cyan).
                -- Cyan-Balken mit weißem Text für Lesbarkeit auf Lime.
                term.setBackgroundColor(colors.cyan) 
                term.setTextColor(colors.white)
                term.write(" [   " .. i .. ". " .. string.sub(item.name, 1, w - 10) .. " ] ")
            end
        end
    end

    -- ==========================================
    -- VISUELLE LÜCKE LAUT SKIZZE (Dots)
    -- ==========================================
    -- Wir bleiben auf dem Lime Hintergrund
    term.setBackgroundColor(colors.lime)
    term.setTextColor(colors.black) -- Schwarze Dots für Lesbarkeit
    term.setCursorPos(2, h-3)
    term.clearLine()
    term.write(" . . . . . ")

    -- ==========================================
    -- ZONE 4: LOWER CONTROL AREA (RED, h-2 to h)
    -- ==========================================
    -- Neue Palette: Roter Hintergrund für den gesamten Steuerbalken.
    -- Text-Kontrast: Für maximale Lesbarkeit auf Rot, verwenden wir Weißen Text.
    local textColorsOnRed = colors.white
    local textColorsOnRedButtons = colors.lightGray -- Buttons etwas anders für visibility

    -- Fake Progress Bar auf Line h-2 (oder h-3)
    local pbLine = h - 2
    term.setCursorPos(1, pbLine)
    term.setBackgroundColor(colors.red) -- Neue Palette: Roter Control-Balken
    term.setTextColor(textColorsOnRed) -- Weißer Text
    term.clearLine()
    
    -- Sketch: "<song Progress bar>". Da CC RAW nicht spulen kann, ist es ein Fake Balken.
    term.write(" [ --- RAW STREAM --- ] ")

    -- Sketch: Controls Line h-1
    local ctrlLine = h - 1
    term.setCursorPos(1, ctrlLine)
    term.setBackgroundColor(colors.red) -- Roter Bg
    term.setTextColor(textColorsOnRedButtons) -- Weißer/Grauer Text für Tasten
    term.clearLine()
    
    local pIcon = isPlaying and "[||]" or "[ >]"
    -- Sketch-Tasten: [-] [|<] [||>] [>|] [+]
    -- Visuell popen die Tasten durch die eckigen Klammern.
    term.write("  [ - ]   [|<]     " .. pIcon .. "     [>|]   [ + ]")

    -- Sketch: Infobar Line h
    term.setCursorPos(1, h)
    term.setBackgroundColor(colors.red) -- Roter Bg
    term.setTextColor(textColorsOnRed) -- Weißer Text
    term.clearLine()
    
    local currentName = (allSongs[currentIdx] and allSongs[currentIdx].name) or "IDLE"
    term.write(" LÄUFT: " .. string.sub(currentName, 1, w - 9))
end

-- ==========================================
-- AUDIO STREAMING ENGINE (UNCHANGED)
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
                
                -- TOP BAR Zone
                if y == 1 then
                    if x > w - 10 then
                        -- Refresh Button [R] REF (Cyan)
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
                    
                -- LOWER CONTROL AREA Zones (Red, y h-1 bis h)
                elseif y == h - 1 then
                    -- Sketch: [-] [|<] [||>] [>|] [+]
                    -- Die Zonen sind jetzt besser lesbar durch die eckigen Klammern.
                    -- Wir optimieren die Click-Zonen für bessere Clickability.
                    
                    -- VOL DOWN [-] (zones 1 to 7)
                    if x >= 1 and x <= 7 then           
                        vol = vol - 0.1
                        if vol < 0.1 then vol = 1.0 end
                        
                    -- PREVIOUS [|<] (zones 8 to 14)
                    elseif x >= 8 and x <= 14 then      
                        if #allSongs > 0 then
                            currentIdx = currentIdx - 1
                            if currentIdx < 1 then currentIdx = #allSongs end
                            isPlaying = false
                            os.queueEvent("start_music")
                        end
                        
                    -- PLAY/PAUSE [||>] (zones 16 to 26)
                    elseif x >= 16 and x <= 26 then     
                        isPlaying = not isPlaying
                        if isPlaying and #allSongs > 0 then
                            os.queueEvent("start_music")
                        end
                        
                    -- NEXT [>|] (zones 28 to 34)
                    elseif x >= 28 and x <= 34 then     
                        if #allSongs > 0 then
                            currentIdx = currentIdx + 1
                            if currentIdx > #allSongs then currentIdx = 1 end
                            isPlaying = false
                            os.queueEvent("start_music")
                        end
                        
                    -- VOL UP [+] (zones 36 to 42)
                    elseif x >= 36 and x <= 42 then     
                        vol = vol + 0.1
                        if vol > 1.0 then vol = 0.1 end
                    end
                end
                drawUI()
            end
        end
    end,
    -- Audio Thread (UNCHANGED)
    function()
        while true do
            os.pullEvent("start_music")
            if allSongs[currentIdx] then playSong(allSongs[currentIdx].url) end
        end
    end,
    -- Auto-Refresh (Alle 30 Sekunden im Hintergrund, UNCHANGED)
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