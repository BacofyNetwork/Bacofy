-- ==========================================
-- PROGRAM: BACOFY PRO (Cyber-Red Edition)
-- ULTIMATE PROGRESS BAR UPDATE
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

-- AUDIO ENGINE STATE
local isPlaying = false
local isPaused = false 
local forceSkip = false 

-- SEEKING & PROGRESS STATE
local currentBytes = 0
local totalBytes = 0
local seekTargetRatio = nil

-- TRACKING
local allSongs = {} 
local currentIdx = 1 
local playedPlaylistName = "" 

-- SCROLLING
local scrollOffset = 0

local w, h = term.getSize()
local cx = math.floor(w / 2) 

-- Helper: Get List
local function getList(url)
    local res = http.get(url .. "?t=" .. os.epoch("utc"))
    if not res then return {} end
    local t = {}
    for line in res.readAll():gmatch("[^\r\n]+") do table.insert(t, line) end
    res.close()
    return t
end

-- Helper: Load Playlist
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
-- UI DRAW ENGINE (Cyber-Red Aesthetic)
-- ==========================================
local function drawUI()
    term.setBackgroundColor(colors.black)
    term.clear()
    
    local cHead = colors.red
    local cHeadText = colors.white
    local cListBg = colors.black
    local cItemBg = colors.gray
    local cActiveItemBg = colors.red 
    local cActiveItemText = colors.white
    local cControlBg = colors.gray 

    -- HEADER (Line 1)
    term.setCursorPos(1, 1)
    term.setBackgroundColor(cHead)
    term.setTextColor(cHeadText)
    term.clearLine()
    term.write(" BACOFY PRO 2.0")
    
    local timeStr = textutils.formatTime(os.time(), true)
    term.setCursorPos(w - #timeStr, 1)
    term.write(timeStr)
    
    -- SUBHEADER / SEARCH (Line 2)
    term.setCursorPos(1, 2)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clearLine()
    
    if view == "MASTER" then
        term.write(" Playlists")
        term.setCursorPos(w - 7, 2)
        term.setTextColor(colors.lightGray)
        term.write("[R] REF") 
    elseif view == "PLAYLIST" then
        term.write(" (<-) Search: ")
        term.setTextColor(colors.white)
        term.write(string.sub(searchQuery .. "_", 1, w - 15)) 
    end
    
    -- LIST AREA (Line 3 to h-4) -- PLATZ GEMACHT FÜR DIE PROGRESS BAR!
    local listStartY = 3
    local listEndY = h - 4
    local maxDisplay = listEndY - listStartY + 1
    
    for y = listStartY, listEndY do
        term.setCursorPos(1, y)
        term.setBackgroundColor(cListBg) 
        term.clearLine()
    end
    
    local listToDraw = (view == "MASTER") and playlists or filteredSongs
    
    if scrollOffset > #listToDraw - maxDisplay then
        scrollOffset = math.max(0, #listToDraw - maxDisplay)
    end
    if scrollOffset < 0 then scrollOffset = 0 end
    
    for i = 1, maxDisplay do
        local idx = i + scrollOffset
        local item = listToDraw[idx]
        
        if item then
            term.setCursorPos(1, listStartY + i - 1)
            local isActive = false
            local displayText = ""
            
            if view == "MASTER" then
                displayText = "  [ Playlist: " .. item .. " ] "
            else
                displayText = "  [   " .. i .. ". " .. item.name .. " ] "
                if isPlaying and allSongs[currentIdx] and playedPlaylistName == selectedPlaylist then
                    if item.url == allSongs[currentIdx].url then 
                        isActive = true 
                        displayText = "  [ > " .. i .. ". " .. item.name .. " ] "
                    end
                end
            end
            
            if isActive then
                term.setBackgroundColor(cActiveItemBg)
                term.setTextColor(cActiveItemText)
            else
                term.setBackgroundColor(cItemBg) 
                term.setTextColor(colors.white) 
            end
            
            term.clearLine()
            term.write(string.sub(displayText, 1, w))
        end
    end

    -- CONTROLS AREA BACKGROUND
    term.setBackgroundColor(cControlBg) 
    term.setTextColor(colors.white)
    
    local cButtonAccent = colors.red

    -- PROGRESS BAR (Line h-3)
    term.setCursorPos(1, h - 3)
    term.clearLine()
    local barW = 24
    local barStartX = cx - math.floor(barW / 2)
    
    term.setCursorPos(barStartX, h - 3)
    if totalBytes > 0 and (isPlaying or isPaused) then
        local progress = currentBytes / totalBytes
        if progress > 1 then progress = 1 end
        if progress < 0 then progress = 0 end
        
        local filled = math.floor(progress * barW)
        local empty = barW - filled
        
        term.setTextColor(colors.red)
        term.write(string.rep("=", filled))
        term.setTextColor(colors.black)
        term.write(string.rep("-", empty))
    else
        term.setTextColor(colors.black)
        term.write(string.rep("-", barW))
    end

    -- MEDIA BUTTONS (Line h-2)
    term.setCursorPos(1, h - 2)
    term.clearLine()
    local playIcon = (isPlaying and not isPaused) and "||" or "> "
    term.setCursorPos(cx - 9, h - 2)
    term.setTextColor(cButtonAccent)
    term.write("<<")
    term.setCursorPos(cx - 4, h - 2)
    term.setTextColor(colors.white)
    term.write(playIcon)
    term.setCursorPos(cx + 3, h - 2)
    term.setTextColor(cButtonAccent)
    term.write("[]")
    term.setCursorPos(cx + 10, h - 2)
    term.write(">>")
    
    -- VOLUME CONTROLS (Line h-1)
    term.setCursorPos(1, h - 1)
    term.clearLine()
    
    local volStr = tostring(math.floor(vol * 100))
    if #volStr == 1 then volStr = "0" .. volStr end
    if volStr == "100" then volStr = "MAX" end
    
    local vText = "[-]    VOL: " .. volStr .. "    [+]"
    local vStartX = cx - math.floor(#vText / 2)
    
    term.setCursorPos(vStartX, h - 1)
    term.setTextColor(cButtonAccent)
    term.write("[-]")
    
    term.setCursorPos(vStartX + 7, h - 1)
    term.setTextColor(colors.white)
    term.write("VOL: ")
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.write(volStr)
    
    term.setBackgroundColor(cControlBg) 
    term.setTextColor(cButtonAccent)
    term.setCursorPos(vStartX + #vText - 3, h - 1)
    term.write("[+]")

    -- STATUS FOOTER (Line h)
    term.setCursorPos(1, h)
    term.setBackgroundColor(cHead)
    term.setTextColor(cHeadText)
    term.clearLine()
    
    if isPlaying then
        local currentName = (allSongs[currentIdx] and allSongs[currentIdx].name) or "Unknown"
        if isPaused then
            term.write(" PAUSED:  " .. string.sub(currentName, 1, w - 11))
        else
            term.write(" PLAYING: " .. string.sub(currentName, 1, w - 11))
        end
    else
        term.write(" STOPPED")
    end
end

-- ==========================================
-- AUDIO STREAMING ENGINE (MIT ECHTEM SEEKING!)
-- ==========================================
local function playSong(url)
    if not speaker then return end
    
    -- HTTP Range Request Header bauen, falls wir springen
    local reqHeaders = {}
    if seekTargetRatio and totalBytes > 0 then
        currentBytes = math.floor(totalBytes * seekTargetRatio)
        reqHeaders["Range"] = "bytes=" .. currentBytes .. "-"
        seekTargetRatio = nil
    else
        currentBytes = 0
        totalBytes = 0
    end
    
    local res = http.get({ url = url, binary = true, headers = reqHeaders })
    if not res then 
        if isPlaying then
            currentIdx = currentIdx + 1
            if currentIdx > #allSongs then currentIdx = 1 end
        end
        return 
    end
    
    -- Hole Dateigröße für die Progress Bar
    local respHeaders = res.getResponseHeaders and res.getResponseHeaders() or {}
    if currentBytes == 0 then
        totalBytes = tonumber(respHeaders["Content-Length"]) or tonumber(respHeaders["content-length"]) or 0
    end
    
    term.redirect(term.native()) 
    drawUI()
    
    local eof = false
    local pendingBuffer = nil 
    local chunksRead = 0
    
    while isPlaying and not forceSkip and not seekTargetRatio do
        if isPaused then
            os.pullEvent()
        else
            local buffer = pendingBuffer
            if not buffer then
                local chunk = res.read(16384) 
                if chunk == nil or chunk == "" then 
                    eof = true
                    break 
                end
                
                buffer = {}
                if type(chunk) == "string" then
                    currentBytes = currentBytes + #chunk
                    for i = 1, #chunk do
                        local val = string.byte(chunk, i)
                        if val > 127 then val = val - 256 end
                        table.insert(buffer, val)
                    end
                elseif type(chunk) == "number" then
                    currentBytes = currentBytes + 1
                    local val = chunk
                    if val > 127 then val = val - 256 end
                    table.insert(buffer, val)
                    for i = 2, 4096 do
                        local b = res.read()
                        if not b then break end
                        currentBytes = currentBytes + 1
                        if b > 127 then b = b - 256 end
                        table.insert(buffer, b)
                    end
                end
                
                -- Live Update der Progress Bar (ca. jede Sekunde)
                chunksRead = chunksRead + 1
                if chunksRead % 3 == 0 then
                    drawUI() 
                end
            end
            
            local queued = false
            while isPlaying and not forceSkip and not isPaused and not seekTargetRatio and not queued do
                if speaker.playAudio(buffer, vol) then
                    queued = true
                    pendingBuffer = nil
                else
                    os.pullEvent()
                end
            end
            
            if not queued then
                pendingBuffer = buffer
            end
        end
    end
    res.close()
    
    if forceSkip then
        forceSkip = false
    elseif eof and isPlaying and not seekTargetRatio then 
        currentIdx = currentIdx + 1
        if currentIdx > #allSongs then currentIdx = 1 end
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
    function() -- Input Loop
        while true do
            local event, p1, p2, p3 = os.pullEvent()
            
            if event == "mouse_scroll" then
                scrollOffset = scrollOffset + p1
                drawUI()
                
            elseif event == "char" and view == "PLAYLIST" then
                searchQuery = searchQuery .. p1
                scrollOffset = 0
                filteredSongs = {}
                for _, s in ipairs(currentSongs) do 
                    if s.name:lower():find(searchQuery:lower()) then table.insert(filteredSongs, s) end 
                end
                drawUI()
            
            elseif event == "key" and p1 == keys.backspace and view == "PLAYLIST" and #searchQuery > 0 then
                searchQuery = searchQuery:sub(1, -2)
                scrollOffset = 0
                filteredSongs = {}
                for _, s in ipairs(currentSongs) do 
                    if s.name:lower():find(searchQuery:lower()) then table.insert(filteredSongs, s) end 
                end
                drawUI()
                
            elseif event == "mouse_click" then
                local x, y = p2, p3
                
                if y == 2 then
                    if view == "MASTER" and x > w - 8 then
                        playlists = getList(masterURL) 
                    elseif view == "PLAYLIST" and x <= 9 then
                        view = "MASTER" 
                        scrollOffset = 0
                    end
                
                elseif y >= 3 and y <= h - 4 then
                    local displayIdx = y - 2
                    local actualIdx = displayIdx + scrollOffset
                    
                    if view == "MASTER" then
                        if playlists[actualIdx] then
                            selectedPlaylist = playlists[actualIdx]
                            currentSongs = loadPlaylist(selectedPlaylist)
                            filteredSongs = currentSongs
                            searchQuery = "" 
                            scrollOffset = 0
                            view = "PLAYLIST"
                        end
                    elseif view == "PLAYLIST" then
                        if filteredSongs[actualIdx] then
                            for i, s in ipairs(currentSongs) do
                                if s.url == filteredSongs[actualIdx].url then
                                    currentIdx = i
                                    allSongs = currentSongs 
                                    break
                                end
                            end
                            playedPlaylistName = selectedPlaylist 
                            isPaused = false
                            if isPlaying then forceSkip = true else isPlaying = true end
                            seekTargetRatio = nil 
                            os.queueEvent("audio_update") 
                            drawUI()
                        end
                    end
                    
                -- KLICKBARE PROGRESS BAR (Line h-3)
                elseif y == h - 3 then
                    local barW = 24
                    local barStartX = cx - math.floor(barW / 2)
                    if x >= barStartX and x < barStartX + barW then
                        if totalBytes > 0 and (isPlaying or isPaused) then
                            seekTargetRatio = (x - barStartX) / barW
                            isPaused = false 
                            os.queueEvent("audio_update")
                            drawUI()
                        end
                    end
                    
                -- MEDIA CONTROLS (Line h-2)
                elseif y == h - 2 then
                    if x >= cx - 11 and x <= cx - 7 then       -- [<<] Prev
                        if #allSongs > 0 then
                            currentIdx = currentIdx - 1
                            if currentIdx < 1 then currentIdx = #allSongs end
                            isPaused = false
                            seekTargetRatio = nil
                            if isPlaying then forceSkip = true else isPlaying = true end
                            os.queueEvent("audio_update")
                            drawUI()
                        end
                    elseif x >= cx - 4 and x <= cx then        -- [> / ||] Play/Pause
                        if #allSongs > 0 then
                            if not isPlaying then
                                isPlaying = true
                                isPaused = false
                            else
                                isPaused = not isPaused
                            end
                            os.queueEvent("audio_update")
                            drawUI() 
                        end
                    elseif x >= cx + 3 and x <= cx + 7 then    -- [[]] Stop
                        isPlaying = false
                        isPaused = false
                        seekTargetRatio = nil
                        currentBytes = 0
                        os.queueEvent("audio_update")
                        drawUI()
                    elseif x >= cx + 10 and x <= cx + 14 then  -- [>>] Next
                        if #allSongs > 0 then
                            currentIdx = currentIdx + 1
                            if currentIdx > #allSongs then currentIdx = 1 end
                            isPaused = false
                            seekTargetRatio = nil
                            if isPlaying then forceSkip = true else isPlaying = true end
                            os.queueEvent("audio_update")
                            drawUI()
                        end
                    end
                    
                -- VOLUME CONTROLS (Line h-1)
                elseif y == h - 1 then
                    local volStr = tostring(math.floor(vol * 100))
                    if #volStr == 1 then volStr = "0" .. volStr end
                    if volStr == "100" then volStr = "MAX" end
                    local vTextLen = #("[-]    VOL: " .. volStr .. "    [+]")
                    local btnStart = cx - math.floor(vTextLen / 2)

                    if x >= btnStart - 1 and x <= btnStart + 3 then    
                        vol = vol - 0.1
                        if vol < 0.0 then vol = 0.0 end
                    elseif x >= btnStart + vTextLen - 4 and x <= btnStart + vTextLen + 1 then 
                        vol = vol + 0.1
                        if vol > 1.0 then vol = 1.0 end
                    end
                    drawUI()
                end
            end
        end
    end,
    function()
        while true do
            if isPlaying and #allSongs > 0 and allSongs[currentIdx] then
                playSong(allSongs[currentIdx].url)
            else
                os.sleep(0.1)
            end
        end
    end,
    function()
        while true do
            os.sleep(30)
            if view == "MASTER" then
                playlists = getList(masterURL)
            else
                local oldLen = #currentSongs
                currentSongs = loadPlaylist(selectedPlaylist)
                if #currentSongs > oldLen then
                    filteredSongs = {}
                    for _, s in ipairs(currentSongs) do 
                        if s.name:lower():find(searchQuery:lower()) then table.insert(filteredSongs, s) end 
                    end
                end
            end
            drawUI()
        end
    end
)