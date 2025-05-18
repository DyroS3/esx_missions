local ESX = exports['es_extended']:getSharedObject()
local currentMission = nil -- 客户端任务数据存储
local display = false

-- 调试打印函数
local function DebugPrint(message)
    if Config.Debug then
        print('[esx_missions:client] ' .. message)
    end
end

-- 任务帮助函数处理
local function HandleMissionHelp(helpId)
    if helpId == 'get_noob_car_help' then
        DebugPrint('玩家开始获取新手车任务')
        -- 这里可以添加具体逻辑, 比如：
        -- 显示导航点
        -- TriggerEvent('esx_missions:showBlip', vector3(x, y, z))
        -- 显示提示
        -- ESX.ShowNotification('请前往车行购买新手车')
    end
end

-- 显示任务界面
local function ShowMissions()
    if display then return end

    -- 使用ox_lib回调获取玩家任务数据
    lib.callback('esx_missions:getPlayerMissions', false, function(playerMissions)
        display = true
        SetNuiFocus(true, true)

        -- 处理重置类型信息并发送到UI
        local missionsWithResetInfo = {}
        for category, categoryData in pairs(Config.Missions) do
            missionsWithResetInfo[category] = table.deepcopy(categoryData)
            for i, mission in ipairs(missionsWithResetInfo[category].mission) do
                -- 添加任务重置类型文本说明
                if mission.resetType == 'daily' then
                    mission.resetTypeText = '每日重置'
                elseif mission.resetType == 'weekly' then
                    mission.resetTypeText = '每周重置'
                elseif mission.resetType == 'monthly' then
                    mission.resetTypeText = '每月重置'
                else
                    mission.resetTypeText = '不重置'
                end
            end
        end

        -- 发送配置任务和玩家任务数据到NUI
        SendNUIMessage({
            type = "setMissionUI",
            status = true,
            missions = missionsWithResetInfo,
            playerMissions = playerMissions -- 添加玩家任务进度数据
        })
    end)
end

-- 创建深度拷贝函数（避免引用传递）
function table.deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[table.deepcopy(orig_key)] = table.deepcopy(orig_value)
        end
        setmetatable(copy, table.deepcopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- 隐藏任务界面
local function HideMissions()
    if not display then return end
    display = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        type = "setMissionUI",
        status = false
    })
end

-- 注册命令
RegisterCommand(Config.Other.command.openMission, function()
    ShowMissions()
end, false)

-- 注册按键
if Config.Other.key.enable then
    RegisterKeyMapping(Config.Other.command.openMission, '打开任务界面', 'keyboard', Config.Other.key.openMission)
end

-- NUI回调: 关闭任务界面
RegisterNUICallback('closeMissions', function(data, cb)
    HideMissions()
    cb('ok')
end)

-- NUI回调: 开始任务
RegisterNUICallback('startMission', function(data, cb)
    if data and data.missionName and data.category then
        DebugPrint(string.format("收到开始任务请求: %s (分类: %s)", data.missionName, data.category))
        if data.help then
            HandleMissionHelp(data.help)
        end
        cb('ok')
    else
        DebugPrint("无效的 startMission 请求数据")
        cb('error')
    end
end)


-- 获取服务端数据同步
RegisterNetEvent('esx_missions:syncMissions', function(missions)
    if missions then
        currentMission = missions
        DebugPrint("任务数据已同步到客户端")

        -- 如果任务界面已打开, 则更新显示
        if display then
            SendNUIMessage({
                type = "updateMissions",
                playerMissions = missions
            })
        end
    else
        DebugPrint("无效的任务数据")
    end
end)

-- 导出函数, 供其他资源调用以更新任务状态
-- missionType: 任务类型, 例如 '新手任务'
-- missionName: 任务的唯一名称, 例如 'get_noob_car'
-- progress: 任务进度, 可以是数字（例如完成次数）或布尔值（true 表示完成）
exports('updateMissionStatus', function(missionCategory, missionName, progress)
    if not missionCategory or not missionName or progress == nil then
        DebugPrint('[esx_missions] Error: updateMissionStatus called with invalid arguments.')
        ESX.ShowNotification('更新任务状态时出错：参数无效。')
        return
    end
    TriggerServerEvent('esx_missions:updateMissionStatus', missionCategory, missionName, progress)
end)

-- 测试命令: 用于测试任务更新
RegisterCommand('testMission', function(source, args, rawCommand)
    local missionCategory = args[1] or '日常任务'
    local missionName = args[2] or 'daily_kill_player'
    local progress = tonumber(args[3]) or 10

    DebugPrint(string.format("尝试更新任务：类别=%s, 名称=%s, 进度=%s", missionCategory, missionName, tostring(progress)))

    if missionCategory and missionName and progress then
        exports['esx_missions']:updateMissionStatus(missionCategory, missionName, progress)
    else
        ESX.ShowNotification('无效的参数, 请使用 /testMission <任务类型> <任务名称> <进度>')
    end
end, false)

-- 测试重置时间
RegisterCommand('checkResetTimes', function()
    local message = "重置时间配置:\n"
    message = message .. "每日: " .. (Config.ResetTimes.daily.hour or 0) .. ":" .. (Config.ResetTimes.daily.minute or 0) .. "\n"
    message = message .. "每周: 周" .. (Config.ResetTimes.weekly.weekday or 1) .. " " .. (Config.ResetTimes.weekly.hour or 0) .. ":" .. (Config.ResetTimes.weekly.minute or 0) .. "\n"
    message = message .. "每月: " .. (Config.ResetTimes.monthly.day or 1) .. "日 " .. (Config.ResetTimes.monthly.hour or 0) .. ":" .. (Config.ResetTimes.monthly.minute or 0)

    DebugPrint(message)
    ESX.ShowNotification(message)
end, false)

-- 示例：监听服务器确认任务更新的事件 (可选)
-- RegisterNetEvent('esx_missions:notifyClientMissionUpdate')
-- AddEventHandler('esx_missions:notifyClientMissionUpdate', function(message)
--   ESX.ShowNotification(message)
-- end)
