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
