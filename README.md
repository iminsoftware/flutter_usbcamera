# flutter_usbcamera

[English](README_EN.md) | 中文

Flutter 插件，用于 Android 平台 UVC（USB Video Class）摄像头的预览、拍照、录像、录音及 OpenGL 特效渲染。

基于 [AndroidUSBCamera (AUSBC)](https://github.com/jiangdongguo/AndroidUSBCamera) 库封装。

## 功能

- USB 摄像头实时预览（OpenGL 渲染）
- 拍照 / 录像 / 录音
- 分辨率切换
- 亮度、对比度、色调等参数调节
- OpenGL 特效（黑白、灵魂出窍、缩放动画）
- 画面旋转（0° / 90° / 180° / 270°）
- 设备热插拔监听
- 麦克风实时播放

## 平台支持

| 平台 | 支持 |
|---------|------|
| Android | ✅   |
| iOS     | ❌   |
| Web     | ❌   |

## 环境要求

- Flutter >= 3.3.0
- Android minSdk >= 21
- Android compileSdk >= 34
- NDK（用于编译 libuvc 原生库）

## 集成步骤

### 1. 添加依赖

在你的 Flutter 项目 `pubspec.yaml` 中添加：

```yaml
dependencies:
  flutter_usbcamera:
    path: ../flutter_usbcamera  # 本地路径引用
```

或者如果发布到私有仓库：

```yaml
dependencies:
  flutter_usbcamera: ^0.0.1
```

### 2. 配置 Android

#### 2.1 settings.gradle

在你的项目 `android/settings.gradle` 末尾添加子模块引用：

```groovy
// 解析插件路径
def flutterPluginsFile = new File(rootProject.projectDir.parentFile, '.flutter-plugins')
def pluginDir = null
if (flutterPluginsFile.exists()) {
    flutterPluginsFile.eachLine { line ->
        if (line.startsWith('flutter_usbcamera=')) {
            pluginDir = line.split('=')[1].trim()
        }
    }
}
if (pluginDir == null) {
    pluginDir = new File(rootProject.projectDir, '../../flutter_usbcamera/android').absolutePath
}

include ':libuvc'
project(':libuvc').projectDir = new File(pluginDir, 'libuvc')

include ':libnative'
project(':libnative').projectDir = new File(pluginDir, 'libnative')

include ':libausbc'
project(':libausbc').projectDir = new File(pluginDir, 'libausbc')
```

#### 2.2 build.gradle

确保 `android/app/build.gradle` 中：

```groovy
android {
    compileSdk 34
    ndkVersion "27.0.12077973"  // 或你本地安装的 NDK 版本

    defaultConfig {
        minSdk 21
        ndk {
            abiFilters 'armeabi-v7a', 'arm64-v8a'
        }
    }
}
```

#### 2.3 build.gradle (项目级)

确保 `android/build.gradle` 的 `allprojects.repositories` 中包含 jitpack：

```groovy
allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url "https://jitpack.io" }
    }
}
```

#### 2.4 AndroidManifest.xml

插件已自动声明以下权限，无需手动添加：

```xml
<uses-feature android:name="android.hardware.usb.host" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

如需存储到外部目录，在你的 app 的 `AndroidManifest.xml` 中添加：

```xml
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />

<application
    android:requestLegacyExternalStorage="true"
    ...>
```

## 快速开始

### 基本用法

```dart
import 'package:flutter_usbcamera/flutter_usbcamera.dart';

class CameraPage extends StatefulWidget {
  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final _controller = UsbCameraController();
  StreamSubscription<CameraEvent>? _eventSub;
  bool _isCameraOpened = false;

  @override
  void initState() {
    super.initState();
    _eventSub = UsbCameraController.events.listen(_handleEvent);
    _controller.registerUsb();
  }

  void _handleEvent(CameraEvent event) {
    switch (event.type) {
      case CameraEventType.onAttachDev:
        // USB 摄像头插入，自动请求权限
        if (event.deviceId != null) {
          _controller.requestPermission(event.deviceId!);
        }
        break;
      case CameraEventType.onConnectDev:
        // 权限通过，打开摄像头
        _openCamera(event.deviceId!);
        break;
      case CameraEventType.onCameraState:
        if (event.state == 'opened') {
          setState(() => _isCameraOpened = true);
        } else if (event.state == 'closed') {
          setState(() => _isCameraOpened = false);
        }
        break;
      default:
        break;
    }
  }

  Future<void> _openCamera(int deviceId) async {
    await _controller.openCamera(
      deviceId,
      request: const CameraRequest(
        previewWidth: 640,
        previewHeight: 480,
        renderMode: RenderMode.opengl,
        previewFormat: PreviewFormat.mjpeg,
      ),
    );
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 摄像头预览区域
          Expanded(
            child: UsbCameraPreview(),
          ),
          // 拍照按钮
          ElevatedButton(
            onPressed: _isCameraOpened
                ? () => _controller.captureImage()
                : null,
            child: Text('拍照'),
          ),
        ],
      ),
    );
  }
}
```

## API 参考

### UsbCameraPreview

摄像头预览组件，内部嵌入 Android 原生 TextureView。

```dart
const UsbCameraPreview({
  double? width,
  double? height,
  Widget? placeholder,
})
```

直接放到 widget 树中即可，无需传入 textureId。

### UsbCameraController

摄像头控制器，提供所有摄像头操作方法。

#### 生命周期

| 方法 | 说明 |
|------|------|
| `registerUsb()` | 注册 USB 监听，开始检测设备插拔 |
| `unregisterUsb()` | 注销 USB 监听 |
| `dispose()` | 释放所有资源 |

#### 设备管理

| 方法 | 说明 |
|------|------|
| `getDeviceList()` | 获取已连接的 USB 设备列表 |
| `hasPermission(deviceId)` | 检查设备权限 |
| `requestPermission(deviceId)` | 请求设备权限 |
| `switchCamera(deviceId)` | 切换到另一个摄像头 |

#### 摄像头控制

| 方法 | 说明 |
|------|------|
| `openCamera(deviceId, {request})` | 打开摄像头 |
| `closeCamera({deviceId})` | 关闭摄像头 |
| `isCameraOpened()` | 是否已打开 |
| `updateResolution(width, height)` | 切换分辨率 |
| `getAllPreviewSizes()` | 获取支持的分辨率列表 |
| `setRotateType(type)` | 设置旋转角度 |

#### 拍摄

| 方法 | 说明 |
|------|------|
| `captureImage({path})` | 拍照 |
| `captureVideoStart({path, durationInSec})` | 开始录像 |
| `captureVideoStop()` | 停止录像 |
| `captureAudioStart({path})` | 开始录音 |
| `captureAudioStop()` | 停止录音 |

#### 参数调节

| 方法 | 说明 |
|------|------|
| `setBrightness(value)` / `getBrightness()` | 亮度 |
| `setContrast(value)` / `getContrast()` | 对比度 |
| `setZoom(value)` / `getZoom()` | 缩放 |
| `setGain(value)` / `getGain()` | 增益 |
| `setGamma(value)` / `getGamma()` | 伽马 |
| `setSharpness(value)` / `getSharpness()` | 锐度 |
| `setSaturation(value)` / `getSaturation()` | 饱和度 |
| `setHue(value)` / `getHue()` | 色调 |
| `setAutoFocus(enable)` | 自动对焦 |
| `setAutoWhiteBalance(enable)` | 自动白平衡 |

#### 特效

| 方法 | 说明 |
|------|------|
| `addRenderEffect(effectId)` | 添加渲染特效 |
| `removeRenderEffect(effectId)` | 移除渲染特效 |
| `updateRenderEffect(classifyId, {effectId})` | 更新特效 |

内置特效 ID：

```dart
EffectId.blackWhite  // 黑白滤镜 (100)
EffectId.soul        // 灵魂出窍 (200)
EffectId.zoom        // 缩放动画 (300)
```

#### 麦克风

| 方法 | 说明 |
|------|------|
| `startPlayMic()` | 开始实时播放麦克风 |
| `stopPlayMic()` | 停止播放 |

### 事件流

通过 `UsbCameraController.events` 监听所有事件：

```dart
UsbCameraController.events.listen((event) {
  switch (event.type) {
    case CameraEventType.onAttachDev:    // 设备插入
    case CameraEventType.onDetachDev:    // 设备拔出
    case CameraEventType.onConnectDev:   // 设备连接（权限通过）
    case CameraEventType.onDisConnectDev: // 设备断开
    case CameraEventType.onCancelDev:    // 权限被拒绝
    case CameraEventType.onCameraState:  // 摄像头状态变化 (opened/closed/error)
    case CameraEventType.onCaptureBegin: // 开始拍摄
    case CameraEventType.onCaptureComplete: // 拍摄完成
    case CameraEventType.onCaptureError: // 拍摄错误
    case CameraEventType.onPlayMicBegin: // 麦克风开始
    case CameraEventType.onPlayMicComplete: // 麦克风结束
    case CameraEventType.onPlayMicError: // 麦克风错误
  }
});
```

### 数据模型

```dart
// USB 设备信息
class UsbDevice {
  final int deviceId;
  final String deviceName;
  final int vendorId;
  final int productId;
  final String productName;
}

// 摄像头请求参数
class CameraRequest {
  final int previewWidth;      // 默认 640
  final int previewHeight;     // 默认 480
  final RenderMode renderMode; // opengl (推荐) 或 normal
  final PreviewFormat previewFormat; // mjpeg (推荐) 或 yuyv
  final RotateType rotateType; // 旋转角度
}

// 预览尺寸
class PreviewSize {
  final int width;
  final int height;
}
```

## 常见问题

### 画面不显示

确保在调用 `openCamera()` 之前，`UsbCameraPreview` widget 已经在 widget 树中。PlatformView 需要先创建 Android 端的 TextureView，摄像头才能渲染到上面。

### 编译报错 NDK 相关

确保 `local.properties` 中配置了正确的 NDK 路径：

```properties
ndk.dir=/path/to/Android/Sdk/ndk/27.0.12077973
```

### 权限问题

USB 设备权限由系统弹窗授予，首次连接时会弹出。如果用户拒绝，会收到 `onCancelDev` 事件。拔掉重插可以重新触发权限请求。

## 开发者文档

### 项目架构

```
flutter_usbcamera/
├── lib/
│   ├── flutter_usbcamera.dart                  # 公开 API 导出
│   ├── flutter_usbcamera_platform_interface.dart  # 平台接口抽象层
│   ├── flutter_usbcamera_method_channel.dart      # MethodChannel 实现
│   └── src/
│       ├── models.dart                  # 数据模型（UsbDevice, CameraEvent, CameraRequest 等）
│       ├── usb_camera_controller.dart   # 单摄像头控制器
│       ├── multi_camera_controller.dart # 多摄像头控制器
│       └── usb_camera_preview.dart      # 预览 Widget（PlatformView）
├── android/
│   ├── src/main/kotlin/.../FlutterUsbcameraPlugin.kt  # Android 原生插件入口
│   ├── libausbc/    # AUSBC 摄像头核心库
│   ├── libuvc/      # UVC 协议 C 库（NDK 编译）
│   └── libnative/   # JNI 原生桥接层
├── example/         # 示例应用
└── test/            # 单元测试
```

### 通信机制

Flutter 与 Android 原生之间通过两个通道通信：

- `MethodChannel('flutter_usbcamera')` — 用于 Dart 调用原生方法（打开/关闭摄像头、拍照、录像等）
- `EventChannel('flutter_usbcamera/events')` — 用于原生向 Dart 推送事件（设备插拔、摄像头状态变化、拍摄回调等）

预览画面通过 `PlatformViewLink` + Hybrid Composition 方式嵌入，viewType 为 `flutter_usbcamera/cameraview`。

### 核心类说明

| 类 | 职责 |
|----|------|
| `UsbCameraController` | 单摄像头场景的控制器，管理 USB 注册、权限、摄像头开关、拍摄、参数调节、特效等 |
| `MultiCameraController` | 多摄像头场景的控制器，支持同时打开多个 USB 摄像头，独立控制拍照/录像 |
| `UsbCameraPreview` | 预览 Widget，内部使用 Android PlatformView（Hybrid Composition）渲染 TextureView |
| `CameraEvent` | 事件模型，封装所有从原生层推送的事件（设备插拔、状态变化、拍摄回调等） |
| `CameraRequest` | 打开摄像头时的参数配置（分辨率、渲染模式、预览格式、旋转角度） |
| `FlutterUsbcameraPlugin` | Android 原生插件入口（Kotlin），处理 MethodChannel 调用并桥接 AUSBC 库 |

### 本地开发

1. 克隆仓库：

```bash
git clone https://github.com/iminsoftware/flutter_usbcamera.git
cd flutter_usbcamera
```

2. 安装依赖：

```bash
flutter pub get
cd example && flutter pub get
```

3. 运行示例应用（需要连接 Android 设备）：

```bash
cd example
flutter run
```

4. 运行测试：

```bash
flutter test
```

### 原生层开发

Android 原生代码位于 `android/` 目录，包含三个子模块：

- `libuvc` — UVC 协议的 C 实现，通过 NDK 编译为 `.so` 文件，负责底层 USB 视频流解析
- `libnative` — JNI 桥接层，连接 Java/Kotlin 层与 libuvc
- `libausbc` — 基于 [AndroidUSBCamera](https://github.com/jiangdongguo/AndroidUSBCamera) 的 Kotlin 封装，提供摄像头生命周期管理、预览渲染、拍摄等高层 API

修改原生代码后，需要在 example 项目中重新构建：

```bash
cd example
flutter clean
flutter run
```

### 添加新的 MethodChannel 方法

1. 在 `FlutterUsbcameraPlugin.kt` 中的 `onMethodCall` 添加新的 case 处理
2. 在 `UsbCameraController` 或 `MultiCameraController` 中添加对应的 Dart 方法
3. 如果需要新的数据模型，在 `models.dart` 中定义
4. 更新 `flutter_usbcamera.dart` 的导出（如有新文件）

### 添加新的事件类型

1. 在 `CameraEventType` 枚举中添加新类型
2. 在 Android 端通过 `EventChannel` 的 `EventSink` 发送对应事件
3. `CameraEvent.fromMap` 会自动解析新的事件类型（需确保 `event` 字段名与枚举名一致）

### 发布

```bash
# 检查发布前的问题
flutter pub publish --dry-run

# 正式发布到 pub.dev
flutter pub publish
```

发布后在 [pub.dev](https://pub.dev) 包管理页面将包转移到 `imin.sg` publisher。

### 贡献指南

1. Fork 本仓库
2. 创建功能分支：`git checkout -b feature/your-feature`
3. 提交改动：`git commit -m 'feat: add your feature'`
4. 推送分支：`git push origin feature/your-feature`
5. 提交 Pull Request

请确保：
- 代码通过 `flutter analyze` 检查
- 新功能附带对应的使用说明
- Commit message 遵循 [Conventional Commits](https://www.conventionalcommits.org/) 规范

## License

BSD 3-Clause License
