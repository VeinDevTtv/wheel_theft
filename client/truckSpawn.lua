-- Global variable to track the work vehicle so we can despawn it later
WORK_VEHICLE = nil

function SpawnTruck(truckModel)
    -- Find an available spawn point
    local spawnPoint = nil
    
    for _, coords in ipairs(Config.spawnPickupTruck.truckSpawnCoords) do
        -- Check if the area is clear
        local isClear = IsAreaClear(vector3(coords.x, coords.y, coords.z), 3.0)
        
        if isClear then
            spawnPoint = coords
            break
        end
    end
    
    -- No available spawn point found
    if not spawnPoint then
        QBCore.Functions.Notify('No seats available at the moment', 'error', 5000)
        return nil
    end
    
    -- Convert model name to hash
    local modelHash = GetHashKey(truckModel)
    
    -- Request the model
    RequestModel(modelHash)
    
    -- Wait for the model to load
    local timeout = 10000
    while not HasModelLoaded(modelHash) and timeout > 0 do
        Citizen.Wait(100)
        timeout = timeout - 100
    end
    
    if timeout <= 0 then
        QBCore.Functions.Notify('Model failed to load in time', 'error', 5000)
        return nil
    end
    
    -- Spawn the vehicle
    local vehicle = CreateVehicle(modelHash, spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.h, true, false)
    
    -- Set as mission entity so it doesn't despawn
    SetEntityAsMissionEntity(vehicle, true, true)
    
    -- Set vehicle properties
    SetVehicleDoorsLocked(vehicle, 0)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    
    -- Make the player the driver
    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
    
    -- Create a blip for the vehicle if it's not already being driven
    TRUCK_BLIP = AddBlipForEntity(vehicle)
    SetBlipSprite(TRUCK_BLIP, 227)  -- Sprite ID for a car
    SetBlipColour(TRUCK_BLIP, 3)    -- Yellow color
    SetBlipAsShortRange(TRUCK_BLIP, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Your Truck")
    EndTextCommandSetBlipName(TRUCK_BLIP)
    
    TRUCK_VEHICLE = vehicle
    
    return vehicle
end

function IsPlaceTaken(index)
    local truckTable = Config.spawnPickupTruck
    local coords = truckTable.truckSpawnCoords[index]

    local vehicle = GetNearestVehicle(coords.x, coords.y, coords.z, 1.0)

    if vehicle then
        return true
    else
        return false
    end
end

-- Function katdepawni mission fach t'cancella
function DespawnWorkVehicle()
    if WORK_VEHICLE and DoesEntityExist(WORK_VEHICLE) then
        QBCore.Functions.Notify('Removing work vehicle...', 'primary', 3000)
        
        -- Delete any wheels in the vehicle
        if STORED_WHEELS and #STORED_WHEELS > 0 then
            for i=1, #STORED_WHEELS do
                if DoesEntityExist(STORED_WHEELS[i]) then
                    DeleteEntity(STORED_WHEELS[i])
                end
            end
            STORED_WHEELS = {}
        end
        
        -- Mark as mission entity so it can be deleted
        SetEntityAsMissionEntity(WORK_VEHICLE, true, true)
        
        -- Delete the vehicle
        DeleteVehicle(WORK_VEHICLE)
        
        -- Reset the global variable
        WORK_VEHICLE = nil
        
        QBCore.Functions.Notify('Work vehicle removed!', 'success', 3000)
    end
    
    -- Ensure target vehicle is also cleaned up
    if TARGET_VEHICLE and DoesEntityExist(TARGET_VEHICLE) then
        QBCore.Functions.Notify('Removing target vehicle...', 'primary', 3000)
        
        -- Delete any brick props
        if MISSION_BRICKS and #MISSION_BRICKS > 0 then
            local brickCount = 0
            for k, brick in pairs(MISSION_BRICKS) do
                if DoesEntityExist(brick) then
                    DeleteEntity(brick)
                    brickCount = brickCount + 1
                end
            end
            QBCore.Functions.Notify('Removed ' .. brickCount .. ' brick props', 'success', 3000)
            MISSION_BRICKS = {}
        end
        
        -- Mark as mission entity so it can be deleted
        SetEntityAsMissionEntity(TARGET_VEHICLE, true, true)
        
        -- Delete the vehicle
        DeleteVehicle(TARGET_VEHICLE)
        
        -- Reset the global variable
        TARGET_VEHICLE = nil
        
        QBCore.Functions.Notify('Target vehicle removed!', 'success', 3000)
    end
end

function RemoveTruckBlip()
    if TRUCK_BLIP and DoesBlipExist(TRUCK_BLIP) then
        RemoveBlip(TRUCK_BLIP)
        TRUCK_BLIP = nil
    end
end

function ClearTruckVehicle()
    if TRUCK_VEHICLE and DoesEntityExist(TRUCK_VEHICLE) then
        DeleteEntity(TRUCK_VEHICLE)
        TRUCK_VEHICLE = nil
        
        if TRUCK_BLIP and DoesBlipExist(TRUCK_BLIP) then
            RemoveBlip(TRUCK_BLIP)
            TRUCK_BLIP = nil
        end
    end
end

function ClearTargetVehicle(force)
    if TARGET_VEHICLE and DoesEntityExist(TARGET_VEHICLE) then
        if force then
            -- Debug notification removed
            
            -- Clear any bricks
            local brickCount = 0
            if MISSION_BRICKS and #MISSION_BRICKS > 0 then
                for _, existingBrick in pairs(MISSION_BRICKS) do
                    if DoesEntityExist(existingBrick) then
                        DeleteEntity(existingBrick)
                        brickCount = brickCount + 1
                    end
                end
                MISSION_BRICKS = {}
            end
            
            -- Debug notification removed
            
            DeleteEntity(TARGET_VEHICLE)
            TARGET_VEHICLE = nil
            
            -- Debug notification removed
        end
    end
end