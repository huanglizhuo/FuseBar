# Mac Menu Bar Status Combiner — MVP PRD

## 1. 产品概述

### 1.1 产品定位

一款 macOS 菜单栏工具，将原本需要分别常驻在 Menu Bar 中的多个 **macOS 系统状态图标**，通过一个紧凑的组合式状态 UI 进行统一展示。

核心目标：

> 用更少的 Menu Bar 空间，保留用户真正需要一眼看到的系统状态。

产品不增加新的系统监控信息，而是重新组织 macOS 已经存在的信息。

例如原本：

`Wi-Fi | Bluetooth | Sound | Battery | Control Center`

可以变为：

`Unified Status | Control Center`

用户点击 Unified Status 后，再展开查看 Wi-Fi、Bluetooth、音量、电池等完整信息。

---

# 2. 背景与问题

随着用户安装越来越多 Menu Bar App，Mac 右上角空间会迅速变得拥挤。

系统自身也可能长期占据多个位置，例如：

* Wi-Fi
* Bluetooth
* Battery
* Sound
* Focus
* Screen Mirroring

这些状态都很有用，因此用户不希望完全隐藏。

但实际使用中，大多数状态只需要回答：

* 是否正常？
* 有没有异常？
* 当前大概是什么状态？

用户并不需要每个状态始终拥有一个独立图标。

### 核心矛盾

传统设计：

> 一个状态 = 一个 Menu Bar Icon

本产品尝试改成：

> 多个相关状态 = 一个 Composite Status Icon

只有在用户需要进一步确认或操作时，再展开为完整状态。

---

# 3. 产品目标

## 3.1 MVP 目标

第一版本只验证三个核心假设：

### 假设 1：组合 UI 可以显著减少 Menu Bar 占用

用户可以隐藏若干 macOS 原生 Menu Bar 图标，并由本应用的一个组合图标替代。

例如：

原来：

`Wi-Fi | Bluetooth | Sound | Battery`

变成：

`◉`

实现：

**4 icons → 1 icon**

---

### 假设 2：压缩后不会明显降低信息获取效率

用户无需打开菜单，也应该能够从组合图标判断关键状态，例如：

* Wi-Fi 是否连接
* Bluetooth 是否有设备连接
* 当前音量是否静音
* 当前电量大致水平
* 是否正在充电

---

### 假设 3：异常状态比正常状态更重要

正常状态应该尽可能安静。

例如：

* Wi-Fi 正常
* 蓝牙正常
* 电池充足
* 音量正常

只显示极简 Composite Icon。

出现异常时：

* Wi-Fi 断开
* 电量低
* 静音
* Bluetooth 设备断开

组合图标应突出异常信息。

因此产品设计原则是：

> Normal state should disappear into the UI.
> Exceptional state should surface itself.

---

# 4. 非目标

MVP 不做：

* CPU 使用率
* RAM
* 温度
* 网络速度
* 磁盘空间
* 天气
* 日历
* 股票
* App Launcher
* Clipboard
* Pomodoro
* 第三方 App 状态
* Menu Bar 图标自动整理
* Bartender / Ice 类完整 Menu Bar 管理

产品不是：

> Another system monitor.

而是：

> A compressed representation of native macOS system status.

---

# 5. MVP 支持的系统状态

第一版只选择 macOS 自身能够在 Menu Bar 中显示/隐藏，并且用户具有长期查看需求的状态。

## Tier 1：MVP 必须支持

### Wi-Fi

需要表达：

* Connected
* Disconnected
* Wi-Fi Off
* 信号强弱

---

### Bluetooth

需要表达：

* Bluetooth On
* Bluetooth Off
* 是否存在 Active Device

MVP 不要求展示全部设备。

只需要表达：

`0 / ≥1 active devices`

---

### Battery

需要表达：

* 当前电量
* Charging
* Fully Charged
* Low Battery

这是组合状态中优先级最高的信息之一。

---

### Sound

需要表达：

* Normal
* Muted
* 大致音量水平

不需要精确显示 `43%`。

---

# 6. MVP Composite Icon

## 6.1 基础设计

参考 iPhone Duo 将：

* Cellular
* Wi-Fi
* Battery

映射进入同一个几何图形的方式。

Mac 版本不应该简单做成：

`WiFi + Bluetooth + Battery + Speaker`

四个缩小 icon 横向排列。

否则只是：

> 四个 icon 压缩成四个更小的 icon。

而没有形成新的视觉系统。

组合图标应该利用：

* 外圈
* 中心
* 点
* 缺口
* Badge
* 动态状态

表达多个信息。

---

# 7. 推荐 MVP Glyph

建议第一版采用：

## Status Orb

一个约：

`18 × 18 pt`

的圆形状态组件。

结构：

### 外圈：Battery

圆环代表 Battery Level。

例如：

`100% → 完整圆环`

`75% → 3/4 圆环`

`50% → 半圆`

`20% → 低电量圆弧`

充电状态增加小型：

`⚡`

或者通过圆环动态效果表示。

---

### 中心：Wi-Fi

圆心区域显示 Wi-Fi glyph。

Wi-Fi 信号强度通过弧线数量表示。

例如：

强：

`)))`

中：

`))`

弱：

`)`

断开：

`×`

---

### 底部：Bluetooth

类似 iPhone Duo 蜂窝信号 dots。

例如：

`•`

代表有 Bluetooth Active Device。

如果无连接：

`·`

如果 Bluetooth Off：

不显示。

MVP 不表达连接设备数量。

Bluetooth 在这里更像：

> Presence Indicator

而不是完整状态。

---

### Sound：状态 Badge

Sound 不适合成为主视觉元素。

仅在特殊状态下显示。

正常播放：

不显示。

Muted：

右下角出现：

`×`

或极简 mute badge。

因此：

> Sound 正常状态不占视觉资源。

---

# 8. 信息优先级

组合 UI 最大的问题不是能不能塞进去，而是：

> 当多个状态同时变化时，哪个应该被用户首先看到？

定义优先级：

### P0

Battery Critical

例如：

`<10%`

必须强提示。

---

### P1

Wi-Fi Disconnected

因为这是非常高频的故障状态。

---

### P1

Charging State

尤其是刚连接电源时。

---

### P2

Muted

---

### P3

Bluetooth Device Connected

---

### P4

Normal Status

正常状态应该尽可能安静。

---

# 9. Normal State

典型情况：

* Wi-Fi Connected
* Bluetooth device connected
* Battery 82%
* Sound Normal

Menu Bar：

`◉`

用户应该能够通过：

* 外环长度 → 感知电量
* 中间 Wi-Fi → 感知网络
* 底部点 → 感知 Bluetooth

获得基本状态。

Sound 正常，因此不出现。

---

# 10. Exceptional States

## Wi-Fi disconnected

中心：

`×`

组合 icon 应明显改变。

---

## Wi-Fi disabled

Wi-Fi glyph 消失。

显示：

`—`

或 disabled state。

---

## Low Battery

外圈明显变短。

当 `<20%`：

可以进入强调状态。

当 `<10%`：

强提醒。

MVP 应优先使用形状变化，而不是完全依赖颜色。

---

## Charging

外圈 + Lightning Indicator。

例如：

`◉⚡`

Lightning 可以短暂出现后淡出，也可以持续显示。

MVP 可以先持续显示。

---

## Muted

出现小型 mute badge。

例如：

`◉ˣ`

---

# 11. 点击交互

点击 Composite Icon：

打开一个轻量 Popover。

建议结构：

**Battery**

`82% · Charging`

---

**Wi-Fi**

`Home WiFi`

`Connected`

---

**Bluetooth**

`AirPods Pro`

`Connected`

---

**Sound**

`Volume 42%`

提供 Volume Slider。

---

Popover 第一版重点仍然是：

> Status first, controls second.

不需要重新实现完整 Control Center。

---

# 12. Interaction Principle

产品需要遵循三级信息架构。

## Level 1

Menu Bar

目的：

Glance.

回答：

> 我的 Mac 现在是否正常？

---

## Level 2

Popover

目的：

Understand.

回答：

> 具体是什么状态？

例如：

`Battery 82%`

`Wi-Fi Home`

`AirPods Connected`

---

## Level 3

System Settings / Control Center

目的：

Manage.

例如：

* 切换 Wi-Fi 网络
* Bluetooth 配对
* Battery Settings
* Sound Output

MVP 不需要复制所有 Control Center 功能。

可以跳转系统对应设置。

---

# 13. 用户首次启动流程

首次启动时告诉用户：

当前应用可以替代以下 Menu Bar Items：

* Wi-Fi
* Bluetooth
* Battery
* Sound

建议用户在 macOS：

`System Settings → Control Center`

隐藏对应 Menu Bar Icons。

然后只保留本应用：

`Unified Status`

---

## Onboarding 示例

页面 1：

### Four icons. One status.

Before:

`Wi-Fi  Bluetooth  Sound  Battery`

After:

`◉`

---

页面 2：

### Nothing important disappears.

The icon still shows:

* Battery
* Wi-Fi
* Bluetooth
* Mute state

Click it for details.

---

页面 3：

### Hide the original icons

引导用户前往：

`System Settings → Control Center`

关闭：

* Wi-Fi in Menu Bar
* Bluetooth in Menu Bar
* Sound in Menu Bar
* Battery in Menu Bar

---

# 14. 一个重要的产品边界

MVP 不应该尝试：

> 自动删除 macOS 系统 Menu Bar Icon。

产品应该由用户主动在 macOS Settings 中关闭这些 icon。

应用只是成为：

> Alternative representation.

这可以降低权限、兼容性和系统行为风险。

---

# 15. 用户自定义

第一版需要一些自定义，但必须克制。

## 必须有

用户可以选择：

`Show Battery`

`Show Wi-Fi`

`Show Bluetooth`

`Show Sound`

---

例如用户仍然喜欢原生 Battery：

可以配置：

Composite：

`Wi-Fi + Bluetooth + Sound`

Native：

`Battery`

---

# 16. 不做自由 Layout Editor

MVP 不支持：

* 拖动 icon
* 自定义环的位置
* 自定义每个 pixel
* 自定义颜色
* 自定义几十种主题

只提供少量官方 Layout Preset。

甚至第一版可以只有：

### Compact Orb

一个设计。

原因：

我们首先需要验证：

> Composite Status 本身有没有价值。

而不是验证一个 Icon Designer。

---

# 17. Menu Bar Width

这是产品最核心的量化指标之一。

传统：

`Wi-Fi + Bluetooth + Sound + Battery`

可能占据大量横向空间。

目标：

Composite Status：

约一个普通 Menu Bar Item 宽度。

产品价值可以直接表达成：

### 4 → 1

未来甚至可以在设置页显示：

> You saved approximately XX pt of menu bar space.

但 MVP 不需要实现精确计算。

---

# 18. 无障碍与可理解性

Composite UI 最大风险：

> 信息压缩后变得难以理解。

所以需要几个原则。

### 1. Hover / Click 必须解释

Popover 中使用正常文字：

`Battery 82%`

而不是继续让用户猜图形。

---

### 2. 不允许所有状态都依赖颜色

必须做到：

即使 monochrome，也可以理解。

---

### 3. 状态图形保持稳定

不能：

Wi-Fi 有时在左边、有时在右边。

用户需要形成 muscle memory。

---

### 4. 异常优先

不要试图同时强调四个状态。

正常信息可以被视觉压缩。

异常信息应该抢占 UI。

---

# 19. Settings

第一版 Settings 只需要三个 Section。

## Status

`☑ Battery`

`☑ Wi-Fi`

`☑ Bluetooth`

`☑ Sound`

---

## Appearance

`Composite Icon`

第一版只有：

`Orb`

---

## Behavior

`Launch at Login`

`Open Popover on Click`

---

# 20. 技术需求

应用类型：

Native macOS Menu Bar App。

建议：

Swift + SwiftUI / AppKit。

应用默认：

* 无 Dock Icon
* 常驻 Menu Bar
* Launch at Login 可选

---

# 21. 系统数据来源

应用只读取本机状态。

包括：

### Battery

* battery %
* charging state
* power source

### Wi-Fi

* enabled / disabled
* connected / disconnected
* signal

### Bluetooth

* enabled / disabled
* active connection

### Sound

* volume
* mute

MVP 不需要 Cloud。

不需要 Account。

不需要 Backend。

不需要 Analytics 才能运行。

---

# 22. 隐私原则

所有数据：

> Local only.

不上传：

* Wi-Fi SSID
* Bluetooth Device
* Battery
* Sound
* Network State

如果加入 analytics，只记录：

* Feature enabled
* Feature disabled
* App launch
* Settings changed

不要上传：

SSID / device name。

---

# 23. MVP User Stories

### Story 1

作为 MacBook 用户，

我想隐藏 Battery / Wi-Fi / Bluetooth / Sound 四个 Menu Bar Icons，

只留下一个 Compact Status Icon，

从而让 Menu Bar 更干净。

---

### Story 2

作为用户，

我希望不点击 icon 就能知道：

* 电量大概是多少
* Wi-Fi 是否连接
* Bluetooth 是否有设备连接

---

### Story 3

当 Wi-Fi 断开时，

我希望 Composite Icon 能明显告诉我网络存在问题。

---

### Story 4

当 Battery 很低时，

我希望 Battery 状态能够覆盖其他次要状态成为视觉重点。

---

### Story 5

我不理解 Composite Icon 时，

点击它应该立即看到：

`Battery`

`Wi-Fi`

`Bluetooth`

`Sound`

的完整文字状态。

---

# 24. MVP Acceptance Criteria

第一版完成标准：

### AC1

应用可以在 Menu Bar 中长期运行。

---

### AC2

单个 Composite Icon 可以同时表达：

* Battery
* Wi-Fi
* Bluetooth
* Sound mute

---

### AC3

Battery 状态实时更新。

---

### AC4

Wi-Fi connected / disconnected 状态实时更新。

---

### AC5

Bluetooth active connection 状态实时更新。

---

### AC6

Mute 状态实时更新。

---

### AC7

点击 icon 可以打开 Popover 查看完整状态。

---

### AC8

用户可以关闭任意一种 Status Indicator。

---

### AC9

应用无需网络连接即可工作。

---

### AC10

应用重启后保留用户设置。

---

# 25. MVP Success Metrics

核心不是 DAU。

最值得验证的是：

## Metric 1 — Icons Replaced

平均每个用户隐藏多少个原生 Menu Bar Icon。

目标：

`≥ 3`

---

## Metric 2 — Compression Ratio

例如：

`4 native icons → 1 composite icon`

目标：

`≥ 3:1`

---

## Metric 3 — Native Icons Restored

用户使用一段时间之后是否重新把：

* Wi-Fi
* Battery
* Bluetooth

等原生 icon 打开。

这是判断 Composite UI 是否真的可读的重要指标。

---

## Metric 4 — Popover Frequency

如果用户每隔几十秒都需要点击 Popover 确认：

`我的电量到底是多少？`

说明 Menu Bar Glyph 信息压缩过头。

理想情况：

用户主要依靠 Glyph。

偶尔才打开 Popover。

---

# 26. 第一版明确 Scope

## V0.1

只做：

**Battery + Wi-Fi**

验证 Composite Glyph。

---

## V0.2

加入：

**Bluetooth**

---

## V0.3

加入：

**Mute**

---

## V1.0

正式形成：

**Battery + Wi-Fi + Bluetooth + Sound**

四合一系统状态。

---

# 27. 为什么建议先做 Battery + Wi-Fi

不要第一天就解决四个变量的视觉编码。

最核心的设计问题其实是：

> 用户能否学会从一个 Glyph 同时读取两种完全不同的信息？

Battery + Wi-Fi 是最佳实验对象。

两者：

* 状态非常高频
* 用户非常熟悉
* 信息容易验证
* 一个适合圆环
* 一个适合中心 Glyph

天然适合：

`Outer Ring = Battery`

`Center = Wi-Fi`

如果这个组合都不好用：

增加 Bluetooth 和 Sound 只会让问题更严重。

---

# 28. 推荐 MVP 最终形态

Menu Bar：

`◉`

内部：

**Outer Ring**

Battery

**Center**

Wi-Fi

**Bottom Dot**

Bluetooth

**Exception Badge**

Mute / Warning

形成：

> Ring + Glyph + Dot + Badge

四层视觉语言。

每一层固定对应一种信息。

用户学习一次之后不再变化。

---

# 29. 核心设计原则

产品所有后续功能都应该遵守以下五条原则：

### 1. Compress, don't hide.

减少图标，而不是减少信息。

### 2. Normal states should be quiet.

正常状态不应该争夺注意力。

### 3. Exceptions get priority.

异常状态拥有最高视觉优先级。

### 4. One geometry, multiple dimensions.

不是把多个图标简单拼在一起，而是让不同状态占据同一个 Glyph 的不同视觉维度。

### 5. Expand on demand.

Menu Bar 极简。

Popover 清晰。

System Control 完整。

---

# 30. 一句话产品定义

> **One icon for your Mac's essential status.**

或者：

> **Four menu bar icons. One glance.**

更偏产品价值的表达：

> **Keep the status. Lose the clutter.**

---

# 31. MVP 最核心验证

这个项目第一阶段真正需要回答的不是：

> 我们还能塞多少个系统状态？

而是：

> **用户是否愿意为了更干净的 Menu Bar，把 Apple 原生的 Battery / Wi-Fi / Bluetooth Icon 隐藏掉，长期只依赖我们的一个 Composite Icon？**

如果答案是 Yes，

之后才值得继续扩展：

* Focus
* Screen Mirroring
* AirPlay
* VPN
* Connected Devices

如果答案是 No，

则应该继续优化 Composite Glyph，而不是增加功能。
