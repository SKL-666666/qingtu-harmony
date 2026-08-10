# 清图 QingTu

> 基于 HarmonyOS 的 AI 图像处理应用：AI 超分辨率增强 + 智能压缩 + 专业相机
> An AI-powered image processing app for HarmonyOS: AI Super-Resolution + Smart Compression + Pro Camera

[![HarmonyOS](https://img.shields.io/badge/HarmonyOS-5.0.5+-000000?logo=huawei&logoColor=red)](https://developer.huawei.com/consumer/cn/harmonyos)
[![ArkTS](https://img.shields.io/badge/Language-ArkTS-blue)](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-overview)
[![License](https://img.shields.io/badge/License-Apache%202.0-green)](LICENSE)
[![Release](https://img.shields.io/github/v/release/SKL-666666/qingtu-harmony)](https://github.com/SKL-666666/qingtu-harmony/releases)

---

## 简介 / Introduction

**清图 (QingTu)** 是一款专为 HarmonyOS 设计的图像处理应用，致力于提供端侧的画质增强与压缩能力，所有处理均在设备本地完成，不依赖云端。

**QingTu** is an image processing app built for HarmonyOS, focused on on-device image enhancement and compression. All processing runs locally on the device — no cloud dependency.

### 核心功能 / Core Features

| 功能 Feature | 说明 Description |
|---|---|
| 🖼️ **AI 超分辨率** AI Super-Resolution | 基于 `ImageProcessing` 的细节增强 + 2 倍真实放大，输出最高 2000px 高清图。Detail enhancement + genuine 2x upscaling, up to 2000px output. |
| 📦 **智能压缩** Smart Compression | 无损感知压缩，显著减小体积的同时保持视觉质量。Perceptually lossless compression that keeps visual quality while shrinking file size. |
| 📷 **专业相机** Pro Camera | 变焦（1x/5x/10x）、拍照后滤镜、双段拍照、延时拍照、网格线、水平仪、闪光灯、录像防抖。Zoom (1x/5x/10x), post-capture filters, dual-shot, self-timer, grid, level indicator, flash, video stabilization. |
| 🔍 **画质对比** Before/After Compare | 分割线滑动手势，直观对比增强前后效果。Drag-to-compare slider for a direct before/after view. |
| 🌗 **深浅色模式** Light/Dark Theme | 跟随系统自动切换，深色纯黑沉浸、浅色纯净明亮。Auto-follows system theme with immersive dark mode and clean light mode. |
| 🖼️ **保存到系统相册** Save to Gallery | 增强结果一键保存至系统相册。Save enhanced results to the system gallery with one tap. |

---

## 截图 / Screenshots

> 敬请期待 / Coming soon

---

## 运行环境 / Requirements

- **HarmonyOS**: 6.1 Release 及以上（API 23+）/ 6.1 Release or later (API 23+)
- **DevEco Studio**: 6.1 Release 及以上 / 6.1 Release or later
- **HarmonyOS SDK**: 6.1 Release 及以上 / 6.1 Release or later
- **设备类型 / Device types**: 手机 Phone / 平板 Tablet

---

## 构建与安装 / Build & Install

### 使用 Release 包安装 / Install from Release

从 [Releases](https://github.com/SKL-666666/qingtu-harmony/releases) 页面下载最新的 `.hap` 安装包：

- `qingtu-v1.0.3-signed.hap` — 已签名包，可直接安装到设备 / Signed package, installable directly on device
- `qingtu-v1.0.3-unsigned.hap` — 未签名包，需配合本地签名工具使用 / Unsigned package, requires local signing

```bash
hdc install qingtu-v1.0.3-signed.hap
```

### 从源码构建 / Build from Source

1. 克隆仓库 / Clone the repository:
   ```bash
   git clone https://github.com/SKL-666666/qingtu-harmony.git
   ```
2. 使用 DevEco Studio 打开项目根目录 / Open the project root in DevEco Studio.
3. 在 `File > Project Structure > Signing Configs` 中配置签名（使用你自己的证书）/ Configure signing under `File > Project Structure > Signing Configs` (use your own certificate).
4. 点击 `Build > Build Hap(s)/APP(s)` 构建产物。/ Click `Build > Build Hap(s)/APP(s)` to build.

---

## 工程目录 / Project Structure

```
├── AppScope/                                    # 应用全局配置 / App-level config
├── entry/src/main/ets/                          # ArkTS 源码 / ArkTS source
│   ├── cameracomponents/                        # 相机功能组件 / Camera overlay components (grid, level)
│   ├── cameraconstants/                         # 相机常量 / Camera constants
│   ├── cameramanagers/                          # 相机管理器 / Camera session, photo, video, preview managers
│   ├── cameramodels/                            # 相机数据模型 / Camera data models
│   ├── camerautils/                             # 相机工具 / Camera utilities (permissions, window)
│   ├── cameraviews/                             # 相机视图 / Camera UI views (operate, settings, zoom)
│   ├── common/                                  # 公共代码 / Shared code
│   │   ├── constants/Theme.ets                  # 主题系统（深浅色）/ Theme system (light/dark)
│   │   └── utils/                               # 工具函数 / Utilities
│   ├── components/business/                     # 业务组件 / Business components (compare viewer, loading)
│   ├── entryability/                            # 应用入口 / App entry
│   ├── entrybackupability/                      # 备份恢复 / Backup ability
│   ├── pages/                                   # 页面 / Pages (Index, Compression, Camera, About)
│   └── services/                                # 业务服务 / Services (image processing, file, camera)
├── entry/src/main/resources/                    # 资源文件（深浅色限定符）/ Resources (dark/light qualifiers)
├── release/                                     # 已打包的 HAP / Pre-built HAP packages
├── .gitignore
├── build-profile.json5                          # 工程构建配置 / Project build config
├── oh-package.json5                             # 包管理配置 / Package config
└── LICENSE                                      # Apache 2.0
```

---

## 技术亮点 / Technical Highlights

- **双通道超分流程**：先进行同尺寸细节增强（HIGH），再进行 2 倍放大（MEDIUM），保证画质与分辨率兼顾。Two-pass super-resolution: same-size detail enhancement (HIGH) then 2x scaling (MEDIUM) for quality + resolution.
- **DMA 内存优化**：解码直出 DMA PixelMap，异步像素读写避免 UI 卡顿。DMA memory-optimized decode with async pixel I/O to avoid UI jank.
- **相机资源管理**：页面不可见时自动停止相机与动画，节省系统资源。Camera session and animations auto-stop when the page is not visible.
- **主题跟随系统**：`EnvironmentCallback` 监听系统深浅色切换，全量 UI 适配。System theme detection via `EnvironmentCallback` with full UI adaptation.

---

## 权限说明 / Permissions

| 权限 Permission | 用途 Purpose |
|---|---|
| `ohos.permission.CAMERA` | 相机拍摄 / Camera capture |
| `ohos.permission.ACCELEROMETER` | 检测设备方向 / Device orientation detection |
| `WRITE_IMAGEVIDEO` (system_grant, ACL) | 保存图片至系统相册 / Save images to system gallery |

---

## 开源协议 / License

本项目基于 [Apache License 2.0](LICENSE) 开源。

This project is licensed under the [Apache License 2.0](LICENSE).

---

## 联系方式 / Contact

- GitHub: [SKL-666666](https://github.com/SKL-666666)
