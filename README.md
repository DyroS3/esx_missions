# ESX Missions: 一个为 FiveM ESX 设计的综合任务系统

## 1. 引言

ESX Missions 是一个为 FiveM ESX 框架设计的强大任务系统. 它允许服务器管理员为玩家创建和管理多种多样的任务, 包括具有每日、每周和每月重置周期的任务. 该系统提供了一个用户界面, 方便玩家追踪任务进度, 并支持灵活的奖励系统.

## 2. 功能特性

*   **多样化的任务类别**: 支持多种任务类型, 如新手教程、主线剧情、支线任务、日常任务、周常任务和月常任务.
*   **自动化重置系统**: 根据可配置的时间表自动重置每日、每周和每月任务.
*   **用户界面 (NUI)**: 提供直观的用户界面, 供玩家查看可用任务、追踪进度并了解奖励.
*   **灵活的奖励系统**: 允许配置奖励, 包括游戏内货币、物品和经验值 (XP).
*   **进度持久化**: 玩家的任务进度会保存到数据库中.
*   **开发者 API**: 提供简单的客户端 API, 供其他资源更新任务状态.

## 3. 先决条件

*   [ESX Legacy](https://github.com/esx-framework/esx-legacy) (或兼容版本的 es_extended).

## 4. 安装步骤

1.  下载 `esx_missions` 资源.
2.  将 `esx_missions` 文件夹放置到您服务器的 `resources` 目录中.
3.  将 `esx_missions.sql` 文件导入到您的 MySQL 数据库中. 这将创建必需的 `user_missions` 表.
4.  在您的 `server.cfg` 文件中添加 `ensure esx_missions`.
5.  重启您的 FiveM 服务器.

## 5. 配置说明

所有主要配置均位于 `shared/config.lua` 文件中.

### 5.1. `Config.Missions`

此表定义了所有任务类别及其各自的任务.

**结构示例:**

```lua
Config.Missions = {
    ['CategoryKey'] = { -- 类别的唯一字符串键 (例如, 'daily_tasks')
        _index = 1,                             -- (整数) UI 中类别的排序顺序 (数字越小越靠前).
        icon = 'fas fa-tasks',                  -- (字符串) 类别的 Font Awesome 图标 (例如, 'fas fa-user-ninja').
        title = '每日任务',                     -- (字符串) 类别的显示标题.
        description = '完成这些任务以获得每日奖励. ', -- (字符串) 类别的描述.
        mission = {                             -- (表, 数组) 此类别中的任务列表.
            {
                icon = 'fas fa-walking',            -- (字符串) 任务的 Font Awesome 图标.
                name = 'daily_walk_distance',       -- (字符串) 任务的唯一内部名称/ID.
                title = '步行5公里',                -- (字符串) 任务的显示标题.
                description = '徒步总共行走5公里. ', -- (字符串) 任务的详细描述.
                count = 5000,                       -- (整数) 完成任务所需的目标计数或进度值 (例如, 距离的米数).
                levelRequire = 0,                   -- (整数) 开始/查看此任务所需的最低玩家等级 (0 表示无要求).
                resetType = 'daily',                -- (字符串) 重置频率: 'never' (永不), 'daily' (每日), 'weekly' (每周), 'monthly' (每月).
                -- isCompleted: (布尔值) 此状态由脚本根据玩家进度动态处理.
                reward = {                          -- (表) 任务奖励.
                    xp = 100,                       -- (整数, 可选) 经验值.
                    money = 500,                    -- (整数, 可选) 游戏内现金.
                    items = {                       -- (表, 数组, 可选) 物品奖励.
                        { name = 'water_bottle', amount = 2, label = '水瓶' } -- 'name' 是物品 ID, 'amount' 是数量, 'label' 是显示名称.
                    },
                    cars = {                        -- (表, 数组, 可选) 车辆奖励 (UI 主要显示名称).
                        { name = 'sultan', label = '苏丹跑车' } -- 'name' 是车辆模型, 'label' 是显示名称.
                    }
                },
                help = 'optional_help_event_trigger' -- (字符串, 可选) 如果存在, 可用于触发客户端事件以获取特定任务的帮助信息.
            },
            -- ... 此类别中的更多任务
        }
    },
    -- ... 更多类别
}
```

### 5.2. `Config.ResetTimes`

此表配置自动任务重置的确切时间.

**结构示例:**

```lua
Config.ResetTimes = {
  daily = { hour = 0, minute = 0 },    -- 每日在 00:00 (服务器时间) 重置.
  weekly = { weekday = 1, hour = 0, minute = 0 }, -- 每周的周一 (1=周一, 7=周日) 00:00 重置.
  monthly = { day = 1, hour = 0, minute = 0 }  -- 每月的第一天 00:00 重置.
}
```

## 6. 使用方法

### 6.1. 玩家命令

*   `/missions`: 打开任务界面.

### 6.2. 管理员/测试命令

*   `/testMission [任务类别Key] [任务名称Key] [进度数量]`: 更新特定任务的进度以进行测试.
    *   示例: `/testMission daily_tasks daily_walk_distance 500`
*   `/checkResetTimes`: 在服务器控制台显示已配置的重置时间.

## 7. API 参考

从其他资源与 `esx_missions` 交互的主要方式是通过客户端导出函数.

### 7.1. `updateMissionStatus` (客户端)

更新当前玩家任务的进度或完成状态.

**语法:**

```lua
exports['esx_missions']:updateMissionStatus(missionCategory, missionName, progress)
```

**参数:**

*   `missionCategory` (字符串): `Config.Missions` 中定义的任务类别键 (例如, `'daily_tasks'`).
*   `missionName` (字符串): 在 `Config.Missions` 中指定类别内定义的任务唯一 `name` (例如, `'daily_walk_distance'`).
*   `progress` (数字 | 布尔值):
    *   如果为 `数字`: 增加到任务当前进度的值. 系统会将此值与现有进度相加.
    *   如果为 `布尔值 (true)`: 将任务标记为完全完成, 无论其当前进度或目标 `count`如何.

**使用示例:**

```lua
-- 示例：玩家执行了推进任务进度的操作
AddEventHandler('myResource:playerWalkedSegment', function(distanceIncrement)
    -- 假设 'daily_tasks' 是一个类别, 'daily_walk_distance' 是一个任务名称
    exports['esx_missions']:updateMissionStatus('daily_tasks', 'daily_walk_distance', distanceIncrement)
end)

-- 示例：直接完成一个任务
RegisterNetEvent('myResource:playerAchievedGoal')
AddEventHandler('myResource:playerAchievedGoal', function(missionCategoryToComplete, missionNameToComplete)
    exports['esx_missions']:updateMissionStatus(missionCategoryToComplete, missionNameToComplete, true)
end)
```

## 8. 数据库结构

系统使用一个主表来存储玩家任务数据.

**表名: `user_missions`**

| 列名           | 类型          | 可为空 | 默认值                       | 描述                                        |
|----------------|---------------|------|------------------------------|-------------------------------------------------|
| `id`           | INT(11)       | 否   | AUTO_INCREMENT               | 主键.                                       |
| `identifier`   | VARCHAR(60)   | 否   |                              | 玩家的唯一标识符 (例如, license, steam).      |
| `mission_data` | LONGTEXT      | 否   |                              | 存储玩家任务进度和状态的 JSON 字符串.           |
| `last_updated` | TIMESTAMP     | 否   | `current_timestamp()` ON UPDATE `current_timestamp()` | 最后更新的时间戳.                              |

**索引:**
*   PRIMARY KEY (`id`)
*   INDEX `identifier` (`identifier`)
*   INDEX `mission_data` (`mission_data`(768)) (针对某些数据库版本对 JSON 数据的部分索引)

**约束:**
*   `mission_data` CHECK (json_valid(`mission_data`)) (确保 `mission_data` 是有效的 JSON)

## 9. 任务重置机制

任务重置系统设计稳健, 并在多个层面运行：

1.  **服务器启动时**: 资源启动时检查并执行必要的重置.
2.  **玩家登录时**: 当玩家登录时, 会根据其任务的 `resetType` 和该类型的上次重置时间检查其任务, 并在必要时进行更新.
3.  **定期检查**: 系统可能包括定期的服务器端检查, 以确保重置正确应用.

任务通过将其进度设置为 0 并将其完成状态设置为 `false` 来重置. 相关重置类型 (`daily`, `weekly`, `monthly`) 的 `lastReset` 时间戳会被更新.

## 10. 故障排除

*   **错误: "attempt to index a nil value" (通常与 `ESX` 或任务数据相关)**:
    *   确保 `es_extended` 在 `esx_missions` 之前启动.
    *   验证数据库中是否存在 `user_missions` 表及其结构是否与文档中的模式匹配.
    *   确认在 API 调用或配置中使用的 `missionCategory` 和 `missionName` 与 `Config.Missions` 中的键完全匹配.
    *   确保在进行任务交互之前, 玩家数据 (`ESX.PlayerData`) 已完全加载.
*   **任务未按预期重置**:
    *   仔细检查 `Config.ResetTimes` 的语法和逻辑时间是否正确.
    *   验证服务器时间是否准确.
    *   在服务器启动时或计划的重置时间, 检查服务器控制台是否有与重置机制相关的任何错误.

## 11. 项目结构

```
esx_missions/
├── client/                 # 客户端代码
│   ├── html/               # NUI (HTML, CSS, JS) 文件, 用于任务界面
│   │   ├── index.html
│   │   ├── style.css
│   │   └── script.js
│   └── main.lua            # 客户端 Lua 逻辑, NUI 事件处理, API 导出
├── server/                 # 服务器端代码
│   └── main.lua            # 服务器端 Lua 逻辑, 数据库交互, 任务重置处理
├── shared/                 # 共享配置
│   └── config.lua          # 共享配置 (Config.Missions, Config.ResetTimes)
├── esx_missions.sql        # 数据库表的 SQL 结构文件
├── fxmanifest.lua          # FiveM 资源清单文件
└── README.md               # 本文档
```

## 12. 贡献代码

欢迎贡献！请随时提交拉取请求 (Pull Requests) 或开启问题 (Issues) 来报告错误、请求功能或提出建议.

贡献代码时请注意:
*   遵循现有的编码风格.
*   为您的更改提供清晰的描述.
*   充分测试您的更改.

## 13. 未来增强计划 (路线图)

*   服务器端对任务开始请求的验证 (例如, 等级要求、前置任务).
*   国际化 (i18n) 支持.
*   在 NUI 中提供更精细的错误反馈.
*   支持为每个任务单独设置自定义重置时间/逻辑.