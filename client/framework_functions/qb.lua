if Config.qbSettings.enabled then
    -- Always initialize QBCore from export
    QBCore = exports['qb-core']:GetCoreObject()
    print("^2[wheel_theft] QBCore initialized from export")

    if QBCore.Functions.GetPlayerData() and QBCore.Functions.GetPlayerData().job then
        PLAYER_JOB = QBCore.Functions.GetPlayerData().job.name
    end

    RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
    AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
        PLAYER_JOB = QBCore.Functions.GetPlayerData().job.name
    end)

    RegisterNetEvent('QBCore:Client:OnJobUpdate')
    AddEventHandler('QBCore:Client:OnJobUpdate', function(JobInfo)
        PLAYER_JOB = JobInfo.name
    end)
end