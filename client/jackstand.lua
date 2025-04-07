local waitTime = 5
local height = 0.18
local targetVehicleNetIds = {} -- Initialize at the top of the file to avoid nil references
-----------------------------------------------------------------------------------------------------------------------------------------------------
-- Function to check if vehicle is a car
-----------------------------------------------------------------------------------------------------------------------------------------------------
IsCar = function(veh)
    local vc = GetVehicleClass(veh)
    return (vc >= 0 and vc <= 7) or (vc >= 9 and vc <= 12) or (vc >= 17 and vc <= 20)
end

function CanRaiseVehicle(vehicle)
    local permTable = Config.jackSystem['raise']

    if TARGET_VEHICLE then
        if  vehicle == TARGET_VEHICLE then
            return true
        end
    end

    if permTable.everyone or Contains(permTable.jobs, PLAYER_JOB) then
        return true
    end

    return false
end

function CanLowerVehicle(vehicle)
    local permTable = Config.jackSystem['lower']

    if TARGET_VEHICLE then
        if  vehicle == TARGET_VEHICLE then
            return true
        end
    end

    if permTable.everyone or Contains(permTable.jobs, PLAYER_JOB) then
        return true
    end

    return false
end

-- Helper function for vector to string conversion (used in debug)
function vec2str(vec)
    if not vec then return "nil" end
    return string.format("%.2f, %.2f, %.2f", vec.x, vec.y, vec.z)
end

function RaiseCar()
    -- Verify player job if jobOnly is enabled
    if Config.job.jobOnly and not JobCheck() then
        QBCore.Functions.Notify(L('job_not_allowed'), 'error', 5000)
        return false
    end
    
    -- Get the vehicle in front of the player
    local player = PlayerPedId()
    local coords = GetEntityCoords(player)
    local vehicle = nil
    
    -- Check if we have a TARGET_VEHICLE first (for mission)
    if TARGET_VEHICLE and DoesEntityExist(TARGET_VEHICLE) then
        local targetCoords = GetEntityCoords(TARGET_VEHICLE)
        if #(coords - targetCoords) < 10.0 then
            vehicle = TARGET_VEHICLE
        else
            QBCore.Functions.Notify(L('vehicle_too_far'), 'error', 5000)
            return false
        end
    else
        -- If no target vehicle or not close enough, try to find any vehicle
        vehicle = GetVehicleInDirection()
        
        if not vehicle then
            QBCore.Functions.Notify(L('no_vehicle_found'), 'error', 5000)
            return false
        end
    end
    
    -- Make sure it's a car
    if not IsCar(vehicle) then
        QBCore.Functions.Notify(L('not_a_car'), 'error', 5000)
        return false
    end
    
    -- Check if player can raise any car or just TARGET_VEHICLE
    if not CanRaiseVehicle(vehicle) then
        QBCore.Functions.Notify(L('not_allowed_raise'), 'error', 5000)
        return false
    end
    
    -- Check if vehicle is already raised
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if Entity(vehicle).state.IsVehicleRaised then
        QBCore.Functions.Notify('Vehicle is already raised', 'error', 5000)
        return false
    end
    
    QBCore.Functions.Notify(L('raising_car'), 'primary', 7000)
    
    -- Remove jackstand item from inventory
    TriggerServerEvent('ls_wheel_theft:server:removeItem', Config.jackStandName)
    
    -- Determine which side of the vehicle the player is on
    local playerPed = PlayerPedId()
    local vehCoords = GetEntityCoords(vehicle)
    local playerCoords = GetEntityCoords(playerPed)
    
    -- Get vehicle dimensions
    local min, max = GetModelDimensions(GetEntityModel(vehicle))
    local vehicleWidth = max.x - min.x
    
    -- Calculate relative position to determine which side of the vehicle the player is on
    local vehicleHeading = GetEntityHeading(vehicle)
    local vehicleHeadingRad = math.rad(vehicleHeading)
    local relativeX = (playerCoords.x - vehCoords.x) * math.cos(vehicleHeadingRad) + 
                      (playerCoords.y - vehCoords.y) * math.sin(vehicleHeadingRad)
    
    -- Determine if player is on the left or right side
    local isOnRightSide = relativeX > 0
    
    -- Calculate the position where the player should move to
    local offsetX = isOnRightSide and (vehicleWidth/2 + 0.5) or -(vehicleWidth/2 + 0.5)
    local positionOffset = vector3(offsetX, 0.0, 0.0)
    
    -- Calculate the world position
    local worldOffset = GetOffsetFromEntityInWorldCoords(vehicle, positionOffset.x, positionOffset.y, positionOffset.z)
    
    -- Move player to position with increased height adjustment to prevent ground clipping
    local _, groundZ = GetGroundZFor_3dCoord(worldOffset.x, worldOffset.y, worldOffset.z, true)
    SetEntityCoordsNoOffset(playerPed, worldOffset.x, worldOffset.y, groundZ + 1.0, false, false, false)
    
    -- Calculate heading based on which side of the vehicle the player is on
    -- If player is on the left side, face right (90 degrees from vehicle heading)
    -- If player is on the right side, face left (270 degrees from vehicle heading)
    local targetHeading = 0
    if isOnRightSide then
        targetHeading = (vehicleHeading + 90) % 360
    else
        targetHeading = (vehicleHeading + 270) % 360
    end
    
    -- Set player heading
    SetEntityHeading(playerPed, targetHeading)
    
    -- Set the animation to make player lie down (mechanic animation)
    local animDict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@"
    local anim = "machinic_loop_mechandplayer"
    local flags = 1 -- Non-looping animation
    local animTime = 5000
    
    RequestAnimDict(animDict)
    local timeout = 1000
    while not HasAnimDictLoaded(animDict) and timeout > 0 do
        Citizen.Wait(10)
        timeout = timeout - 10
    end
    
    if HasAnimDictLoaded(animDict) then
        -- Make player lie down under the vehicle
        TaskPlayAnim(playerPed, animDict, anim, 8.0, -8.0, animTime, flags, 0, false, false, false)
        
        -- Freeze player in position during animation
        FreezeEntityPosition(playerPed, true)
    else
        QBCore.Functions.Notify('Animation failed to load, continuing...', 'primary', 2000)
    end
    
    -- Attach jack stands to vehicle
    Citizen.Wait(500) -- Wait a moment to let animation start
    AttachJackStandsToVehicle(vehicle)
    
    -- Handle the rest of the process after animation
    Citizen.CreateThread(function()
        -- Wait for animation to complete
        Citizen.Wait(animTime)
        
        -- Unfreeze player and clear animation
        FreezeEntityPosition(playerPed, false)
        ClearPedTasks(playerPed)
        
        QBCore.Functions.Notify(L('car_raised'), 'success', 7000)
        
        -- Wait a moment for entity states to update (important!)
        Citizen.Wait(500)
        
        -- Set the IsVehicleRaised state and store plate for saving
        local plate = GetVehicleNumberPlateText(vehicle)
        TriggerServerEvent('ls_wheel_theft:server:setIsRaised', netId, plate, true)
        
        -- Wait for state to sync
        Citizen.Wait(500)
        
        -- Double-check that state was set
        if not Entity(vehicle).state.IsVehicleRaised then
            -- Force set it again if needed
            TriggerServerEvent('ls_wheel_theft:server:setIsRaised', netId, plate, true)
            Citizen.Wait(200)
        end
        
        -- Verify the state was set properly before registering with target
        if Entity(vehicle).state.IsVehicleRaised then
            -- Setup target options for the raised vehicle
            RegisterTargetVehicleWithOxTarget(vehicle)
        else
            QBCore.Functions.Notify('Failed to set vehicle state. Try again.', 'error', 5000)
        end
    end)
    
    return true
end

function FinishJackstand(object)
    local rot = GetEntityRotation(object, 5)
    DetachEntity(object)
    FreezeEntityPosition(object, true)

    local coords = GetEntityCoords(object)
    local _, ground = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 2.0, true)
    SetEntityCoords(object, coords.x, coords.y, ground, false, false, false, false)
    PlaceObjectOnGroundProperly_2(object)
    SetEntityRotation(object, rot.x, rot.y, rot.z, 5, 0)
    SetEntityCollision(object, false, true)
end

function AttachJackToCar(object, vehicle)
    local offset = GetOffsetFromEntityGivenWorldCoords(vehicle, GetEntityCoords(object))

    FreezeEntityPosition(object, false)
    AttachEntityToEntity(object, vehicle, 0, offset, 0.0, 0.0, 90.0, 0, 0, 0, 0, 0, 1)
end

if not targetVehicleNetIds then
    targetVehicleNetIds = {}
end

function RegisterTargetVehicleWithOxTarget(vehicle)
    if not Config.target.enabled then return end
    if not vehicle or not DoesEntityExist(vehicle) then return end
    
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    
    -- Only register if vehicle is raised
    if not Entity(vehicle).state.IsVehicleRaised then
        QBCore.Functions.Notify('Vehicle must be raised to register wheels', 'error', 3000)
        return
    end
    
    -- Clear any existing target options for this vehicle to prevent duplicates
    exports.ox_target:removeEntity(netId)
    
    -- Remove any existing target vehicle from the tracking array if it's the same vehicle
    for i, v in ipairs(targetVehicleNetIds) do
        if v == netId then
            table.remove(targetVehicleNetIds, i)
            break
        end
    end
    
    -- Check if this is the mission target vehicle
    local isTargetVehicle = (vehicle == TARGET_VEHICLE) or Entity(vehicle).state.IsMissionTarget
    
    -- Define wheel bone names and indices
    local wheels = {
        { bone = 'wheel_lf', index = 0, label = 'Steal Front-Left Wheel' },
        { bone = 'wheel_rf', index = 1, label = 'Steal Front-Right Wheel' },
        { bone = 'wheel_lr', index = 2, label = 'Steal Rear-Left Wheel' },
        { bone = 'wheel_rr', index = 3, label = 'Steal Rear-Right Wheel' }
    }
    
    -- Define target options for each wheel
    local options = {}
    for _, wheel in ipairs(wheels) do
        table.insert(options, {
            name = 'wheel_theft_wheel_' .. wheel.index,
            icon = 'fas fa-wrench',
            label = wheel.label,
            bones = { wheel.bone },
            distance = 1.5,
            canInteract = function()
                return Entity(vehicle).state.IsVehicleRaised
            end,
            onSelect = function()
                local coordsTable = nil -- Not needed for this call
                StartWheelDismount(vehicle, wheel.index, false, true, coordsTable, false)
            end
        })
    end
    
    -- For target vehicles, only add the Finish Stealing option
    -- For non-target vehicles, add the simple finish option
    if isTargetVehicle then
        -- This is the target vehicle from the mission
        table.insert(options, {
            name = 'ls_wheel_theft:finish_stealing',
            icon = 'fas fa-check',
            label = 'Finish Stealing',
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
                local lowered = LowerVehicle()
                while not lowered do
                    Citizen.Wait(100)
                end
                SpawnBricksUnderVehicle(vehicle)
                TriggerServerEvent('ls_wheel_theft:RetrieveItem', Config.jackStandName)
                
                -- Remove mission blip and area blip
                if MISSION_BLIP and DoesBlipExist(MISSION_BLIP) then
                    RemoveBlip(MISSION_BLIP)
                    MISSION_BLIP = nil
                end
                
                if MISSION_AREA and DoesBlipExist(MISSION_AREA) then
                    RemoveBlip(MISSION_AREA)
                    MISSION_AREA = nil
                end
                
                -- Remove the vehicle from targeting
                if netId and Contains(targetVehicleNetIds, netId) then
                    exports.ox_target:removeEntity(netId)
                    for i, v in ipairs(targetVehicleNetIds) do
                        if v == netId then
                            table.remove(targetVehicleNetIds, i)
                            break
                        end
                    end
                end
                
                -- Start wheel theft now
                EnableSale()
                
                -- Schedule vehicle cleanup
                CleanupMissionVehicle()
            end
        })
    else
        -- This is a regular vehicle, not the target vehicle
        table.insert(options, {
            name = 'wheel_theft_finish',
            icon = 'fas fa-check',
            label = 'Retrieve Jackstand',
            distance = 2.5,
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
                -- Lower the vehicle and retrieve jackstand
                local lowered = LowerVehicle(false, true)
                Citizen.Wait(1000)
                SpawnBricksUnderVehicle(vehicle)
                TriggerServerEvent('ls_wheel_theft:RetrieveItem', Config.jackStandName)
                
                -- Remove the vehicle from targeting
                if netId then
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
    
    -- Add the options to the vehicle
    exports.ox_target:addEntity(netId, options)
    
    -- Add to tracking table
    table.insert(targetVehicleNetIds, netId)
    
    QBCore.Functions.Notify('Wheels are now ready for theft', 'success', 3000)
end

function LowerVehicle(errorCoords, bypass)
    working = false

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local veh, netId = GetNearestVehicle(playerCoords.x, playerCoords.y, playerCoords.z, 5.0)

    if veh and (Entity(veh).state.IsVehicleRaised or Entity(veh).state.spacerOnKqCarLift) then

        if DoesVehicleHaveAllWheels(veh) and not bypass then
            QBCore.Functions.Notify('Finish the job', 'inform', 5000)
            return false
        end

        if Entity(veh).state.IsVehicleRaised then
            -- Determine which side of the vehicle the player is on
            local vehCoords = GetEntityCoords(veh)
            
            -- Get vehicle dimensions
            local min, max = GetModelDimensions(GetEntityModel(veh))
            local vehicleWidth = max.x - min.x
            
            -- Calculate relative position to determine which side of the vehicle the player is on
            local vehicleHeading = GetEntityHeading(veh)
            local vehicleHeadingRad = math.rad(vehicleHeading)
            local relativeX = (playerCoords.x - vehCoords.x) * math.cos(vehicleHeadingRad) + 
                              (playerCoords.y - vehCoords.y) * math.sin(vehicleHeadingRad)
            
            -- Determine if player is on the left or right side
            local isOnRightSide = relativeX > 0
            
            -- Calculate the position where the player should move to
            local offsetX = isOnRightSide and (vehicleWidth/2 + 0.5) or -(vehicleWidth/2 + 0.5)
            local positionOffset = vector3(offsetX, 0.0, 0.0)
            
            -- Calculate the world position
            local worldOffset = GetOffsetFromEntityInWorldCoords(veh, positionOffset.x, positionOffset.y, positionOffset.z)
            
            -- Move player to position with increased height adjustment to prevent ground clipping
            local _, groundZ = GetGroundZFor_3dCoord(worldOffset.x, worldOffset.y, worldOffset.z, true)
            SetEntityCoordsNoOffset(playerPed, worldOffset.x, worldOffset.y, groundZ + 1.0, false, false, false)
            
            -- Calculate heading based on which side of the vehicle the player is on
            -- If player is on the left side, face right (90 degrees from vehicle heading)
            -- If player is on the right side, face left (270 degrees from vehicle heading)
            local targetHeading = 0
            if isOnRightSide then
                targetHeading = (vehicleHeading + 90) % 360
            else
                targetHeading = (vehicleHeading + 270) % 360
            end
            
            -- Set player heading
            SetEntityHeading(playerPed, targetHeading)
            
            -- Set the animation to make player lie down (mechanic animation)
            local animDict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@"
            local anim = "machinic_loop_mechandplayer"
            local flags = 1 -- Non-looping animation
            local animTime = 5000
            
            RequestAnimDict(animDict)
            local timeout = 1000
            while not HasAnimDictLoaded(animDict) and timeout > 0 do
                Citizen.Wait(10)
                timeout = timeout - 10
            end
            
            if HasAnimDictLoaded(animDict) then
                -- Make player lie down under the vehicle
                TaskPlayAnim(playerPed, animDict, anim, 8.0, -8.0, animTime, flags, 0, false, false, false)
                
                -- Freeze player in position during animation
                FreezeEntityPosition(playerPed, true)
            else
                QBCore.Functions.Notify('Animation failed to load, continuing...', 'primary', 2000)
            end
            
            -- Play sounds for removing jackstands
            PlaySoundFrontend(-1, "TOOL_BOX_ACTION_GENERIC", "GTAO_FM_VEHICLE_ARMORY_RADIO_SOUNDS", 0)
            Citizen.Wait(1000)

            NetworkRequestControlOfEntity(veh)

            local timeout = 2000
            while not NetworkHasControlOfEntity(veh) and timeout > 0 do
                Citizen.Wait(100)
                timeout = timeout - 100
            end

            local vehpos = GetEntityCoords(veh)
            
            -- Play hydraulic lowering sound
            PlaySoundFrontend(-1, "VEHICLES_TRANSIT_HYDRAULIC_DOWN", "VEHICLES_TRANSIT_SOUND", 0)

            -- Store jackstand positions and detach them BEFORE lowering the vehicle
            local jackStandEntities = {}
            for i = 1, 4 do
                if Entity(veh).state['jackStand' .. i] then
                    local jackNetId = Entity(veh).state['jackStand' .. i]
                    local jackEntity = NetworkGetEntityFromNetworkId(jackNetId)
                    
                    if DoesEntityExist(jackEntity) then
                        -- Add to our tracking table
                        jackStandEntities[i] = jackEntity
                        
                        -- Save original position and rotation
                        local jackPos = GetEntityCoords(jackEntity)
                        local jackRot = GetEntityRotation(jackEntity, 2)
                        
                        -- Detach from vehicle if attached
                        if IsEntityAttachedToEntity(jackEntity, veh) then
                            DetachEntity(jackEntity, true, true)
                            
                            -- Restore position and freeze in place
                            SetEntityCoordsNoOffset(jackEntity, jackPos.x, jackPos.y, jackPos.z, false, false, false)
                            SetEntityRotation(jackEntity, jackRot.x, jackRot.y, jackRot.z, 2, true)
                            FreezeEntityPosition(jackEntity, true)
                        end
                    end
                end
            end

            -- Also handle extension jacks
            for i = 1, 4 do
                if Entity(veh).state['jackExtension' .. i] then
                    local extensionNetId = Entity(veh).state['jackExtension' .. i]
                    local extensionEntity = NetworkGetEntityFromNetworkId(extensionNetId)
                    
                    if DoesEntityExist(extensionEntity) and IsEntityAttachedToEntity(extensionEntity, veh) then
                        DetachEntity(extensionEntity, true, true)
                    end
                end
            end

            -- Now lower only the vehicle
            local removeZ = 0
            local targetLowerAmount = 0.18

            while removeZ < targetLowerAmount do
                removeZ = removeZ + 0.001
                SetEntityCoordsNoOffset(veh, vehpos.x, vehpos.y, vehpos.z - removeZ, true, true, true)
                Citizen.Wait(waitTime)
            end

            -- Freeze vehicle temporarily
            FreezeEntityPosition(veh, true)
            
            -- Play sound effects for removing jackstands
            for i = 4, 1, -1 do
                if jackStandEntities[i] and DoesEntityExist(jackStandEntities[i]) then
                    -- Play sound effect for each jackstand removal
                    PlaySoundFrontend(-1, "REMOVE_TOOL", "GTAO_FM_VEHICLE_ARMORY_RADIO_SOUNDS", 0)
                    Citizen.Wait(200)
                end
            end

            -- Delete jackstands after the vehicle is lowered
            for i = 4, 1, -1 do
                if Entity(veh).state['jackStand' .. i] then
                    local jackNetId = Entity(veh).state['jackStand' .. i]
                    TriggerServerEvent('ls_wheel_theft:server:forceDeleteJackStand', jackNetId)
                end
            end
            
            -- Also delete extension jacks if they exist
            for i = 4, 1, -1 do
                if Entity(veh).state['jackExtension' .. i] then
                    local extensionNetId = Entity(veh).state['jackExtension' .. i]
                    TriggerServerEvent('ls_wheel_theft:server:forceDeleteJackStand', extensionNetId)
                end
            end

            Citizen.Wait(100)
            
            -- Unfreeze vehicle and player after jackstands are removed
            FreezeEntityPosition(veh, false)
            FreezeEntityPosition(playerPed, false)
            
            -- Clear animation
            ClearPedTasks(playerPed)

            -- Update vehicle state
            TriggerServerEvent('ls_wheel_theft:server:setIsRaised', netId, false)
            
            -- Return jackstand item to player's inventory
            TriggerServerEvent('ls_wheel_theft:server:addItem', Config.jackStandName, 1)
            QBCore.Functions.Notify('You recovered your jackstand', 'success', 7000)
            
            -- Clean up all mission-related blips to ensure none are left behind
            CleanupAllBlips()
            
            -- Notify player
            QBCore.Functions.Notify('Vehicle lowered and jackstands retrieved.', 'success', 7000)
        else
            TriggerServerEvent('ls_wheel_theft:server:setIsRaised', netId, false)
            FreezeEntityPosition(veh, false)
        end

        return true
    end
    
    return false
end

-- Function to attach jack stands to vehicle at wheel positions
function AttachJackStandsToVehicle(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return end
    
    -- Calculate positions for jackstands using vehicle dimensions
    local vehpos = GetEntityCoords(vehicle)
    local min, max = GetModelDimensions(GetEntityModel(vehicle))
    local width = ((max.x - min.x) / 2) - ((max.x - min.x) / 3.3)
    local length = ((max.y - min.y) / 2) - ((max.y - min.y) / 3.3)
    local zOffset = 0.5
    
    -- Get vehicle heading and convert to radians for precise positioning
    local vehHeading = GetEntityHeading(vehicle)
    local headingRad = math.rad(vehHeading)
    
    -- Request jackstand model
    local model = 'imp_prop_axel_stand_01a'
    RequestModel(model)
    
    -- Wait for model to load
    local modelTimeout = 10000
    while not HasModelLoaded(model) and modelTimeout > 0 do
        Citizen.Wait(100)
        modelTimeout = modelTimeout - 100
    end
    
    if not HasModelLoaded(model) then
        QBCore.Functions.Notify('Failed to load jackstand model', 'error', 5000)
        return false
    end
    
    -- Freeze vehicle to prevent movement during lifting
    FreezeEntityPosition(vehicle, true)
    
    -- Play sound when jackstand placement is started
    PlaySoundFrontend(-1, "TOOL_BOX_ACTION_GENERIC", "GTAO_FM_VEHICLE_ARMORY_RADIO_SOUNDS", 0)
    
    -- Calculate jackstand positions using heading for proper positioning
    -- Use trig functions to place jackstands relative to vehicle orientation
    local frontLeftOffset = vector3(-width, length, 0)
    local frontRightOffset = vector3(width, length, 0)
    local rearLeftOffset = vector3(-width, -length, 0)
    local rearRightOffset = vector3(width, -length, 0)
    
    -- Rotate the offsets based on vehicle heading
    local function rotateVector(vec, heading)
        local headingRad = math.rad(heading)
        local cosHeading = math.cos(headingRad)
        local sinHeading = math.sin(headingRad)
        return vector3(
            vec.x * cosHeading - vec.y * sinHeading,
            vec.x * sinHeading + vec.y * cosHeading,
            vec.z
        )
    end
    
    -- Rotate the offsets based on vehicle heading
    local flOffset = rotateVector(frontLeftOffset, vehHeading)
    local frOffset = rotateVector(frontRightOffset, vehHeading)
    local rlOffset = rotateVector(rearLeftOffset, vehHeading)
    local rrOffset = rotateVector(rearRightOffset, vehHeading)
    
    -- Calculate world positions for jackstands
    local flPosition = vector3(vehpos.x + flOffset.x, vehpos.y + flOffset.y, vehpos.z)
    local frPosition = vector3(vehpos.x + frOffset.x, vehpos.y + frOffset.y, vehpos.z)
    local rlPosition = vector3(vehpos.x + rlOffset.x, vehpos.y + rlOffset.y, vehpos.z)
    local rrPosition = vector3(vehpos.x + rrOffset.x, vehpos.y + rrOffset.y, vehpos.z)
    
    -- Get precise ground positions for each jackstand
    local _, flGroundZ = GetGroundZFor_3dCoord(flPosition.x, flPosition.y, flPosition.z, true)
    local _, frGroundZ = GetGroundZFor_3dCoord(frPosition.x, frPosition.y, frPosition.z, true)
    local _, rlGroundZ = GetGroundZFor_3dCoord(rlPosition.x, rlPosition.y, rlPosition.z, true)
    local _, rrGroundZ = GetGroundZFor_3dCoord(rrPosition.x, rrPosition.y, rrPosition.z, true)
    
    -- Create jackstands at ground level
    local flWheelStand = CreateObject(GetHashKey(model), flPosition.x, flPosition.y, flGroundZ, true, true, true)
    PlaceObjectOnGroundProperly(flWheelStand)
    Citizen.Wait(100)
    PlaySoundFrontend(-1, "TOOL_BOX_ACTION_GENERIC", "GTAO_FM_VEHICLE_ARMORY_RADIO_SOUNDS", 0)
    
    local frWheelStand = CreateObject(GetHashKey(model), frPosition.x, frPosition.y, frGroundZ, true, true, true)
    PlaceObjectOnGroundProperly(frWheelStand)
    Citizen.Wait(100)
    PlaySoundFrontend(-1, "TOOL_BOX_ACTION_GENERIC", "GTAO_FM_VEHICLE_ARMORY_RADIO_SOUNDS", 0)
    
    local rlWheelStand = CreateObject(GetHashKey(model), rlPosition.x, rlPosition.y, rlGroundZ, true, true, true)
    PlaceObjectOnGroundProperly(rlWheelStand)
    Citizen.Wait(100)
    PlaySoundFrontend(-1, "TOOL_BOX_ACTION_GENERIC", "GTAO_FM_VEHICLE_ARMORY_RADIO_SOUNDS", 0)
    
    local rrWheelStand = CreateObject(GetHashKey(model), rrPosition.x, rrPosition.y, rrGroundZ, true, true, true)
    PlaceObjectOnGroundProperly(rrWheelStand)
    PlaySoundFrontend(-1, "TOOL_BOX_ACTION_GENERIC", "GTAO_FM_VEHICLE_ARMORY_RADIO_SOUNDS", 0)
    
    -- Calculate rotation angles for jackstands
    -- Front jackstands should face inward toward the vehicle
    -- Rear jackstands should face outward from the vehicle
    local flRot = vector3(0.0, 0.0, vehHeading - 90.0)
    local frRot = vector3(0.0, 0.0, vehHeading - 90.0)
    local rlRot = vector3(0.0, 0.0, vehHeading + 90.0)
    local rrRot = vector3(0.0, 0.0, vehHeading + 90.0)
    
    -- Apply rotations to jackstands
    SetEntityRotation(flWheelStand, flRot.x, flRot.y, flRot.z, 2, true)
    SetEntityRotation(frWheelStand, frRot.x, frRot.y, frRot.z, 2, true)
    SetEntityRotation(rlWheelStand, rlRot.x, rlRot.y, rlRot.z, 2, true)
    SetEntityRotation(rrWheelStand, rrRot.x, rrRot.y, rrRot.z, 2, true)
    
    -- Get precise positions after placement
    local flStandPos = GetEntityCoords(flWheelStand)
    local frStandPos = GetEntityCoords(frWheelStand)
    local rlStandPos = GetEntityCoords(rlWheelStand)
    local rrStandPos = GetEntityCoords(rrWheelStand)
    
    -- Set collision properties
    SetEntityCollision(flWheelStand, false, true)
    SetEntityCollision(frWheelStand, false, true)
    SetEntityCollision(rlWheelStand, false, true)
    SetEntityCollision(rrWheelStand, false, true)
    
    -- Save jacks to entity state for later removal
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    TriggerServerEvent('ls_wheel_theft:server:saveJacks', netId, 
        NetworkGetNetworkIdFromEntity(flWheelStand), 
        NetworkGetNetworkIdFromEntity(frWheelStand), 
        NetworkGetNetworkIdFromEntity(rlWheelStand), 
        NetworkGetNetworkIdFromEntity(rrWheelStand), 
        true
    )
    
    -- Create thread for lifting the vehicle with simple approach
    Citizen.CreateThread(function()
        -- Get initial vehicle position
        local initialPos = GetEntityCoords(vehicle)
        
        -- Request network control of vehicle
        NetworkRequestControlOfEntity(vehicle)
        local timeout = 2000
        while not NetworkHasControlOfEntity(vehicle) and timeout > 0 do
            Citizen.Wait(100)
            timeout = timeout - 100
        end
        
        -- Play hydraulic lift sound
        PlaySoundFrontend(-1, "VEHICLES_TRANSIT_HYDRAULIC_UP", "VEHICLES_TRANSIT_SOUND", 0)
        
        -- Unfreeze vehicle temporarily to allow lifting
        FreezeEntityPosition(vehicle, false)
        Citizen.Wait(100)
        
        -- Implement gradual lifting animation - simplified approach
        local addZ = 0
        local liftHeight = 0.35 -- Target lift height
        
        while addZ < liftHeight do
            addZ = addZ + 0.001
            SetEntityCoordsNoOffset(vehicle, initialPos.x, initialPos.y, initialPos.z + addZ, true, true, true)
            Citizen.Wait(waitTime)
        end
        
        -- Freeze vehicle in raised position
        FreezeEntityPosition(vehicle, true)
        
        -- Reattach jackstands to the vehicle in final position
        AttachJackToCar(flWheelStand, vehicle)
        AttachJackToCar(frWheelStand, vehicle)
        AttachJackToCar(rlWheelStand, vehicle)
        AttachJackToCar(rrWheelStand, vehicle)
        
        -- Check if vehicle was actually raised
        local finalPos = GetEntityCoords(vehicle)
        local actualLift = finalPos.z - initialPos.z
        
        -- Set decor to mark vehicle as raised
        DecorSetBool(vehicle, "WHEEL_THEFT_LIFTED", true)
        
        -- Play jackstand placement sound
        PlaySoundFrontend(-1, "JACK_VEHICLE", "HUD_MINI_GAME_SOUNDSET", 0)
        Citizen.Wait(200)
        PlaySoundFrontend(-1, "CONFIRM_BEEP", "HUD_MINI_GAME_SOUNDSET", 0)
        
        -- Create extension objects for each jackstand (visual only)
        local extensionModel = 'prop_tool_jack'
        RequestModel(extensionModel)
        
        local modelTimeout = 5000
        while not HasModelLoaded(extensionModel) and modelTimeout > 0 do
            Citizen.Wait(100)
            modelTimeout = modelTimeout - 100
        end
        
        if HasModelLoaded(extensionModel) then
            local flExtension = CreateObject(GetHashKey(extensionModel), flStandPos.x, flStandPos.y, flStandPos.z, true, true, true)
            local frExtension = CreateObject(GetHashKey(extensionModel), frStandPos.x, frStandPos.y, frStandPos.z, true, true, true)
            local rlExtension = CreateObject(GetHashKey(extensionModel), rlStandPos.x, rlStandPos.y, rlStandPos.z, true, true, true)
            local rrExtension = CreateObject(GetHashKey(extensionModel), rrStandPos.x, rrStandPos.y, rrStandPos.z, true, true, true)
            
            -- Hide extensions (they're just for server tracking)
            SetEntityVisible(flExtension, false, false)
            SetEntityVisible(frExtension, false, false)
            SetEntityVisible(rlExtension, false, false)
            SetEntityVisible(rrExtension, false, false)
            
            -- Save extensions to entity state
            TriggerServerEvent('ls_wheel_theft:server:saveExtensionJacks', netId, 
                NetworkGetNetworkIdFromEntity(flExtension), 
                NetworkGetNetworkIdFromEntity(frExtension), 
                NetworkGetNetworkIdFromEntity(rlExtension), 
                NetworkGetNetworkIdFromEntity(rrExtension)
            )
        end
        
        -- Send success notification
        QBCore.Functions.Notify('Vehicle raised with jackstands', 'success', 3000)
    end)
    
    return true
end

function LiftWithBackupMethod(veh, vehicle, liftAmount)
    local initialPos = GetEntityCoords(veh)
    
    if Config.debug then
        -- Only show these notifications in debug mode
        QBCore.Functions.Notify('Initial pos: ' .. vec2str(initialPos), 'primary', 3000)
    end
    
    local success = true
    
    -- Try to lift up the vehicle by setting higher coordinates
    local newZ = initialPos.z + liftAmount
    SetEntityCoordsNoOffset(veh, initialPos.x, initialPos.y, newZ, true, true, true)
    
    -- Check if the lift succeeded
    Citizen.Wait(500)
    local finalPos = GetEntityCoords(veh)
    local actualLift = finalPos.z - initialPos.z
    
    if Config.debug then
        -- Only show these notifications in debug mode
        QBCore.Functions.Notify('Final pos: ' .. vec2str(finalPos), 'primary', 3000)
        QBCore.Functions.Notify('Lift amount: ' .. tostring(actualLift), 'primary', 3000)
    end
    
    -- If lift didn't succeed, try the fallback method
    if actualLift < (liftAmount * 0.5) then
        if Config.debug then
            QBCore.Functions.Notify('First lift failed, trying backup method', 'error', 3000)
        end
        
        -- Freeze vehicle position
        FreezeEntityPosition(veh, true)
        
        -- Try to set coordinates more forcefully
        SetEntityCoordsNoOffset(veh, initialPos.x, initialPos.y, initialPos.z + liftAmount, false, false, false)
        
        Citizen.Wait(500)
        finalPos = GetEntityCoords(veh)
        actualLift = finalPos.z - initialPos.z
        
        if Config.debug then
            QBCore.Functions.Notify('Second attempt lift: ' .. tostring(actualLift), 'primary', 3000)
        end
    end
    
    return actualLift >= (liftAmount * 0.5)
end
