# Liquidify Companion Glass

一个独立、rootless、仅注入 SpringBoard 的 companion tweak。它不修改 Liquidify 主体 dylib，也不 Hook、伪造或绕过任何授权结果。

## 当前实现

1. **透明化**：仅在 `SBDockView` 内隐藏原生 Material/VisualEffect 背景，保留图标和交互。
2. **独立 Metal 玻璃**：暂停式 `MTKView`，使用单次背景快照，实现折射、RGB 色散、近似模糊、Fresnel 边缘和定向眩光。
3. **稳定性**：仅编译 arm64，避免本地旧 arm64e ABI 被优先选中；不 fishhook、不替换授权函数、不修改原包。

## 参数

偏好域：`com.qwer12345uui.liquidifycompanion`

- `Enabled`：默认 `true`
- `RefractionStrength`：默认 `24`，范围 `8...40`
- `BlurRadius`：默认 `2`，范围 `0...10`
- `Dispersion`：默认 `9`，范围 `0...24`
- `Fresnel`：默认 `0.85`，范围 `0...2`
- `Glare`：默认 `0.75`，范围 `0...2`

修改后重启 SpringBoard。当前渲染器采用按布局更新的静态背景快照，避免持续读取屏幕造成递归渲染和高 GPU/CPU 占用；因此动态图像下不会逐帧实时折射。实时效果需要接入私有 Backdrop/CARenderServer 管线，跨 iOS 版本稳定性明显更差。

## 构建

```sh
source /root/pb/env.sh
make clean package FINALPACKAGE=1
```
