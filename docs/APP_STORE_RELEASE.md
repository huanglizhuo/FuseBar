# FuseBar — Mac App Store 发布清单

核对日期：2026-09-16。版本 1.0 (1) 已上传并完成 Add for Review，状态 Ready for Review；尚未执行最终 Submit for Review，也未获审核批准。详见 VALIDATION.md 与 Distribution/README.md。

## 当前状态

- 已实现菜单栏状态合并、详情面板、可选权限、登录启动设置和原生分层 AppIcon。
- 最近一次 Debug 构建成功，17 项 XCTest 通过；不等同于发行环境或完整硬件测试。
- 已启用 App Sandbox 并上传商店签名构建；Developer ID 版已完成公证和 Gatekeeper 验证。完整多系统硬件回归仍待补充。
- 已添加隐私清单、隐私政策及支持链接，商店已保存三张实际 UI 组成的产品图片。

## 上架前工程工作

- [ ] 固定归属明确且可注册的 Bundle ID，配置开发者 Team、Release 分发签名和 provisioning。当前 Bundle ID 为 `com.clothpath.fusebar`。
- [ ] 开启 App Sandbox，仅添加功能所需 entitlement。核验蓝牙、读取 Wi-Fi 名称所需定位权限，以及 CoreAudio 输出音量、IOKit 电池读取在沙箱中的实际行为。
- [ ] 重点验证 IOBluetooth 已连接设备查询；若受沙箱限制，缩减可选蓝牙功能，避免使用私有 API 或未验证的临时例外。
- [ ] 新增 `PrivacyInfo.xcprivacy`，逐项审计 required-reason API，包含当前 UserDefaults 偏好存储；按实际使用选择 Apple 允许的理由。
- [ ] 设置工具类应用分类、发行版本号与递增 build number。
- [ ] 权限拒绝后仍能使用基本功能；定位仅用于可选 Wi-Fi 名称，不要求用户授权后才能进入应用。
- [ ] 验证登录启动明确由用户开启，退出后停止工作。
- [ ] 在最低支持 macOS 14 和当前系统验证启动、权限、睡眠唤醒、多显示器、刘海屏、无电池 Mac、外接音频和低电量状态。
- [ ] 检查长时间运行的 CPU、唤醒次数和能耗；当前 3 秒轮询应测量后决定是否改为事件通知与低频兜底。
- [ ] 验证图标在旧系统的回退和新系统的不同外观；若声明支持 Intel，同时验证相应发行架构。

## App Store Connect 流程

1. 加入 Apple Developer Program；如采用付费下载或 IAP，完成对应协议、税务及收款信息。
2. 注册 Bundle ID，在 App Store Connect 创建 macOS App，填写名称、SKU、主要语言和分类。
3. 准备中英文描述、关键词、支持 URL、隐私政策 URL、年龄分级、地区和定价；按实际情况回答隐私及出口合规问题。
4. 使用 App Store 接受的 Xcode 版本创建 Release Archive，在 Organizer 执行 Validate，再通过 Distribute App → App Store Connect 上传。使用 App Store 分发签名；Developer ID 和公证是站外分发的另一条路线。
5. 等待构建处理，先经 TestFlight 验证签名和沙箱后的真实行为，再选择构建、上传截图并填写审核备注。
6. Add for Review 后继续 Submit for Review；建议首版选择手动发布，审核通过后核查商品页再发布。

## 产品与商品页建议

- 定位为“将电量、网络与声音状态集中到一个菜单栏入口”。说明原有系统图标需要用户在系统设置中自行隐藏；避免宣传为自动接管或隐藏任意第三方图标。
- 保持蓝牙和 Wi-Fi 名称权限可选，强调基础状态不依赖这些权限。
- 应用完全免费，无买断收费、订阅或内购。
- 准备三张清晰的真实截图：精简后的菜单栏、完整详情面板、居中的低电量/充电/静音提醒。状态应来自可复现的实际功能；设计稿和 fixture 预览不能直接充当真实运行证据。
- 本地处理且没有开发者或第三方收集数据时，可以根据实际审计结果填报“不收集数据”；不能仅凭“无登录”推断。
- 隐私政策解释本地电池、网络、声音和可选蓝牙状态用途，说明可选定位权限的原因，并提供联系方式；在应用内提供可访问入口。

## 审核备注草稿（提交前以最终行为核对）

FuseBar is a macOS menu bar utility. After launch, click the FuseBar status icon in the menu bar to open its panel. It does not display a Dock icon. No account is required. Bluetooth details and the Wi-Fi network name are optional; the basic status display remains usable without those permissions. Users can optionally hide their original system status icons in System Settings. FuseBar does not automatically hide or modify other apps' menu bar items. Launch at login is enabled only by the user.

## Apple 官方参考

- [App Review Guidelines，特别是 2.4.5 Mac App Store 要求](https://developer.apple.com/app-store/review/guidelines/)
- [App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)
- [App Store Connect 工作流](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-workflow)
- [隐私填报](https://developer.apple.com/app-store/app-privacy-details/)
- [Required-reason API 类型与理由](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)
- [截图规格](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- [提交审核](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app)

## 1.0.1 (2) 更新

已构建修复版、完成 Developer ID 公证并发布 GitHub1.0.1。App Store 导出在 productbuild 安装包签名阶段被钥匙串取消授权，尚未上传新版。需要允许使用现有 Mac Developer Installer 签名私钥，再重试 Distribution/AppStore.plist 导出。随后在 App Store Connect 将待提交版本更新至1.0.1、选择构建2并重新 Add for Review；原1.0(1)的 Ready for Review 状态不代表修复版已加入审核。电脑控制连接当前超时，商店页面尚未改动。
