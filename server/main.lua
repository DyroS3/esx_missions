local ESX = exports['es_extended']:getSharedObject()
-- 调试信息输出
local function DebugPrint(message)
  if Config.Debug then
    print('[esx_missions:server] ' .. message)
  end
end

-- 任务缓存管理系统, 存储所有在线玩家的任务数据 结构为 {playerId: {missionCategory: [missionData]}}
local missionCache = {}

-- 任务重置时间跟踪器
local lastResetCheck = {
  daily = 0,  -- 日常任务最后重置检查时间
  weekly = 0, -- 周常任务最后重置检查时间
  monthly = 0 -- 月常任务最后重置检查时间
}

-- 速率限制管理器
local rateLimiter = {
  players = {}, -- 存储玩家的请求记录 {playerId: {lastCheck: number, count: number, violations: number}}

  -- 检查玩家是否超过速率限制
  ---@param playerId number 玩家ID
  ---@return boolean 是否允许请求
  check = function(self, playerId)
    if not Config.Other.updateRateLimit then
      return true -- 如果未启用速率限制, 直接返回true
    end

    local now = os.time()
    if not self.players[playerId] then
      -- 首次请求, 初始化记录
      self.players[playerId] = {
        lastCheck = now,
        count = 1,
        violations = 0,    -- 违规次数
        firstViolation = 0 -- 首次违规时间
      }
      return true
    end

    local playerData = self.players[playerId]
    local timeDiff = now - playerData.lastCheck

    if timeDiff >= Config.Other.updateRateLimitTime then
      -- 超过时间窗口, 重置计数
      playerData.lastCheck = now
      playerData.count = 1
      -- 重置违规记录（如果超过30分钟没有违规）
      if now - playerData.firstViolation > 1800 then
        playerData.violations = 0
        playerData.firstViolation = 0
      end
      return true
    end

    -- 在时间窗口内
    if playerData.count >= Config.Other.updateRateLimitCount then
      -- 记录违规
      playerData.violations = playerData.violations + 1
      if playerData.firstViolation == 0 then
        playerData.firstViolation = now
      end

      -- 检查违规次数
      if playerData.violations >= 3 then
        -- 记录作弊日志
        local player = ESX.GetPlayerFromId(playerId)
        local identifier = player and player.identifier or 'Unknown'
        local name = player and player.name or 'Unknown'

        DebugPrint(string.format('[反作弊] 玩家 %s (%s) 在30分钟内触发速率限制3次, 已被踢出服务器', name, identifier))

        Wait(100)
        ---@diagnostic disable-next-line: param-type-mismatch
        DropPlayer(playerId, '检测到可疑行为：任务更新请求过于频繁')
        return false
      end

      -- 发送警告
      TriggerClientEvent('esx:showNotification', playerId, ('警告：请求过于频繁, 这是第 %d 次警告, 累计3次将被踢出服务器'):format(playerData.violations))
      return false
    end

    -- 增加计数
    playerData.count = playerData.count + 1
    return true
  end,

  -- 清理玩家数据
  ---@param playerId number 玩家ID
  clear = function(self, playerId)
    self.players[playerId] = nil
  end
}

-- 获取玩家特定任务的数据
---@param playerId number 玩家ID
---@param missionCategory string 任务类别
---@param missionName string 任务名称
---@return boolean | table -- 成功返回任务数据对象, 失败返回false
local function GetMissionData(playerId, missionCategory, missionName)
  if not playerId or not missionCache[playerId] then
    return false
  end

  if not missionCategory or not missionCache[playerId][missionCategory] then
    return false
  end

  if not missionName then
    return false
  end

  for _, mission in ipairs(missionCache[playerId][missionCategory]) do
    if mission.name == missionName then
      return mission
    end
  end
  return false
end

-- 获取玩家特定任务的进度
---@param playerId number 玩家ID
---@param missionCategory string 任务类别
---@param missionName string 任务名称
---@return number -- 任务当前进度, 如无数据则返回0
local function GetMissionProgress(playerId, missionCategory, missionName)
  if not playerId or not missionCategory or not missionName then
    return 0
  end

  local missionData = GetMissionData(playerId, missionCategory, missionName)
  if missionData then
    return missionData.progress or 0
  end
  return 0
end

-- 获取任务配置信息
---@param missionCategory string 任务类别
---@param missionName string 任务名称
---@return table | nil -- 任务配置对象, 不存在则返回nil
local function GetMissionConfig(missionCategory, missionName)
  if Config.Missions and Config.Missions[missionCategory] and Config.Missions[missionCategory].mission then
    for _, mission in ipairs(Config.Missions[missionCategory].mission) do
      if mission.name == missionName then
        return mission
      end
    end
  end
  return nil
end

-- 检查任务是否需要重置
---@param resetType string 重置类型：'daily', 'weekly', 'monthly', 'never'
---@param lastReset number 任务上次重置的时间戳
---@return boolean -- 是否需要重置任务
local function ShouldResetMission(resetType, lastReset)
  if not resetType or resetType == 'never' or not lastReset then
    return false
  end

  local currentTime = os.time()
  local currentDate = os.date('*t', currentTime)
  local lastResetDate = os.date('*t', lastReset)
  local resetTimes = Config.ResetTimes[resetType]

  if not resetTimes then
    return false
  end

  local function hasPassedResetTime()
    return currentDate.hour > (resetTimes.hour or 0) or
        (currentDate.hour == (resetTimes.hour or 0) and currentDate.min >= (resetTimes.minute or 0))
  end

  if resetType == 'daily' then
    -- 检查是否过了一天且到了重置时间
    return (currentDate.day ~= lastResetDate.day or
          currentDate.month ~= lastResetDate.month or
          currentDate.year ~= lastResetDate.year) and
        hasPassedResetTime()
  elseif resetType == 'weekly' then
    -- 检查是否过了一周且到了重置时间
    local dayDiff = os.difftime(currentTime, lastReset) / (24 * 60 * 60)
    local resetWeekday = resetTimes.weekday or 1
    local lastWeekResetDay = lastResetDate.wday - 1
    if lastWeekResetDay == 0 then lastWeekResetDay = 7 end

    return (dayDiff >= 7 or
      (currentDate.wday == resetWeekday and
        hasPassedResetTime() and
        (lastWeekResetDay ~= resetWeekday or dayDiff >= 1)))
  elseif resetType == 'monthly' then
    -- 检查是否过了一个月且到了重置时间
    local resetDay = resetTimes.day or 1
    return (currentDate.month ~= lastResetDate.month or
      currentDate.year ~= lastResetDate.year or
      (currentDate.day == resetDay and
        lastResetDate.day ~= resetDay and
        hasPassedResetTime()))
  end

  return false
end

-- 重置特定玩家的特定任务
---@param playerId number 玩家ID
---@param missionCategory string 任务类别
---@param missionName string 任务名称
---@return boolean -- 重置成功返回true, 失败返回false
local function ResetMission(playerId, missionCategory, missionName)
  if missionCache[playerId] and missionCache[playerId][missionCategory] then
    for i, mission in ipairs(missionCache[playerId][missionCategory]) do
      if mission.name == missionName then
        mission.progress = 0
        mission.completed = false
        mission.lastReset = os.time() -- 记录重置时间
        return true
      end
    end
  end
  return false
end

-- 按重置类型重置所有在线玩家的对应任务
---@param resetType string 重置类型：'daily', 'weekly', 'monthly'
local function ResetMissionsByType(resetType)
  local currentTime = os.time()
  DebugPrint('正在重置 ' .. resetType .. ' 类型的任务, 时间: ' .. os.date('%Y-%m-%d %H:%M:%S', currentTime))

  -- 更新最后检查时间
  lastResetCheck[resetType] = currentTime

  -- 从数据库获取所有玩家的任务数据
  MySQL.query('SELECT * FROM user_missions', {}, function(results)
    if results then
      local updateCount = 0
      local onlinePlayersProcessed = {}

      -- 首先处理在线玩家
      for playerId, playerData in pairs(missionCache) do
        local player = ESX.GetPlayerFromId(playerId)
        if player then
          local resetCount = 0
          onlinePlayersProcessed[player.identifier] = true

          -- 遍历所有任务类别
          for categoryName, categoryMissions in pairs(playerData) do
            -- 遍历类别中的所有任务
            for i, mission in ipairs(categoryMissions) do
              -- 获取任务配置
              local missionConfig = GetMissionConfig(categoryName, mission.name)
              if missionConfig and missionConfig.resetType == resetType then
                -- 重置任务
                mission.progress = 0
                mission.completed = false
                mission.lastReset = currentTime
                resetCount = resetCount + 1
              end
            end
          end

          if resetCount > 0 then
            -- 保存到数据库
            local missionDataJson = json.encode(playerData)
            MySQL.query('UPDATE user_missions SET mission_data = ? WHERE identifier = ?', {
              missionDataJson,
              player.identifier
            })

            -- 通知玩家
            TriggerClientEvent('esx:showNotification', playerId, '已重置 ' .. resetCount .. ' 个' ..
              (resetType == 'daily' and '日常' or
                resetType == 'weekly' and '周常' or
                resetType == 'monthly' and '月常' or '') .. '任务')

            -- 同步到客户端
            TriggerClientEvent('esx_missions:syncMissions', playerId, playerData)
            updateCount = updateCount + 1
          end
        end
      end

      -- 然后处理离线玩家
      for _, row in ipairs(results) do
        -- 跳过已处理的在线玩家
        if not onlinePlayersProcessed[row.identifier] then
          local playerData = json.decode(row.mission_data)
          local needsUpdate = false

          -- 遍历所有任务类别
          for categoryName, categoryMissions in pairs(playerData) do
            -- 遍历类别中的所有任务
            for i, mission in ipairs(categoryMissions) do
              -- 获取任务配置
              local missionConfig = GetMissionConfig(categoryName, mission.name)
              if missionConfig and missionConfig.resetType == resetType then
                -- 重置任务
                mission.progress = 0
                mission.completed = false
                mission.lastReset = currentTime
                needsUpdate = true
              end
            end
          end

          -- 如果有任务被重置，更新数据库
          if needsUpdate then
            local missionDataJson = json.encode(playerData)
            MySQL.query('UPDATE user_missions SET mission_data = ? WHERE identifier = ?', {
              missionDataJson,
              row.identifier
            })
            updateCount = updateCount + 1
          end
        end
      end

      DebugPrint(('已更新 %d 个玩家的任务数据'):format(updateCount))
    end
  end)
end

-- 初始化任务重置系统
local function InitTaskScheduler()
  DebugPrint('初始化任务重置系统...')

  -- 启动单独线程处理任务重置检查
  CreateThread(function()
    -- 记录上次检查时间
    local lastChecks = {
      daily = { time = 0 },
      weekly = { time = 0 },
      monthly = { time = 0 }
    }

    -- 输出重置时间配置
    for resetType, times in pairs(Config.ResetTimes) do
      local timeStr = string.format('时间: %02d:%02d', times.hour or 0, times.minute or 0)
      if resetType == 'weekly' then
        timeStr = string.format('周%d %s', times.weekday or 1, timeStr)
      elseif resetType == 'monthly' then
        timeStr = string.format('%d日 %s', times.day or 1, timeStr)
      end
      DebugPrint(string.format('任务重置配置 - %s: %s', resetType, timeStr))
    end

    -- 主循环, 每分钟检查一次
    while true do
      local now = os.time()
      local currentDate = os.date('*t', now)

      -- 检查各类型任务重置
      for resetType, times in pairs(Config.ResetTimes) do
        local lastCheck = lastChecks[resetType]
        if lastCheck then
          local lastCheckDate = os.date('*t', lastCheck.time)

          -- 检查是否需要重置
          if currentDate.day ~= lastCheckDate.day or
              currentDate.month ~= lastCheckDate.month or
              currentDate.year ~= lastCheckDate.year then
            -- 检查是否到达重置时间点
            if currentDate.hour == (times.hour or 0) and
                currentDate.min == (times.minute or 0) and
                (resetType ~= 'weekly' or currentDate.wday == (times.weekday or 1)) and
                (resetType ~= 'monthly' or currentDate.day == (times.day or 1)) then
              -- 执行重置
              DebugPrint(string.format('执行%s任务重置, 当前时间: %s',
                resetType,
                os.date('%Y-%m-%d %H:%M:%S')
              ))
              lastResetCheck[resetType] = now
              ResetMissionsByType(resetType)
              lastCheck.time = now
            end
          end
        end
      end

      -- 等待下一分钟
      Wait(60000)
    end
  end)
end

-- 资源启动时执行初始化
CreateThread(function()
  -- 确保所有系统都已加载
  Wait(1000)

  -- 初始化任务调度器
  InitTaskScheduler()
end)

-- 玩家登录事件处理
-- 加载任务数据并检查任务重置情况
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer, isNew)
  local player = xPlayer
  if player then
    -- 获取数据库中数据
    MySQL.query('SELECT * FROM user_missions WHERE identifier = ?', {
      player.identifier
    }, function(response)
      if response[1] then
        missionCache[playerId] = json.decode(response[1].mission_data) or {}

        -- 检查是否需要重置任务
        local updateNeeded = false
        for categoryName, categoryMissions in pairs(missionCache[playerId]) do
          for i, mission in ipairs(categoryMissions) do
            local missionConfig = GetMissionConfig(categoryName, mission.name)
            if missionConfig and missionConfig.resetType and missionConfig.resetType ~= 'never' then
              if ShouldResetMission(missionConfig.resetType, mission.lastReset) then
                mission.progress = 0
                mission.completed = false
                mission.lastReset = os.time()
                updateNeeded = true
              end
            end
          end
        end

        -- 如果有任务被重置, 保存到数据库
        if updateNeeded then
          local missionDataJson = json.encode(missionCache[playerId])
          MySQL.query('UPDATE user_missions SET mission_data = ? WHERE identifier = ?', {
            missionDataJson,
            player.identifier
          })
          -- 通知玩家任务已重置
          TriggerClientEvent('esx:showNotification', playerId, '部分任务已重置')
        end
      else
        -- 数据库中没有数据, 则使用 Config.Missions 初始化
        missionCache[playerId] = {}
        local currentTime = os.time()

        for categoryName, categoryData in pairs(Config.Missions) do
          missionCache[playerId][categoryName] = {}
          if categoryData.mission then
            for _, missionConfig in ipairs(categoryData.mission) do
              table.insert(missionCache[playerId][categoryName], {
                name = missionConfig.name, -- 任务配置中的名称
                progress = 0,              -- 初始进度为0
                completed = false,         -- 初始状态为未完成
                lastReset = currentTime    -- 初始重置时间为当前时间
              })
            end
          end
        end
        -- 保存初始化后的数据到数据库
        local missionDataJson = json.encode(missionCache[playerId])
        MySQL.query('INSERT INTO user_missions (identifier, mission_data) VALUES (?, ?) ON DUPLICATE KEY UPDATE mission_data = ?', {
          player.identifier,
          missionDataJson,
          missionDataJson
        })
      end
    end)
  end
end)

-- 玩家离开服务器事件处理
-- 保存玩家任务数据到数据库
AddEventHandler('esx:playerDropped', function(playerId)
  local player = ESX.GetPlayerFromId(playerId)
  if player then
    local missionData = missionCache[playerId] or {}
    local missionDataJson = json.encode(missionData)

    -- 保存数据到数据库
    MySQL.query('INSERT INTO user_missions (identifier, mission_data) VALUES (?, ?) ON DUPLICATE KEY UPDATE mission_data = ?', {
      player.identifier,
      missionDataJson,
      missionDataJson
    })

    -- 清理速率限制数据
    rateLimiter:clear(playerId)
  end
end)

-- 等级检查函数
---@param playerId number 玩家ID
---@param requiredLevel number 需要的等级
---@return boolean 是否满足等级要求
local function CheckLevelRequirement(playerId, requiredLevel)
  if GetResourceState('xperience') == 'started' then
    local playerLevel = exports.xperience:GetPlayerRank(playerId)
    return playerLevel >= requiredLevel
  else
    return true
  end
end

-- 更新任务数据的辅助函数
---@param playerId number 玩家ID
---@param missionCategory string 任务类别
---@param missionName string 任务名称
---@param progress number 当前进度
---@param completed boolean 是否完成
---@param additionalData? table 额外数据
local function UpdateMissionData(playerId, missionCategory, missionName, progress, completed, additionalData)
  -- 确保缓存存在
  if not missionCache[playerId] then missionCache[playerId] = {} end
  if not missionCache[playerId][missionCategory] then missionCache[playerId][missionCategory] = {} end

  -- 查找任务数据
  local missionExists = false
  for _, mission in ipairs(missionCache[playerId][missionCategory]) do
    if mission.name == missionName then
      mission.progress = progress
      mission.completed = completed
      -- 合并额外数据
      if additionalData then
        for k, v in pairs(additionalData) do
          mission[k] = v
        end
      end
      missionExists = true
      break
    end
  end

  -- 如果任务不存在, 添加任务
  if not missionExists then
    local newMission = {
      name = missionName,
      progress = progress,
      completed = completed,
      firstUpdate = os.time(),
      lastReset = os.time()
    }
    -- 合并额外数据
    if additionalData then
      for k, v in pairs(additionalData) do
        newMission[k] = v
      end
    end
    table.insert(missionCache[playerId][missionCategory], newMission)
  end
end

-- 发放任务奖励的辅助函数
---@param xPlayer table ESX玩家对象
---@param missionCategory string 任务类别
---@param missionConfig table 任务配置
local function GrantMissionRewards(xPlayer, missionCategory, missionConfig)
  if not missionConfig.reward then return end

  -- 发放金钱奖励
  if missionConfig.reward.money then
    xPlayer.addMoney(missionConfig.reward.money)
  end

  -- 发放经验奖励
  if missionConfig.reward.xp then
    DebugPrint(('XP系统未实现. 玩家 %s (%s) 完成任务种类: "%s" 任务名称: "%s" 并应获得 %d XP.'):format(
      xPlayer.identifier,
      xPlayer.name,
      missionCategory,
      missionConfig.title,
      missionConfig.reward.xp
    ))
  end

  -- 发放物品奖励
  if missionConfig.reward.item then
    for _, itemData in ipairs(missionConfig.reward.item) do
      if itemData.amount > 0 then
        xPlayer.addInventoryItem(itemData.name, itemData.amount)
      end
    end
  end

  -- 发放车辆奖励
  if missionConfig.reward.car then
    DebugPrint(('车辆奖励系统未实现. 玩家 %s (%s) 完成任务种类: "%s" 任务名称: "%s" 并应获得一辆车.'):format(
      xPlayer.identifier,
      xPlayer.name,
      missionCategory,
      missionConfig.title
    ))
  end
end

-- 任务状态更新事件处理
-- 接收客户端发送的任务进度更新请求, 并处理任务进度、完成状态和奖励发放
-- @param {string} missionCategory - 任务类别
-- @param {string} missionName - 任务名称
-- @param {number|boolean} progress - 任务进度增量或完成状态
-- @returns {boolean} - 更新成功返回true, 失败返回false
RegisterNetEvent('esx_missions:updateMissionStatus')
AddEventHandler('esx_missions:updateMissionStatus', function(missionCategory, missionName, progress)
  local src = source
  local xPlayer = ESX.GetPlayerFromId(src)

  if not xPlayer then return end

  -- 检查速率限制
  if not rateLimiter:check(src) then
    TriggerClientEvent('esx:showNotification', src, '请求过于频繁, 请稍后再试')
    return false
  end

  -- 检查任务是否有效
  local missionConfig = GetMissionConfig(missionCategory, missionName)
  if not missionConfig then
    TriggerClientEvent('esx:showNotification', src, '错误: 任务不存在')
    return false
  end

  -- 检查等级要求
  if missionConfig.levelRequire and missionConfig.levelRequire > 0 then
    if not CheckLevelRequirement(src, missionConfig.levelRequire) then
      TriggerClientEvent('esx:showNotification', src, ('错误: 需要等级 %d 才能进行此任务'):format(missionConfig.levelRequire))
      return false
    end
  end

  local currentProgress = GetMissionProgress(src, missionCategory, missionName) or 0

  -- 更新进度
  if type(progress) == "number" then
    currentProgress = currentProgress + progress
  end

  if type(progress) == "boolean" and progress == true then
    currentProgress = missionConfig.count
  end

  if currentProgress >= missionConfig.count then
    -- 检查任务是否已经完成
    local currentMissionData = GetMissionData(src, missionCategory, missionName)
    if currentMissionData and not currentMissionData.completed then
      -- 发放奖励
      GrantMissionRewards(xPlayer, missionCategory, missionConfig)

      -- 更新任务数据
      UpdateMissionData(src, missionCategory, missionName, missionConfig.count, true, {
        completedAt = os.time()
      })

      -- 通知客户端任务完成
      TriggerClientEvent('esx:showNotification', src, ('任务种类: "%s" 任务名称: "%s" 已完成！'):format(missionCategory, missionConfig.title))
    end
  else
    -- 更新任务数据
    UpdateMissionData(src, missionCategory, missionName, currentProgress, false)

    -- 通知客户端进度更新
    TriggerClientEvent('esx:showNotification', src, ('任务种类: "%s" 任务名称: "%s" 进度已更新。当前进度: %d/%d'):format(missionCategory, missionConfig.title, currentProgress, missionConfig.count))
  end

  -- 任务数据更新后, 同步到客户端
  TriggerClientEvent('esx_missions:syncMissions', src, missionCache[src])
end)

-- 服务端回调: 获取玩家任务数据
lib.callback.register('esx_missions:getPlayerMissions', function(source)
  local player = ESX.GetPlayerFromId(source)
  if not player then return end

  return missionCache[source] or {}
end)

-- 导出等级检查函数供其他资源使用
exports('checkMissionLevelRequirement', function(playerId, missionCategory, missionName)
  if not playerId or not missionCategory or not missionName then
    return false
  end

  local missionConfig = GetMissionConfig(missionCategory, missionName)
  if not missionConfig then
    return false
  end

  if not missionConfig.levelRequire or missionConfig.levelRequire <= 0 then
    return true
  end

  return CheckLevelRequirement(playerId, missionConfig.levelRequire)
end)

-- 添加服务端回调用于客户端检查等级要求
lib.callback.register('esx_missions:checkLevelRequirement', function(source, missionCategory, missionName)
  if not source or not missionCategory or not missionName then
    return false
  end

  local missionConfig = GetMissionConfig(missionCategory, missionName)
  if not missionConfig then
    return false
  end

  if not missionConfig.levelRequire or missionConfig.levelRequire <= 0 then
    return true
  end

  return CheckLevelRequirement(source, missionConfig.levelRequire)
end)
