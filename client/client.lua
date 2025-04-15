Keys = {
    ["ESC"] = 322, ["F1"] = 288, ["F2"] = 289, ["F3"] = 170, ["F5"] = 166, ["F6"] = 167, ["F7"] = 168, ["F8"] = 169, ["F9"] = 56, ["F10"] = 57,
    ["~"] = 243, ["1"] = 157, ["2"] = 158, ["3"] = 160, ["4"] = 164, ["5"] = 165, ["6"] = 159, ["7"] = 161, ["8"] = 162, ["9"] = 163, ["-"] = 84, ["="] = 83, ["BACKSPACE"] = 177,
    ["TAB"] = 37, ["Q"] = 44, ["W"] = 32, ["E"] = 38, ["R"] = 45, ["T"] = 245, ["Y"] = 246, ["U"] = 303, ["P"] = 199, ["["] = 39, ["]"] = 40, ["ENTER"] = 18,
    ["CAPS"] = 137, ["A"] = 34, ["S"] = 8, ["D"] = 9, ["F"] = 23, ["G"] = 47, ["H"] = 74, ["K"] = 311, ["L"] = 182,
    ["LEFTSHIFT"] = 21, ["Z"] = 20, ["X"] = 73, ["C"] = 26, ["V"] = 0, ["B"] = 29, ["N"] = 249, ["M"] = 244, [","] = 82, ["."] = 81,
    ["LEFTCTRL"] = 36, ["LEFTALT"] = 19, ["SPACE"] = 22, ["RIGHTCTRL"] = 70,
    ["HOME"] = 213, ["PAGEUP"] = 10, ["PAGEDOWN"] = 11, ["DELETE"] = 178,
    ["LEFT"] = 174, ["RIGHT"] = 175, ["TOP"] = 27, ["DOWN"] = 173,
    ["NENTER"] = 201, ["N4"] = 108, ["N5"] = 60, ["N6"] = 107, ["N+"] = 96, ["N-"] = 97, ["N7"] = 117, ["N8"] = 61, ["N9"] = 118
}

-- Debugging Variables
DEBUG_MODE = true -- Set to true to enable debugging

-- Debug function to check entity network status
function DebugNetworkEntity(entity, entityName)
    if not DEBUG_MODE then return end
    
    if not DoesEntityExist(entity) then
        print("^1[DEBUG] " .. entityName .. " does not exist")
        QBCore.Functions.Notify("DEBUG: " .. entityName .. " does not exist", "error", 3000)
        return false
    end
    
    local netId = NetworkGetNetworkIdFromEntity(entity)
    local isNetworked = NetworkGetEntityIsNetworked(entity)
    local hasControl = NetworkHasControlOfEntity(entity)
    local hasNetworkId = netId ~= 0
    local owner = NetworkGetEntityOwner(entity)
    
    print("^3[DEBUG] " .. entityName .. " Network Info:")
    print("^3Network ID: " .. netId)
    print("^3Is Networked: " .. tostring(isNetworked))
    print("^3Has Control: " .. tostring(hasControl))
    print("^3Owner: " .. owner)
    
    -- Display notification to player
    QBCore.Functions.Notify("DEBUG: " .. entityName .. " NetID: " .. netId .. " | Networked: " .. tostring(isNetworked), "primary", 3000)
    
    -- Return true if entity is properly networked
    return isNetworked and hasNetworkId
end

-- Function to ensure entity is properly networked
function EnsureEntityIsNetworked(entity, entityName, maxAttempts)
    if not DEBUG_MODE then return true end
    
    local attempts = 0
    maxAttempts = maxAttempts or 5
    
    if not DoesEntityExist(entity) then
        QBCore.Functions.Notify("DEBUG: Cannot network non-existent " .. entityName, "error", 3000)
        return false
    end
    
    while attempts < maxAttempts do
        if NetworkGetEntityIsNetworked(entity) then
            break
        end
        
        NetworkRegisterEntityAsNetworked(entity)
        attempts = attempts + 1
        QBCore.Functions.Notify("DEBUG: Attempting to network " .. entityName .. " (" .. attempts .. "/" .. maxAttempts .. ")", "primary", 1000)
        Citizen.Wait(200)
    end
    
    local success = NetworkGetEntityIsNetworked(entity)
    if success then
        QBCore.Functions.Notify("DEBUG: Successfully networked " .. entityName, "success", 2000)
    else
        QBCore.Functions.Notify("DEBUG: Failed to network " .. entityName .. " after " .. maxAttempts .. " attempts", "error", 3000)
    end
    
    return success
end

MISSION_BLIP = nil
MISSION_AREA = nil
sellerBlip = nil
MISSION_ACTIVATED = false
PLAYER_JOB = nil
STORED_WHEELS = {}
WHEEL_PROP = nil
TARGET_VEHICLE = nil
MISSION_BRICKS = {}
CURRENT_LOCATION_INDEX = nil

-- Variables for ox_target integration
local targetVehicleNetIds = {}
local truckNetId = nil
local myWheelProps = {} -- Track wheels owned by this player specifically

function StartMission(specificLocation, locationIndex)
    MISSION_ACTIVATED = true
    CURRENT_LOCATION_INDEX = locationIndex
    
    -- Initialize mission start time (used for identification without state bags)
    -- We'll use this instead of state bags to identify mission ownership
    MISSION_START_TIME = GetGameTimer()
    MISSION_OWNER_ID = GetPlayerServerId(PlayerId())
    
    if DEBUG_MODE then
        print("^2[DEBUG] Starting mission with timestamp: " .. MISSION_START_TIME)
    end

    if Config.spawnPickupTruck.enabled then
        SpawnTruck()
    end

    Citizen.CreateThread(function()
        local sleep = 1500
        local vehicleModel = Config.vehicleModels[math.random(1, #Config.vehicleModels)]
        local missionLocation = specificLocation or Config.missionLocations[math.random(1, #Config.missionLocations)]
        local coords = ModifyCoordinatesWithLimits(missionLocation.x, missionLocation.y, missionLocation.z, missionLocation.h)
        local player = PlayerPedId()
        local blip = Config.missionBlip
        MISSION_BLIP = CreateSellerBlip(vector3(coords.x, coords.y, coords.z), blip.blipIcon, blip.blipColor, 1.0, 1.0, blip.blipLabel)
        MISSION_AREA = AddBlipForRadius(coords.x, coords.y, coords.z, 100.0)
        SetBlipAlpha(MISSION_AREA, 150)
        local vehicle = SpawnMissionVehicle(vehicleModel, missionLocation)
        SetCustomRims(vehicle)
        TARGET_VEHICLE = vehicle

        if Config.enableBlipRoute then
            SetBlipRoute(MISSION_BLIP, true)
        end
        QBCore.Functions.Notify('Your target vehicle\'s plate number: '.. GetVehicleNumberPlateText(vehicle), 'inform', 40000)

        if Config.printLicensePlateToConsole then
            print('Your target vehicle\'s plate number:' .. GetVehicleNumberPlateText(vehicle))
        end

        if Config.debug then
            SetEntityCoords(PlayerPedId(), missionLocation.x + 2.0, missionLocation.y, missionLocation.z, false, false, false, false)
        end

        if not Config.target.enabled then
            while true do
                local playerCoords = GetEntityCoords(player)
                local vehicleCoords = GetEntityCoords(vehicle)
                local distance = #(vehicleCoords - playerCoords)

                if distance < 3.5 then
                    sleep = 1
                    Draw3DText(vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 0.5, L('Lift the car to steal wheels'), 4, 0.035, 0.035)

                    if Entity(vehicle).state.IsVehicleRaised then
                        RemoveBlip(MISSION_BLIP)
                        RemoveBlip(MISSION_AREA)
                        StartWheelTheft(vehicle)
                        break
                    end
                else
                    if IsPedDeadOrDying(PlayerPedId(), 1) then
                        RemoveBlip(MISSION_BLIP)
                        RemoveBlip(MISSION_AREA)
                        CancelMission()
                    end
                end

                Citizen.Wait(sleep)
            end
        else
            --AddEntityToTargeting
        end

    end)
end

function StartWheelTheft(vehicle)
    Citizen.Wait(4000)
    local notified = 'waiting'

    -- Register the target vehicle with ox_target if it's enabled
    if Config.target.enabled then
        if DEBUG_MODE then
            print("^3[DEBUG] Starting wheel theft - waiting for network sync before registering target")
            QBCore.Functions.Notify("DEBUG: Waiting for network sync...", "primary", 3000)
        end
        
        -- Add a longer delay for vehicles to properly network before registration
        -- This is especially important for high-ping players
        Citizen.Wait(2000)
        
        if not DoesEntityExist(vehicle) then
            if DEBUG_MODE then
                print("^1[DEBUG] Vehicle no longer exists after delay!")
                QBCore.Functions.Notify("DEBUG: Vehicle disappeared during sync delay", "error", 3000)
            end
            return
        end
        
        -- Force the entity to be networked
        NetworkRegisterEntityAsNetworked(vehicle)
        Citizen.Wait(500)
        
        -- Request control of the entity
        if not NetworkHasControlOfEntity(vehicle) then
            if DEBUG_MODE then
                print("^3[DEBUG] Requesting control of vehicle")
                QBCore.Functions.Notify("DEBUG: Requesting vehicle control", "primary", 1000)
            end
            
            NetworkRequestControlOfEntity(vehicle)
            Citizen.Wait(1000) -- Wait a bit for control request
        end
        
        if DEBUG_MODE then
            print("^2[DEBUG] Registering vehicle with ox_target after delay")
            QBCore.Functions.Notify("DEBUG: Registering vehicle after sync", "success", 3000)
        end
        
        RegisterTargetVehicleWithOxTarget(vehicle, true)
    end

    while true do
        local sleep = 1000
        local playerId = PlayerPedId()
        local playerCoords = GetEntityCoords(playerId)
        local vehicleCoords = GetEntityCoords(vehicle)
        local distance = #(playerCoords - vehicleCoords)

        if distance < 200 and not WHEEL_PROP then
            local wheelCoords, wheelToPlayerDistance, wheelIndex, isWheelMounted = FindNearestWheel(vehicle)

            if isWheelMounted then
                if not Config.target.enabled then
                    sleep = 1
                    Draw3DText(wheelCoords.x, wheelCoords.y, wheelCoords.z, L('Press ~g~[~w~E~g~]~w~ to start stealing'), 4, 0.035, 0.035)

                    if IsControlJustReleased(0, Keys['E']) then
                        if notified == 'waiting' and IsPoliceNotified() then
                            notified = true

                            if Config.dispatch.notifyThief then
                                StartVehicleAlarm(vehicle)
                            end

                            TriggerDispatch(GetEntityCoords(PlayerPedId()))
                        elseif notified == 'waiting' and not IsPoliceNotified() then
                            notified = false
                        end

                        StartWheelDismount(vehicle, wheelIndex, false, true, false)
                    end
                end
                -- Target implementation is handled by RegisterTargetVehicleWithOxTarget
            end

            -- Check if all wheels are removed
            local allWheelsRemoved = true
            for i=0, 3 do
                local wheelOffset = GetVehicleWheelXOffset(vehicle, i)
                if wheelOffset ~= 9999999.0 then
                    allWheelsRemoved = false
                    break
                end
            end
            
            -- If all wheels are removed and the player is not currently holding a wheel,
            -- we stop the wheel theft loop - the rest will be handled by the finish option in RegisterTargetVehicleWithOxTarget
            if allWheelsRemoved and not WHEEL_PROP then
                QBCore.Functions.Notify('All wheels have been removed. Lower the vehicle to finish.', 'inform', 8000)
                return
            end
        else
            -- Stop wheel theft and cancel mission if player is too far away
            if distance > 300 then
                QBCore.Functions.Notify('You have moved too far from the target vehicle.', 'error', 5000)
                CancelMission()
                return
            end
        end

        Citizen.Wait(sleep)
    end
end

function CanPlayerLowerThisCar()
    local permTable = Config.jackSystem['lower']

    return UseCache('jobCache', function()
        return Contains(permTable.jobs, PLAYER_JOB)
    end, 500)
end

Citizen.CreateThread(function()
    local permTable = Config.jackSystem['lower']

    while true do
        local sleep = 1500
        local player = PlayerPedId()
        local coords = GetEntityCoords(player)

        if permTable.everyone or CanPlayerLowerThisCar() then
            local vehicle, isRaised = NearestVehicleCached(coords, 3.0)

            if vehicle and vehicle ~= TARGET_VEHICLE and isRaised then
                -- Register the vehicle with ox_target if it's enabled
                if Config.target.enabled then
                    RegisterTargetVehicleWithOxTarget(vehicle, false)
                else
                    -- Legacy E key approach
                    sleep = 1
                    local wheelCoords, wheelToPlayerDistance, wheelIndex, isWheelMounted = FindNearestWheel(vehicle)
                    local vehicleCoords = GetEntityCoords(vehicle)

                    if isWheelMounted then
                        Draw3DText(wheelCoords.x, wheelCoords.y, wheelCoords.z + 0.5, L('Press ~g~[~w~E~g~]~w~ to steal this wheel'), 4, 0.065, 0.065)

                        if IsControlJustReleased(0, Keys['E']) then
                            StartWheelDismount(vehicle, wheelIndex, false, true, false, true)
                        end
                    else
                        Draw3DText(vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 0.5, L('Press ~g~[~w~E~g~]~w~ to lower this vehicle'), 4, 0.065, 0.065)

                        if IsControlJustReleased(0, Keys['E']) then
                            local lowered = LowerVehicle(false, true)

                            while not lowered do
                                Citizen.Wait(100)
                            end

                            SpawnBricksUnderVehicle(vehicle)
                            break
                        end
                    end
                end
            end
        end

        Citizen.Wait(sleep)
    end
end)

function NearestVehicleCached(coords, radius)
    return UseCache('nearestCacheVehicle', function()
        local vehicle = GetNearestVehicle(coords.x, coords.y, coords.z, radius)

        if vehicle then
            return vehicle, Entity(vehicle).state.IsVehicleRaised
        else
            return vehicle
        end
    end, 500)
end

function StopWheelTheft(vehicle)
    -- With ox_target, we don't need a separate thread as finishing is handled by the target options
    if Config.target.enabled then
        -- The ox_target is already set up in RegisterTargetVehicleWithOxTarget
        -- We just need to make sure the vehicle network ID is tracked for cleanup
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        if not Contains(targetVehicleNetIds, netId) then
            table.insert(targetVehicleNetIds, netId)
        end
        return
    end
    
    -- Legacy E key approach
    Citizen.CreateThread(function()
        while true do
            local sleep = 1000
            local player = PlayerPedId()
            local playerCoords = GetEntityCoords(player)
            local vehicleCoords = GetEntityCoords(vehicle)

            if #(vehicleCoords - playerCoords) < 3.5 then
                sleep = 1
                Draw3DText(vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 0.5, L('Press ~g~[~w~E~g~]~w~ to finish stealing'), 4, 0.035, 0.035)

                if IsControlJustReleased(0, Keys['E']) then
                    local lowered = LowerVehicle()

                    while not lowered do
                        Citizen.Wait(100)
                    end

                    SpawnBricksUnderVehicle(vehicle)
                    TriggerServerEvent('ls_wheel_theft:RetrieveItem', Config.jackStandName)

                    break
                end
            end

            Citizen.Wait(sleep)
        end

        SetEntityAsNoLongerNeeded(vehicle)
    end)
end

function IsPoliceNotified()
    if not Config.dispatch.enabled then
        return false
    end

    local alertChance = Config.dispatch.alertChance
    local random = math.random(1,100)

    if random <= alertChance then
        return true
    else
        return false
    end
end

-- Function to register a target vehicle with ox_target for wheel theft
function RegisterTargetVehicleWithOxTarget(vehicle, isTargetVehicle)
    -- Only register if ox_target is enabled
    if not Config.target.enabled then return end
    
    -- Debug check for entity existence
    if not DoesEntityExist(vehicle) then
        if DEBUG_MODE then
            print("^1[DEBUG] Target vehicle does not exist when trying to register with ox_target")
            QBCore.Functions.Notify("DEBUG: Vehicle doesn't exist for ox_target registration", "error", 3000)
        end
        return
    end
    
    -- Ensure vehicle is properly networked for targeting
    local isNetworked = EnsureEntityIsNetworked(vehicle, "Target Vehicle")
    if not isNetworked and DEBUG_MODE then
        print("^1[DEBUG] Failed to ensure vehicle is networked")
        return
    end
    
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    
    -- Debug check for valid network ID
    if netId == 0 and DEBUG_MODE then
        print("^1[DEBUG] Target vehicle has invalid network ID (0)")
        QBCore.Functions.Notify("DEBUG: Vehicle has invalid network ID", "error", 3000)
        return
    end
    
    if Contains(targetVehicleNetIds, netId) then 
        if DEBUG_MODE then
            print("^3[DEBUG] Vehicle already registered with ox_target. NetID: " .. netId)
            QBCore.Functions.Notify("DEBUG: Vehicle already registered (NetID: " .. netId .. ")", "primary", 3000)
        end
        return
    end
    
    -- Debug network info
    DebugNetworkEntity(vehicle, "Target Vehicle")
    
    -- Check if this is a mission target vehicle and player is the mission owner
    local localPlayerId = GetPlayerServerId(PlayerId())
    local isMissionOwner = (isTargetVehicle and localPlayerId == MISSION_OWNER_ID)
    
    -- Only register the vehicle if it's not a mission target or the player is the mission owner
    if not isTargetVehicle or isMissionOwner then
        table.insert(targetVehicleNetIds, netId)
        
        if DEBUG_MODE then
            print("^2[DEBUG] Adding vehicle to targetVehicleNetIds. NetID: " .. netId)
            QBCore.Functions.Notify("DEBUG: Registering vehicle options. NetID: " .. netId, "success", 3000)
        end
        
        -- Define options for the vehicle
        local options = {}
        
        -- If the vehicle is raised, add wheel options
        if Entity(vehicle).state.IsVehicleRaised then
            -- Add wheel options
            local wheelBones = {
                'wheel_lf', -- Left Front
                'wheel_rf', -- Right Front
                'wheel_lr', -- Left Rear
                'wheel_rr'  -- Right Rear
            }
            
            for i, boneName in ipairs(wheelBones) do
                local wheelIndex = i - 1
                local boneIndex = GetEntityBoneIndexByName(vehicle, boneName)
                
                if boneIndex ~= -1 then
                    table.insert(options, {
                        name = 'ls_wheel_theft:steal_wheel_' .. wheelIndex,
                        icon = 'fas fa-tire',
                        label = 'Steal Wheel',
                        bones = {boneName},
                        canInteract = function()
                            -- Check if the wheel is still mounted
                            local _, _, _, isWheelMounted = FindNearestWheel(vehicle)
                            -- Only allow interaction if the vehicle is raised and the player is the mission owner
                            if isTargetVehicle then
                                return isWheelMounted and Entity(vehicle).state.IsVehicleRaised and localPlayerId == MISSION_OWNER_ID
                            else
                                return isWheelMounted and Entity(vehicle).state.IsVehicleRaised
                            end
                        end,
                        onSelect = function()
                            local notified = IsPoliceNotified()
                            
                            if notified and Config.dispatch.notifyThief then
                                StartVehicleAlarm(vehicle)
                                TriggerDispatch(GetEntityCoords(PlayerPedId()))
                            end
                            
                            StartWheelDismount(vehicle, wheelIndex, false, true, false, not isTargetVehicle)
                        end
                    })
                    
                    if DEBUG_MODE then
                        print("^2[DEBUG] Added target option for " .. boneName)
                    end
                else if DEBUG_MODE then
                    print("^1[DEBUG] Could not find bone: " .. boneName)
                end
                end
            end
            
            -- Add lower vehicle option if this is not a target vehicle
            if not isTargetVehicle then
                table.insert(options, {
                    name = 'ls_wheel_theft:lower_vehicle',
                    icon = 'fas fa-arrow-down',
                    label = 'Lower Vehicle',
                    distance = 3.0,
                    canInteract = function()
                        -- Only show if all wheels are removed
                        local allWheelsRemoved = true
                        for i=0, 3 do
                            local wheelOffset = GetVehicleWheelXOffset(vehicle, i)
                            if wheelOffset ~= 9999999.0 then
                                allWheelsRemoved = false
                                break
                            end
                        end
                        return allWheelsRemoved and Entity(vehicle).state.IsVehicleRaised
                    end,
                    onSelect = function()
                        local lowered = LowerVehicle(false, true)
                        while not lowered do
                            Citizen.Wait(100)
                        end
                        SpawnBricksUnderVehicle(vehicle)
                    end
                })
            end
            
            -- Add finish stealing option if this is a target vehicle
            if isTargetVehicle then
                table.insert(options, {
                    name = 'ls_wheel_theft:finish_stealing',
                    icon = 'fas fa-check',
                    label = 'Finish Stealing',
                    distance = 3.0,
                    canInteract = function()
                        -- Only show if all wheels are removed and player is the mission owner
                        local allWheelsRemoved = true
                        for i=0, 3 do
                            local wheelOffset = GetVehicleWheelXOffset(vehicle, i)
                            if wheelOffset ~= 9999999.0 then
                                allWheelsRemoved = false
                                break
                            end
                        end
                        return allWheelsRemoved and Entity(vehicle).state.IsVehicleRaised and localPlayerId == MISSION_OWNER_ID
                    end,
                    onSelect = function()
                        local lowered = LowerVehicle()
                        while not lowered do
                            Citizen.Wait(100)
                        end
                        SpawnBricksUnderVehicle(vehicle)
                        TriggerServerEvent('ls_wheel_theft:RetrieveItem', Config.jackStandName)
                        if netId and Contains(targetVehicleNetIds, netId) then
                            exports.ox_target:removeEntity(netId)
                            for i, v in ipairs(targetVehicleNetIds) do
                                if v == netId then
                                    table.remove(targetVehicleNetIds, i)
                                    break
                                end
                            end
                        end
                    end
                })
            end
        end
        
        -- Only add options if we have any
        if #options > 0 then
            if DEBUG_MODE then
                print("^2[DEBUG] Adding " .. #options .. " options to entity with NetID: " .. netId)
                QBCore.Functions.Notify("DEBUG: Adding " .. #options .. " target options", "success", 3000)
            end
            
            -- Try-catch style error handling for addEntity
            local success, error = pcall(function()
                exports.ox_target:addEntity(netId, options)
            end)
            
            if not success and DEBUG_MODE then
                print("^1[DEBUG] Error adding entity to ox_target: " .. tostring(error))
                QBCore.Functions.Notify("DEBUG: Target registration error: " .. tostring(error), "error", 3000)
            end
        else if DEBUG_MODE then
            print("^3[DEBUG] No options to add to entity with NetID: " .. netId)
            QBCore.Functions.Notify("DEBUG: No options to add to target", "primary", 3000)
        end
        end
    else
        if DEBUG_MODE then
            print("^3[DEBUG] Skipping target registration - player is not the mission owner")
            QBCore.Functions.Notify("DEBUG: Not registering target - not mission owner", "primary", 3000)
        end
    end
end

-- Function to register truck with ox_target for wheel storage
function RegisterTruckWithOxTarget(vehicle)
    -- Only register if ox_target is enabled and we're holding a wheel
    if not Config.target.enabled or not WHEEL_PROP then return end
    
    -- Debug check for entity existence
    if not DoesEntityExist(vehicle) then
        if DEBUG_MODE then
            print("^1[DEBUG] Truck vehicle does not exist when trying to register with ox_target")
            QBCore.Functions.Notify("DEBUG: Truck doesn't exist for ox_target registration", "error", 3000)
        end
        return
    end
    
    -- Force network registration for the entity
    if not NetworkGetEntityIsNetworked(vehicle) then
        NetworkRegisterEntityAsNetworked(vehicle)
        Citizen.Wait(500) -- Wait for network registration
    end
    
    -- Set entity as mission entity to prevent cleanup
    SetEntityAsMissionEntity(vehicle, true, true)
    
    -- Get network ID of the truck (should be valid now)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    
    -- Debug check for valid network ID
    if netId == 0 then
        if DEBUG_MODE then
            print("^1[DEBUG] Truck vehicle has invalid network ID (0)")
            QBCore.Functions.Notify("DEBUG: Truck still has invalid network ID", "error", 3000)
        end
        return
    end
    
    -- Don't register if it's already registered
    if truckNetId == netId then return end
    
    -- Store the network ID of the player's truck
    truckNetId = netId
    
    -- Use minimal data in entity states - avoid large strings that can cause overflow
    -- Store only the essential owner ID instead of complex mission identifiers
    Entity(vehicle).state:set('OwnerID', GetPlayerServerId(PlayerId()), true)
    
    if DEBUG_MODE then
        print("^2[DEBUG] Setting truckNetId to: " .. netId)
        print("^2[DEBUG] Setting truck owner to: " .. GetPlayerServerId(PlayerId()))
        QBCore.Functions.Notify("DEBUG: Registered truck with owner ID", "success", 3000)
    end
    
    -- Define options for the truck with ownership checking
    local options = {
        {
            name = 'ls_wheel_theft:store_wheel',
            icon = 'fas fa-box',
            label = 'Store Wheel',
            distance = 3.0,
            canInteract = function()
                -- Only show if player is holding a wheel and this is their truck
                local ownerID = Entity(vehicle).state.OwnerID
                local myID = GetPlayerServerId(PlayerId())
                
                if DEBUG_MODE and ownerID ~= myID then
                    print("^3[DEBUG] Owner mismatch: " .. tostring(ownerID) .. " vs " .. myID)
                end
                
                return WHEEL_PROP ~= nil and ownerID == myID
            end,
            onSelect = function()
                local storedWheel = PutWheelInTruckBed(vehicle, #STORED_WHEELS + 1)
                DeleteEntity(WHEEL_PROP)
                ClearPedTasksImmediately(PlayerPedId())
                table.insert(STORED_WHEELS, storedWheel)
                WHEEL_PROP = nil
                
                -- Remove the truck from ox_target as we no longer need it
                if truckNetId then
                    exports.ox_target:removeEntity(truckNetId)
                    truckNetId = nil
                end
            end
        }
    }
    
    -- Add options to the truck
    exports.ox_target:addEntity(netId, options)
end

function BeginWheelLoadingIntoTruck(wheelProp)
    if not Config.target.enabled then
        Citizen.CreateThread(function()
            while true do
                local sleep = 300
                local player = PlayerPedId()
                local playerCoords = GetEntityCoords(player)
                local vehicle = GetNearestVehicle(playerCoords.x, playerCoords.y, playerCoords.z, 5.0)

                if vehicle and IsVehicleATruck(vehicle) then
                    sleep = 1
                    local textCoords = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -1.5, 0.2)
                    Draw3DText(textCoords.x, textCoords.y, textCoords.z + 0.5, L('Press ~g~[~w~E~g~]~w~ to store the wheel'), 4, 0.035, 0.035)

                    if IsControlJustReleased(0, Keys['E']) then
                        local storedWheel = PutWheelInTruckBed(vehicle, #STORED_WHEELS + 1)
                        DeleteEntity(wheelProp)
                        ClearPedTasksImmediately(player)
                        table.insert(STORED_WHEELS, storedWheel)
                        WHEEL_PROP = nil

                        return
                    end
                end

                Citizen.Wait(sleep)
            end
        end)
    else
        -- Register the nearest truck with ox_target for wheel storage
        Citizen.CreateThread(function()
            while WHEEL_PROP do
                local sleep = 300
                local player = PlayerPedId()
                local playerCoords = GetEntityCoords(player)
                local vehicle = GetNearestVehicle(playerCoords.x, playerCoords.y, playerCoords.z, 5.0)
                
                if vehicle and IsVehicleATruck(vehicle) then
                    local vehicleCoords = GetEntityCoords(vehicle)
                    local distance = #(vehicleCoords - playerCoords)
                    
                    if distance < 5.0 then
                        RegisterTruckWithOxTarget(vehicle)
                    end
                end
                
                Citizen.Wait(sleep)
            end
            
            -- Clean up when wheel is no longer held
            if truckNetId then
                exports.ox_target:removeEntity(truckNetId)
                truckNetId = nil
            end
        end)
    end
end

function EnableWheelTakeOut()
    if not Config.target.enabled then
        Citizen.CreateThread(function()
            local player = PlayerPedId()

            while #STORED_WHEELS > 0 do
                local sleep = 1000
                local playerCoords = GetEntityCoords(player)
                local vehicle = GetNearestVehicle(playerCoords.x, playerCoords.y, playerCoords.z, 5.0)
                local vehicleCoords = GetEntityCoords(vehicle)

                if IsVehicleATruck(vehicle) and not IsPedInAnyVehicle(player, true) and #(vehicleCoords - playerCoords) < 3.5 then
                    sleep = 1
                    local textCoords = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -1.5, 0.2)
                    Draw3DText(textCoords.x, textCoords.y, textCoords.z + 0.5, L('Press ~g~[~w~H~g~]~w~ to take Wheel out'), 4, 0.035, 0.035)

                    if IsControlJustReleased(0, Keys['H']) and not HOLDING_WHEEL then
                        local wheelProp = PutWheelInHands()
                        HOLDING_WHEEL = wheelProp
                        DeleteEntity(STORED_WHEELS[#STORED_WHEELS])
                        table.remove(STORED_WHEELS, #STORED_WHEELS)
                    end
                end

                Citizen.Wait(sleep)
            end
            
            -- Clean up when no more wheels are stored
            if truckNetId then
                exports.ox_target:removeEntity(truckNetId)
                truckNetId = nil
            end
        end)
    else
        -- Register trucks that have stored wheels with ox_target
        Citizen.CreateThread(function()
            while #STORED_WHEELS > 0 do
                local sleep = 300
                local player = PlayerPedId()
                local playerCoords = GetEntityCoords(player)
                local vehicle = GetNearestVehicle(playerCoords.x, playerCoords.y, playerCoords.z, 5.0)
                
                if vehicle and IsVehicleATruck(vehicle) then
                    local vehicleCoords = GetEntityCoords(vehicle)
                    local distance = #(vehicleCoords - playerCoords)
                    
                    if distance < 5.0 and not HOLDING_WHEEL then
                        RegisterTruckForWheelRetrieval(vehicle)
                    end
                end
                
                Citizen.Wait(sleep)
            end
            
            -- Clean up when no more wheels are stored
            if truckNetId then
                exports.ox_target:removeEntity(truckNetId)
                truckNetId = nil
            end
        end)
    end
end

function StartWheelDismount(vehicle, wheelIndex, mount, TaskPlayerGoToWheel, coordsTable, disableWheelProp)
    local success = true
    
    -- Check if bolt minigame resource exists and try to use it
    if GetResourceState('ls_bolt_minigame') == 'started' then
        -- Use pcall to safely try the export
        local status, result = pcall(function() 
            return exports['ls_bolt_minigame']:BoltMinigame(vehicle, wheelIndex, mount, TaskPlayerGoToWheel, coordsTable)
        end)
        
        if status then
            success = result
        else
            -- Export failed, notify and continue
            QBCore.Functions.Notify('Bolt minigame resource error, skipping...', 'primary', 3000)
            -- Still continue with wheel removal
            success = true
        end
    else
        -- Resource not available, just simulate wheel removal
        QBCore.Functions.Notify('Removing wheel...', 'primary', 2000)
        -- Add a small delay to simulate the minigame
        Citizen.Wait(1500)
    end

    if success and not disableWheelProp then
        SetVehicleWheelXOffset(vehicle, wheelIndex, 9999999.0)
        WHEEL_PROP = PutWheelInHands()
        BeginWheelLoadingIntoTruck(WHEEL_PROP)
    end

    if disableWheelProp then
        BreakOffVehicleWheel(vehicle, wheelIndex, false, false, false, false)
    end
end

function IsVehicleATruck(vehicle)
    return UseCache('isVehicleATruck', function()
        local pickupTruckHashes = {
            GetHashKey("bison"),    GetHashKey("bobcatxl"),    GetHashKey("crusader"),
            GetHashKey("dubsta3"),    GetHashKey("rancherxl"),    GetHashKey("sandking"),
            GetHashKey("sandking2"),    GetHashKey("rebel"),    GetHashKey("rebel2"),
            GetHashKey("kamacho"),    GetHashKey("youga2"),    GetHashKey("monster"),
            GetHashKey("bison3"),    GetHashKey("bodhi2"),    GetHashKey("Sadler")
        }

        return Contains(pickupTruckHashes, GetEntityModel(vehicle))
    end, 500)
end

-- Event to lift vehicle using jackstand from inventory
RegisterNetEvent('ls_wheel_theft:LiftVehicle')
AddEventHandler('ls_wheel_theft:LiftVehicle', function()
    -- Debug output to check if the event is triggered
    QBCore.Functions.Notify('Attempting to use jackstand...', 'primary', 2000)
    -- Call the RaiseCar function from jackstand.lua
    RaiseCar()
end)

RegisterNetEvent('ls_wheel_theft:LowerVehicle')
AddEventHandler('ls_wheel_theft:LowerVehicle', function()
    LowerVehicle()
end)

if Config.command.enabled then
    RegisterCommand(Config.command.name, function()
        RaiseCar()
        TriggerServerEvent('ls_wheel_theft:ResetPlayerState', NetworkGetNetworkIdFromEntity(PlayerPedId()))
    end)
end

-- Add a resource stop handler to ensure the work vehicle is cleaned up
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        -- Clean up work vehicle when resource stops
        -- This is a safety measure to prevent vehicles from being left in the world if the script is stopped
        -- Normal despawning should happen through the CancelMission function when players cancel at the NPC
        if WORK_VEHICLE and DoesEntityExist(WORK_VEHICLE) then
            SetEntityAsMissionEntity(WORK_VEHICLE, true, true)
            DeleteVehicle(WORK_VEHICLE)
            WORK_VEHICLE = nil
        end
        
        -- Clean up all ox_target entities
        if Config.target.enabled then
            -- Clean up all registered target vehicles
            for _, netId in ipairs(targetVehicleNetIds) do
                exports.ox_target:removeEntity(netId)
            end
            targetVehicleNetIds = {}
            
            -- Clean up truck if registered
            if truckNetId then
                exports.ox_target:removeEntity(truckNetId)
                truckNetId = nil
            end
        end
    end
end)

-- Add this function to clean up the target vehicle after all wheels are removed
function CleanupMissionVehicle()
    if TARGET_VEHICLE and DoesEntityExist(TARGET_VEHICLE) then
        -- Start a timer to delete the vehicle after 10 seconds
        Citizen.CreateThread(function()
            QBCore.Functions.Notify('Target vehicle will be removed in 10 seconds...', 'primary', 5000)
            
            -- Wait 10 seconds
            Citizen.Wait(10000)
            
            -- Delete the vehicle if it still exists
            if TARGET_VEHICLE and DoesEntityExist(TARGET_VEHICLE) then
                -- Delete all brick props
                if MISSION_BRICKS and #MISSION_BRICKS > 0 then
                    local brickCount = 0
                    for k, brick in pairs(MISSION_BRICKS) do
                        if DoesEntityExist(brick) then
                            DeleteEntity(brick)
                            brickCount = brickCount + 1
                        end
                    end
                    MISSION_BRICKS = {}
                end
                
                SetEntityAsMissionEntity(TARGET_VEHICLE, true, true)
                DeleteVehicle(TARGET_VEHICLE)
                QBCore.Functions.Notify('Target vehicle has been cleaned up', 'success', 3000)
                TARGET_VEHICLE = nil
            end
        end)
    end
end

-- Function to restore wheels on a vehicle for a new mission
function RestoreWheelsForNewMission(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then
        return false
    end
    
    -- Check if any wheels are missing
    local wheelsNeedRestoring = false
    for i=0, 3 do
        local wheelOffset = GetVehicleWheelXOffset(vehicle, i)
        if wheelOffset == 9999999.0 then
            wheelsNeedRestoring = true
            break
        end
    end
    
    if wheelsNeedRestoring then
        -- Restore all wheels to the vehicle
        SetVehicleWheelXOffset(vehicle, 0, -0.88)  -- front left
        SetVehicleWheelXOffset(vehicle, 1, 0.88)   -- front right
        SetVehicleWheelXOffset(vehicle, 2, -0.88)  -- rear left
        SetVehicleWheelXOffset(vehicle, 3, 0.88)   -- rear right
        
        -- Force wheel update
        SetVehicleOnGroundProperly(vehicle)
        SetVehicleTyreFixed(vehicle, 0)
        SetVehicleTyreFixed(vehicle, 1)
        SetVehicleTyreFixed(vehicle, 2)
        SetVehicleTyreFixed(vehicle, 3)
        
        QBCore.Functions.Notify('Vehicle wheels have been restored for the new mission!', 'success', 5000)
        return true
    end
    
    return false
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    QBCore.Functions.GetPlayerData(function(PlayerData)
        if PlayerData.job then
            PLAYER_JOB = PlayerData.job.name
        end
    end)
end)

-- Function to check if entity is a car
function IsCar(entity)
    if not DoesEntityExist(entity) or not IsEntityAVehicle(entity) then
        return false
    end

    local entityModel = GetEntityModel(entity)
    if IsThisModelACar(entityModel) then
        return true
    else
        return false
    end
end

-- At the end of the file, add this event handler
RegisterNetEvent('ls_wheel_theft:Client:StartMission')
AddEventHandler('ls_wheel_theft:Client:StartMission', function(location, locationIndex)
    -- Add debug prints
    print("^2[wheel_theft] Client:StartMission event received")
    print("^2[wheel_theft] Location received: " .. json.encode(location))
    print("^2[wheel_theft] Location index: " .. tostring(locationIndex))
    
    -- Start the mission with the location provided by the server
    StartMission(location, locationIndex)
end)

-- Add a disconnection handler to free locations if a player disconnects
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        -- Free any occupied location before resource stops
        if CURRENT_LOCATION_INDEX then
            TriggerServerEvent('ls_wheel_theft:FreeLocation', CURRENT_LOCATION_INDEX)
            CURRENT_LOCATION_INDEX = nil
        end
    end
end)

-- Also free location on player disconnect
AddEventHandler('playerDropped', function()
    if CURRENT_LOCATION_INDEX then
        TriggerServerEvent('ls_wheel_theft:FreeLocation', CURRENT_LOCATION_INDEX)
    end
end)

-- Debug command to manually refresh target registration
RegisterCommand('wheeltheft_debug', function(source, args)
    if not DEBUG_MODE then return end
    
    local action = args[1] or 'help'
    
    if action == 'help' then
        print("^3[DEBUG] Available debug commands:")
        print("^3/wheeltheft_debug target - Force refresh target vehicle registration")
        print("^3/wheeltheft_debug truck - Force refresh truck registration")
        print("^3/wheeltheft_debug entities - Show all registered entity IDs")
        print("^3/wheeltheft_debug netinfo - Show network info for nearest vehicle")
        QBCore.Functions.Notify("DEBUG: Check console for command help", "primary", 3000)
    
    elseif action == 'target' then
        local player = PlayerPedId()
        local coords = GetEntityCoords(player)
        local vehicle = GetNearestVehicle(coords.x, coords.y, coords.z, 10.0)
        
        if DoesEntityExist(vehicle) then
            QBCore.Functions.Notify("DEBUG: Force refreshing target vehicle registration", "primary", 3000)
            RegisterTargetVehicleWithOxTarget(vehicle, vehicle == TARGET_VEHICLE)
        else
            QBCore.Functions.Notify("DEBUG: No vehicle found nearby", "error", 3000)
        end
    
    elseif action == 'truck' then
        local player = PlayerPedId()
        local coords = GetEntityCoords(player)
        local vehicle = GetNearestVehicle(coords.x, coords.y, coords.z, 10.0)
        
        if DoesEntityExist(vehicle) and IsVehicleATruck(vehicle) then
            QBCore.Functions.Notify("DEBUG: Force refreshing truck registration", "primary", 3000)
            RegisterTruckWithOxTarget(vehicle)
        else
            QBCore.Functions.Notify("DEBUG: No truck found nearby", "error", 3000)
        end
    
    elseif action == 'entities' then
        print("^3[DEBUG] Target vehicle NetIDs:")
        for i, netId in ipairs(targetVehicleNetIds) do
            print("^3" .. i .. ": " .. netId)
        end
        
        print("^3[DEBUG] Truck NetID: " .. (truckNetId or "none"))
        QBCore.Functions.Notify("DEBUG: Printed entity IDs to console", "primary", 3000)
    
    elseif action == 'netinfo' then
        local player = PlayerPedId()
        local coords = GetEntityCoords(player)
        local vehicle = GetNearestVehicle(coords.x, coords.y, coords.z, 10.0)
        
        if DoesEntityExist(vehicle) then
            DebugNetworkEntity(vehicle, "Nearest Vehicle")
        else
            QBCore.Functions.Notify("DEBUG: No vehicle found nearby", "error", 3000)
        end
    end
end, false)

-- Register trucks that have stored wheels with ox_target
function RegisterTruckForWheelRetrieval(vehicle)
    if not Config.target.enabled then return false end
    if not vehicle or not DoesEntityExist(vehicle) then return false end
    
    -- Force network registration for the entity if needed
    if not NetworkGetEntityIsNetworked(vehicle) then
        NetworkRegisterEntityAsNetworked(vehicle)
        Citizen.Wait(500)
    end
    
    -- Get network ID of the truck
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    
    -- Make sure network ID is valid
    if netId == 0 then
        if DEBUG_MODE then
            print("^1[DEBUG] Retrieval truck has invalid network ID (0)")
        end
        return false
    end
    
    -- Get the truck owner from entity state
    local ownerID = Entity(vehicle).state.OwnerID
    local myID = GetPlayerServerId(PlayerId())
    
    -- Only allow the owner to retrieve wheels
    if ownerID ~= myID then
        if DEBUG_MODE then
            print("^1[DEBUG] Cannot retrieve from truck - ownership verification failed")
            print("^1[DEBUG] Truck Owner: " .. tostring(ownerID) .. " | My ID: " .. myID)
        end
        return false
    end
    
    -- Don't register if it's already registered
    if truckNetId == netId then return false end
    
    -- If there was a previously registered truck, remove it
    if truckNetId then
        exports.ox_target:removeEntity(truckNetId)
    end
    
    truckNetId = netId
    
    -- Define options for the truck
    local options = {
        {
            name = 'ls_wheel_theft:take_wheel',
            icon = 'fas fa-hand-holding',
            label = 'Take Wheel Out',
            distance = 3.0,
            canInteract = function()
                -- Only show if:
                -- 1. Player is not holding a wheel
                -- 2. There are wheels stored
                -- 3. This player owns the truck
                return not HOLDING_WHEEL and #STORED_WHEELS > 0 and 
                       Entity(vehicle).state.OwnerID == GetPlayerServerId(PlayerId())
            end,
            onSelect = function()
                if not HOLDING_WHEEL and #STORED_WHEELS > 0 then
                    local wheelProp = PutWheelInHands()
                    HOLDING_WHEEL = wheelProp
                    DeleteEntity(STORED_WHEELS[#STORED_WHEELS])
                    table.remove(STORED_WHEELS, #STORED_WHEELS)
                    
                    -- If there are no more wheels, clean up the target
                    if #STORED_WHEELS == 0 and truckNetId then
                        exports.ox_target:removeEntity(truckNetId)
                        truckNetId = nil
                    end
                end
            end
        }
    }
    
    -- Add options to the truck
    exports.ox_target:addEntity(netId, options)
    return true
end

function PutWheelInTruckBed(vehicle, wheelIndex)
    local wheelBoneNames = {
        'wheel_lf',
        'wheel_rf',
        'wheel_lr',
        'wheel_rr'
    }

    -- Get wheel bone index
    local wheelIndex = wheelIndex or 1
    local boneIndex = GetEntityBoneIndexByName(vehicle, 'boot')
    
    if boneIndex == -1 then boneIndex = GetEntityBoneIndexByName(vehicle, 'trunk') end
    if boneIndex == -1 then boneIndex = GetEntityBoneIndexByName(vehicle, 'platelight') end
    if boneIndex == -1 then
        -- Fallback to a hardcoded position in the truck bed
        local vehCoords = GetEntityCoords(vehicle)
        local vehHeading = GetEntityHeading(vehicle)
        local pos = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -2.0, 0.0)
        return SpawnWheelPropAttached(vehicle, pos.x, pos.y, pos.z + 0.4)
    end
    
    local coords = GetWorldPositionOfEntityBone(vehicle, boneIndex)
    local wheelProp = SpawnWheelPropAttached(vehicle, coords.x, coords.y, coords.z + 0.4)
    
    -- Record this wheel as owned by this player but only locally
    -- This avoids state bag overflow issues
    local wheelInfo = {
        entity = wheelProp,
        netId = NetworkGetNetworkIdFromEntity(wheelProp),
        ownerId = GetPlayerServerId(PlayerId()),
        timestamp = GetGameTimer()
    }
    
    -- Store only locally to avoid state bag overflow
    table.insert(myWheelProps, wheelInfo)
    
    if DEBUG_MODE then
        print("^2[DEBUG] Stored wheel in truck. Local tracking only.")
    end
    
    return wheelProp
end

-- Event to receive wheel ownership check results - DISABLED to prevent state bag overflow
--[[
RegisterNetEvent('ls_wheel_theft:WheelOwnerResult')
AddEventHandler('ls_wheel_theft:WheelOwnerResult', function(wheelNetId, ownerId)
    local myServerId = GetPlayerServerId(PlayerId())
    
    if ownerId and tonumber(ownerId) == tonumber(myServerId) then
        -- This wheel is owned by me, I can interact with it
        if DEBUG_MODE then
            print("^2[DEBUG] Confirmed ownership of wheel: " .. wheelNetId)
            QBCore.Functions.Notify("DEBUG: You own wheel " .. wheelNetId, "success", 3000)
        end
    else
        -- This wheel is owned by someone else or has no owner
        if DEBUG_MODE then
            if ownerId then
                print("^3[DEBUG] Wheel " .. wheelNetId .. " is owned by player " .. ownerId)
                QBCore.Functions.Notify("DEBUG: Wheel " .. wheelNetId .. " belongs to player " .. ownerId, "error", 3000)
            else
                print("^3[DEBUG] Wheel " .. wheelNetId .. " has no registered owner")
                QBCore.Functions.Notify("DEBUG: Wheel " .. wheelNetId .. " has no owner", "primary", 3000)
            end
        end
    end
end)

-- Function to check wheel ownership with the server
function CheckWheelOwnership(wheelNetId)
    TriggerServerEvent('ls_wheel_theft:CheckWheelOwner', wheelNetId)
end
]]--

function CancelMission()
    MISSION_ACTIVATED = false

    -- Use the centralized blip cleanup function
    CleanupAllBlips()

    -- Free the location so other players can use it
    if CURRENT_LOCATION_INDEX then
        TriggerServerEvent('ls_wheel_theft:FreeLocation', CURRENT_LOCATION_INDEX)
        CURRENT_LOCATION_INDEX = nil
    end
    
    -- Reset mission owner ID
    MISSION_OWNER_ID = nil
    
    if DEBUG_MODE then
        print("^2[DEBUG] Mission cancelled, cleared mission ID")
        QBCore.Functions.Notify("DEBUG: Mission cancelled, ID cleared", "primary", 3000)
    end

    -- Despawn the work vehicle if it exists
    -- This ensures the truck is only removed when a player explicitly cancels the mission by speaking to the NPC
    -- The function is defined in truckSpawn.lua and handles vehicle cleanup
    DespawnWorkVehicle()

    -- Clean up any brick props left
    if MISSION_BRICKS and #MISSION_BRICKS > 0 then
        for _, brick in pairs(MISSION_BRICKS) do
            if DoesEntityExist(brick) then
                DeleteEntity(brick)
            end
        end
        MISSION_BRICKS = {}
    end
end