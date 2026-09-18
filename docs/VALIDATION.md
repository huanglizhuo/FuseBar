# 开发预览验收记录

日期：2026-09-15。环境：Apple Silicon、macOS 26、Xcode 26.6，最低构建目标 macOS 14。

## 已验证

| 项目 | 结果 |
| --- | --- |
| XcodeGen 工程生成 | 成功，生成工程已保留，无包下载依赖 |
| Debug 原生应用构建/本地签名 | 成功，产物 `build/Build/Products/Debug/FuseBar.app` |
| LSUIElement | Info.plist 实际值为 true |
| XCTest | 11 项通过，0 失败 |
| 系统适配器只读烟雾测试 | 电池/CoreWLAN/CoreAudio 连续读取 5 次，未请求蓝牙授权、未写音量；检查值域与未知状态，不代表外设兼容性验证 |
| 圆环浅色/深色导出 | 10 个状态均已渲染并目视检查，含实际 22 pt 画布和放大视图 |
| 三页面排版 | 使用应用实际 SwiftUI 页面和模拟状态，经 AppKit 离屏渲染检查 |
| 偏好恢复 | 独立 UserDefaults suite，重建 Store 后开关状态保留 |
| 源码索引 | 已建立 codebase-memory-mcp 图谱 |

测试内容：9%/10%/19%/20% 阈值，接电抑制低电警报，无电池/未知区别，电量夹取，SSID 隐藏不等于断开，RSSI 分档，禁用指标退出优先级，零音量静音，全关仍保留入口摘要，充电角标，设置恢复和系统读取。

## 环境问题与处理

- 初次 XCTest 被沙箱禁止连接 testmanagerd；在允许本机测试服务的环境中重跑通过。
- 初次图谱进程无法在受限沙箱访问图形会话；允许图形会话后导出成功。
- SwiftUI ImageRenderer 不能绘制 AppKit 原生滑块/复选框；三页面预览改用离屏 NSHostingView，圆环仍使用 ImageRenderer。
- Computer Use 两次连接 FuseBar 超时。没有据此宣称菜单栏点击、焦点、Escape 或权限弹窗已通过 UI 验收。
- CoreAudio 烟雾测试有系统 HAL 诊断消息，返回值域测试通过；需要在硬件回归中观察，不把它当成所有输出设备均可控的证据。

## 尚待发布前验收

- [ ] 实际菜单栏图标及 tooltip、单击打开、点击外部/Escape 关闭、设置页切换。
- [ ] 首次使用、蓝牙允许/拒绝/撤回、定位允许/拒绝/撤回的完整 UI 流程。
- [ ] 接拔电源、实际低电阈值、Wi-Fi 开关/断网/切换网络。
- [ ] AirPods 等已配对设备连接/断开；未枚举 BLE 设备的文案可理解性。
- [ ] 音量写入、静音、切换默认输出、HDMI/USB/聚合/多声道设备。
- [ ] 登录启动的系统批准流程、注销再登录验证；当前测试不更改用户登录项。
- [ ] Mac mini/无电池、Intel、macOS 14/15/26、刘海与多显示器。
- [ ] VoiceOver、键盘、增强对比度、睡眠恢复和 8 小时能耗/内存采样。
- [x] 原生分层应用图标、兼容 ICNS 与外观预览。
- [ ] Developer ID 签名、公证与分发包。

结论：可构建、可运行的开发预览；尚未达到正式发行验收标准。约 3 秒轮询已实现，事件级更新与长期能耗优化是下一阶段。

## 2026-09-15 · SF Symbols 图标修订

- 手绘充电折线改为官方 `bolt.fill`；Wi-Fi 改用支持 variableValue 的官方符号。其余角标及连接点统一为 SF Symbols，连续电量环保留自定义绘制。
- 弹窗电池、Wi-Fi 和声音图标按状态选择；蓝牙行使用通用无线天线符号并保留中文标签。
- 核对本机 Apple CoreGlyphs 名称及版本元数据：所有新增引用兼容 macOS 14。没有进行 macOS 14 真机验证。
- 构建成功；既有 11 项 XCTest 全部通过，0 失败。
- 已导出并目视检查浅/深色 12 个圆环状态（新增中等和较弱信号），以及三页面模拟预览。确认 variableValue 分层绘制生效，充电符号完整，页面无缺失符号。
- 本次未进行实际菜单栏点击、硬件切换或能耗测试；上方尚待验收列表仍有效。

## 2026-09-15 · 底部单一状态提示

- 取消蓝牙常驻点和右侧角标；底部提示固定在 x=11 的中轴，扩大底部缺口至 80°。正常时留空，警告/充电/静音只显示一项，均使用官方 SF Symbols。
- 图标与标题共享同一优先级决策：严重低电 → Wi-Fi 断开 → 低电 → 充电 → 静音。蓝牙在详情与可选悬停摘要中显示，沿用已保存的蓝牙偏好。
- XCTest 14 项通过，0 失败。新增覆盖逐步解除多个异常后下一提示显现、蓝牙不占位、禁用指标及未展示状态仍保留详情。
- 已检查浅/深色 12 状态图谱与三页面模拟预览：没有右侧角标、底部符号居中、正常状态无蓝牙点，静音符号不碰撞圆环。构建及图谱导出成功。
- 本次仍是模拟 UI 验证，不替代菜单栏实机交互与硬件切换验收。

## 2026-09-15 · 原生 Liquid Glass 应用图标

- 制作 `AppIcon.icon`：系统背景 + 三组原创 SVG 前景，启用原生 glass。图层保持未裁切的 1024 × 1024 画布，不含烘焙光影、位图纹理或 SF Symbols 导出图像。
- 本机 Icon Composer 1.6 的官方 ictool 成功渲染 Default、Dark、ClearLight、ClearDark、TintedLight、TintedDark 六种外观，均已目视检查；另导出 16/32/64/128/256 px 默认外观，检查 32/64 px 辨识度。
- Xcode 26.6 成功执行 CompileAssetCatalogVariant，应用包包含 `Assets.car` 和 `AppIcon.icns`。Info.plist 的 CFBundleIconName 与 CFBundleIconFile 实际值均为 AppIcon。
- 已导出独立 `Design/AppIcon/FuseBar.icns`，与本次编译产物一致。
- XCTest 14 项通过，0 失败。未修改菜单栏 template 状态图形和系统状态读取代码。
- 尚未在旧版 macOS 真机检查回退效果，也未完成多背景下系统动态照明的实机验收；工具渲染和资源编译成功不代表 Apple 审核认证。

## FuseBar 1.0 — 2026-09-16

- Renamed product, scheme, source/test folders and executable to FuseBar. Preserved the user's registered `com.clothpath.mergebar` Bundle ID and Team `N9Q47Y2LQ4` in project.yml.
- Release Archive succeeded with arm64 and x86_64 slices. Verified signed entitlements: App Sandbox, Bluetooth and optional location access. Added PrivacyInfo.xcprivacy for app-only UserDefaults use.
- 14 XCTest cases passed, 0 failures (`/private/tmp/fusebar-tests.log`). This is not full interactive permission or multi-device verification.
- App Store Connect upload of version 1.0 build 1 succeeded (`/private/tmp/fusebar-upload.log`).
- Store screenshot artwork uses the production PopoverView rendered by NSHostingView, with a live read-only local snapshot from a separate renderer. No SSID or Bluetooth device names appear. Output is 2880×1800. These are composed product images, not desktop screen captures or proof of sandboxed hardware behavior.
- Native computer-use app selection timed out for the menu-bar-only app. Do not treat this as a verified installation failure or as successful interactive testing.
- Developer ID Application certificate created in Xcode with user authorization; private key remains in Keychain. No credentials are committed.

### Distribution verification

- Developer ID export and stapling completed. `codesign --verify --deep --strict`, `stapler validate`, and Gatekeeper assessment all passed locally (`source=Notarized Developer ID`).
- App Store Connect: three screenshots uploaded by the owner; version 1.0 (1), metadata, free pricing and published privacy declaration completed. Add for Review succeeded; UI explicitly shows **Ready for Review** and **added for review**. This is not yet **Waiting for Review** or App Store approval.
- GitHub release pipeline uses local Xcode signing/notarization and hosted macOS verification. No Apple secrets are stored in Actions. First hosted run passed signature, Team ID, bundle/version, stapled ticket and Gatekeeper checks; its lipo command order was corrected before rerunning.
- Hosted verification rerun succeeded: https://github.com/huanglizhuo/MergeBar/actions/runs/35002736988 . It published https://github.com/huanglizhuo/MergeBar/releases/tag/v1.0 with FuseBar-1.0-macOS.zip and SHA256SUMS.txt. Release is no longer a draft. ZIP SHA-256: `12897085eaa987cd90a920a2574ee08d05be8f6cf5613a17753ebad3f3f70adc`.

## 2026-09-16 — FuseBar promotional video

- Created the editable HyperFrames project at `videos/fusebar-launch`, three linked 10-second scenes with original icon fusion, a real native UI screenshot, and GitHub download CTA.
- Final strict HyperFrames check reported no lint/runtime/layout/contrast findings; inspected scene snapshots and decoded final MP4 frames.
- MP4 verified: 30 seconds, 1080×1080, 60 fps, H.264/AAC, 3,944,460 bytes. Original synthesized soundtrack, no external music samples.
- These are marketing visuals, not additional live hardware verification.
- X copy prepared for @huang4fun. Upload blocked (`Not allowed` and native picker error); not published. Details and continuation steps in `videos/fusebar-launch/REVIEW.md`.


## 2026-09-16 — Volume dots and Personal Hotspot

- `zsh Scripts/build.sh`: successful native Debug build. Final `zsh Scripts/test.sh`: 17 tests passed, 0 failures, including volume boundaries, priority suppression, CoreWLAN-missing/hotspot fallback, ordinary Wi-Fi and associated networks without an available path.
- Read-only local probe observed CoreWLAN unavailable inside the tool sandbox while a Wi-Fi-only Network path was satisfied/expensive. Outside that sandbox CoreWLAN reported station mode, RSSI -31, with the same satisfied/expensive Wi-Fi path. No SSID, BSSID or IP was recorded.
- A tool compiled from production SwiftUI/StatusStore/SystemReader rendered the current local state with the chain-link icon and connected hotspot/metered detail. This exposed and verified a startup race fix: path changes arriving during the first hardware sample are resampled immediately. This is live local data in an offscreen production view, not an on-screen capture of a newly installed distribution build.
- Light/dark fixture galleries regenerated at 66 pt and actual 18 pt. Four dots stay symmetric, separate from arc endpoints; priority glyphs replace them; Personal Hotspot symbol is visible in both sizes. These are simulated fixture previews, not live hardware verification.
- `personalhotspot` represents expensive Wi-Fi paths (including iPhone Personal Hotspot), using public Network.framework. The signal does not prove manufacturer; ordinary metered Wi-Fi may also use the link glyph. No private API, SSID heuristics, scan or new entitlement.
- Full physical hotspot disconnect/reconnect, VPN combinations, macOS14/15 and Intel remain unverified. Existing GitHub1.0/App Store build1 have not been replaced by this change.

- Video v2: HyperFrames0.8.41 strict check passed with zero findings;17 stills and encoded contact sheet inspected. Export34.000s,1080square60fps,H.264/AAC,4,580,955bytes;2040frames fully decoded. Opening uses a menu-bar concept and continuous zoom/curl/four-dot fusion; labels demonstrate volume and hotspot. End card marks new features as a preview. See `videos/fusebar-launch/REVIEW.md`.

## 2026-09-16 — 1.0.1 distribution preparation

Release archive 1.0.1 (2) succeeded. Developer ID export and Apple notarization succeeded; stapler validation and Gatekeeper assessment passed (`source=Notarized Developer ID`). Executable contains x86_64 and arm64. ZIP prepared for hosted verification. App Store export failed at productbuild with userCanceledErr (-128), before upload; installer-key signing authorization needs to be completed locally. Computer-use calls currently time out, so App Store Connect and X cannot be changed through that connection.

GitHub 1.0.1 published successfully: https://github.com/huanglizhuo/FuseBar/releases/tag/v1.0.1 . Verification Action35063495541 completed successfully, checking Apple Team, Developer ID, bundle/version, arm64+x86_64, stapled ticket and Gatekeeper. Source/tag commit af059f2. ZIP SHA256 f64d313f7ea7312235910b2f2490e0ee4ddd5ef4ac6639c97b5e97fd9ecb9513. Video v2 is attached as a release asset.

## System shortcut buttons

Added Applications launcher and Mission Control buttons to the status panel. Verified this Mac has /System/Applications/Apps.app (com.apple.apps.launcher) and Mission Control.app (com.apple.exposelauncher); older Launchpad paths are supported as fallbacks. Opening uses NSWorkspace after closing the popover; missing app/open errors are visible, and an async failure reopens the panel. No new entitlement or runtime dependency.

`Scripts/build.sh` succeeded; existing 17 XCTest cases passed. Offscreen production-view render inspected and saved as docs/previews/quick-actions.png: both controls fit at the bottom without clipping. Computer-use getApp timed out, so actual button-triggered Apps/Mission Control presentation and older-macOS fallback remain unverified. These changes are in the local development build, not the published 1.0.1 ZIP.

## 2026-09-16：控制中心第一批（未发布）

- 需求范围和分期已写入 `docs/CONTROL_CENTER_PLAN.md`；保留现有圆环和热点逻辑。新增声音输出页、应用页（搜索、运行标记、固定/取消固定、独立持久化），复用系统启动器/Mission Control 入口。
- Xcode 开发签名构建通过；21 项测试全部通过，新增 4 项覆盖应用去重、搜索、缺失应用保留与固定列表持久化。受限 shell 首次无法访问开发签名，使用现有签名身份在允许的本机环境重跑成功；没有创建新证书。
- 独立原生离屏程序只读枚举：5 个可用声音输出、1 个当前输出、8 个普通运行应用。`docs/previews/control-center.png` 为真实数据的离屏 NSHostingView 渲染，不是实机弹窗点击或沙箱权限验证。
- Computer Use 列举桌面成功，但打开开发版 FuseBar 超时；应用激活、Apps/Launchpad、Mission Control、沙箱内输出切换/设备拔插仍待实机验证。本次没有改变当前输出、网络或蓝牙，没有退出用户应用。
- Wi-Fi 选择、蓝牙连接、文件夹、废纸篓、逐窗口操作仍在后续阶段，未以可用功能宣传或发布。

## 2026-09-16：系统能力审查与第二批开发补全

- 官方功能对照：`SYSTEM_CAPABILITY_RESEARCH.md`；代码审查：`CAPABILITY_REVIEW.md`；逐项进展：`CONTROL_CENTER_PLAN.md`。未宣称完整替代系统 Dock/控制中心。
- 最终开发签名构建通过；25 项测试全部通过（2026-09-16 21:42），覆盖扫描结果去重/当前 AP 保留、同名不同认证网络、固定顺序边界、无效书签保留及移除。Swift 编译无代码警告；仅 Xcode 常见的未使用 AppIntents 元数据提示。
- `docs/previews/system-controls.png` 为原生离屏渲染，已检查 Wi-Fi 权限/未扫描、蓝牙未授权、文件夹空状态、系统目录滚动布局。只读枚举当时为 4 个声音输出、1 个当前输出、8 个运行应用；与先前 5 个输出的差异说明硬件列表会变化，不代表自动拔插验收。
- Computer Use 访问 FuseBar 超时；访问 Finder 也出现远超设定超时的阻塞。未完成真实点击验收，停止依赖该路径。本次没有执行网络扫描/加入/关机、音频静音/切换、蓝牙连接、用户文件选择或其他应用隐藏等实机写操作。
- 新增只读用户选择文件、app-scope bookmarks 权限；隐私政策和 Wi-Fi 定位用途文案同步更新。真实授权选择器、书签跨重启/文件移动、Wi-Fi 连接/断电、音频硬件写入和跨 macOS 版本仍待验证，不能用单元测试代替。
- 安装到 `/Applications/FuseBar.app`，签名严格校验通过。安装前版本备份为 `/private/tmp/FuseBar-before-controls.mfHdg6/FuseBar.app`；保留用户偏好。此为本地开发版本，未更新 GitHub Release 或 App Store 构建。

## 2026-09-16：热点图标尺寸与偏灰修正

- 菜单栏热点符号 8 → 6.5 pt（缩小 18.75%），圆环与符号中心位置不变。
- 同一热点快照、22 pt、2× ImageRenderer 对比：原 `.primary` 模板峰值 alpha = 0.870588；专用黑色单色模板峰值 alpha = 1.0。确认先前模板烘焙了额外透明度；最终颜色仍由系统 template 着色。弱轨道和未填充音量点继续按设计降低透明度。
- `Scripts/build.sh` 通过；原生离屏栅格对比通过。未新增仅重复尺寸常量的测试；未声称已对照实时系统菜单栏截图。安装应用严格签名验证通过，并重启开发版。

## 2026-09-16：首页应用网格与音量即时更新

- 构建成功，28 项测试通过：新增 6/12/13 个应用的网格边界、溢出占位、停止应用过滤与重复进程去重；CoreAudio 真实只读监听注册、重复 start 不增加注册数、stop 清空注册测试通过。
- `docs/previews/compact-home.png` 使用本机 8 个运行应用的原生离屏渲染，已检查两行网格、统一小按钮、音量百分比。超出两行分支通过模型测试；未声称已人工点击超出按钮。
- 音量 setter 与系统回读分离，滑块拖动/键盘输入都会写入；40 ms 合并为设计节流间隔，并非实测端到端延迟保证。声音独立事件监听与读回，不再依赖三秒轮询；保留轮询降级。没有为了测试改变用户真实音量或音频输出。
- 已更新本机 `/Applications/FuseBar.app` 并重启，签名严格校验通过。尚未更新公开发行版本。

## 2026-09-16：AirDrop 空图标与网络名称授权提示

- 本机 NSImage(systemSymbolName:) 证实 `airdrop` 不存在，导致空白；改为已验证的 `square.and.arrow.up`（分享语义，不宣称官方 AirDrop 专属标志）。系统功能目录全部 12 个 SF Symbol 名称解析成功。
- 原首页仅以连接且 SSID 为 nil 显示授权按钮，未区分授权和名称可用性。抽取实际 UI 使用的决策函数，29 项测试中授权但 SSID nil 用例先失败，再加入授权状态判断后全部通过。CLLocationManager 启动时创建但不请求权限、不订阅位置，独立发布权限状态；授权回调和刷新同步更新。已授权页面显示授权完成，SSID 不可读时如实提示暂不可用；未承诺这次修复可绕过 macOS 的 SSID 读取限制。
- 构建和严格签名验证通过；更新并重启本机开发版本。没有撤销/重置用户权限进行测试，没有读取或记录网络名称。

## 2026-09-16：返回位置与重新打开回首页

- 二级页面统一左上返回入口，移除底部返回。关闭后重新打开在 AppDelegate 的实际 show 路径重建 NSHostingController，避免 SwiftUI @State 保留旧页面；保留 StatusStore、持久化设置和授权。
- 构建通过、git diff --check 通过；原生离屏渲染检查 Wi-Fi、蓝牙、文件夹、系统四页左上返回位置（`docs/previews/system-controls.png`）。本次为低影响导航/UI 调整，未新增镜像实现的单元测试；未冒称实机点击验证。
- 安装并重启本机开发版，严格签名验证通过。

## 2026-09-16：菜单栏重复点击开关

- 修正 transient 自动关闭与默认 mouse-up toggle 的竞争窗口：NSPopover 改为 applicationDefined，按钮只在 leftMouseDown 切换。显式处理外部鼠标点击、应用失活与本地 Escape；鼠标位于状态按钮时外部/本地关闭监听不抢先关闭。监听仅在展示期间存在，关闭和退出时移除；不申请键盘全局监控或辅助功能权限。
- 临时原生测试程序从生产 AppDelegate 生成，仅暴露 popover 读数并使用 demo Store；调用实际 toggle selector 6 次，isShown 依次 true/false/true/false/true/false；performClose 后再次 toggle 为 true。此为原生生命周期集成检查，不是物理鼠标事件回放，原始点击时序未录制。
- 现有 29 项测试与最终构建通过，git diff --check 通过。修复 Swift 并发警告，事件监听内仅返回 Bool，不跨隔离返回 NSEvent。
- 安装并启动本机开发版、严格签名校验通过，保留关闭后重新打开首页的行为。
- 依据：Apple NSPopover.Behavior 的 transient 自动关闭与 applicationDefined 自主管理；Apple Monitoring Events 对本地/全局鼠标监听及移除的说明。

## 1.1.0 localization / GitHub release validation (2026-09-16)

- Five bundled `Localizable.strings` catalogs, each with 218 keys, plus localized Bluetooth/location permission descriptions. UI, runtime status/error strings and accessibility use the same resolver. Regional variants and ordered system preferences are supported; unsupported lists fall back to English, Chinese variants use Simplified Chinese.
- `zsh Scripts/build.sh` succeeded; `zsh Scripts/test.sh` passed 32 tests, including regional matching, preference order, unsupported-language fallback, bundled catalog parity and placeholder preservation. Format arguments containing `%` remain data.
- `zsh Scripts/render-readme-previews.sh` rendered six production native views in each of five languages. Reviewed English status/settings/guide/system, all five status pages, French long-form text and Spanish Wi-Fi layout. Corrected truncated home shortcuts using native mini buttons and intrinsic label sizing. These offscreen renders use a sample status and local app shelf; they are not live hardware or mouse-event verification.
- README now uses English 1.1.0 native previews. App Store submission/build/forms were not modified. Intel/older macOS runtime and live network switching remain unverified as recorded above.

- Universal Release archive succeeded (`arm64 x86_64`). Developer ID export was attempted three times: Apple timestamp service unavailable twice; Xcode account request failed once with NSURLError -1009 on an expensive/constrained hotspot path. Plain HTTPS connectivity to Apple succeeded. No 1.1.0 release asset has been published or claimed notarized. Awaiting authorization to temporarily disable Low Data Mode, then retry signing/notarization and restore the setting.

## Vibe Coding workspace (2026-09-17, development build)

- Implemented configurable Carbon global hotkey registration with exclusive conflict detection, enabled system-shortcut checks, persisted key code/modifiers, transactional replacement, clear/release and restart registration. Recorder uses local focused AppKit events; no Accessibility/Input Monitoring permission added. Escape cancels recording; recorded function/arrow keys have readable labels. Empty search Return does not launch an invisible result.
- Added optional coding layout, pinned+running home shelf, app picker with read-only scoped bookmarks, bounded common-directory app discovery, search with arrow/Return handlers, shared home context actions and frontmost-app indication. Fixed favorites remain present when stopped. Existing running items retain relative order; removal still compacts the running section and is not a claim that every running slot is immovable.
- Added local project name/folder/preview/repository editing and selection. Only HTTP(S) web entries without embedded credentials; folder access requires explicit selection and read-only bookmark. Remove changes local configuration only. No shell execution, server startup, window restoration or automatic Dock preference changes.
- 40 tests passed: existing status/localization coverage plus merged shelf overflow/stability, project validation/persistence/removal, shortcut encoding/validation, native recorder capture/cancellation, real Carbon registration conflict/release/re-registration, and an application-target Carbon hotkey event invoking the callback once while ignoring an unknown ID. The last test is event dispatch, not a physical keyboard event.
- Native offscreen production views rendered in five languages. Inspected coding home in English/Japanese, shortcut settings in English/French, project editor in English/Spanish; guide/settings use bounded scroll regions. `docs/previews/coding/` uses sample status/project and a local app list, not live hardware verification.
- Development build installed in /Applications/FuseBar.app with a backup under /private/tmp/FuseBar-before-coding.*; strict signature verification passed. Computer Use could not read this menu-bar app (timeout); physical hotkey delivery, full-screen/multiple-display behavior, keyboard selection/focus restoration, actual folder picker/bookmark reopening and complete Dock-free workflow remain manual acceptance items. No claim of complete runtime verification.
- App Store and public GitHub release were not changed. The existing release signing/network blocker remains separate from this development work.

### 2026-09-17 — 横向应用栏与文件选择器修复

- 首页两种布局均改为搜索框上方的单行水平滚动应用栏，无 12 项截断；13 个固定应用的顺序/完整性测试通过。System 首页快捷按钮移除，设置保留系统功能入口。
- 回归测试经真实 `FileShortcuts.add` 调用路径，注入返回取消的 NSOpenPanel 替身，在 runModal 期间发送 AppKit 失活通知，监测 NSPopover.performClose 请求。修复前出现 3 个断言失败；修复后保持弹窗，取消后正常关闭。该测试验证真实通知/关闭监听，不代表实机鼠标点击系统文件选择器的端到端验证。
- 原因：失活监听直接关闭弹窗，全局点击监听也没有系统选择器生命周期保护。三个选择器统一采用显式 presentation scope，关闭监听及快捷键/状态按钮均尊重该状态。
- `zsh Scripts/test.sh`：41 项测试、0 失败（/private/tmp/fusebar-panel-green.log）。`zsh Scripts/build.sh`：BUILD SUCCEEDED。
- 原生离屏视图渲染完成五语页面；检查英文编码首页与中文状态首页，单行应用位于搜索上方且无 System 快捷按钮。示例状态属于预览，非实时硬件证据。

### 2026-09-17 — 恢复两行应用栏

- 按用户调整恢复六列、最多两行，位置仍在搜索框上方。超过 12 项时前 11 项加省略号进入完整应用页，保留固定/运行筛选。System 快捷按钮移除和文件选择器修复未改动。
- `zsh Scripts/build.sh` 成功；五语原生离屏预览生成完成，检查英文编码首页确认六列换行且搜索框位于应用栏下方。此轮为布局调整，未新增测试或重复运行全套测试。
- 开发构建通过严格签名检查并替换 `/Applications/FuseBar.app`，已重新启动。

### 2026-09-17 — 标题栏快捷按钮与菜单栏加粗

- 构建成功（/private/tmp/fusebar-header-build.log），`git diff --check` 通过。此次布局/绘制参数调整未新增测试。
- 五语原生离屏预览生成，检查英文编码页确认标题右侧四个无文字图标、底部无重复快捷入口、两行应用栏保留。悬停名称使用 SwiftUI help，尚未进行实机鼠标悬停验收。
- 菜单栏渲染显式启用 emphasized：外环 1.7 pt、默认中心符号 bold；22 pt 画布与位置不变，详情图标保留原笔画。
- 开发构建及安装后的应用严格签名验证通过，已替换并启动本机 /Applications/FuseBar.app。

### 2026-09-17 — 设置回到底部、移除读取/刷新行

- Settings 从顶部移至左下角，保留 ⌘,；移除状态页读取说明与刷新按钮，保留自动刷新。
- `zsh Scripts/build.sh` 成功；五语离屏预览生成完成，检查英文状态首页确认顶部三个图标、左下设置、声音滑块后直接为页脚。纯布局修改未新增/重跑单元测试。
- 构建与安装后严格签名检查通过，已替换并启动本机 FuseBar。

### 2026-09-17 — 输入源图标、切换与显示模式

- 独立 Apple Development 签名 `.app` 验证程序使用与 FuseBar 相同沙箱权限。本机 ABC、Hiragana、微信输入法均读取并解码原生图标成功。`TISSelectInputSource` 实际切换返回 0、读回匹配，恢复原输入源返回 0、读回匹配。证据：`/private/tmp/fusebar-input-sandbox-verification.log`。未修改系统已启用的输入源集合。
- 通知与显示逻辑：仅输入源 ID 变化触发两秒展示，重复刷新不延长，连续变化延长到最新一次；常驻设置持久化。失败读回不伪装成功。单元测试覆盖时间边界、未知值、语言回退、设置恢复和拒绝切换。
- 实际图标预览发现 Canvas 中 NSImage 模板中心空白；改为 CoreGraphics 单色透明度掩码及 CGImage 绘制，保留白色镂空。新增回归测试确认白色镂空透明、Orb 中心确实有图案；原生三输入源预览已目视检查。
- 最新完整测试日志 `/private/tmp/fusebar-input-final-tests.log`；46 项测试全部通过。五语界面预览包含样例系统状态与本机真实输入源名称/图标，不标记为实时菜单栏截图。
- 电脑控制 `getApp('/Applications/FuseBar.app')` 返回 timeoutReached，尚未完成原生鼠标选择、输入中候选框、跨应用焦点恢复的端到端验收。实际沙箱切换成功不等同于上述交互场景均已验证。
- 不读取按键、正文或候选内容；输入法内部 Shift 中英文模式未承诺检测。ABC 使用公开但已弃用的 IconRef 图像转换作为兼容路径，不调用私有 API。
- 最终 `zsh Scripts/build.sh` 成功，构建及安装后严格签名检查通过；已备份旧应用、替换 `/Applications/FuseBar.app` 并确认新进程启动。未 push、未发布 GitHub 或 App Store。

### 2026-09-17 — 输入源 light/dark 主题修复

- 可重复渲染测试复现：InputSourceGlyph 在 dark 环境中心像素仍为黑色（redComponent=0，预期 >0.8）。原因是弹窗与菜单项直接使用第三方原始黑色图片，未采用模板着色。圆环输出的最终 isTemplate 标记仍存在。
- 弹窗图标改用 CGImage 模板与语义 primary；原生输入源菜单项使用 templateIcon，交由菜单适配外观及高亮。
- `zsh Scripts/test.sh`：47 项、0 失败，含明暗图标与 Orb 中心颜色回归；`zsh Scripts/build.sh` 成功，git diff --check 通过。
- 目视检查本机 ABC、Hiragana、微信输入法的明暗原生离屏图谱：暗底亮图、亮底暗图，镂空保留。未改变用户系统主题；这些是渲染验证，不是实际 NSStatusBar 壁纸/高亮的端到端截图。

### 2026-09-17 — 缩小输入法图标

- 圆环中心图案由 9 pt 缩至 7 pt；输入源行、原生菜单图片逻辑尺寸与 SwiftUI frame 统一限制为 14 pt。保持单色模板与中心位置。
- 构建、严格签名检查及 git diff --check 通过。重新生成五语预览及明暗图谱，目视检查深色图谱确认更小的图案与间距。此次纯尺寸调整未新增/重跑单元测试。
- 已替换并启动本机 FuseBar；原生菜单鼠标展开未作端到端验证。

### 2026-09-17 — 固定与运行应用按最近使用排序

- 首页合并列表按最近激活/启动置顶，固定应用仍保留，去重后维持两行/溢出规则；无记录运行应用按 launchDate 补齐。监听由弹窗生命周期移至 AppDelegate 启动/退出，FuseBar 自身和非 regular 应用不记入。
- 仅本机保存最多 100 个 bundle ID，普通 refresh 不改写记录。新增测试覆盖固定/运行混合排序、重复/失效 ID、重新激活置顶、持久恢复、忽略自身、刷新稳定与记录上限。
- `zsh Scripts/test.sh`：49 项、0 失败（/private/tmp/fusebar-recency-tests.log）；构建、严格签名检查及 git diff --check 通过。已替换本机应用并确认新进程运行。
- 未模拟用户跨应用鼠标切换；上述事件监听生命周期经代码审查，排序与保存经自动化测试。既往未记录的激活历史无法从系统补取，不宣称重建历史使用顺序。

### 2026-09-17 — 输入源状态行与底栏重排

- Input Source 标准布局与其他状态行保持相同文字大小、图标列宽、上下间距与分隔线；编码布局同排显示。选择源改为二级列表，仍调用既有选择/焦点恢复流程。
- 底栏使用独立居中布局放置 Apps/Windows/Files，左右为设置图标及 Quit；帮助位于右上角。设置快捷键与悬停/辅助标签保留。
- 构建与 git diff --check 通过。五语离屏预览生成完成，目视检查英文标准、编码首页与输入源二级页：无重叠，居中按钮正确，当前源勾选可见。此次 UI 调整未新增/重复运行单元测试；未声称原生鼠标端到端验证。

### 2026-09-17 — 源码推送前截图与文档同步

- 重新运行 `Scripts/render-readme-previews.sh docs/previews`，生成九个页面 × 五种语言，共 45 张页面预览及两张输入源明暗图谱。检查英文标准/编码首页，全部文件生成成功；README、截图索引与主要文档相对链接校验通过。
- README 改为当前开发版定位、实际底栏/输入源/应用排序/快捷键/项目行为，增加截图索引；工作台定义、产品计划、能力说明、隐私政策同步。历史发布文案与商店素材明确为旧版；不更新 App Store 表单。
- 已通过 `gh release view` 核实当前公开版本仍为 v1.0.1。侧边子菜单尚未实现，明确标记为计划，不以假截图描述完成。
- 最新完整测试：49 项、0 失败（/private/tmp/fusebar-push-tests.log）；之前同一应用源码的构建与签名验证通过。此轮不创建 release/tag，仅提交并 push 开发源码和文档。

### 2026-09-17 — 独立侧边子菜单

- 电池、Wi-Fi、声音、蓝牙、输入源在标准/编码布局中使用各自 NSView 锚点展开独立 NSPopover。锚点不截获鼠标事件。主菜单保持可见，设置/项目等页面仍按原导航。
- 回归测试覆盖子窗口归属判断、同项切换关闭、不同项替换、缺失锚点、Escape 子菜单优先、主菜单关闭联动清理；系统选择器原回归仍通过。
- 真实 AppKit 测试创建独立测试窗口与 NSPopover（非 mock）：屏幕左侧向右展开，屏幕右侧向左展开，子窗口边界在 visibleFrame 内。测试结束清理窗口；未操作用户系统设置。
- `zsh Scripts/test.sh`：52 项、0 失败（/private/tmp/fusebar-submenu-final-tests.log）。最终另加的锚点 hitTest 穿透通过编译；最终构建/签名检查记录见下。
- 五语页面及四张侧边组合布局预览已生成，检查输入源紧凑侧栏；组合图不代表实际锚点位置。真实摆放依据上述 AppKit 测试。未完成跨多显示器或用户实际鼠标逐项操作验收。
- 最终 `zsh Scripts/build.sh` 成功，构建及安装后严格签名检查通过，已替换并启动本机 FuseBar；此轮未提交/push 或创建 release。

### 2026-09-17 — 输入源焦点、外部关闭和图标统一

- 根因：原流程要求 500 ms 内先恢复原应用焦点，超时即报错并跳过 TIS 选择。现用 `yieldActivation(to:)` 交还焦点，恢复为尽力操作；短暂等待后执行实际选择，只有切换调用/读回失败才提示错误，取消请求不继续选择。
- 外部鼠标点击统一显式关闭子菜单与主菜单，包含系统文件选择器；菜单内部点击保持打开。系统选择器仅打开产生的焦点变化仍保留保护，选择器自身不被关闭。
- 新增回归覆盖焦点未恢复仍执行选择、真实选择失败、取消过期请求、主/子窗口内部点击、未知/其他窗口外部点击，以及文件选择器期间外部点击。
- `zsh Scripts/test.sh`：56 项、0 失败（`/private/tmp/fusebar-interaction-tests.log`）。最终 `zsh Scripts/build.sh` 成功（`/private/tmp/fusebar-interaction-final-build.log`）；构建产物及安装副本严格签名检查通过，已替换并启动 `/Applications/FuseBar.app`。
- 底栏按钮 28 pt 点击框、15 pt medium 图案；Quit 改 power。主要状态/输入源/底栏图标统一 primary。重新生成五语预览和侧边布局组合，目视检查英文标准与编码首页：底栏无重叠，图标同色。预览为离屏渲染，不代表真实鼠标验收。
- 自动化测试及构建验证完成；未完成用户桌面实际鼠标输入源切换端到端验证。本轮未提交、push 或发布 release。

### 2026-09-17 — P0 / P1 / P2 控制面板优化

- P0：缩小标题、去口号、单行状态、长名称 tooltip 与辅助详情；主状态行与编码按钮根据独立子菜单选择实时高亮。固定/运行应用沿用前台底色及运行点，固定标记仅悬停出现。
- P1：统一搜索包含已发现应用、明确添加的文件书签、内置操作；最近三条有效记录横排显示，最多保存 20 个标识。搜索查询不持久化。搜索结果支持键盘选择和 Return，状态结果仍打开侧边菜单。文件列表回首页后重载，避免搜索使用过期书签列表。
- P2：低电量/断网图文警示；声音设备名与百分比分开、滑杆旁直接静音；底栏/状态按钮统一 hover、pressed、selected、disabled 与焦点描边，尊重减少动态效果。状态按钮 ↑↓ / Return / →，输入源 ↑↓ / Return，子菜单 ← 返回，保留 Escape 逐级关闭。
- 新增搜索模型测试涵盖跨类别/大小写和重音匹配、空结果、过期目标过滤、去重/顺序、持久化和 20 项上限。完整测试 59 项、0 失败（`/private/tmp/fusebar-ui-final-tests.log`）。最终键盘焦点和横排最近项 UI 调整通过最终构建（`/private/tmp/fusebar-ui-final-build.log`）。
- 五语九页、明暗输入源图谱、四张侧边组合图，以及新增英文深色首页/搜索/空结果/最近操作预览生成完成。目视检查英文标准/编码、法文、深色、搜索与最近项：无重叠；长文字单行截断且有 tooltip。标准示例预览由 352×656 pt 改为 352×492 pt，约减少 25% 高度；尺寸包含预览外边距，实际高度受运行应用数量、权限提示和近期项影响。
- 全部截图均为离屏原生渲染；最近项为隔离偏好中的示例记录。未宣称用户桌面的鼠标/键盘完整端到端验收，也未验证跨多显示器和所有辅助功能组合。
- Hallmark 组件自评（1–5）：理念 4、层级 4、执行 4、产品针对性 5、克制 5、结构变化 4。沿用 macOS 字体、语义色与材质；无网页外壳、无额外运行依赖。
- 最终构建产物及 `/Applications/FuseBar.app` 严格签名检查通过；已替换并启动本机应用。本轮未提交/push 或创建 release。

### 2026-09-18 — 默认中心图标选择

- 新增网络连接 / 声音输出选择，偏好写入 centerIndicator；旧用户及未知值回退网络。声音使用现有公开扬声器符号，随音量/静音变化，无可用输出显示问号。输入源覆盖优先级、外环和底部提示位置保持。网络和声音指标开关各自控制对应中心是否显示，禁用时不绘制错误的额外中性环。
- 五语设置与说明更新，设置预览重新生成，目视检查英文选项无重叠。截图为离屏渲染，未宣称桌面鼠标操作验收。
- 61 项测试、0 失败（/private/tmp/fusebar-center-tests.log），包含新偏好默认值、保存/恢复、非法值回退、选中指标开关、未知/静音/高音量符号。构建通过（/private/tmp/fusebar-center-build.log）。
- 构建及安装副本严格签名检查通过，已替换并启动本机 FuseBar；未提交/push 或发布版本。
