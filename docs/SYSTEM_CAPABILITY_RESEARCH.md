# FuseBar 系统能力研究：菜单栏、控制中心与 Dock

> 当前实现摘要（2026-09-17）：最近使用应用架、可配置快捷键、编码布局与项目入口、输入源读取/切换及主题图标已加入开发源码；底部为设置图标 / 居中三快捷按钮 / Quit，帮助在右上角。电池、Wi-Fi、声音、蓝牙和输入源采用独立侧边子菜单，设置/项目等仍采用面板内导航。下文保留阶段性决策/审计历史；最新界面以 [README](../README.md)、[编码工作台定义](CODING_WORKSPACE_PLAN.md) 和 [验证记录](VALIDATION.md) 为准。

研究日期：2026-09-16。范围：macOS Sonoma 14、Sequoia 15、Tahoe 26；以 Apple 官方用户指南、公开开发文档与本项目现状为依据。此文是能力审计与支持计划，不代表列出的功能已经实现。实现进度以 `CONTROL_CENTER_PLAN.md` 和 `VALIDATION.md` 为准。

## 结论与覆盖定义

FuseBar 可以成为日常状态与应用操作的统一入口，但“功能相同”“打开系统页面”“尚待研究”必须分开计数。现有版本覆盖电池/网络/声音状态、部分音量控制、声音输出选择、已连接蓝牙摘要、运行/固定应用、系统应用启动器和 Mission Control；**尚未完整替代 Dock、控制中心或所有系统菜单**。

本次审计覆盖 Apple 文档列出的系统菜单/控制类别及 Dock 的主要操作。它不是声称已穷举每台 Mac 的所有动态控件：硬件、输入法、VPN、正在录制/共享、辅助功能、账户、系统小版本和第三方扩展都会改变实际列表。Tahoe 的控件库可扩展，Apple 的“使用控制中心”页面不提供固定穷尽清单；应补充 14/15/26 实机控件库逐项截图核对，不能根据单台电脑宣称“全部”。[Apple 菜单栏结构](https://support.apple.com/en-gb/guide/mac-help/-mchlp1446/mac)、[Tahoe 控制中心](https://support.apple.com/en-euro/guide/mac-help/mchl50f94f8f/26/mac/26)。

支持级别：

- **直接**：FuseBar 自己展示或执行；需要公开接口、权限处理、成功回读和沙箱实测。
- **委托**：明确标为“打开…”，交给系统应用/设置完成，不能算内置切换器。
- **研究**：存在候选接口或需硬件/沙箱验证；不得提前显示承诺成功的按钮。
- **系统保留**：当前范围没有验证过的通用实现，继续保留系统入口；这不是未经证实地断言 macOS 永远不可能实现。

双渠道当前共用 App Sandbox。公证或 Developer ID 签名不会解除沙箱限制，也不会自动提供辅助功能、定位、蓝牙、录音等权限。未来如考虑独立增强版，需要单独产品决策、权限说明和测试，不应悄悄放宽现有版本。

## A. 系统菜单与控制中心逐项矩阵

“当前”基于此次实现开始前的源码/规划：已有 = 代码存在，仍不等于所有硬件、系统版本已验证。P1 优先补齐常用直接功能；P2 在专项验证后开放；P3 按需求与成本评估。

| 功能 | 当前覆盖 | 实现/支持计划 | 级别与关键边界 |
| --- | --- | --- | --- |
| Wi-Fi 连接、信号、关闭/未知状态 | 已有 | 保留实时状态和未知态 | 直接；不可把拒绝权限显示为断网 |
| iPhone/个人热点 | 部分：昂贵 Wi-Fi 路径显示热点样式 | 保持“热点/按流量计费”文案；连接入口走网络面板 | 不能仅凭 `isExpensive` 确认设备制造商；Instant Hotspot 自动发现/唤醒仍研究 |
| Wi-Fi 扫描、选择、密码连接 | 无 | P1 按需扫描；P2 个人网络连接、密码临时内存、失败恢复 | CoreWLAN 有公开扫描/关联接口；定位、沙箱和当前系统必须实测；企业证书认证交给系统 [A1] |
| Wi-Fi 总开关/断开 | 无 | P2 独立明确操作，回读后更新 | `setPower`/`disassociate` 为公开候选；不能以文档存在代替真实沙箱验证 [A1] |
| 蓝牙开关/连接摘要 | 已有只读摘要 | P1 内部已配对列表；总开关先委托设置 | Host controller 文档给出读取电源状态；未验证公开写电源接口 [A2] |
| 蓝牙配对、连接/断开、配件电池 | 无 | P2 按设备类别验证经典蓝牙连接；配对、BLE 特有操作先委托 | 连接链路不代表音频路由或 HID 服务成功；AirPods 电量无通用保证 |
| AirDrop 可发现性/接收设置 | 无 | P1 设置入口；P2 用户选定文件的 AirDrop 分享 | `NSSharingService` 支持发送文件，不等于控制系统接收模式 [A3] |
| 音量、当前输出、静音状态 | 已有 | P1 设备允许时补静音切换；保持 HDMI 等无软件音量的说明 | 直接；各 property 的可写能力分开判断 |
| 声音输出选择 | 已有 | 回读、设备拔插、AirPlay/聚合设备专项验证 | 只改媒体输出，不擅自改提示音输出 |
| 声音输入/麦克风选择与输入音量 | 无 | P2 Core Audio 能力枚举与回读 | 读取设备能力与录音是不同权限；不为列表无故启动录音 |
| 电池百分比、电源/充电、低电量 | 已有 | 保持现有圆环和告警 | 笔记本和无电池机器分别验证 |
| 低电量模式/高能耗模式/优化充电 | 无 | P1 低电量模式只读；模式切换与电池健康委托设置 | `ProcessInfo.isLowPowerModeEnabled` 是只读公开状态；不是电源模式写接口 [A4] |
| 显示亮度、True Tone、Night Shift、外接屏 | 无 | P1 显示设置入口；P2 独立显示设备兼容性研究 | 不承诺所有屏幕；本次未核实跨 Apple Silicon/Intel/外接屏的统一公开写接口 |
| 屏幕镜像、AirPlay、Sidecar | 无 | P1 显示/镜像系统入口；P2 研究公开选择器的实际范围 | App 的媒体路由选择器不能自动等同全桌面镜像 |
| 键盘背光 | 无 | P1 键盘设置入口；P2 支持硬件限定的能力研究 | 没背光键盘应隐藏控制；未验证通用公开滑块接口 |
| Focus/勿扰 | 无 | P1 Focus 设置；P2 用户明确配置的快捷指令 | `INFocusStatusCenter` 只读取共享状态，不是列出/切换全部 Focus 的 API；平台可用性需 SDK 检查 [A5] |
| Stage Manager | 无 | P1 桌面与程序坞设置入口 | 本次未验证稳定公开总开关；不能用隐藏偏好写入冒充支持 |
| Now Playing：曲名、播放/暂停、上一首/下一首 | 无 | P2 按支持的播放器做显式集成；其余保留系统控件 | `MPNowPlayingInfoCenter` 用于本 app 发布媒体信息，不是读写任意其他播放器的总线 [A6] |
| 日期/时钟 | 无 | P1 本地日期时间；P2 月历、时区可选 | 本地格式与系统时区；不宣称隐藏系统时钟 |
| 通知中心、其他应用通知、Live Activities | 无 | 系统保留；入口如能稳定验证可委托 | `UNUserNotificationCenter` 只管理本 app 通知，不能据此读取全局通知 [A7] |
| Spotlight 搜索与动作 | 无；现有搜索仅固定/运行应用 | P1 系统入口或提示原生快捷键；P2 全部已安装应用搜索 | 应用搜索不可冒称全系统文件/Spotlight 查询等价物 |
| Siri / Apple Intelligence | 无 | 系统入口，按硬件/地区/版本显示 | 不仿制 Siri；本次未验证直接稳定唤起接口 |
| 输入法切换、输入模式 | 无 | P2 Text Input Source 候选 API 与沙箱专项验证 | `TIS…` 候选尚未完成官方文档/当前 SDK 验证，不承诺本批上线 |
| 字符/表情查看器、键盘查看器 | 无 | P2 公开入口研究，键盘设置兜底 | 输入菜单的两种查看器是不同功能；Apple 说明见 [S4] |
| 快速用户切换 | 无 | P1 用户与群组/锁定相关系统入口 | 不提供伪造账户切换按钮；本次未验证无额外权限的通用切换 API |
| Time Machine 状态、备份、恢复 | 无 | P1 设置入口；P2 只读状态研究 | 启动备份/恢复有权限与磁盘副作用，未经验证不执行 |
| VPN 状态、连接/断开 | 无 | P1 VPN 设置入口；P2 按服务类型研究 | `NEVPNManager` 管理 Personal VPN 配置，不据此承诺任意第三方 VPN；不要为查看现有 VPN 新建配置 [A8] |
| Weather | 无 | P1 打开 Weather；P3 可选 WeatherKit 小组件 | 网络/定位/归属标记/配额要另行设计；与默认本地处理分开 [A9] |
| Shortcuts | 无 | P1 打开 Shortcuts；P2 用户命名快捷指令列表与运行 | Apple 正式支持 URL scheme；不自动读取剪贴板，不假定调用完成即执行成功 [A10] |
| Accessibility Shortcuts：VoiceOver、Zoom、颜色、键盘等 | 无 | P1 辅助功能设置；P2 个别公开入口专项验证 | 不等于获得跨应用辅助功能控制权限；不同功能不可伪装统一开关 |
| Hearing、Background Sounds、Live Captions | 无 | P1 辅助功能/声音入口 | 功能因系统/地区/硬件而异；当前没有已验证的通用控制层 |
| Music Recognition / Shazam | 无 | P1 系统入口；P3 独立可选 ShazamKit 集成 | 官方提供 macOS ShazamKit；需服务能力、音频来源和隐私设计，不能承诺零权限 [A11] |
| 摄像头、麦克风、位置、系统音频/录屏隐私指示 | 无 | 系统保留 | 不隐藏、不仿制“完整监控”；系统 Control Center 可显示使用中的 app [S3] |
| 视频效果/麦克风模式/屏幕共享/录制停止按钮 | 无 | 系统保留；仅本 app 自建录制可提供自身控制 | 与当前会话及 app 有关，不是全局公共控制 API 的已验证能力 |
| Tahoe 额外时钟/计时器等控件、第三方控制扩展 | 无 | P3 逐项控件库审计；先打开对应系统 app | 控件可扩展，不能静态声称固定数量或复制全部控件 [S3] |
| Apple 菜单：关于、更新、睡眠、重启、关机、锁定、退出登录 | 无 | P1 设置/系统信息入口；会话/电源写操作专项研究 | 与普通状态菜单分开；避免为了“覆盖率”直接增加高影响批量动作 |
| 当前应用菜单：File/Edit/View/Window/Help/Services | 无 | 保留原生菜单 | 不属于状态 icon 合并；复制其他应用菜单需要单独权限/兼容性研究，不能由 NSStatusItem 自动获得 |

## B. Dock 对照矩阵

Dock 的公开用户功能包括应用启动/切换、文件交给应用、Finder 定位、隐藏、快捷菜单、固定排序、Handoff、外观和徽章；以 Apple Dock 指南作为产品行为基线，不等于第三方可直接操作其内部数据。[Apple Dock 指南](https://support.apple.com/guide/mac-help/open-apps-from-the-dock-mh35859/mac)。

| 功能 | 当前覆盖 | 支持计划及验收 |
| --- | --- | --- |
| 运行应用、启动、激活、图标、运行标记 | 已有 | P1 持续刷新；应用退出/卸载时明确反馈；NSWorkspace/NSRunningApplication [A12] |
| 固定应用、移除、排序 | 已有固定/移除，排序待补 | P1 独立顺序持久化；不导入/修改系统 Dock 偏好 |
| 搜索所有安装应用、添加未运行应用 | 部分；当前只固定/运行 | P2 用户选 app 或明确受支持的目录扫描；区分搜索范围 |
| 隐藏/显示、隐藏其他应用 | 无 | P1 公开 AppKit 方法，保留目标 app 身份并真实验证 |
| 正常退出 / 强制退出 | 无 | **当前沙箱版本不直接支持**；打开目标 app 或系统操作入口。Apple 明确 `terminate()` 从沙箱不能退出其他 app [A13]；不能将原规划的正常退出写成已可实现 |
| Finder、在 Finder 中显示应用 | 无 | P1 NSWorkspace 激活/定位，实测沙箱行为 [A12] |
| Apps/Launchpad、Mission Control | 已有委托 | 依系统版本解析系统 app；名称准确，不冒称内置窗口列表 |
| 每 app 窗口列表、最小化/恢复、关闭、窗口排列 | 无 | P3 AXUIElement 可选能力研究；辅助功能授权、沙箱与商店可行性单独证明；公开 AX 存在不等于当前沙箱可用 [A14] |
| 应用 Exposé、显示桌面、Spaces | 无 | P3 系统入口/接口研究；不以模拟按键、私有 Dock 通信充作默认实现 |
| 文件/文件夹固定、Downloads、文件栈预览 | 无 | P2 用户选择 + 安全作用域书签；重启/失效/拒绝处理；不拿容器 Downloads 冒充用户 Downloads |
| 最近应用/最近文件 | 无 | P2 仅 FuseBar 自己打开的历史，开关与清除；其他 app 的最近菜单留给系统 |
| 拖文件到 app 打开 | 无 | P2 **有公开候选，不属“无接口”**：接收用户文件授权，再 `NSWorkspace.open(_:withApplicationAt:configuration:)`；文件类型/多文件/拒绝沙箱实测 [A15] |
| 废纸篓：打开/移入/恢复/清空 | 无 | P2 经验证的 Finder 入口；移入可研究 `recycle`，需授权文件；恢复/清空另行定义，不默认支持 [A12] |
| 外接磁盘推出 | 无 | P2 **有公开 API** `unmountAndEjectDevice(at:)`；只显示用户可操作卷，确认目标与忙碌错误，不自动推出 [A16] |
| Handoff 推荐 | 无 | 系统保留；Apple 文档描述系统 Dock 的跨设备推荐；本次未找到全局推荐列表的已验证公开读取接口 [S5] |
| 其他 app 的 Dock 徽章、进度、跳动、动态菜单 | 无 | 系统保留；`NSDockTile` 操作自己 app/窗口的 tile，不是全局读取器 [A17] |
| 启动时打开 | FuseBar 自身已有 | 其他 app 启动项由其设置或系统登录项管理，不替他人 app 写登录项 |
| Dock 位置/大小/放大/自动隐藏 | 无 | P1 桌面与程序坞设置入口；由用户决定保留/自动隐藏，不杀 Dock 进程 |
| Dock 键盘导航/拖拽/触控板习惯 | 无等价覆盖 | P2 FuseBar 自己的键盘导航、Escape/返回、VoiceOver；不宣称替代所有系统手势 |

## C. 实施与验证顺序

1. **纠正规划与安全补齐**：修正“沙箱正常退出”“拖文件无接口”“磁盘推出无接口”的旧定义；实现固定排序、隐藏/显示、Finder 定位、日期/低电量只读，以及明确的系统功能目录。目录入口只计“委托”。
2. **设备直接控制**：Wi-Fi 按需扫描→个人网络连接；蓝牙逐硬件配对列表→连接能力；声音静音/输入；每个操作有忙碌、失败、设备消失、权限拒绝、回读。
3. **文件与工作流**：文件选择器/书签、文件夹栈、用户选择文件交给指定 app、AirDrop 分享、Shortcuts；每项验证权限作用域与取消路径。
4. **高级控制专题**：输入法、窗口 AX、显示/键盘背光、VPN、媒体、外接卷；验证通过一个再开放一个，不把整个专题一次性标完成。
5. **跨版本发布门槛**：macOS 14/15/26 + Apple Silicon/Intel，沙箱实测与设备矩阵。源码编译、模型测试、离屏 UI、只读枚举、真实操作是五类不同证据；补丁不得以构建成功替代真实操作成功。

任何“研究/委托”不应计入“直接替代”的百分比。用户真正完成某项任务才是验收单位，例如“选择 Wi-Fi 成功连接并回读”，不是“有一个 Wi-Fi 按钮”。

## 官方依据索引

### 系统功能与版本范围

- S1 [Sonoma 14 控制中心设置](https://support.apple.com/en-nz/guide/mac-help/mchlad96d366/14.0/mac/14.0)、[Sequoia 15 控制中心设置](https://support.apple.com/guide/mac-help/change-control-center-settings-mchlad96d366/15.0/mac/15.0)：Wi-Fi、蓝牙、AirDrop、Focus、Stage Manager、镜像、显示、声音、Now Playing，以及附加模块。具体模块随版本与硬件变化。
- S2 [Tahoe 26 菜单栏设置](https://support.apple.com/en-euro/guide/mac-help/mchlad96d366/26/mac/26)：时钟、Siri、Spotlight、网络、声音、电池、Focus、显示、Now Playing、用户切换、Time Machine、VPN、Weather。此列表不包含所有上下文指示器。
- S3 [Tahoe 26 控制中心](https://support.apple.com/en-euro/guide/mac-help/mchl50f94f8f/26/mac/26)：编辑/排列/调整控件以及隐私使用信息；不是固定完整扩展清单。
- S4 [键盘查看器](https://support.apple.com/en-au/guide/mac-help/mchlp1015/mac)、[辅助功能键盘与输入菜单](https://support.apple.com/guide/mac-help/use-the-accessibility-keyboard-mchlc74c1c9f/mac)。
- S5 [Handoff](https://support.apple.com/en-au/guide/mac-help/mchl732d3c0a/mac)。

### 接口证据（接口存在不等于本项目已完成兼容性验证）

- A1 [CoreWLAN](https://developer.apple.com/documentation/CoreWLAN)、[CWInterface](https://developer.apple.com/documentation/corewlan/cwinterface?changes=_2)：client-vended interfaces 支持沙箱；扫描、关联、电源接口。
- A2 [IOBluetoothHostController](https://developer.apple.com/documentation/iobluetooth/iobluetoothhostcontroller)：文档中的电源状态读取。
- A3 [NSSharingService](https://developer.apple.com/documentation/appkit/nssharingservice?changes=_6_1)：分享内容/文件，包括 AirDrop。
- A4 [低电量模式状态](https://developer.apple.com/documentation/foundation/processinfo/islowpowermodeenabled?changes=la)：只读与通知。
- A5 [INFocusStatusCenter](https://developer.apple.com/documentation/intents/infocusstatuscenter?changes=_2.)、[INFocusStatus](https://developer.apple.com/documentation/intents/infocusstatus)：授权读取是否允许通知，不是模式选择器。
- A6 [MPNowPlayingInfoCenter](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter?changes=_4_2&language=objc)：app 自身媒体信息。
- A7 [UNUserNotificationCenter](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter)：本 app 通知范围。
- A8 [NEVPNManager](https://developer.apple.com/documentation/networkextension/nevpnmanager?changes=_9)：Personal VPN 配置与 entitlement；不作为全局第三方 VPN 管理证明。
- A9 [WeatherKit](https://developer.apple.com/weatherkit/)：服务、配额与归属要求。
- A10 [Shortcuts URL 运行接口](https://support.apple.com/en-au/guide/shortcuts-mac/apd624386f42/mac)。
- A11 [ShazamKit](https://developer.apple.com/shazamkit/)、[系统 Music Recognition](https://support.apple.com/en-au/guide/shazam/devfa00a0eb5/web)。
- A12 [NSWorkspace](https://developer.apple.com/documentation/AppKit/NSWorkspace?changes=latest_minor&language=_5)、[OpenConfiguration](https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration?language=objc)：应用、文件、Finder、回收及打开行为。
- A13 [NSRunningApplication.terminate](https://developer.apple.com/documentation/appkit/nsrunningapplication/terminate%28%29?changes=_3)：官方明确沙箱不能用此方法退出其他应用。
- A14 [AXUIElement](https://developer.apple.com/documentation/applicationservices/axuielement_h)：跨应用可访问性对象及信任检查；仍需独立沙箱验证。
- A15 [打开文件到指定应用](https://developer.apple.com/documentation/appkit/nsworkspace/open%28_%3Awithapplicationat%3Aconfiguration%3Acompletionhandler%3A%29?changes=_7)。
- A16 [推出卷](https://developer.apple.com/documentation/appkit/nsworkspace/unmountandejectdevice%28at%3A%29?changes=_6)。
- A17 [NSDockTile](https://developer.apple.com/documentation/appkit/nsdocktile?changes=_6)：自己的 app/窗口 Dock 图块。
