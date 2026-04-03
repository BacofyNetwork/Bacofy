-- ==========================================
-- PROGRAM: BACOFY PRO (Modern UI Edition)
-- ==========================================

local speaker = peripheral.find("speaker")
local baseURL = "https://raw.githubusercontent.com/BacofyNetwork/Bacofy/main/Music/"
local masterURL = baseURL .. "master.txt"

local playlists = {}
local currentSongs = {}
local filteredSongs = {}
local view = "MASTER"
local selectedPlaylist = ""
local searchQuery = ""
local vol = 0.5
local currentIdx = 1
local isPlaying = false
local w, h = term.getSize()

local function getList(url)
    local res = http.get(url .. "?t=" .. os.epoch("utc"))
    if not res then return {} end
    local t = {}
    for line in res.readAll():gmatch("[^\r\n]+") do table.insert(t, line) end
    res.close()
    return t
end

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
-- NEUES DESIGN (MODERN PLAYER)
-- ==========================================
local function drawUI()
    term.setBackgroundColor(colors.black)
    term.clear()
    
    if view == "MASTER" then
        -- Master Header
        term.setCursorPos(1, 1)
        term.setBackgroundColor(colors.blue)
        term.clearLine()
        term.setTextColor(colors.white)
        term.write(" BACOFY PLAYLISTS")
        
        -- Playlist Liste
        term.setBackgroundColor(colors.black)
        for i, item in ipairs(playlists) do
            if i > h - 2 then break end
            term.setCursorPos(2, 1 + i)
            term.setTextColor(colors.white)
            term.write(i .. ". " .. item)
        end
        
        -- Master Footer
        term.setCursorPos(1, h)
        term.setBackgroundColor(colors.gray)
        term.clearLine()
        term.setTextColor(colors.white)
        term.write(" [R] REFRESH PLAYLISTS")
        
    elseif view == "PLAYLIST" then
        -- Zeile 1: Header & Back Button
        term.setCursorPos(1, 1)
        term.setBackgroundColor(colors.blue)
        term.clearLine()
        term.setTextColor(colors.yellow)
        term.write("[< BACK]")
        term.setTextColor(colors.white)
        term.write(" | PL: " .. string.sub(selectedPlaylist, 1, w - 12))
        
        -- Zeile 2: Suchleiste
        term.setCursorPos(1, 2)
        term.setBackgroundColor(colors.black)
        term.clearLine()
        term.setTextColor(colors.lightGray)
        term.write(" Suche: ")
        term.setTextColor(colors.white)
        term.write(searchQuery .. "_")
        
        -- Zeile 3 bis h-2: Die Lieder
        term.setBackgroundColor(colors.black)
        if #filteredSongs == 0 then
            term.setCursorPos(2, 4)
            term.setTextColor(colors.red)
            term.write("Keine Lieder gefunden.")
        else
            for i, item in ipairs(filteredSongs) do
                if i > h - 4 then break end
                term.setCursorPos(2, 2 + i)
                
                local isCurrent = (currentSongs[currentIdx] and item.url == currentSongs[currentIdx].url and isPlaying)
                if isCurrent then
                    term.setTextColor(colors.lime)
                    term.write("> " .. item.name)
                else
                    term.setTextColor(colors.white)
                    term.write(i .. ". " .. item.name)
                end
            end
        end
        
        -- Zeile h-1: NOW PLAYING Balken
        term.setCursorPos(1, h - 1)
        term.setBackgroundColor(colors.gray)
        term.clearLine()
        term.setTextColor(colors.cyan)
        local currentName = (currentSongs[currentIdx] and currentSongs[currentIdx].name) or "Nichts"
        term.write(" LÄUFT: " .. string.sub(currentName, 1, w - 9))
        
        -- Zeile h: Media Controls
        term.setCursorPos(1, h)
        term.setBackgroundColor(colors.cyan)
        term.clearLine()
        term.setTextColor(colors.black)
        local pIcon = isPlaying and "[||]" or "[ >]"
        term.write(" [|<] " .. pIcon .. " [>|] | VOL: " .. math.floor(vol * 100) .. "%")
    end
end

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
    
    if isPlaying then 
        currentIdx = currentIdx + 1
        if currentIdx > #currentSongs then currentIdx = 1 end
        os.queueEvent("start_music")
    end
end

playlists = getList(masterURL)
drawUI()

parallel.waitForAny(
    function()
        while true do
            local ev, p1, p2, p3 = os.pullEvent()
            
            if ev == "char" and view == "PLAYLIST" then
                searchQuery = searchQuery .. p1
                filteredSongs = {}
                for _, s in ipairs(currentSongs) do 
                    if s.name:lower():find(searchQuery:lower()) then table.insert(filteredSongs, s) end 
                end
                drawUI()
                
            elseif ev == "key" and p1 == keys.backspace and view == "PLAYLIST" and #searchQuery > 0 then
                searchQuery = searchQuery:sub(1, -2)
                filteredSongs = {}
                for _, s in ipairs(currentSongs) do 
                    if s.name:lower():find(searchQuery:lower()) then table.insert(filteredSongs, s) end 
                end
                drawUI()
                
            elseif ev == "mouse_click" then
                local x, y = p2, p3
                
                if view == "MASTER" then
                    if y >= 2 and y < h then
                        local idx = y - 1
                        if playlists[idx] then
                            selectedPlaylist = playlists[idx]
                            currentSongs = loadPlaylist(selectedPlaylist)
                            filteredSongs = {}
                            for i, s in ipairs(currentSongs) do table.insert(filteredSongs, s) end
                            searchQuery = ""
                            view = "PLAYLIST"
                        end
                    elseif y == h then
                        playlists = getList(masterURL)
                    end
                    
                elseif view == "PLAYLIST" then
                    if y == 1 and x <= 8 then
                        -- BACK Button
                        view = "MASTER"
                    elseif y >= 3 and y <= h - 2 then
                        -- Song Click
                        local idx = y - 2
                        if filteredSongs[idx] then
                            for i, s in ipairs(currentSongs) do 
                                if s.url == filteredSongs[idx].url then 
                                    currentIdx = i 
                                    break 
                                end 
                            end
                            isPlaying = false 
                            os.queueEvent("start_music")
                        end
                    elseif y == h then
                        -- Controls
                        if x >= 2 and x <= 5 then           -- [|<]
                            if #currentSongs > 0 then
                                currentIdx = currentIdx - 1
                                if currentIdx < 1 then currentIdx = #currentSongs end
                                isPlaying = false
                                os.queueEvent("start_music")
                            end
                        elseif x >= 7 and x <= 10 then      -- [||]
                            isPlaying = not isPlaying
                            if isPlaying then os.queueEvent("start_music") end
                        elseif x >= 12 and x <= 15 then     -- [>|]
                            if #currentSongs > 0 then
                                currentIdx = currentIdx + 1
                                if currentIdx > #currentSongs then currentIdx = 1 end
                                isPlaying = false
                                os.queueEvent("start_music")
                            end
                        elseif x >= 18 then                 -- VOL
                            vol = vol + 0.1
                            if vol > 1.0 then vol = 0.1 end
                        end
                    end
                end
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