-- Add at the top of the file after other variables
local occupiedLocations = {}

-- Function to get an available location
local function GetAvailableLocation()
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
        return nil
    end
    
    -- Pick a random available location
    local selected = availableLocations[math.random(1, #availableLocations)]
    occupiedLocations[selected.index] = true
    
    return selected.location, selected.index
end

-- Function to free a location
local function FreeLocation(locationIndex)
    if locationIndex then
        occupiedLocations[locationIndex] = nil
    end
end

-- Modify the StartMission event handler
RegisterNetEvent('ls_wheel_theft:StartMission')
AddEventHandler('ls_wheel_theft:StartMission', function()
    local src = source
    local Player = QBX:GetPlayer(src)
    if not Player then return end

    -- Check if player has required items
    local hasItem = Player.Functions.GetItemByName(Config.jackStandName)
    if not hasItem then
        TriggerClientEvent('QBCore:Notify', src, 'You need a jackstand to start this mission', 'error')
        return
    end

    -- Get an available location
    local location, locationIndex = GetAvailableLocation()
    if not location then
        TriggerClientEvent('QBCore:Notify', src, 'All work locations are currently occupied. Please wait for one to become available.', 'error')
        return
    end

    -- Start the mission with the selected location
    TriggerClientEvent('ls_wheel_theft:Client:StartMission', src, location, locationIndex)
end)

-- Add event to free location when mission is completed or cancelled
RegisterNetEvent('ls_wheel_theft:FreeLocation')
AddEventHandler('ls_wheel_theft:FreeLocation', function(locationIndex)
    FreeLocation(locationIndex)
end) 