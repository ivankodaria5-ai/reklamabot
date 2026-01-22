-- ==================== ADOPT ME CHAT ADVERTISER ====================
-- Simple script that advertises RBLX.PW in chat and hops servers automatically
-- ============================================================================

-- ==================== CONFIGURATION ====================
local PLACE_ID = 920587237  -- Adopt Me place ID
local MIN_PLAYERS_PREFERRED = 5  -- Preferred minimum players
local MIN_PLAYERS_FALLBACK = 1  -- Fallback minimum if search takes too long
local MAX_PLAYERS_ALLOWED = 100  -- Accept almost any server
local SEARCH_TIMEOUT = 15  -- After 15 seconds, lower standards
local TELEPORT_COOLDOWN = 15  -- Reduced cooldown
local SCRIPT_URL = "https://raw.githubusercontent.com/ivankodaria5-ai/reklamabot/refs/heads/main/reklama.lua"  -- UPDATE THIS!

-- Advertisement messages (English)
local MESSAGES = {
    "Best site to sell Adopt Me pets - RBLX . PW",
    "Got extra pets? Sell them on RBLX PW for mon3y",
    "RBLX . PW - #1 marketplace for Adopt Me pets",
    "Sel your Adopt Me pets safely on RBLX . PW",
    "Trade Adopt Me pets for cash at RBLX. PW",
    "RBLX . PW - instant payouts for your Adopt Me pets",
    "Got duplicate pets? Cash them out on RBLX . PW",
    "SeIIing Adopt Me pets? Check out RBLX.PW for best prices",
    "RBLX . PW - tra sted mark etplace for Adopt Me trading",
    "Turn your Adopt Me pets into cash at RBLX . PW",
    "RBLX . PW - safe and fast Adopt Me pet sales",
    "Best pri ces for Adopt Me pets at RBLX . PW"
}

-- ==================== SERVICES ====================
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer

-- HTTP setup for different executors
local httprequest = (syn and syn.request) or http and http.request or http_request or (fluxus and fluxus.request) or request
local queueFunc = queueonteleport or queue_on_teleport or (syn and syn.queue_on_teleport) or function() print("[HOP] Queue not supported!") end

-- ==================== LOGGING ====================
local logLines = {}
local function log(msg)
    local timestamp = os.date("[%Y-%m-%d %H:%M:%S]")
    local logMsg = timestamp .. " " .. msg
    print(logMsg)
    table.insert(logLines, logMsg)
end

local function saveLog()
    if writefile then
        local content = table.concat(logLines, "\n")
        writefile("adoptme_advertiser.log", content)
    end
end

-- Auto-save log every 30 seconds
task.spawn(function()
    while true do
        task.wait(30)
        saveLog()
    end
end)

-- ==================== ANTI-AFK MOVEMENT ====================
local DIRECTION_KEYS = {
    {Enum.KeyCode.W}, {Enum.KeyCode.W, Enum.KeyCode.D}, {Enum.KeyCode.D},
    {Enum.KeyCode.D, Enum.KeyCode.S}, {Enum.KeyCode.S}, {Enum.KeyCode.S, Enum.KeyCode.A},
    {Enum.KeyCode.A}, {Enum.KeyCode.A, Enum.KeyCode.W},
}

local function startCircleMove(duration)
    log("[ANTI-AFK] Starting circle movement...")
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
    local startTime = tick()
    local step = 1
    task.spawn(function()
        while tick() - startTime < duration do
            for _, k in DIRECTION_KEYS[step] do 
                VirtualInputManager:SendKeyEvent(true, k, false, game) 
            end
            task.wait(0.1)
            for _, k in DIRECTION_KEYS[step] do 
                VirtualInputManager:SendKeyEvent(false, k, false, game) 
            end
            step = step % 8 + 1
        end
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        log("[ANTI-AFK] Movement done")
    end)
end

-- Wait with anti-AFK movement
local function waitWithMovement(duration)
    local elapsed = 0
    while elapsed < duration do
        local waitTime = math.min(10, duration - elapsed)
        task.wait(waitTime)
        elapsed = elapsed + waitTime
        
        if elapsed < duration then
            startCircleMove(3)
            task.wait(3)
            elapsed = elapsed + 3
        end
    end
end

-- ==================== CHAT FUNCTION ====================
local function sendChat(msg)
    task.spawn(function()
        -- TextChatService (new chat)
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local ch = TextChatService.TextChannels.RBXGeneral
            if ch then 
                pcall(function() 
                    ch:SendAsync(msg) 
                end) 
            end
        end
        
        -- Legacy chat fallback
        local say = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
        if say then
            say = say:FindFirstChild("SayMessageRequest")
            if say then 
                pcall(function() 
                    say:FireServer(msg, "All") 
                end) 
            end
        end
    end)
end

-- ==================== SERVER HOP FUNCTION ====================
local function serverHop()
    log("[HOP] Starting server hop...")
    saveLog()
    
    -- Check if httprequest is available
    if not httprequest then
        log("[HOP] httprequest not available! Using simple teleport...")
        queueFunc('loadstring(game:HttpGet("' .. SCRIPT_URL .. '"))()')
        local tpOk = pcall(function()
            TeleportService:Teleport(PLACE_ID, player)
        end)
        if tpOk then
            log("[HOP] Simple teleport started!")
            task.wait(999)
        end
        return
    end
    
    local cursor = ""
    local maxPages = 10  -- Check more pages for Adopt Me
    local pagesChecked = 0
    local searchStartTime = tick()
    local currentMinPlayers = MIN_PLAYERS_PREFERRED
    
    log("[HOP] Looking for servers with " .. currentMinPlayers .. "+ players...")
    
    while pagesChecked < maxPages do
        -- Check if search is taking too long
        local elapsedTime = tick() - searchStartTime
        if elapsedTime > SEARCH_TIMEOUT and currentMinPlayers ~= MIN_PLAYERS_FALLBACK then
            currentMinPlayers = MIN_PLAYERS_FALLBACK
            log("[HOP] Search timeout! Lowering requirements to " .. currentMinPlayers .. "+ players...")
        end
        
        pagesChecked = pagesChecked + 1
        task.wait(2)  -- Increased delay to avoid rate limiting
        
        local url = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100%s",
            PLACE_ID,
            cursor ~= "" and "&cursor=" .. cursor or ""
        )
        
        log("[HOP] Checking page " .. pagesChecked .. "...")
        
        local success, response = pcall(function()
            return httprequest({Url = url})
        end)
        
        if not success then
            log("[HOP] HTTP request error: " .. tostring(response))
            task.wait(5)
            continue
        end
        
        if not response then
            log("[HOP] No response object!")
            task.wait(5)
            continue
        end
        
        log("[HOP DEBUG] Response StatusCode: " .. tostring(response.StatusCode or "N/A"))
        
        -- Check for rate limiting
        if response.StatusCode == 429 then
            log("[HOP] Rate limited! Waiting 30 seconds...")
            task.wait(30)
            continue
        end
        
        if not response.Body then
            log("[HOP] No response body! Rate-limited or blocked")
            task.wait(10)
            continue
        end
        
        log("[HOP DEBUG] Response Body length: " .. #tostring(response.Body))
        log("[HOP DEBUG] Response Body preview: " .. tostring(response.Body):sub(1, 200))
        
        local bodySuccess, body = pcall(function() 
            return HttpService:JSONDecode(response.Body) 
        end)
        
        if not bodySuccess then
            log("[HOP] JSON decode error: " .. tostring(body))
            task.wait(5)
            continue
        end
        
        if not body or not body.data then
            log("[HOP] Response missing 'data' field!")
            log("[HOP DEBUG] Body keys: " .. table.concat(body and {table.unpack(body)} or {}, ", "))
            task.wait(5)
            continue
        end
        
        -- Find valid servers (any server that's not current one)
        log("[HOP DEBUG] Total servers in response: " .. (body.data and #body.data or 0))
        log("[HOP DEBUG] Current requirement: " .. currentMinPlayers .. "+ players")
        
        local servers = {}
        local serverStats = {}  -- For debugging
        for _, server in pairs(body.data or {}) do
            local players = server.playing or 0
            table.insert(serverStats, players)
            
            if server.id ~= game.JobId 
                and players >= currentMinPlayers 
                and players <= MAX_PLAYERS_ALLOWED then
                table.insert(servers, server)
            end
        end
        
        -- Show player count distribution
        if #serverStats > 0 then
            table.sort(serverStats)
            log("[HOP DEBUG] Player counts: min=" .. serverStats[1] .. " max=" .. serverStats[#serverStats] .. " (showing first 10: " .. table.concat({table.unpack(serverStats, 1, math.min(10, #serverStats))}, ",") .. ")")
        end
        
        log("[HOP] Found " .. #servers .. " suitable servers on this page")
        
        if #servers > 0 then
            -- Pick a random server from the list
            local selected = servers[math.random(#servers)]
            local playing = selected.playing or "?"
            local maxP = selected.maxPlayers or "?"
            log("[HOP] Teleporting to server: " .. selected.id .. " (" .. playing .. "/" .. maxP .. ")")
            
            -- Queue script for next server
            queueFunc('loadstring(game:HttpGet("' .. SCRIPT_URL .. '"))()')
            
            local teleportOptions = Instance.new("TeleportOptions")
            teleportOptions.ShouldReserveServer = false
            
            local tpOk, err = pcall(function()
                TeleportService:TeleportToPlaceInstance(PLACE_ID, selected.id, player, teleportOptions)
            end)
            
            if tpOk then
                log("[HOP] Teleport started! Waiting for load...")
                task.wait(999)  -- Wait indefinitely, script will reload on new server
                return
            else
                log("[HOP] Teleport error: " .. tostring(err))
                task.wait(5)
            end
        else
            log("[HOP] No suitable servers on this page")
            if body.nextPageCursor then
                cursor = body.nextPageCursor
            else
                log("[HOP] No more pages!")
                break
            end
        end
    end
    
    log("[HOP] Could not find server after checking " .. pagesChecked .. " pages")
    log("[HOP] Using fallback: Random server teleport...")
    
    -- Fallback: Just teleport to a random server (Roblox will pick one)
    queueFunc('loadstring(game:HttpGet("' .. SCRIPT_URL .. '"))()')
    
    local tpOk, err = pcall(function()
        TeleportService:Teleport(PLACE_ID, player)
    end)
    
    if tpOk then
        log("[HOP] Random teleport initiated! Waiting...")
        task.wait(999)
    else
        log("[HOP] Random teleport failed: " .. tostring(err))
        log("[HOP] Waiting 30s before retrying...")
        task.wait(30)
    end
end

-- ==================== MAIN LOOP ====================
log("=== ADOPT ME CHAT ADVERTISER STARTED ===")
log("=== ADVERTISING RBLX.PW ===")

-- Wait for character to load
if not player.Character then
    log("Waiting for character...")
    player.CharacterAdded:Wait()
end
player.Character:WaitForChild("HumanoidRootPart")
log("Character loaded!")

-- Server counter for pattern
local serverCount = 0

-- Main advertising loop
local function advertiseLoop()
    serverCount = serverCount + 1
    local messagesToSend = 3  -- Always send 3 messages
    
    -- Every 3rd server: double delays and add dot prefix
    local isSlowServer = (serverCount % 3 == 0)
    local initialDelay = isSlowServer and 10 or 5  -- 10 sec on every 3rd server, 5 sec normally
    local messageDelay = isSlowServer and 4 or 2   -- 4 sec on every 3rd server, 2 sec normally
    local dotPrefix = isSlowServer and ". " or ""  -- Add dot on every 3rd server
    
    log("[MAIN] Server #" .. serverCount .. (isSlowServer and " (SLOW MODE - 2x delays + dot)" or " (NORMAL MODE)"))
    log("[MAIN] Waiting " .. initialDelay .. " seconds after joining server...")
    task.wait(initialDelay)
    
    log("[MAIN] Sending " .. messagesToSend .. " messages then hopping...")
    
    -- Send 3 random messages with appropriate delay
    for i = 1, messagesToSend do
        local message = dotPrefix .. MESSAGES[math.random(#MESSAGES)]
        log("[CHAT] Sending message " .. i .. "/" .. messagesToSend .. ": " .. message)
        sendChat(message)
        task.wait(messageDelay)
    end
    
    log("[MAIN] All messages sent! Waiting 2 seconds before server hop...")
    task.wait(2)  -- Give players time to see messages
    
    log("[MAIN] Switching to new server...")
    serverHop()
end

-- Start the main loop with fallback
while true do
    advertiseLoop()
    log("[MAIN] Restarting loop...")
    task.wait(2)
end