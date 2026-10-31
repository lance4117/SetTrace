# 墨绿三线图标 · Android 接入

2026-10-15。按用户要求，将 `settrace-brand-final/` 正式设计接入 Android 启动器，品牌母版未修改。

## 资源

- 前景的四段路径直接取自最终白色 SVG，背景为 `#153C34`。
- API 26 起使用共用矢量前景和独立背景。108 dp 自适应画布内，将 100 单位母版缩放至中心 72 dp 可见区：scale 0.72，translate 18 dp，保留系统遮罩与运动空间。
- API 33 起提供 monochrome 层，支持系统主题图标着色。
- API 24–25 使用普通／圆形 PNG，各提供 mdpi 至 xxxhdpi 五档：48、72、96、144、192 px。
- Manifest 配置普通及圆形入口。旧的五张前景位图由共用矢量替代。

## 核验

| 检查 | 结果 |
| --- | --- |
| 四段矢量与母版比较 | pathData 完全一致 |
| 背景、缩放、安全留白、资源引用 | 通过 |
| 五档普通及圆形 PNG | 尺寸正确；普通图标与最终预览按 Lanczos 缩放后的像素一致 |
| Android Debug APK 构建 | 通过，正式入口 `lib/main.dart`；0.2.0+6、minSdk 24、targetSdk 36 |
| AAPT / AAPT2 解包检查 | Manifest、API 26/33 XML、四段路径、缩放值及全部密度图标已正确编译入包 |
| APK 中 xxxhdpi 图标 | 与资源源文件逐像素一致；普通及圆形图像已目视检查 |
| `git diff --check` | 通过 |

APK：`build/app/outputs/flutter-apk/app-debug.apk`。

SHA-256：`1a905f3260e93e2d707fce0972136c6691feb85d96f60b4f6e26cce87bcd1c91`。

机器可读结果与 APK 提取图像位于忽略的构建目录 `build/qa/launcher-icon/`。

`adb devices -l` 当前无连接设备，未安装到真机或模拟器，未验证具体启动器或系统主题图标的实际渲染。App 主题、业务逻辑、版本号和用户数据未变更。

## 再生成

常规 Flutter 构建直接使用现有资源，不需要 Python。更新品牌素材后，可在 Python 3 + Pillow 环境运行：

```powershell
python tool/generate_android_icons.py
flutter build apk --debug --no-pub --target lib/main.dart
```

本机验证通过 Flutter SDK 的 Dart snapshot 等价入口构建，避开批处理启动器和 SDK 缓存权限问题。现有 Java native-access 与 SDK 工具 XML 版本提示未影响构建成功。
