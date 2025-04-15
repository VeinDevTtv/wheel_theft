-- wheel_theft/client/laptop_integration.lua
-- This file handles integration between wheel_theft and qbx_laptop

-- Local variables
local QBX = exports.qbx_core
local activeContract = nil
local wheelTheftConfig = nil

-- Load wheel theft configuration
local function LoadWheelTheftConfig()
    local config = {}
    
    -- Try to get config from wheel_theft export
    local success, result = pcall(function()
        return exports['wheel_theft']:GetConfig()
    end)
    
    if success and result then
        config = result
    else
        -- Set up a basic default config if export fails
        config = {
            locations = {},
            vehicles = {
                -- Default vehicle classes
                "sedan", "suv", "coupe", "muscle", "sport", "super", "compact"
            },
            difficulty = {
                min = 1,
                max = 5
            },
            reward = {
                base = 100,
                multiplier = 1.5
            }
        }
    end
    
    return config
end

-- Initialize the integration
CreateThread(function()
    -- Wait for resources to start
    Wait(1000)
    
    -- Load wheel theft config
    wheelTheftConfig = LoadWheelTheftConfig()
    
    -- Register the app with qbx_laptop
    exports['qbx_laptop']:RegisterApplication({
        name = 'wheeltheft',
        icon = 'fa-solid fa-tire',
        label = 'Wheel Theft',
        color = '#2c3e50',
        description = 'Specialized wheel theft contracts and tools',
        tooltipText = 'Start stealing wheels around the city',
        tooltipPos = 'top',
        job = nil,
        blockedJobs = { 'police' },
        requiresItems = nil
    })
    
    print("[wheel_theft] Successfully integrated with QBX Laptop")
end)

-- Event from laptop to start a mission
RegisterNetEvent('wheel_theft:StartMission')
AddEventHandler('wheel_theft:StartMission', function(contractData)
    -- Save active contract
    activeContract = contractData
    
    -- Get location based on contract data
    local location = GetLocationForContract(contractData)
    
    -- Spawn vehicle and setup mission based on contract
    SetupWheelTheftMission(contractData, location)
    
    -- Notify player
    lib.notify({
        title = 'WheelTheft',
        description = 'Contract started. Find the vehicle.',
        type = 'info'
    })
end)

-- Helper function to get location for contract
function GetLocationForContract(contract)
    -- Choose appropriate location based on contract details
    local location = {
        coords = vector3(0, 0, 0),
        heading = 0,
        area = contract.location or "Unknown"
    }
    
    -- If contract has coords, use those
    if contract.coords then
        location.coords = contract.coords
    elseif wheelTheftConfig and wheelTheftConfig.locations and #wheelTheftConfig.locations > 0 then
        -- Choose a location based on security level or other factors
        local securityNum = tonumber(string.match(contract.security or "1/5", "%d"))
        local locIndex = math.random(1, #wheelTheftConfig.locations)
        
        -- Try to match security level if locations have that property
        for i, loc in ipairs(wheelTheftConfig.locations) do
            if loc.security and loc.security == securityNum then
                locIndex = i
                break
            end
        end
        
        location = wheelTheftConfig.locations[locIndex]
    end
    
    return location
end

-- Setup wheel theft mission
function SetupWheelTheftMission(contract, location)
    -- Call wheel_theft's mission setup function
    TriggerEvent('wheel_theft:internal:SetupMission', {
        contract = contract,
        location = location
    })
end

-- When wheels are stolen successfully in wheel_theft
RegisterNetEvent('wheel_theft:internal:WheelsStolen')
AddEventHandler('wheel_theft:internal:WheelsStolen', function(data)
    if not activeContract then return end
    
    -- Notify laptop about mission completion
    TriggerServerEvent('qbx_laptop:server:CompleteWheelTheftMission', data.count or 1)
    
    -- Reset active contract
    activeContract = nil
end)

-- When mission fails in wheel_theft
RegisterNetEvent('wheel_theft:internal:MissionFailed')
AddEventHandler('wheel_theft:internal:MissionFailed', function(reason)
    if not activeContract then return end
    
    -- Notify laptop about mission failure
    TriggerServerEvent('qbx_laptop:server:FailWheelTheftMission', reason)
    
    -- Reset active contract
    activeContract = nil
end)

-- Export to check if the resource has an active contract from laptop
exports('HasActiveContract', function()
    return activeContract ~= nil
end)

-- Export to get current active contract details
exports('GetActiveContract', function()
    return activeContract
end)

-- Register callbacks for laptop NUI
lib.callback.register('qbx_laptop:client:GetWheelTheftContracts', function()
    local contracts = lib.callback.await('qbx_laptop:server:GetWheelTheftContracts', false)
    return contracts
end)

lib.callback.register('qbx_laptop:client:GetWheelTheftShopItems', function()
    local items = lib.callback.await('qbx_laptop:server:GetWheelTheftShopItems', false)
    return items
end)

lib.callback.register('qbx_laptop:client:GetWheelTheftPlayerData', function()
    local data = lib.callback.await('qbx_laptop:server:GetWheelTheftData', false)
    return data
end)

lib.callback.register('qbx_laptop:client:StartWheelTheftContract', function(contractId)
    local result = lib.callback.await('qbx_laptop:server:AcceptWheelTheftContract', false, contractId)
    
    if result.success then
        exports['qbx_laptop']:CloseApplication()
        TriggerEvent('wheel_theft:StartMission', result.contract)
    else
        lib.notify({
            title = 'WheelTheft',
            description = result.message,
            type = 'error'
        })
    end
    
    return result.success
end)

lib.callback.register('qbx_laptop:client:PurchaseWheelTheftItem', function(itemId)
    local result = lib.callback.await('qbx_laptop:server:PurchaseWheelTheftItem', false, itemId)
    
    if result.success then
        lib.notify({
            title = 'WheelTheft',
            description = 'Item purchased successfully',
            type = 'success'
        })
    else
        lib.notify({
            title = 'WheelTheft',
            description = result.message,
            type = 'error'
        })
    end
    
    return result.success
end)

-- Events from server to update UI while laptop is open
RegisterNetEvent('qbx_laptop:client:WheelTheftMissionCompleted', function(data)
    -- Update any open UI
    exports['qbx_laptop']:SendAppEvent('wheeltheft', {
        action = 'missionCompleted',
        data = data
    })
    
    lib.notify({
        title = 'WheelTheft',
        description = 'Mission completed! Earned ' .. data.reward .. ' crypto and ' .. data.xp .. ' XP',
        type = 'success'
    })
end)

RegisterNetEvent('qbx_laptop:client:WheelTheftMissionFailed', function(data)
    -- Update any open UI
    exports['qbx_laptop']:SendAppEvent('wheeltheft', {
        action = 'missionFailed',
        data = data
    })
    
    lib.notify({
        title = 'WheelTheft',
        description = 'Mission failed: ' .. data.reason,
        type = 'error'
    })
end)

print('Wheel Theft laptop integration loaded (client)') 