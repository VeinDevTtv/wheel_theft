-- Server-side controller for wheel theft missions
local QBCore = exports['qb-core']:GetCoreObject()

-- Track occupied locations
local occupiedLocations = {}

-- Discord webhook configuration
local webhookConfig = {
    url = "REPLACE_WITH_YOUR_DISCORD_WEBHOOK_URL", -- Replace with your Discord webhook URL
    name = "Wheel Theft Missions",
    avatar = "https://i.imgur.com/REPLACE_WITH_IMAGE_ID.png", -- Replace with your preferred avatar image
    color = 16711680, -- Red color for events (decimal value)
    enabled = true -- Set to false to disable webhook logging
}

-- Function to send Discord webhook message
local function SendDiscordWebhook(title, description, fields, color)
    if not webhookConfig.enabled or webhookConfig.url == "REPLACE_WITH_YOUR_DISCORD_WEBHOOK_URL" then
        return -- Don't send if webhooks are disabled or URL not configured
    end

    local embed = {
        {
            ["title"] = title,
            ["description"] = description,
            ["color"] = color or webhookConfig.color,
            ["footer"] = {
                ["text"] = "LS Wheel Theft | " .. os.date("%Y-%m-%d %H:%M:%S")
            },
            ["fields"] = fields
        }
    }

    PerformHttpRequest(webhookConfig.url, function(err, text, headers) end, 'POST', json.encode({
        username = webhookConfig.name,
        embeds = embed,
        avatar_url = webhookConfig.avatar
    }), { ['Content-Type'] = 'application/json' })
end

-- Function to get player identification for logs
local function GetPlayerLogInfo(playerId)
    local Player = QBCore.Functions.GetPlayer(playerId)
    if not Player then return "Unknown Player" end
    
    local playerName = Player.PlayerData.name or "Unknown"
    local charName = Player.PlayerData.charinfo and Player.PlayerData.charinfo.firstname or "Unknown"
    local lastName = Player.PlayerData.charinfo and Player.PlayerData.charinfo.lastname or ""
    local playerIdentifier = Player.PlayerData.license or "Unknown License"
    
    return {
        id = playerId,
        name = playerName,
        character = charName .. " " .. lastName,
        identifier = playerIdentifier
    }
end

-- Function to get an available location
local function GetAvailableLocation(playerId)
    -- Debug print current occupied locations
    print("^3[wheel_theft] Current occupied locations:")
    for idx, pid in pairs(occupiedLocations) do
        print("^3[wheel_theft] Location " .. idx .. " is occupied by player " .. pid)
    end
    
    -- Force reset all locations only if this is the only player online
    local playerCount = GetNumPlayerIndices()
    if playerCount <= 1 then
        print("^2[wheel_theft] Only one player online, ensuring all locations are available")
        occupiedLocations = {}
    end
    
    local availableLocations = {}
    
    -- Check which locations are not occupied
    for i, location in ipairs(Config.missionLocations) do
        if not occupiedLocations[i] then
            table.insert(availableLocations, {
                index = i,
                location = location
            })
        end
    end
    
    -- If no locations are available, return nil
    if #availableLocations == 0 then
        print("^1[wheel_theft] No available locations found")
        return nil
    end
    
    -- Pick a random available location
    local selected = availableLocations[math.random(1, #availableLocations)]
    
    -- Mark as occupied BEFORE returning to prevent race conditions
    occupiedLocations[selected.index] = playerId
    
    print("^2[wheel_theft] Assigned location " .. selected.index .. " to player " .. playerId)
    return selected.location, selected.index
end

-- Function to free a location
local function FreeLocation(locationIndex)
    if locationIndex then
        print("^2[wheel_theft] Freeing location index: " .. locationIndex)
        occupiedLocations[locationIndex] = nil
    end
end

-- Reset all locations when resource starts
AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        print("^2[wheel_theft] Resource started, resetting all locations")
        occupiedLocations = {}
    end
end)

-- Reset all locations when resource stops
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        print("^2[wheel_theft] Resource stopping, resetting all locations")
        occupiedLocations = {}
    end
end)

-- Event to start a mission
RegisterNetEvent('ls_wheel_theft:StartMission')
AddEventHandler('ls_wheel_theft:StartMission', function()
    local src = source
    
    print("^3[wheel_theft] StartMission triggered by player ID: " .. src)
    
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then 
        print("^1[wheel_theft] Player object not found")
        return 
    end

    -- Check if player already has an active mission
    local playerHasActiveMission = false
    for locationIndex, playerId in pairs(occupiedLocations) do
        if tonumber(playerId) == tonumber(src) then
            playerHasActiveMission = true
            print("^3[wheel_theft] Player " .. src .. " already has an active mission at location " .. locationIndex)
            break
        end
    end
    
    if playerHasActiveMission then
        TriggerClientEvent('QBCore:Notify', src, 'You already have an active mission. Complete or cancel it first.', 'error')
        return
    end

    -- Print the player's information for debugging
    print("^3[wheel_theft] Player found: " .. Player.PlayerData.name)
    
    -- Check if player has required items
    local item = Player.Functions.GetItemByName(Config.jackStandName)
    local hasItem = item and item.amount > 0
    
    print("^3[wheel_theft] Player has jackstand item: " .. tostring(hasItem))
    
    if not hasItem then
        TriggerClientEvent('QBCore:Notify', src, 'You need a jackstand to start this mission', 'error')
        return
    end

    -- Get an available location
    local location, locationIndex = GetAvailableLocation(src)
    
    -- If no location is available and multiple players online, send notification
    if not location then
        local playerCount = GetNumPlayerIndices()
        if playerCount > 1 then
            print("^1[wheel_theft] All locations occupied with " .. playerCount .. " players online")
            TriggerClientEvent('QBCore:Notify', src, 'All work locations are currently occupied. Please wait for one to become available.', 'error')
            return
        else
            -- Safety measure: If somehow locations are all occupied with only one player
            print("^2[wheel_theft] No locations available with only one player, forcing reset")
            occupiedLocations = {}
            location, locationIndex = GetAvailableLocation(src)
            
            if not location then
                TriggerClientEvent('QBCore:Notify', src, 'Error getting a location. Please try again.', 'error')
                return
            end
        end
    end

    -- Start the mission with the selected location
    print("^2[wheel_theft] Starting mission for player " .. src .. " with location index: " .. locationIndex)
    TriggerClientEvent('ls_wheel_theft:Client:StartMission', src, location, locationIndex)
    
    -- Log mission start to Discord webhook
    local playerInfo = GetPlayerLogInfo(src)
    local locationCoords = location.x .. ", " .. location.y .. ", " .. location.z
    
    SendDiscordWebhook(
        "Wheel Theft Mission Started",
        "A player has started a wheel theft mission",
        {
            {name = "Player", value = playerInfo.character .. " (ID: " .. playerInfo.id .. ")", inline = true},
            {name = "Location Index", value = tostring(locationIndex), inline = true},
            {name = "Coordinates", value = locationCoords, inline = false}
        },
        5763719 -- Green color for starting missions
    )
end)

-- Event to free a location when mission is completed or cancelled
RegisterNetEvent('ls_wheel_theft:FreeLocation')
AddEventHandler('ls_wheel_theft:FreeLocation', function(locationIndex)
    local src = source
    print("^2[wheel_theft] Player " .. src .. " freeing location index: " .. tostring(locationIndex))
    FreeLocation(locationIndex)
    
    -- Log mission completion/cancellation to Discord webhook
    local playerInfo = GetPlayerLogInfo(src)
    
    SendDiscordWebhook(
        "Wheel Theft Mission Ended",
        "A player has completed or cancelled a wheel theft mission",
        {
            {name = "Player", value = playerInfo.character .. " (ID: " .. playerInfo.id .. ")", inline = true},
            {name = "Location Index", value = tostring(locationIndex), inline = true},
            {name = "Status", value = "Location Freed", inline = true}
        },
        15105570 -- Orange color for mission completion/cancellation
    )
end)

-- Log successful wheel theft
RegisterNetEvent('ls_wheel_theft:LogWheelStolen')
AddEventHandler('ls_wheel_theft:LogWheelStolen', function(vehicleModel, wheelIndex)
    local src = source
    local playerInfo = GetPlayerLogInfo(src)
    
    -- Get wheel position name for more readable logs
    local wheelPosition = "Unknown"
    if wheelIndex == 0 then wheelPosition = "Front Left"
    elseif wheelIndex == 1 then wheelPosition = "Front Right"
    elseif wheelIndex == 2 then wheelPosition = "Rear Left"
    elseif wheelIndex == 3 then wheelPosition = "Rear Right"
    end
    
    SendDiscordWebhook(
        "Wheel Stolen",
        "A player has successfully stolen a wheel",
        {
            {name = "Player", value = playerInfo.character .. " (ID: " .. playerInfo.id .. ")", inline = true},
            {name = "Vehicle", value = vehicleModel, inline = true},
            {name = "Wheel", value = wheelPosition, inline = true}
        },
        10181046 -- Purple color for wheel theft
    )
end)

-- Free locations when a player disconnects
AddEventHandler('playerDropped', function()
    local src = source
    print("^2[wheel_theft] Player " .. src .. " disconnected, checking for occupied locations")
    
    -- Find and free any locations occupied by this player
    for index, playerId in pairs(occupiedLocations) do
        if tonumber(playerId) == tonumber(src) then
            print("^2[wheel_theft] Freeing location " .. index .. " for disconnected player " .. src)
            occupiedLocations[index] = nil
            
            -- Log player disconnect with mission active
            local playerInfo = GetPlayerLogInfo(src)
            SendDiscordWebhook(
                "Player Disconnected During Mission",
                "A player disconnected while having an active wheel theft mission",
                {
                    {name = "Player", value = playerInfo.character .. " (ID: " .. playerInfo.id .. ")", inline = true},
                    {name = "Location Index", value = tostring(index), inline = true},
                    {name = "Status", value = "Location Freed (Disconnect)", inline = true}
                },
                16711680 -- Red color for disconnects
            )
        end
    end
end) 