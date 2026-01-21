-- ==================== MURDER MYSTERY 2 CHAT ADVERTISER ====================
-- Simple script that advertises RBLX.PW in chat and hops servers automatically
-- ============================================================================

-- ==================== CONFIGURATION ====================
local PLACE_ID = 142823291  -- Murder Mystery 2 place ID
local MIN_PLAYERS = 8  -- Minimum players in server
local MAX_PLAYERS_ALLOWED = 12  -- Maximum players in server
local TELEPORT_RETRY_DELAY = 8
local TELEPORT_COOLDOWN = 30
local SCRIPT_URL = "https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/mm2_advertiser.lua"  -- UPDATE THIS!

local MESSAGE_INTERVAL_MIN = 25  -- Minimum seconds between messages
local MESSAGE_INTERVAL_MAX = 45  -- Maximum seconds between messages
local MESSAGES_BEFORE_HOP = math.random(3, 4)  -- Send 3-4 messages then hop to new server

-- Advertisement messages (English)
local MESSAGES = {
    "Best site to sell MM2 items - RBLX.PW",
    "Got extra godlies? Sell them on RBLX.PW for real money",
    "RBLX.PW - #1 marketplace for MM2 knives and guns",
    "Sell your MM2 items safely on RBLX.PW",
    "Trade MM2 godlies for cash at RBLX.PW",
    "RBLX.PW - instant payouts for your MM2 items",
    "Got duplicate godlies? Cash them out on RBLX.PW",
    "Selling MM2 items? Check out RBLX.PW for best prices",
    "RBLX.PW - trusted marketplace for MM2 trading",
    "Turn your MM2 collection into cash at RBLX.PW",
    "RBLX.PW - safe and fast MM2 item sales",
    "Best prices for MM2 godlies at RBLX.PW"
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
        writefile("mm2_advertiser.log", content)
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
    
    local cursor = ""
    
    while true do
        task.wait(2)
        
        local url = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100%s",
            PLACE_ID,
            cursor ~= "" and "&cursor=" .. cursor or ""
        )
        
        local success, response = pcall(function()
            return httprequest({Url = url})
        end)
        
        if not success or not response then
            log("[HOP] HTTP request failed, retrying in 5s...")
            waitWithMovement(5)
            continue
        end
        
        if not response.Body then
            log("[HOP] Response has no Body! Likely rate-limited.")
            log("[HOP] Waiting 20 seconds...")
            waitWithMovement(20)
            continue
        end
        
        local bodySuccess, body = pcall(function() 
            return HttpService:JSONDecode(response.Body) 
        end)
        
        if not bodySuccess or not body or not body.data then
            log("[HOP] Failed to parse response, retrying in 5s...")
            waitWithMovement(5)
            continue
        end
        
        -- Find valid servers
        local servers = {}
        for _, server in pairs(body.data) do
            if server.id ~= game.JobId 
                and server.playing >= MIN_PLAYERS 
                and server.playing <= MAX_PLAYERS_ALLOWED then
                table.insert(servers, server)
            end
        end
        
        if #servers > 0 then
            table.sort(servers, function(a, b) return (a.playing or 0) > (b.playing or 0) end)
            
            log("[HOP] Found " .. #servers .. " suitable servers")
            
            local selected = servers[1]
            local playing = selected.playing or "?"
            local maxP = selected.maxPlayers or "?"
            log("[HOP] Trying server: " .. selected.id .. " (" .. playing .. "/" .. maxP .. ")")
            
            -- Queue script for next server
            queueFunc('loadstring(game:HttpGet("' .. SCRIPT_URL .. '"))()')
            
            local teleportOptions = Instance.new("TeleportOptions")
            teleportOptions.ShouldReserveServer = false
            
            local tpOk, err = pcall(function()
                TeleportService:TeleportToPlaceInstance(PLACE_ID, selected.id, player, teleportOptions)
            end)
            
            if tpOk then
                log("[HOP] Teleport initiated! Waiting...")
                waitWithMovement(180)  -- Wait 3 minutes
                log("[HOP] Teleport timed out")
                log("[HOP] Cooling down for " .. TELEPORT_COOLDOWN .. "s...")
                waitWithMovement(TELEPORT_COOLDOWN)
            else
                log("[HOP] Teleport failed: " .. tostring(err))
                log("[HOP] Cooling down for " .. TELEPORT_COOLDOWN .. "s...")
                waitWithMovement(TELEPORT_COOLDOWN)
            end
            
            if body.nextPageCursor then
                cursor = body.nextPageCursor
                log("[HOP] Moving to next page...")
            else
                log("[HOP] Exhausted all pages, restarting...")
                waitWithMovement(TELEPORT_COOLDOWN)
                cursor = ""
            end
        else
            if body.nextPageCursor then
                cursor = body.nextPageCursor
                log("[HOP] No suitable servers, checking next page...")
            else
                log("[HOP] Exhausted all pages. Starting over in 10s...")
                waitWithMovement(10)
                cursor = ""
            end
        end
    end
end

-- ==================== MAIN LOOP ====================
log("=== MM2 CHAT ADVERTISER STARTED ===")
log("=== ADVERTISING RBLX.PW ===")

-- Wait for character to load
if not player.Character then
    log("Waiting for character...")
    player.CharacterAdded:Wait()
end
player.Character:WaitForChild("HumanoidRootPart")
log("Character loaded!")

-- Main advertising loop
local function advertiseLoop()
    local messageCount = 0
    local messagesToSend = math.random(3, 4)
    
    log("[MAIN] Will send " .. messagesToSend .. " messages then hop")
    
    while messageCount < messagesToSend do
        -- Send random advertisement message
        local message = MESSAGES[math.random(#MESSAGES)]
        log("[CHAT] Sending message " .. (messageCount + 1) .. "/" .. messagesToSend .. ": " .. message)
        sendChat(message)
        
        messageCount = messageCount + 1
        
        -- If not last message, wait before sending next one
        if messageCount < messagesToSend then
            local waitTime = math.random(MESSAGE_INTERVAL_MIN, MESSAGE_INTERVAL_MAX)
            log("[MAIN] Waiting " .. waitTime .. " seconds before next message...")
            
            -- Do anti-AFK movement while waiting
            local elapsed = 0
            while elapsed < waitTime do
                local chunk = math.min(15, waitTime - elapsed)
                task.wait(chunk)
                elapsed = elapsed + chunk
                
                -- Do a quick circle move every 15 seconds
                if elapsed < waitTime then
                    startCircleMove(2)
                    task.wait(2)
                    elapsed = elapsed + 2
                end
            end
        end
    end
    
    -- Done sending messages, hop to new server
    log("[MAIN] Sent all messages! Switching to new server...")
    serverHop()
end

-- Start the main loop
advertiseLoop()

-- Fallback restart (should never reach here)
log("[ERROR] Main loop ended! Restarting...")
task.wait(5)
while true do
    advertiseLoop()
end