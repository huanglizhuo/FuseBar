# MergeBar · 汇聚之环

## 视觉概念

用一个包裹信号的开口圆环表达“多个系统状态，共用一个入口”。外环呼应电量，内部两段向中心收拢的弧与单点呼应信号聚合；图标与菜单栏保持同一识别轮廓，但以稳定的品牌形态展示，不显示即时电量、警告或充电状态。

配色为安静的蓝绿色，源色 sRGB `#096D8C`。白色前景经系统材质处理后呈现玻璃质感。图形居中，无文字、无侧边角标、无附加设备插画。圆角端部和足够的实体宽度支持小尺寸识别。

## 制作方式

交付的是原生 Icon Composer 文档，不是玻璃质感的概念效果图：

- `Sources/MergeBar/AppIcon.icon`：Xcode 使用的可编辑源文件。
- `01-orbit.svg`：外部状态环，半径 278、实体宽 80。
- `02-converging-signals.svg`：两段汇聚弧，共用一组材质。
- `03-merged-core.svg`：核心节点。
- 所有源图层使用 1024 × 1024 SVG，曲线已展开为填充路径，无描边依赖。背景由 Icon Composer 定义。
- 三组透明度参数分别为 0.38 / 0.16 / 0.08；每层启用原生 glass。系统负责光照、折射、阴影、外形裁切和外观适配。
- 文件起始模板由本机 Icon Composer 1.6 创建；分层配置经其官方 `ictool` 渲染及 Xcode 26.6 的资源编译器验证。
- 图层由项目脚本确定性生成，没有使用生成式位图或第三方图标资产，也没有把 SF Symbols 的图像拷贝进应用品牌图标。

## 对照 Apple 指南

遵循 [App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons) 的分层、简洁、居中和矢量优先原则。源图层不预裁圆角、不烘焙高光/模糊/层间阴影。默认、深色、透明和染色外观保留相同几何，交由系统适配。[Icon Composer](https://developer.apple.com/icon-composer/) 是实际渲染工具。

这里的“符合”指制作方式与设计原则对齐，并通过工具编译；不意味着 Apple 审核认证，也不保证所有系统版本渲染完全一致。

## 重建与预览

```sh
python3 Design/AppIcon/generate_layers.py
zsh Scripts/render-app-icon.sh
xcodegen generate
zsh Scripts/build.sh
```

矢量生成器会同步更新 `.icon/Assets`，不会重置 Icon Composer 的材质参数。

预览位于 `docs/previews/app-icon`：六种外观的 1024 px PNG，以及默认外观 16、32、64、128、256 px。透明/染色预览使用官方渲染器的默认环境，实际系统背景与用户染色选项会改变呈现。

`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` 已配置。Xcode 自动生成 `AppIcon.icns` 和 `Assets.car`，供旧版系统与 Liquid Glass 系统使用。设计目录中的 `MergeBar.icns` 是本次构建的独立导出，需要在重新构建后从应用包复制更新。

应用仍为无 Dock 图标的菜单栏工具；Finder、系统设置等场景会显示新应用图标。18 pt 菜单栏绘制继续使用原有单色 template 图像，以维持动态状态可读性。
