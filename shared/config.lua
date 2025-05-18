Config = {}

-- Debug模式配置
Config.Debug = true -- 设置为true开启调试打印信息

-- 任务配置
Config.Missions = {
  ['新手任务'] = {
    _index = 1,
    icon = 'grip-lines',
    title = '新手任务',
    description = '完成新手任务, 获得丰厚新手奖励',
    mission = {
      {
        icon = 'car',
        name = 'get_noob_car', -- 任务名称
        title = '获得一辆新手车', -- 任务标题
        description = '获得一辆新手车', -- 任务描述
        help = 'get_noob_car_help', -- 任务帮助标识符
        count = 20, -- 任务总次数
        levelRequire = 0, -- 等级要求
        resetType = 'never', -- 重置类型: 'never'（永不重置）, 'daily'（每日）, 'weekly'（每周）, 'monthly'（每月）
        reward = { -- 任务奖励
          xp = 600, -- 经验奖励
          money = 2000, -- 金钱奖励
          item = { -- 物品奖励
            {
              name = 'water', -- 物品代码
              label = '瓶装水',
              amount = 50, -- 物品数量
            }
          },
          car = {
            {
              name = 'pcj',
              label = 'PCJ 600',
              amount = 10,
            }
          }
        }
      },
      {
        icon = 'calendar-check',
        name = 'do_daily_signin',
        title = '每日签到',
        description = '每日登录服务器即可在F5签到, 获得丰厚奖励',
        help = '每日登录服务器即可在F5签到, 获得丰厚奖励', -- 使用字符串类型的help
        count = 1,
        levelRequire = 0,
        resetType = 'daily', -- 每日重置
        reward = {
          xp = 100,
          money = 1000,
          item = {
            {
              name = 'water',
              label = '瓶装水',
              amount = 1,
            }
          },
        }
      },
    }
  },
  ['主线任务'] = {
    _index = 2,
    icon = 'up-right-from-square',
    title = '主线任务',
    description = '完成主线任务，体验完整剧情',
    mission = {}
  },
  ['支线任务'] = {
    _index = 3,
    icon = 'up-right-from-square',
    title = '支线任务',
    description = '完成支线任务，获得额外奖励',
    mission = {}
  },
  ['日常任务'] = {
    _index = 4,
    icon = 'cloud-sun',
    title = '日常任务',
    description = '完成日常任务, 获得丰厚日常奖励',
    mission = {
      {
        icon = 'user-slash',
        name = 'daily_kill_player',
        title = '击杀玩家',
        description = '击杀够数玩家即可完成任务!',
        count = 100,
        levelRequire = 0,
        resetType = 'daily', -- 每日重置
        reward = {
          xp = 100,
          money = 1000,
        }
      }
    }
  },
  ['周常任务'] = {
    _index = 5,
    icon = 'calendar-week',
    title = '周常任务',
    description = '完成周常任务, 获得丰厚周常奖励',
    mission = {
      {
        icon = 'user-slash',
        name = 'weekly_kill_player',
        title = '击杀玩家',
        description = '击杀够数玩家即可完成任务!',
        count = 100,
        levelRequire = 0,
        resetType = 'weekly', -- 每周重置
        reward = {
          xp = 100,
          money = 1000,
        }
      }
    }
  },
  ['月常任务'] = {
    _index = 6,
    icon = 'calendar-check',
    title = '月常任务',
    description = '完成月常任务，获得丰厚月常奖励',
    mission = {}
  },
}

-- 任务重置配置
Config.ResetTimes = {
  daily = { hour = 0, minute = 10 },              -- 每天0点重置
  weekly = { weekday = 1, hour = 0, minute = 0 }, -- 每周一0点重置
  monthly = { day = 1, hour = 0, minute = 0 }     -- 每月1号0点重置
}

-- 其他杂项设置
Config.Other = {
  key = {
    enable = true, -- 是否开启按键配置
    openMission = 'F5', -- 打开任务界面
  },

  command = { -- 命令配置
    openMission = 'missions', -- 打开任务界面
  },

  updateRateLimit = true,    -- 是否开启更新速率限制, 用于检查 esx_missions:updateMissionStatus 事件的调用频率
  updateRateLimitTime = 10,  -- 更新速率限制时间, 单位: 秒
  updateRateLimitCount = 10, -- 更新速率限制次数, 单位: 次
}