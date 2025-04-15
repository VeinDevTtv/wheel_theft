-- wheel_theft/server/laptop_integration.lua
-- Handles server-side integration between wheel_theft and qbx_laptop

-- Import libs
local QBX = exports.qbx_core

-- Player data
local playerData = {}
local playerTierRequirements = {
    D = 0,    -- Beginner tier, available to all
    C = 1000, -- Basic tier
    B = 3000, -- Intermediate tier
    A = 7500, -- Advanced tier
    S = 15000 -- Expert tier
}

-- Available contracts by tier
local contracts = {
    D = { -- Beginner tier contracts
        {
            id = 'D1',
            title = 'Basic Wheel Removal',
            description = 'Remove wheels from an unattended vehicle in a quiet area.',
            location = 'Sandy Shores',
            vehicleType = 'sedan',
            security = '1/5',
            timeWindow = '60 min',
            difficulty = 1,
            requiredTier = 'D',
            requiredTools = {'basic_tools'},
            reward = {
                crypto = 100,
                xp = 100
            }
        },
        {
            id = 'D2',
            title = 'Scrap Yard Salvage',
            description = 'Steal wheels from vehicles in a scrap yard.',
            location = 'Scrap Yard',
            vehicleType = 'suv',
            security = '1/5',
            timeWindow = '60 min',
            difficulty = 1,
            requiredTier = 'D',
            requiredTools = {'basic_tools'},
            reward = {
                crypto = 150,
                xp = 150
            }
        }
    },
    C = { -- Basic tier contracts
        {
            id = 'C1',
            title = 'Parking Lot Operation',
            description = 'Target a vehicle in a public parking lot.',
            location = 'Legion Square Parking',
            vehicleType = 'coupe',
            security = '2/5',
            timeWindow = '45 min',
            difficulty = 2,
            requiredTier = 'C',
            requiredTools = {'basic_tools', 'wheel_jack'},
            reward = {
                crypto = 200,
                xp = 200
            }
        },
        {
            id = 'C2',
            title = 'Highway Rest Stop',
            description = 'Steal wheels from a vehicle at a highway rest stop.',
            location = 'Route 68',
            vehicleType = 'muscle',
            security = '2/5',
            timeWindow = '45 min',
            difficulty = 2,
            requiredTier = 'C',
            requiredTools = {'basic_tools', 'wheel_jack'},
            reward = {
                crypto = 250,
                xp = 250
            }
        }
    },
    B = { -- Intermediate tier contracts
        {
            id = 'B1',
            title = 'Custom Wheel Acquisition',
            description = 'Steal specific custom wheels from a vehicle.',
            location = 'Vinewood Hills',
            vehicleType = 'sport',
            security = '3/5',
            timeWindow = '40 min',
            difficulty = 3,
            requiredTier = 'B',
            requiredTools = {'advanced_tools', 'wheel_jack'},
            reward = {
                crypto = 350,
                xp = 350
            }
        },
        {
            id = 'B2',
            title = 'Hotel Valet Target',
            description = 'Steal wheels from a car parked with a hotel valet.',
            location = 'Del Perro',
            vehicleType = 'sport',
            security = '3/5',
            timeWindow = '35 min',
            difficulty = 3,
            requiredTier = 'B',
            requiredTools = {'advanced_tools', 'wheel_jack'},
            reward = {
                crypto = 400,
                xp = 400
            }
        }
    },
    A = { -- Advanced tier contracts
        {
            id = 'A1',
            title = 'Dealership After Hours',
            description = 'Infiltrate a car dealership and steal premium wheels.',
            location = 'Premium Deluxe Motorsport',
            vehicleType = 'super',
            security = '4/5',
            timeWindow = '30 min',
            difficulty = 4,
            requiredTier = 'A',
            requiredTools = {'advanced_tools', 'speed_jack', 'security_bypass'},
            reward = {
                crypto = 550,
                xp = 550
            }
        },
        {
            id = 'A2',
            title = 'High-End Car Meet',
            description = 'Target a vehicle at an exclusive car meet.',
            location = 'Rockford Hills',
            vehicleType = 'super',
            security = '4/5',
            timeWindow = '25 min',
            difficulty = 4,
            requiredTier = 'A',
            requiredTools = {'advanced_tools', 'speed_jack', 'security_bypass'},
            reward = {
                crypto = 600,
                xp = 600
            }
        }
    },
    S = { -- Expert tier contracts
        {
            id = 'S1',
            title = 'Celebrity Vehicle',
            description = 'Steal wheels from a celebrity\'s protected vehicle.',
            location = 'Richman',
            vehicleType = 'super',
            security = '5/5',
            timeWindow = '20 min',
            difficulty = 5,
            requiredTier = 'S',
            requiredTools = {'professional_tools', 'speed_jack', 'security_bypass', 'silent_tools'},
            reward = {
                crypto = 800,
                xp = 800
            }
        },
        {
            id = 'S2',
            title = 'Rare Prototype Wheels',
            description = 'Steal prototype wheels from a highly secured research facility.',
            location = 'NOOSE Facility',
            vehicleType = 'super',
            security = '5/5',
            timeWindow = '15 min',
            difficulty = 5,
            requiredTier = 'S',
            requiredTools = {'professional_tools', 'speed_jack', 'security_bypass', 'silent_tools'},
            reward = {
                crypto = 1000,
                xp = 1000
            }
        }
    }
}

-- Shop items
local shopItems = {
    {
        id = 'basic_tools',
        label = 'Basic Wheel Removal Kit',
        description = 'Standard tools for basic wheel removal operations.',
        price = 500,
        requiredTier = 'D',
        effectiveness = 1,
        oneTime = true
    },
    {
        id = 'wheel_jack',
        label = 'Hydraulic Jack',
        description = 'Makes lifting vehicles faster and easier.',
        price = 1500,
        requiredTier = 'C',
        effectiveness = 2,
        oneTime = true
    },
    {
        id = 'advanced_tools',
        label = 'Advanced Tool Kit',
        description = 'Professional-grade tools for more secure wheel removal.',
        price = 3000,
        requiredTier = 'B',
        effectiveness = 3,
        oneTime = true
    },
    {
        id = 'speed_jack',
        label = 'Racing Speed Jack',
        description = 'Ultra-fast hydraulic jack used by racing teams.',
        price = 5000,
        requiredTier = 'A',
        effectiveness = 4,
        oneTime = true
    },
    {
        id = 'security_bypass',
        label = 'Security Bypass Module',
        description = 'Electronic device to bypass vehicle security systems.',
        price = 7500,
        requiredTier = 'A',
        effectiveness = 3,
        oneTime = true
    },
    {
        id = 'silent_tools',
        label = 'Silent Operation Kit',
        description = 'Specially designed tools for silent operation.',
        price = 10000,
        requiredTier = 'S',
        effectiveness = 5,
        oneTime = true
    }
}

-- Initialize integration
CreateThread(function()
    -- Wait for resources to start
    Wait(1000)
    
    print("[wheel_theft] Successfully integrated with QBX Laptop (server)")
end)

-- Helper functions
local function GetPlayerData(playerId)
    if not playerData[playerId] then
        playerData[playerId] = {
            tier = 'D',
            xp = 0,
            completedContracts = 0,
            failedContracts = 0,
            ownedItems = {'basic_tools'},
            activeContract = nil
        }
    end
    
    return playerData[playerId]
end

local function UpdatePlayerTier(playerId)
    local data = GetPlayerData(playerId)
    local currentTier = data.tier
    
    -- Check if player qualifies for a tier upgrade
    for tier, xpRequired in pairs(playerTierRequirements) do
        if data.xp >= xpRequired then
            data.tier = tier
        end
    end
    
    -- If tier changed, notify player
    if data.tier ~= currentTier then
        TriggerClientEvent('qbx_laptop:client:WheelTheftTierChange', playerId, {
            oldTier = currentTier,
            newTier = data.tier
        })
    end
end

local function GetAvailableContracts(playerId)
    local data = GetPlayerData(playerId)
    local availableContracts = {}
    
    -- Add all contracts that match player's tier or lower
    for tier, tierContracts in pairs(contracts) do
        if playerTierRequirements[tier] <= playerTierRequirements[data.tier] then
            for _, contract in ipairs(tierContracts) do
                table.insert(availableContracts, contract)
            end
        end
    end
    
    return availableContracts
end

local function GetAvailableShopItems(playerId)
    local data = GetPlayerData(playerId)
    local availableItems = {}
    
    -- Add all items that match player's tier or lower
    for _, item in ipairs(shopItems) do
        local owned = false
        
        -- Check if player already owns this item
        for _, ownedItem in ipairs(data.ownedItems) do
            if ownedItem == item.id then
                owned = true
                break
            end
        end
        
        local itemData = table.clone(item)
        itemData.owned = owned
        
        -- Only show items for player's tier or lower
        if playerTierRequirements[item.requiredTier] <= playerTierRequirements[data.tier] then
            table.insert(availableItems, itemData)
        end
    end
    
    return availableItems
end

local function PlayerHasRequiredTools(playerId, requiredTools)
    local data = GetPlayerData(playerId)
    
    -- Check if player has all required tools
    for _, requiredTool in ipairs(requiredTools) do
        local hasItem = false
        
        for _, ownedItem in ipairs(data.ownedItems) do
            if ownedItem == requiredTool then
                hasItem = true
                break
            end
        end
        
        if not hasItem then
            return false
        end
    end
    
    return true
end

-- Register server callbacks
lib.callback.register('qbx_laptop:server:GetWheelTheftData', function(source)
    return GetPlayerData(source)
end)

lib.callback.register('qbx_laptop:server:GetWheelTheftContracts', function(source)
    return GetAvailableContracts(source)
end)

lib.callback.register('qbx_laptop:server:GetWheelTheftShopItems', function(source)
    return GetAvailableShopItems(source)
end)

lib.callback.register('qbx_laptop:server:AcceptWheelTheftContract', function(source, contractId)
    local player = QBX.GetPlayer(source)
    if not player then
        return { success = false, message = 'Player not found' }
    end
    
    local data = GetPlayerData(source)
    
    -- Check if player already has an active contract
    if data.activeContract then
        return { success = false, message = 'You already have an active contract' }
    end
    
    -- Find the contract
    local targetContract = nil
    for tier, tierContracts in pairs(contracts) do
        for _, contract in ipairs(tierContracts) do
            if contract.id == contractId then
                targetContract = contract
                break
            end
        end
        if targetContract then break end
    end
    
    if not targetContract then
        return { success = false, message = 'Contract not found' }
    end
    
    -- Check if player meets tier requirement
    if playerTierRequirements[targetContract.requiredTier] > playerTierRequirements[data.tier] then
        return { success = false, message = 'You need to be Tier ' .. targetContract.requiredTier .. ' or higher for this contract' }
    end
    
    -- Check if player has required tools
    if not PlayerHasRequiredTools(source, targetContract.requiredTools) then
        return { success = false, message = 'You don\'t have the required tools for this contract' }
    end
    
    -- Set active contract
    data.activeContract = targetContract
    
    return { 
        success = true, 
        contract = targetContract 
    }
end)

lib.callback.register('qbx_laptop:server:PurchaseWheelTheftItem', function(source, itemId)
    local player = QBX.GetPlayer(source)
    if not player then
        return { success = false, message = 'Player not found' }
    end
    
    local data = GetPlayerData(source)
    
    -- Find the item
    local targetItem = nil
    for _, item in ipairs(shopItems) do
        if item.id == itemId then
            targetItem = item
            break
        end
    end
    
    if not targetItem then
        return { success = false, message = 'Item not found' }
    end
    
    -- Check if player already owns this item
    for _, ownedItem in ipairs(data.ownedItems) do
        if ownedItem == itemId then
            return { success = false, message = 'You already own this item' }
        end
    end
    
    -- Check if player meets tier requirement
    if playerTierRequirements[targetItem.requiredTier] > playerTierRequirements[data.tier] then
        return { success = false, message = 'You need to be Tier ' .. targetItem.requiredTier .. ' or higher to purchase this item' }
    end
    
    -- Check if player can afford the item
    local cryptoAmount = player.PlayerData.money.crypto or 0
    if cryptoAmount < targetItem.price then
        return { success = false, message = 'Not enough crypto currency' }
    end
    
    -- Deduct crypto and add item
    player.Functions.RemoveMoney('crypto', targetItem.price)
    table.insert(data.ownedItems, itemId)
    
    -- Also add the actual item to inventory if applicable
    -- This depends on how your inventory system works
    -- player.Functions.AddItem(itemId, 1)
    
    return { success = true }
end)

-- Event to handle mission completion
RegisterNetEvent('qbx_laptop:server:CompleteWheelTheftMission', function(wheelsCount)
    local src = source
    local player = QBX.GetPlayer(src)
    if not player then return end
    
    local data = GetPlayerData(src)
    
    -- Check if player has an active contract
    if not data.activeContract then return end
    
    -- Calculate rewards based on contract and performance
    local baseReward = data.activeContract.reward.crypto
    local baseXP = data.activeContract.reward.xp
    
    -- Adjust rewards based on number of wheels stolen
    local wheelsMultiplier = math.min(wheelsCount, 4) / 4
    local finalReward = math.floor(baseReward * (1 + wheelsMultiplier))
    local finalXP = math.floor(baseXP * (1 + wheelsMultiplier))
    
    -- Add rewards to player
    player.Functions.AddMoney('crypto', finalReward)
    data.xp = data.xp + finalXP
    data.completedContracts = data.completedContracts + 1
    
    -- Update player tier if needed
    UpdatePlayerTier(src)
    
    -- Clear active contract
    local completedContract = data.activeContract
    data.activeContract = nil
    
    -- Notify player
    TriggerClientEvent('qbx_laptop:client:WheelTheftMissionCompleted', src, {
        reward = finalReward,
        xp = finalXP,
        contract = completedContract
    })
end)

-- Event to handle mission failure
RegisterNetEvent('qbx_laptop:server:FailWheelTheftMission', function(reason)
    local src = source
    local data = GetPlayerData(src)
    
    -- Check if player has an active contract
    if not data.activeContract then return end
    
    -- Update player data
    data.failedContracts = data.failedContracts + 1
    
    -- Store failed contract
    local failedContract = data.activeContract
    data.activeContract = nil
    
    -- Notify player
    TriggerClientEvent('qbx_laptop:client:WheelTheftMissionFailed', src, {
        reason = reason or "Unknown reason",
        contract = failedContract
    })
end)

-- Handle player disconnect
AddEventHandler('playerDropped', function()
    local src = source
    
    -- If player had an active contract, mark it as failed
    if playerData[src] and playerData[src].activeContract then
        playerData[src].failedContracts = playerData[src].failedContracts + 1
        playerData[src].activeContract = nil
    end
end)

-- Optional: Save player data periodically or on server shutdown
-- This depends on your server's database structure
-- You could use QBX's built-in methods or your own implementation

print('Wheel Theft laptop integration loaded (server)') 