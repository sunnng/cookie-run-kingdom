---
name: sb-biscuit-script-dev
description: 帅斌饼干助手（懒人精灵 Lua 脚本）的开发指南。当用户询问如何新增功能模块、如何开发脚本、脚本架构、页面/路由/任务/会话如何编写、图色或 OCR 封装怎么用、UI 配置面板怎么加、调度注册如何接入、调试日志怎么看时，必须使用本 skill。也适用于审查脚本代码、重构模块、修复状态机或调度 bug。
---

# 帅斌饼干脚本开发指南

本 skill 面向在 `帅斌饼干/脚本` 工程中新增、修改、调试 Lua 脚本的同学。先理解整体架构，再按约定分层实现，能显著降低维护成本。

## 一、项目结构

```
帅斌饼干/脚本/
├── main.lua                 -- 入口：初始化 UI、授权、OCR，关闭窗口后启动 Runtime
├── config.lua               -- 静态常量（版本、热更、OCR、显示、用户配置默认值）
├── core/                    -- 核心框架
│   ├── runtime.lua          -- 永久运行引擎：调度 + 守卫
│   ├── scheduler.lua        -- 任务调度器
│   ├── state-machine.lua    -- 通用状态机
│   ├── guard.lua            -- 弹窗/陷阱守卫
│   └── state.lua            -- 全局状态（较少使用）
├── lib/                     -- 通用工具库
│   ├── touch.lua            -- 点击、滑动、按键封装
│   ├── color.lua            -- 比色、找色、等待、tapUntilMatch
│   ├── ocr.lua              -- TomatoOCR 封装
│   ├── logger.lua           -- 日志 + 文件轮转
│   ├── store.lua            -- data/store.json 键值持久化
│   ├── user-config.lua      -- 用户配置（默认值 + 持久化覆盖）
│   ├── status-hud.lua       -- 顶部状态 HUD
│   ├── paths.lua            -- 数据/日志路径
│   └── ...
├── ui/                      -- imgui 界面
│   ├── app.lua              -- 主窗口入口
│   ├── components.lua       -- 可复用控件
│   ├── tabs/
│   │   ├── feature-tab.lua  -- 功能开关
│   │   └── config-tab.lua   -- 参数配置
│   └── *-config-panel.lua   -- 各模块专属配置面板
└── game/                    -- 业务模块
    ├── register.lua         -- 把任务/守卫注入核心框架
    ├── 通用_王国/           -- 通用页面：王国首页等
    ├── 通用_弹窗/           -- 通用弹窗处理
    ├── 功能_洗脆饼/         -- 简单功能模块示例
    └── 常规_XXX/            -- 常规玩法模块
        ├── XXX_路由.lua
        ├── XXX_特征库.lua
        ├── XXX首页_页面.lua
        └── 模块_XXX/
            ├── XXX_任务.lua
            ├── XXX_页面.lua
            └── XXX_会话.lua
```

除脚本目录外，项目说明文档按功能模块分类存放：

```
项目根目录/
├── 开发文档/                 -- 懒人精灵平台 API 文档，只读，禁止修改和新增
│   ├── 触控方法/
│   ├── 图色方法/
│   ├── OCR 方法/
│   └── ...
├── 产品说明文档.md           -- 项目级说明
├── 矿山开采流程.md           -- 矿山模块说明
├── 竞技场模块说明文档.md     -- 竞技场模块说明
└── ...                       -- 其他按功能模块分类的项目文档
```

## 二、核心设计原则

1. **分层解耦**：页面（图色/OCR/点击）→ 路由（导航）→ 任务（状态机）→ 会话（持久化）。不要在一个文件里写所有逻辑。
2. **状态机驱动长流程**：任何多步骤、需要反复轮询识别的玩法，必须用 `core.state-machine`。
3. **调度器统一入口**：所有周期性任务通过 `game.register.lua` 注册到 `core.scheduler`。
4. **配置即数据**：用户可调参数放 `config.lua` 的 `STATIC.USER` 默认值，运行时通过 `lib.user-config` 读写。
5. **静态配置只读**：`config.lua` 里 `STATIC` 是打包常量，运行时只读。动态覆盖用 `lib.user-config` + `lib.store`。
6. **所有长按/等待必须切分片**：使用 `Guard.sleep` 或 `Color.wait` 系列，保证等待期间守卫能扫描弹窗。

## 三、新增一个功能模块的标准步骤

> 提示：本章每一层（任务/页面/路由/会话/特征库/UI 面板）都提供了可直接复制使用的 Lua 模板，详见「十二、脚本模板」。

以一个常规玩法为例，推荐创建以下文件：

```
game/常规_玩法名/
├── 玩法名_路由.lua          -- 页面间导航（进入 + 返回）
├── 玩法名_特征库.lua        -- 所有比色/OCR 特征定义
├── 玩法名首页_页面.lua      -- 玩法入口首页识别与按钮
└── 模块_子玩法/
    ├── 子玩法_任务.lua      -- 状态机主流程
    ├── 子玩法_页面.lua      -- 子页面图色/OCR/点击
    └── 子玩法_会话.lua      -- 进度/冷却/ busy 持久化
```

如果功能很简单（如洗脆饼），可以简化为：

```
game/功能_洗脆饼/
├── task.lua                 -- 任务入口
└── 词条库.lua              -- 数据/配置表
```

### 3.1 任务层：状态机

```lua
local StateMachine = require("core.state-machine")
local Logger = require("lib.logger")
local Guard = require("core.guard")

local Task = {}
local TAG = "[模块名]"

local function detect(sm)
    -- 识别当前页面，返回下一个状态名
end

local function navigate(sm)
    -- 导航到目标页面
end

local function doSomething(sm)
    -- 执行业务逻辑
    -- 成功进入下一状态：return "nextState"
    -- 需要重试：return StateMachine.RETRY
    -- 保持等待：return StateMachine.KEEP
    -- 完成：return StateMachine.DONE
    -- 致命错误：return false, "错误信息"
end

local handlers = {
    detect = detect,
    navigate = navigate,
    doSomething = doSomething,
}

function Task.run()
    local sm = StateMachine.new()
    sm:init("detect", {
        maxRetry = 3,
        timeout = 1800,
        retryIntervalMs = 1000,
    })
    local ok, err = sm:run(handlers, {
        interval = 500,
        guard = Guard.check,
        label = "模块名",
    })
    return ok
end

return Task
```

状态机返回值约定：

| 返回值 | 含义 |
|--------|------|
| `"state"` | 切换到该状态，重试计数清零 |
| `StateMachine.RETRY` | 当前状态重试，`retries += 1` |
| `StateMachine.KEEP` / `nil` | 保持当前状态，不计重试 |
| `StateMachine.DONE` | 正常结束 |
| `false, "msg"` | 致命错误，终止任务 |

### 3.2 页面层：图色 / OCR / 点击

页面模块只负责：识别页面、识别元素、执行点击。不持有状态。

```lua
local Color = require("lib.color")
local Touch = require("lib.touch")
local Ocr = require("lib.ocr")
local Logger = require("lib.logger")

local Page = {}
local TAG = "[模块名.页面]"

local Features = require("game.常规_XXX.XXX_特征库").xxx()

function Page.isXxxPage()
    return Color.match(Features.page.feature)
end

function Page.waitXxxPage(timeoutMs, intervalMs)
    return Color.wait(Features.page.feature, timeoutMs, intervalMs)
end

function Page.tapSomeBtn()
    Touch.tapArea(Features.someBtn, 800)
end

function Page.readSomeText()
    return Ocr.text(Features.someOcrRect, "text")
end

return Page
```

### 3.3 路由层：导航

```lua
local Route = {}

function Route.kingdomHomeToXxxHome()
    KingdomPage.tapEventBtn()
    KingdomPage.tapXxxBtn()
    return XxxHomePage.wait()
end

function Route.returnToKingdom()
    -- 从任意页面返回王国首页
end

return Route
```

### 3.4 会话层：持久化

用于记录冷却、busy、进度等跨轮次状态。

```lua
local Store = require("lib.store")
local Logger = require("lib.logger")

local Session = {}
local KEY = "模块名_session"
local TAG = "[模块名.会话]"

function Session.enterBusyWait(waitSec)
    local until_ = os.time() + waitSec
    Store.set(KEY, { allBusyUntil = until_, recordedAt = os.time() })
end

function Session.checkReady()
    local raw = Store.get(KEY)
    if not raw or not raw.allBusyUntil then
        return true, 0
    end
    local remain = raw.allBusyUntil - os.time()
    if remain <= 0 then
        return true, 0
    end
    return false, remain
end

function Session.restoreProgress()
    local _, remain = Session.checkReady()
    return remain
end

function Session.clear()
    Store.set(KEY, {})
end

function Session.describe()
    -- 返回给 UI 展示的状态字符串
end

return Session
```

### 3.5 特征库

特征库存放所有 `findMultiColor` / `cmpColorExT` / OCR 区域定义。不要散落在业务代码里。

```lua
local FeatureLib = {}

local common = {
    backBtn = { 1546, 39, 1559, 53 },
}

local xxx = {
    page = {
        feature = {"x|y|color,...", 0.9},
    },
    someBtn = { x1, y1, x2, y2 },
    someOcrRect = { x1, y1, x2, y2 },
}

function FeatureLib.xxx()
    return xxx
end

return FeatureLib
```

比色字符串格式：`"x|y|color,...
- `color` 可直接写 `0xRRGGBB`，也可写 `0xRRGGBB-0x101010` 做偏色。
- `findMultiColor` 参数顺序：`x1, y1, x2, y2, firstColor, offsetColors, dir, sim`。
- `offsetColors` 格式：`"dx|dy|color|..."`。

## 四、核心库速查

### 4.1 lib.touch

```lua
local Touch = require("lib.touch")

Touch.tapR(x, y, delayMs)           -- 带抖动的点击
Touch.tapArea(rect, delayMs)        -- 区域内随机点击
Touch.tapAreaSafe(rect, delayMs)    -- rect 为 nil 时跳过
Touch.pressBack(delayMs)            -- 按返回键
Touch.swipeEx(opts)                 -- 精细滑动
Touch.swipeX(x1, x2, y, opts)
Touch.swipeY(y1, y2, x, opts)
```

`swipeEx` 参数：

```lua
{
    x1, y1, x2, y2,     -- 起点/终点
    moveMs = 600,       -- 滑动总时长
    holdMs = 200,       -- 终点停留
    downMs = 50,        -- 按下后等待
    steps = 1,          -- 分段数
    pauseMs = 0,        -- 分段间停顿
    upMs = 0,           -- 松手后等待
    id = 1              -- 手指 ID
}
```

### 4.2 lib.color

```lua
local Color = require("lib.color")

Color.match(feature)                -- 单特征比色
Color.matchAny(features)            -- 任一匹配
Color.wait(features, timeoutMs, intervalMs)
Color.waitMatch(feature, timeoutMs, intervalMs, sleepMs)
Color.waitGone(feature, timeoutMs, intervalMs)
Color.tapUntilMatch(tapTarget, feature, opts)
Color.find(def)                     -- 返回 x, y
Color.findAll(def)                  -- 返回 {x, y} 数组
Color.tapFind(def, delayMs)
```

### 4.3 lib.ocr

```lua
local Ocr = require("lib.ocr")

Ocr.scan(rect, mode, returnType, cfg)   -- mode: 2=单行, 3=多行；returnType: "text"/"num"/"json"
Ocr.text(rect, returnType)
Ocr.number(rect, cfg)
Ocr.has(text, rect)
Ocr.tap(text, rect, delayMs)
Ocr.find(text, rect)                    -- 返回 x, y
Ocr.wait(text, rect, timeoutMs, intervalMs)
Ocr.waitTap(text, rect, timeoutMs, intervalMs, delayMs)
Ocr.fraction(rect)                      -- 识别 "cur/max"，返回 cur, max, raw
```

### 4.4 lib.user-config

```lua
local UserConfig = require("lib.user-config")

local cfg = UserConfig.get("mine")          -- 读取某模块配置
UserConfig.set("mine", { targetFloor = 6 }) -- 局部修改
UserConfig.save()                           -- 持久化到 store
```

### 4.5 lib.store

```lua
local Store = require("lib.store")

Store.get(key, default)
Store.set(key, value)
Store.del(key)
Store.incr(key, delta, default)
Store.clear()
```

### 4.6 lib.logger

```lua
local Logger = require("lib.logger")

Logger.error(msg)
Logger.warn(msg)
Logger.info(msg)
Logger.debug(msg)   -- 默认不输出，调 Logger.level = 4 开启
```

## 五、注册到调度器

在 `game/register.lua` 中：

1. 引入任务、会话、路由。
2. 用 `Guard.register` 注册弹窗陷阱。
3. 用 `Scheduler.add(name, condition, action)` 注册任务。

```lua
local Scheduler = require("core.scheduler")
local Guard = require("core.guard")
local UserConfig = require("lib.user-config")

local XxxTask = require("game.常规_XXX.模块_XXX.XXX_任务")
local XxxSession = require("game.常规_XXX.模块_XXX.XXX_会话")
local SquareRoute = require("game.常规_布谷鸟广场.广场_路由")
local SquareTask = require("game.常规_布谷鸟广场.广场_任务")

-- 通用离开广场逻辑
local function leaveSquareIfNeeded()
    if SquareRoute.isSquareContext() then
        if not SquareTask.leaveForOtherTask() then
            Logger.warn("[Register] 离开广场失败")
            return false
        end
    end
    return true
end

Scheduler.add("任务名", function()
    -- condition
    local cfg = UserConfig.get("xxx")
    if not cfg.enabled then
        return false
    end
    local canRun, remain = XxxSession.checkReady()
    if not canRun then
        -- 可更新 HUD
        return false
    end
    return true
end, function()
    -- action
    if not leaveSquareIfNeeded() then
        return
    end
    XxxTask.run()
end)
```

任务优先级原则：

- 矿山相关任务优先（矿山待执行时，广场/海滩/竞技场应跳过）。
- 广场挂机作为最低优先级填充任务。

## 六、UI 配置面板

### 6.1 功能开关（feature-tab.lua）

新增开关：

```lua
local function bindXxxCheckbox(handle)
    local cfg = UserConfig.get("xxx")
    imgui.setChecked(handle, cfg.enabled == true)
    imgui.setOnCheck(handle, function(_, checked)
        UserConfig.set("xxx", { enabled = checked })
        UserConfig.save()
    end)
end

-- 在 build 中
bindXxxCheckbox(imgui.createCheckBox(row, "功能名"))
```

### 6.2 参数配置（config-tab.lua）

```lua
local XxxConfigPanel = require("ui.xxx-config-panel")

local xxxTree = imgui.createTreeBoxLayout(layout, "功能名", -1)
local xxxPanel = XxxConfigPanel.build(xxxTree)

-- 在 save 按钮回调中
xxxPanel.save()
```

### 6.3 配置面板示例

```lua
local Components = require("ui.components")
local UserConfig = require("lib.user-config")

local Panel = {}

function Panel.build(parent)
    local cfg = UserConfig.get("xxx")
    local input = Components.labeledInput(parent, "参数:", cfg.someValue)

    local function save()
        local value = tonumber(imgui.getInputText(input))
        if value and value > 0 then
            UserConfig.set("xxx", { someValue = math.floor(value) })
        end
    end

    local function refresh()
        local saved = UserConfig.get("xxx")
        imgui.setInputText(input, tostring(saved.someValue))
    end

    return { save = save, refresh = refresh }
end

return Panel
```

完整配置面板模板见 `scripts/ui-config-panel-template.lua`。

## 七、调试与测试

### 7.1 本地日志

- 日志文件：`/sdcard/帅斌饼干/run.log`（具体路径见 `lib.paths`）。
- 开启 DEBUG：`lib.logger.level = 4`。
- 查看实时日志：用 `adb logcat` 或读取 run.log。

### 7.2 单元测试技巧

- 写一个临时入口文件，require 目标模块并调用函数，观察 print 输出。
- 比色/找色用 `Color.match` / `Color.find` 单独验证特征是否命中。
- OCR 用 `Ocr.text` / `Ocr.scan` 单独截图验证识别结果。

### 7.3 状态机调试

开启 DEBUG 后，状态机每轮会打印：

```
[StateMachine] [标签] [tick#N] 状态=xxx retry=0 err=0
```

如果任务异常退出，查看最后状态、重试次数、错误信息。

## 八、代码风格

1. **模块头注释**：每个文件顶部写清楚模块名、路径、功能、依赖。
2. **局部变量用 `local`**，不要污染全局。
3. **TAG 常量**：每个业务模块定义本地 `TAG`，日志统一前缀。
4. **命名约定**：
   - 目录：`功能_名称`、`常规_名称`、`通用_名称`
   - 文件：`模块_子玩法/子玩法_任务.lua`、`子玩法_页面.lua`、`子玩法_会话.lua`
   - 函数：`isXxxPage()`、`waitXxxPage()`、`tapXxxBtn()`、`readXxx()`
5. **空格**：逗号后空格、赋值号两侧空格、`if ... then` 前后空格。
6. **不要直接调原生 `sleep` 做长等待**：用 `Guard.sleep` 或 `Color.wait`。
7. **不要直接调原生 `tap`**：用 `Touch.tapR` / `Touch.tapArea`。

## 九、文档管理规范

1. **`开发文档/` 只读**：该目录存放懒人精灵平台提供的原生 API 文档（触控、图色、OCR、交互方法等）。禁止在此目录下修改、删除或新增任何文件。
2. **项目说明文档放根目录**：根据项目自身生成的流程、设计、模块说明等文档，统一放在项目根目录下。
3. **按功能模块分类命名**：
   - 全局/产品级说明：`产品说明文档.md`
   - 单个玩法/功能模块：`{模块名}模块说明文档.md`、`{模块名}流程.md`、`{模块名}设计文档.md`
   - 示例：`矿山开采流程.md`、`竞技场模块说明文档.md`、`远程控制实施计划.md`
4. **不要混放**：不要把项目说明文档塞进 `开发文档/`，也不要把平台 API 文档复制到根目录。
5. **文档应与代码同步**：修改状态机、调度逻辑或配置项后，同步更新对应模块说明文档，避免文档与实际行为脱节。

## 十、常见陷阱

| 问题 | 正确做法 |
|------|----------|
| 长 sleep 期间弹窗未处理 | 用 `Guard.sleep(ms, stepMs)` 或 `Color.wait` |
| 状态机里直接 `sleep` | 返回 `StateMachine.KEEP`，由 runner 分片 sleep |
| 比色特征到处写 | 集中放到 `*_特征库.lua` |
| 用户配置直接改 `config.lua` | 运行时改 `lib.user-config`，打包常量只读 |
| 任务里写死等待时间 | 用 `Session` 持久化 busy/冷却 |
| OCR 后不复原引擎参数 | `Ocr.scan` 内部已 `applyEngine()` 还原 |
| 忘记在 register 注册 | 功能永远不会被调度器执行 |
| 弹窗处理写在任务里 | 通用弹窗用 `Guard.register` |
| 比色字符串格式错误 | 参考特征库现有写法，用 `-101010` 偏色 |
| 多指触控 ID 冲突 | `touchDown`/`touchMoveEx`/`touchUp` 使用不同 id |

## 十一、快速新增功能检查清单

- [ ] 在 `config.lua` 的 `STATIC.USER` 添加默认值
- [ ] 创建 `game/常规_功能名/` 目录及特征库、页面、路由、任务、会话
- [ ] 如果功能简单，可只创建 `game/功能_功能名/task.lua`
- [ ] 在 `ui/tabs/feature-tab.lua` 添加开关（如需要）
- [ ] 在 `ui/tabs/config-tab.lua` 添加配置面板（如需要）
- [ ] 在 `game/register.lua` 注册任务和守卫
- [ ] 本地临时入口测试核心识别和点击
- [ ] 完整运行，查看日志和 HUD
- [ ] 处理弹窗、异常、超时、重试边界

## 十二、脚本模板

本 skill 附带可直接复制使用的 Lua 模板，位于 `sb-biscuit-script-dev/scripts/`：

| 模板文件 | 用途 | 目标路径示例 |
|----------|------|--------------|
| `feature-module-template.lua` | 标准状态机任务模块 | `game/常规_XXX/模块_XXX/XXX_任务.lua` |
| `page-module-template.lua` | 页面识别与点击模块 | `game/常规_XXX/模块_XXX/XXX_页面.lua` |
| `route-module-template.lua` | 导航路由模块 | `game/常规_XXX/XXX_路由.lua` |
| `session-module-template.lua` | 冷却/进度持久化模块 | `game/常规_XXX/模块_XXX/XXX_会话.lua` |
| `feature-lib-template.lua` | 比色/OCR 特征库 | `game/常规_XXX/XXX_特征库.lua` |
| `ui-config-panel-template.lua` | imgui 配置面板 | `ui/xxx-config-panel.lua` |

使用方式：复制模板到目标路径，替换所有 `XXX`、`子玩法`、`xxx` 占位符，按业务补充 TODO 处代码。

## 十三、参考示例

- 简单功能：`game/功能_洗脆饼/task.lua`
- 标准状态机模块：`game/常规_未知的地底矿山/模块_矿山开采/`
- 配置面板：`ui/biscuit-config-panel.lua`
- 调度注册：`game/register.lua`

遇到具体实现问题时，先定位属于哪一层（页面/路由/任务/会话/UI/调度），再按本指南对应章节处理。
