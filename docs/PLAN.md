# MergeBar · 产品与实施计划

## 产品决策

面向 macOS 14+ 的原生菜单栏应用。用一个固定 28 pt 宽的入口承载 18 pt 状态圆环。用户手动隐藏系统图标；应用不移动或注入其他菜单栏项目。无账号、后端、分析埋点、屏幕录制或辅助功能权限。

参考 [CircleStatusBar](https://github.com/artemnovichkov/CircleStatusBar) 的最终形态：开口圆环、居中的 Wi-Fi、底部连接点。已查看 comparison-sheet.jpg 和 WiFiGlyph 源码。参考项目是动画研究，不能直接提供电池或无线连接数据；MergeBar 独立实现绘制，不复制参考媒体或代码。

## 视觉与交互规格

- 外环：从左下端沿 300° 量程绘制电量，底部留固定缺口供蓝牙点使用。背景细环表示量程，实线表示当前电量。无电池时不画电量环，未知时画虚线。
- 中心：Wi-Fi 两条弧与点表示强度；关闭为短横线，断开为叉，未知为问号。不能把 SSID 为空判成断开，也不能把 Wi-Fi 连接称为互联网畅通。
- 底部：蓝牙连接为实点，开启但未发现已连接的配对设备为空心点，关闭不画，未授权为小问号。MVP 仅覆盖系统可枚举的已配对设备，不能声称检测所有 BLE 连接。
- 右上固定角标：电量 <10% 且未接电为叹号；否则充电为闪电。右下固定角标为静音叉。没有状态换位、颜色依赖或常驻动画。角标不覆盖中心 Wi-Fi。
- 提醒标题优先级：严重低电量 → Wi-Fi 断开 → 低电量 <20% → 充电 → 静音 → 平静摘要。关闭的指标退出提醒计算。
- 单击打开 320 pt 宽原生 Popover：标题与摘要、四行状态、音量滑块、设置/帮助/退出。Escape 或点击外部关闭。悬停和 VoiceOver 读完整文字。
- 设置：四项显示开关（允许全关，保留中性入口）、唯一 Compact Orb 外观、登录启动、图形说明与首次使用引导。点击打开弹窗始终启用，避免用户关闭后失去入口。
- 首次启动：展示“四个图标，一个入口”、图例与系统设置按钮。隐藏原生图标完全由用户决定；新 macOS 的路径可能为“菜单栏”，旧版本为“控制中心”。
- 系统字体、系统材质、原生按钮与焦点状态；中英文中的第一版界面采用中文，设备名称原样展示。

## 系统能力与降级

| 数据 | 实现 | 限制/降级 |
| --- | --- | --- |
| 电池 | IOKit IOPS，仅内置电池 | 桌面 Mac 显示无内置电池；读取失败为未知；外接电源但未充电单独说明 |
| Wi-Fi | CoreWLAN 电源、关联模式、RSSI、SSID | SSID 需定位授权；默认不请求，用户点击“显示网络名称”后才请求权限，不启动位置更新；名称不可用仍显示关联状态；不主动扫描网络 |
| 蓝牙 | CoreBluetooth 授权/电源 + IOBluetooth 已配对设备连接状态 | 用户点击后才请求权限；不扫描、不配对；未授权和未连接分开 |
| 声音 | CoreAudio 默认输出、主声道或左右声道音量、静音 | HDMI/USB 等无软件音量控制时禁用滑块，提供系统设置；写入失败可见 |
| 登录启动 | SMAppService.mainApp | 显示真实服务状态及系统待批准状态，不用本地布尔值伪装成功 |

读取在串行后台队列执行，初始 3 秒轮询、弹窗打开与唤醒立即刷新。禁止重叠刷新。休眠停止计时；改变后的快照才触发图标更新。首个可运行版的延迟上限目标约 3 秒，后续事件驱动替换轮询；不宣称当前已达到事件级实时更新。

## 架构

`SystemReader + AudioDevice → StatusSnapshot → StatusStore → OrbView / PopoverView`

- Domain：值类型快照、显示偏好、阈值和优先级纯函数，无硬件依赖。
- System：系统框架适配器，状态读取与音量写入集中封装。
- Store：主线程发布状态、后台采样、权限、偏好持久化、休眠/唤醒管理。
- UI：AppKit NSStatusItem + NSPopover，SwiftUI 矢量圆环与页面。ImageRenderer 生成 template NSImage 适应明暗菜单栏。
- 工程：XcodeGen 描述 + 提交生成的 Xcode 工程，零外部运行依赖；macOS 14 最低版本；本地 ad-hoc 签名。正式发行须 Developer ID、Hardened Runtime、公证与真机兼容性回归。

## 实施顺序与验收门槛

1. P0 规划与空工程：保存 PRD、产品决策、构建入口与状态模型。
2. v0.1：Battery + Wi-Fi、圆环、弹窗、未知/无硬件处理；构建通过、阈值与异常规则测试。
3. v0.2：蓝牙权限、已配对设备连接点；授权前不访问设备名称。
4. v0.3：声音读取、静音角标、可写音量控制；不支持控制的设备禁用控件。
5. MVP 集成：持久设置、引导、登录启动、设置跳转、VoiceOver 文本、休眠恢复、全状态预览与测试。
6. 发布前验证：Intel 与 Apple Silicon、macOS 14/15/26、浅/深色及高对比度、VoiceOver、拒绝权限、AirPods/HDMI/无电池、切换输出、睡眠、8 小时运行与能耗采样。验证前只能称开发预览。

## 产品验证

邀请 5–8 位 Mac 用户完成“一眼判断低电、断网、静音”任务；与原生图标比较准确率和时间。记录自愿隐藏的图标数（目标 ≥3）、一周内恢复原生图标的原因。仅访谈/本地记录，不内置遥测。若 18 pt 无法稳定辨认四状态，优先减少默认指标或调整几何，不继续增加状态种类。

## 证据

- [Apple CoreWLAN](https://developer.apple.com/documentation/corewlan)
- [Apple 工程师关于 SSID 定位授权说明](https://developer.apple.com/forums/thread/732431)
- [IOBluetoothDevice.isConnected](https://developer.apple.com/documentation/iobluetooth/iobluetoothdevice/isconnected())
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)

更细的属性签名以本机 Xcode 26.6 SDK 头文件和编译器验证为准。
