-- Server-side controller for wheel theft missions
local QBCore = exports['qb-core']:GetCoreObject()

-- Track occupied locations
local occupiedLocations = {}

-- Function to get an available location
local function GetAvailableLocation(playerId)
    -- Force reset all locations if this is the only player
    local playerCount = GetNumPlayerIndices()

    
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
    
    print("^3[wheel_theft] Available location found: " .. tostring(location ~= nil))
    
    if not location then
        -- If no location is available, reset all locations and try again
        print("^2[wheel_theft] No locations available, resetting all locations")
        occupiedLocations = {}
        location, locationIndex = GetAvailableLocation(src)
        
        if not location then
            TriggerClientEvent('QBCore:Notify', src, 'All work locations are currently occupied. Please wait for one to become available.', 'error')
            return
        end
    end

    -- Start the mission with the selected location
    print("^2[wheel_theft] Starting mission for player " .. src .. " with location index: " .. locationIndex)
    TriggerClientEvent('ls_wheel_theft:Client:StartMission', src, location, locationIndex)
end)

-- Event to free a location when mission is completed or cancelled
RegisterNetEvent('ls_wheel_theft:FreeLocation')
AddEventHandler('ls_wheel_theft:FreeLocation', function(locationIndex)
    local src = source
    print("^2[wheel_theft] Player " .. src .. " freeing location index: " .. tostring(locationIndex))
    FreeLocation(locationIndex)
end)

-- Free locations when a player disconnects
AddEventHandler('playerDropped', function()
    local src = source
    print("^2[wheel_theft] Player " .. src .. " disconnected, checking for occupied locations")
    
    -- Find and free any locations occupied by this player
    for index, playerId in pairs(occupiedLocations) do
        if playerId == src then
            print("^2[wheel_theft] Freeing location " .. index .. " for disconnected player " .. src)
            occupiedLocations[index] = nil
        end
    end
end) 