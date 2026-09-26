# FuseBar · The Orb（v2）

## 视觉概念

图标就是菜单栏里的那颗圆环本身，放大成品牌形态（概念稿见 `concepts/A-orb.svg`）：

- **开口圆环**：沿用 `OrbGeometry` 的 145° 起点、250° 弧长，底部留出 110° 缺口。和状态项一样由两部分组成：一条半透明的完整轨道，加一段实心的数值弧（固定取 78%，是品牌比例，不代表实时电量）。
- **四个状态点**：落在缺口里的 4 个圆点，对应圆环上的音量点位（125° / 102° / 79° / 56°），前两个点亮，后两个减弱。
- **网络信号**：中心是圆环默认的网络图标，三段弧加一个点。

图标不显示即时电量、音量、警告或充电状态。相比 v1，外环改成“轨道 + 数值弧”的真实结构，并补上底部状态点，和菜单栏里看到的圆环一一对应。

配色从蓝绿色改为明亮的蓝色，源色 sRGB `#2F63E8`，由 Icon Composer 的自动渐变生成明暗。白色前景经系统材质处理后呈现玻璃质感。图形居中，无文字、无角标。

## 制作方式

交付的是原生 Icon Composer 文档，不是玻璃质感的概念效果图：

- `Sources/FuseBar/AppIcon.icon`：Xcode 使用的可编辑源文件。
- `01-orbit.svg`：圆环，中心 (512, 487)，半径 317、实体宽 80；轨道 28% 不透明，数值弧不透明。
- `02-status-dots.svg`：四个状态点，半径 27.5，落在圆环半径上；后两个 38% 不透明。
- `03-signal.svg`：网络信号，三段弧宽 40 加中心点。
- 所有源图层使用 1024 × 1024 SVG，全部为填充路径，无描边依赖。坐标由概念稿的 824 px 图标主体按 1024/824 放大到 Icon Composer 的完整画布。背景由 Icon Composer 定义。
- 三组透明度参数分别为 0.20 / 0.12 / 0.06；每层启用原生 glass。系统负责光照、折射、阴影、外形裁切和外观适配。
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

`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` 已配置。Xcode 自动生成 `AppIcon.icns` 和 `Assets.car`，供旧版系统与 Liquid Glass 系统使用。设计目录中的 `FuseBar.icns` 是本次构建的独立导出，需要在重新构建后从应用包复制更新。

应用仍为无 Dock 图标的菜单栏工具；Finder、系统设置等场景会显示新应用图标。18 pt 菜单栏绘制继续使用原有单色 template 图像，以维持动态状态可读性。
