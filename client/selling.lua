local saleActive = false
local cooldown = false
local sellerBlip = false
HOLDING_WHEEL = nil
local storedWheels = {}
local sellerPedNetId = nil
local cratePropNetId = nil

function ContinueSale(sellerPed, crateProp)
    -- Register the seller ped and crate with ox_target if enabled
    if Config.target.enabled then
        -- Wait a bit to ensure everything is properly loaded
        Citizen.Wait(2000)
        RegisterSellerPedWithOxTarget(sellerPed)
        RegisterCrateWithOxTarget(crateProp)
    end
    
    Citizen.CreateThread(function()
        local wheelTakeOutEnabled = false
        QBCore.Functions.Notify('Put the stolen wheels in the crate to finish the sale', 'inform', 7000)

        while saleActive do
            local sleep = 1000
            local player = PlayerPedId()
            local playerCoords = GetEntityCoords(player)
            local sellerCoords = GetEntityCoords(sellerPed)
            local crateCoords = GetEntityCoords(crateProp)

            -- Only use Draw3DText if ox_target is disabled
            if not Config.target.enabled then
                if HOLDING_WHEEL and #storedWheels ~= 4 then
                    if GetDistanceBetweenCoords(playerCoords.x, playerCoords.y, playerCoords.z, crateCoords.x, crateCoords.y, crateCoords.z, false) < 3.0 then
                        sleep = 1
                        Draw3DText(crateCoords.x, crateCoords.y, crateCoords.z, L('Press ~g~[~w~E~g~]~w~ to drop off wheel'), 4, 0.065, 0.065)

                        if IsControlJustReleased(0, Keys['E']) and not cooldown then
                            table.insert(storedWheels, HOLDING_WHEEL)
                            SetCooldown(3000)
                            DropOffWheel(crateProp, #storedWheels)
                        end
                    end

                elseif #storedWheels == 4 then
                    if GetDistanceBetweenCoords(playerCoords.x, playerCoords.y, playerCoords.z, sellerCoords.x, sellerCoords.y, sellerCoords.z, false) < 3.0 then
                        sleep = 1
                        Draw3DText(sellerCoords.x, sellerCoords.y, sellerCoords.z, L('Press ~g~[~w~E~g~]~w~ to complete the sale'), 4, 0.065, 0.065)

                        if IsControlJustReleased(0, Keys['E']) and not cooldown then
                            SetCooldown(3000)
                            CompleteSale(sellerPed)
                        end
                    end
                end
            end

            if not wheelTakeOutEnabled and GetDistanceBetweenCoords(playerCoords.x, playerCoords.y, playerCoords.z, crateCoords.x, crateCoords.y, crateCoords.z, false) < 50.0 then
                EnableWheelTakeOut()
                wheelTakeOutEnabled = true
            end

            Citizen.Wait(sleep)
        end
    end)
end

function EnableSale()
    local sellerTable = Config.missionPeds['sale_ped']
    if not sellerTable then
        QBCore.Functions.Notify('ERROR: Sale ped config missing', 'error', 5000)
        return
    end
    
    QBCore.Functions.Notify('Starting the sale process... Spawning seller and crate', 'inform', 4000)
    
    local ped = SpawnPed(sellerTable)
    local blip = sellerTable.blip
    local cratePropModel = sellerTable.wheelDropOff.crateProp
    local wheelDropOffCoords = sellerTable.wheelDropOff.location
    local crateProp = CreateCrateProp(wheelDropOffCoords)

    if not DoesEntityExist(ped) then
        QBCore.Functions.Notify('ERROR: Failed to spawn seller ped', 'error', 5000)
        return
    end
    
    if not DoesEntityExist(crateProp) then
        QBCore.Functions.Notify('ERROR: Failed to spawn crate prop', 'error', 5000)
        return
    end

    -- Store references to clean up later
    sellerPedNetId = NetworkSafeGetNetworkId(ped)
    cratePropNetId = NetworkSafeGetNetworkId(crateProp)
    
    FreezeEntityPosition(crateProp, true)
    FreezeEntityPosition(ped, true)

    if blip.showBlip then
        sellerBlip = CreateSellerBlip(GetEntityCoords(ped), blip.blipIcon, blip.blipColor, 1.0, 1.0, blip.blipLabel)

        if Config.enableBlipRoute then
            SetBlipRoute(sellerBlip, true)
        end
    end

    saleActive = true
    ContinueSale(ped, crateProp)
    
    QBCore.Functions.Notify('Take your wheels to the crate and then complete the sale with the dealer', 'success', 8000)
end

function RegisterSellerPedWithOxTarget(sellerPed)
    if not sellerPed or not DoesEntityExist(sellerPed) then return end

    -- Get network ID for tracking
    sellerPedNetId = NetworkSafeGetNetworkId(sellerPed)
    
    -- Clear any existing targets for this entity to prevent duplicates
    if sellerPedNetId then
        exports.ox_target:removeEntity(sellerPedNetId)
    end
    
    -- Create options for the seller ped
    local options = {
        {
            name = 'ls_wheel_theft:complete_sale',
            icon = 'fas fa-dollar-sign',
            label = 'Complete Sale',
            canInteract = function()
                -- Only show when all 4 wheels are in the crate and not already paid
                return #storedWheels == 4 and not LocalPlayer.state.AlreadyPaid
            end,
            onSelect = function()
                if not cooldown then
                    SetCooldown(3000)
                    CompleteSale(sellerPed)
                end
            end
        }
    }
    
    -- Debug info
    if DEBUG_MODE then
        QBCore.Functions.Notify('Registering seller with target system (NetID: ' .. sellerPedNetId .. ')', 'primary', 2000)
    end
    
    -- Register with ox_target using just the entity
    exports.ox_target:addLocalEntity(sellerPed, options)
    
    QBCore.Functions.Notify('Seller is ready. Drop off all wheels in the crate, then talk to the seller.', 'success', 5000)
end

function RegisterCrateWithOxTarget(crateProp)
    if not crateProp or not DoesEntityExist(crateProp) then return end
    
    -- Get network ID for tracking
    cratePropNetId = NetworkSafeGetNetworkId(crateProp)
    
    -- Clear any existing targets for this entity to prevent duplicates
    if cratePropNetId then
        exports.ox_target:removeEntity(cratePropNetId)
    end
    
    -- Create options for the crate
    local options = {
        {
            name = 'ls_wheel_theft:drop_wheel',
            icon = 'fas fa-tire',
            label = 'Drop Off Wheel',
            canInteract = function()
                -- Only show this option if we have wheels and are currently holding one
                return HOLDING_WHEEL ~= nil and DoesEntityExist(HOLDING_WHEEL)
            end,
            onSelect = function()
                if not cooldown then
                    SetCooldown(3000)
                    DropOffWheel(crateProp, #storedWheels + 1)
                    
                    -- Notify the player about remaining wheels
                    if #storedWheels < 4 then
                        QBCore.Functions.Notify('You need to drop off ' .. (4 - #storedWheels) .. ' more wheels.', 'primary', 3000)
                    else
                        QBCore.Functions.Notify('All wheels dropped off! Talk to the seller to complete the sale.', 'success', 5000)
                    end
                end
            end
        }
    }
    
    -- Debug info
    if DEBUG_MODE then
        QBCore.Functions.Notify('Registering crate with target system (NetID: ' .. cratePropNetId .. ')', 'primary', 2000)
    end
    
    -- Register with ox_target using local entity
    exports.ox_target:addLocalEntity(crateProp, options)
end

function RegisterCompleteSaleOption(crateProp)

    -- Gha khli had function daba wakha no need for this
    -- This function is no longer needed as we're using only entity-based targeting
    -- This is here just as a placeholder to avoid breaking any existing calls
    -- The complete sale option is now handled directly with the seller ped
end

function CompleteSale(sellerPed)
    -- Check if player has already been paid for this mission
    if LocalPlayer.state.AlreadyPaid then
        QBCore.Functions.Notify('You have already been paid for this job!', 'error', 5000)
        return
    end
    
    -- Set paid flag immediately to prevent double-triggering
    LocalPlayer.state.AlreadyPaid = true
    LocalPlayer.state.MissionCompleted = true
    
    saleActive = false
    
    -- Play animation for selling
    local playerPed = PlayerPedId()
    if sellerPed and DoesEntityExist(sellerPed) then
        TaskTurnPedToFaceEntity(playerPed, sellerPed, 1000)
        Citizen.Wait(1000)
        
        PlayAnim('mp_common', 'givetake2_b', 0, sellerPed)
        PlayAnim('mp_common', 'givetake1_a')
        
        Citizen.Wait(1000)
        
        ClearPedTasks(playerPed)
        TaskStartScenarioInPlace(sellerPed, "WORLD_HUMAN_GUARD_STAND", 0, true)
    end

    -- Delete the seller ped if it exists
    if sellerPed and DoesEntityExist(sellerPed) then
        DeleteEntity(sellerPed)
    end

    -- Delete all stored wheels
    for k, wheel in pairs(storedWheels) do
        if wheel and DoesEntityExist(wheel) then
            DeleteEntity(wheel)
        end
    end
    storedWheels = {}
    
    -- Clean up targeting
    if Config.target.enabled then
        if sellerPedNetId then
            exports.ox_target:removeEntity(sellerPedNetId)
            sellerPedNetId = nil
        end
        
        if cratePropNetId then
            exports.ox_target:removeEntity(cratePropNetId)
            cratePropNetId = nil
        end
    end

    -- Clean up blips
    if sellerBlip and DoesBlipExist(sellerBlip) then
        RemoveBlip(sellerBlip)
        sellerBlip = nil
    end
    
    -- Use comprehensive blip cleanup to ensure everything is removed
    CleanupAllBlips()
    
    -- Make server-side payment - THIS IS THE ONLY PAYMENT PLAYER WILL RECEIVE
    TriggerServerEvent('ls_wheel_theft:server:CompleteSale', 4)  -- Always pay for 4 wheels
    
    QBCore.Functions.Notify('Sale completed and payment received! Return to the mission giver to finish the job. (No additional payment will be given)', 'success', 10000)
    
    -- Create a blip to guide the player back to the mission giver
    local missionTable = Config.missionPeds['mission_ped']
    local missionBlip = CreateSellerBlip(vector3(missionTable.location.x, missionTable.location.y, missionTable.location.z), 
        500, 2, 1.0, 1.0, "Return to Mission Giver")
    
    if Config.enableBlipRoute then
        SetBlipRoute(missionBlip, true)
    end
    
    -- Store the blip ID for later cleanup
    LocalPlayer.state.ReturnBlip = missionBlip
    
    -- Trigger the refresh event to update mission ped targeting
    TriggerServerEvent('ls_wheel_theft:server:refreshMissionPed')
end

function SetCooldown(time)
    cooldown = true
    Citizen.CreateThread(function()
        Citizen.Wait(time)
        cooldown = false
    end)
end

-- Event to remove the entities from ox_target when the resource stops
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName and Config.target.enabled then
        -- Clean up entity-based targets
        if sellerPedNetId then
            local sellerPed = NetworkGetEntityFromNetworkId(sellerPedNetId)
            if DoesEntityExist(sellerPed) then
                exports.ox_target:removeLocalEntity(sellerPed)
            end
        end
        
        if cratePropNetId then
            local crateProp = NetworkGetEntityFromNetworkId(cratePropNetId)
            if DoesEntityExist(crateProp) then
                exports.ox_target:removeLocalEntity(crateProp)
            end
        end
    end
end)

function DropOffWheel(crateProp, wheelCount)
    if not crateProp or not DoesEntityExist(crateProp) then
        QBCore.Functions.Notify('ERROR: Drop off crate does not exist', 'error', 5000)
        return
    end
    
    QBCore.Functions.Notify('Dropping off wheel ' .. wheelCount .. ' of 4...', 'primary', 3000)
    
    local player = PlayerPedId()
    local coords = GetEntityCoords(crateProp)

    -- Delete the wheel in player's hands
    if HOLDING_WHEEL and DoesEntityExist(HOLDING_WHEEL) then
        DeleteEntity(HOLDING_WHEEL)
        HOLDING_WHEEL = nil
        ClearPedTasksImmediately(player)
    end
    
    -- Create a new wheel in the crate (position depends on wheel count)
    local model = GetHashKey(Settings.wheelTakeOff.wheelModel)
    
    if not HasModelLoaded(model) then
        RequestModel(model)
        while not HasModelLoaded(model) do
            Citizen.Wait(1)
        end
    end
    
    -- Create the wheel prop
    local wheelProp = CreateObject(model, coords.x, coords.y, coords.z, true, true, true)
    
    -- Register as networked object
    NetworkRegisterEntityAsNetworked(wheelProp)
    local netId = NetworkGetNetworkIdFromEntity(wheelProp)
    SetNetworkIdCanMigrate(netId, true)
    SetNetworkIdExistsOnAllMachines(netId, true)
    SetEntityAsMissionEntity(wheelProp, true, true)
    
    -- Stack wheels vertically one over one using zTable for heights
    local zTable = {0.15, 0.35, 0.55, 0.75}
    AttachEntityToEntity(wheelProp, crateProp, 0, 0.0, 0.0, zTable[wheelCount], -90.0, 0.0, 0.0, true, true, false, false, 2, true)
    
    -- Store the wheel properly in the storedWheels array at the specific index
    storedWheels[wheelCount] = wheelProp
    
    if wheelCount == 4 then
        QBCore.Functions.Notify('All wheels have been dropped off. Speak to the seller to complete the sale!', 'success', 5000)
    end
end

-- Function to create the crate prop at the seller location
function CreateCrateProp(coords)
    RequestModel(Config.selling.crateModel)
    while not HasModelLoaded(Config.selling.crateModel) do
        Citizen.Wait(100)
    end
    
    local crateCoords = vector3(coords.x + Config.selling.crateOffset.x, coords.y + Config.selling.crateOffset.y, coords.z + Config.selling.crateOffset.z)
    local crateProp = CreateObject(GetHashKey(Config.selling.crateModel), crateCoords.x, crateCoords.y, crateCoords.z, true, true, true)
    
    -- Ensure the crate is properly networked
    if crateProp and DoesEntityExist(crateProp) then
        -- Set as mission entity to prevent cleanup
        SetEntityAsMissionEntity(crateProp, true, true)
        
        -- Ensure it's networked and we have control over it
        if not NetworkGetEntityIsNetworked(crateProp) then
            NetworkRegisterEntityAsNetworked(crateProp)
            
            -- Wait for networking to complete
            local attempts = 0
            while not NetworkGetEntityIsNetworked(crateProp) and attempts < 5 do
                Citizen.Wait(100)
                attempts = attempts + 1
            end
        end
        
        -- Get control of entity if needed
        if not NetworkHasControlOfEntity(crateProp) then
            NetworkRequestControlOfEntity(crateProp)
            local attempts = 0
            while not NetworkHasControlOfEntity(crateProp) and attempts < 5 do
                Citizen.Wait(100)
                attempts = attempts + 1
            end
        end
        
        -- Verify we have a network ID
        local netId = NetworkGetNetworkIdFromEntity(crateProp)
        if netId == 0 and DEBUG_MODE then
            print("^1[DEBUG] Warning: Crate prop created but couldn't get network ID")
        else if DEBUG_MODE then
            print("^2[DEBUG] Created crate prop with NetID: " .. netId)
        end
        end
    end
    
    SetEntityHeading(crateProp, coords.h)
    FreezeEntityPosition(crateProp, true)
    
    return crateProp
end
