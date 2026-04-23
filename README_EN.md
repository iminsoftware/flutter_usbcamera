# flutter_usbcamera

English | [中文](README.md)

A Flutter plugin for UVC (USB Video Class) camera preview, capture, recording, audio recording, and OpenGL effect rendering on Android.

Built on top of [AndroidUSBCamera (AUSBC)](https://github.com/jiangdongguo/AndroidUSBCamera).

## Features

- Real-time USB camera preview (OpenGL rendering)
- Image capture / Video recording / Audio recording
- Resolution switching
- Brightness, contrast, hue, and other parameter adjustments
- OpenGL effects (black & white, soul, zoom animation)
- Frame rotation (0° / 90° / 180° / 270°)
- Device hot-plug detection
- Microphone live playback

## Platform Support

| Platform | Supported |
|----------|-----------|
| Android  | ✅        |
| iOS      | ❌        |
| Web      | ❌        |

## Requirements

- Flutter >= 3.3.0
- Android minSdk >= 21
- Android compileSdk >= 34
- NDK (for compiling the libuvc native library)

## Integration

### 1. Add Dependency

Add to your Flutter project's `pubspec.yaml`:

```yaml
dependencies:
  flutter_usbcamera: ^0.0.1
```

Or use a local path reference:

```yaml
dependencies:
  flutter_usbcamera:
    path: ../flutter_usbcamera
```

### 2. Android Configuration

#### 2.1 settings.gradle

Append the following submodule references to your project's `android/settings.gradle`:

```groovy
// Resolve plugin path
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

#### 2.2 build.gradle (app-level)

Ensure your `android/app/build.gradle` contains:

```groovy
android {
    compileSdk 34
    ndkVersion "27.0.12077973"  // or your locally installed NDK version

    defaultConfig {
        minSdk 21
        ndk {
            abiFilters 'armeabi-v7a', 'arm64-v8a'
        }
    }
}
```

#### 2.3 build.gradle (project-level)

Ensure `android/build.gradle` includes jitpack in `allprojects.repositories`:

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

The plugin automatically declares the following permissions:

```xml
<uses-feature android:name="android.hardware.usb.host" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

If you need external storage access, add to your app's `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />

<application
    android:requestLegacyExternalStorage="true"
    ...>
```

## Quick Start

### Basic Usage

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
        // USB camera attached, request permission automatically
        if (event.deviceId != null) {
          _controller.requestPermission(event.deviceId!);
        }
        break;
      case CameraEventType.onConnectDev:
        // Permission granted, open camera
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
          // Camera preview area
          Expanded(
            child: UsbCameraPreview(),
          ),
          // Capture button
          ElevatedButton(
            onPressed: _isCameraOpened
                ? () => _controller.captureImage()
                : null,
            child: Text('Capture'),
          ),
        ],
      ),
    );
  }
}
```

## API Reference

### UsbCameraPreview

Camera preview widget, embedding an Android native TextureView.

```dart
const UsbCameraPreview({
  double? width,
  double? height,
  Widget? placeholder,
})
```

Simply place it in the widget tree. No textureId required.

### UsbCameraController

Camera controller providing all camera operation methods.

#### Lifecycle

| Method | Description |
|--------|-------------|
| `registerUsb()` | Register USB monitor, start detecting device plug/unplug |
| `unregisterUsb()` | Unregister USB monitor |
| `dispose()` | Release all resources |

#### Device Management

| Method | Description |
|--------|-------------|
| `getDeviceList()` | Get list of connected USB devices |
| `hasPermission(deviceId)` | Check device permission |
| `requestPermission(deviceId)` | Request device permission |
| `switchCamera(deviceId)` | Switch to another camera |

#### Camera Control

| Method | Description |
|--------|-------------|
| `openCamera(deviceId, {request})` | Open camera |
| `closeCamera({deviceId})` | Close camera |
| `isCameraOpened()` | Check if camera is open |
| `updateResolution(width, height)` | Switch resolution |
| `getAllPreviewSizes()` | Get supported resolution list |
| `setRotateType(type)` | Set rotation angle |

#### Capture

| Method | Description |
|--------|-------------|
| `captureImage({path})` | Capture image |
| `captureVideoStart({path, durationInSec})` | Start video recording |
| `captureVideoStop()` | Stop video recording |
| `captureAudioStart({path})` | Start audio recording |
| `captureAudioStop()` | Stop audio recording |

#### Parameter Adjustment

| Method | Description |
|--------|-------------|
| `setBrightness(value)` / `getBrightness()` | Brightness |
| `setContrast(value)` / `getContrast()` | Contrast |
| `setZoom(value)` / `getZoom()` | Zoom |
| `setGain(value)` / `getGain()` | Gain |
| `setGamma(value)` / `getGamma()` | Gamma |
| `setSharpness(value)` / `getSharpness()` | Sharpness |
| `setSaturation(value)` / `getSaturation()` | Saturation |
| `setHue(value)` / `getHue()` | Hue |
| `setAutoFocus(enable)` | Auto focus |
| `setAutoWhiteBalance(enable)` | Auto white balance |

#### Effects

| Method | Description |
|--------|-------------|
| `addRenderEffect(effectId)` | Add render effect |
| `removeRenderEffect(effectId)` | Remove render effect |
| `updateRenderEffect(classifyId, {effectId})` | Update effect |

Built-in effect IDs:

```dart
EffectId.blackWhite  // Black & white filter (100)
EffectId.soul        // Soul effect (200)
EffectId.zoom        // Zoom animation (300)
```

#### Microphone

| Method | Description |
|--------|-------------|
| `startPlayMic()` | Start microphone live playback |
| `stopPlayMic()` | Stop playback |

### Event Stream

Listen to all events via `UsbCameraController.events`:

```dart
UsbCameraController.events.listen((event) {
  switch (event.type) {
    case CameraEventType.onAttachDev:     // Device attached
    case CameraEventType.onDetachDev:     // Device detached
    case CameraEventType.onConnectDev:    // Device connected (permission granted)
    case CameraEventType.onDisConnectDev: // Device disconnected
    case CameraEventType.onCancelDev:     // Permission denied
    case CameraEventType.onCameraState:   // Camera state change (opened/closed/error)
    case CameraEventType.onCaptureBegin:  // Capture started
    case CameraEventType.onCaptureComplete: // Capture completed
    case CameraEventType.onCaptureError:  // Capture error
    case CameraEventType.onPlayMicBegin:  // Microphone started
    case CameraEventType.onPlayMicComplete: // Microphone stopped
    case CameraEventType.onPlayMicError:  // Microphone error
  }
});
```

### Data Models

```dart
// USB device information
class UsbDevice {
  final int deviceId;
  final String deviceName;
  final int vendorId;
  final int productId;
  final String productName;
}

// Camera open request parameters
class CameraRequest {
  final int previewWidth;      // Default: 640
  final int previewHeight;     // Default: 480
  final RenderMode renderMode; // opengl (recommended) or normal
  final PreviewFormat previewFormat; // mjpeg (recommended) or yuyv
  final RotateType rotateType; // Rotation angle
}

// Preview size
class PreviewSize {
  final int width;
  final int height;
}
```

## FAQ

### Preview not showing

Make sure `UsbCameraPreview` widget is already in the widget tree before calling `openCamera()`. The PlatformView needs to create the Android-side TextureView first for the camera to render onto.

### NDK build errors

Ensure `local.properties` has the correct NDK path:

```properties
ndk.dir=/path/to/Android/Sdk/ndk/27.0.12077973
```

### Permission issues

USB device permissions are granted via a system dialog on first connection. If the user denies, you'll receive an `onCancelDev` event. Unplug and re-plug the device to trigger the permission request again.

## Developer Documentation

### Project Architecture

```
flutter_usbcamera/
├── lib/
│   ├── flutter_usbcamera.dart                     # Public API exports
│   ├── flutter_usbcamera_platform_interface.dart   # Platform interface abstraction
│   ├── flutter_usbcamera_method_channel.dart       # MethodChannel implementation
│   └── src/
│       ├── models.dart                  # Data models (UsbDevice, CameraEvent, CameraRequest, etc.)
│       ├── usb_camera_controller.dart   # Single camera controller
│       ├── multi_camera_controller.dart # Multi-camera controller
│       └── usb_camera_preview.dart      # Preview widget (PlatformView)
├── android/
│   ├── src/main/kotlin/.../FlutterUsbcameraPlugin.kt  # Android native plugin entry
│   ├── libausbc/    # AUSBC camera core library
│   ├── libuvc/      # UVC protocol C library (NDK compiled)
│   └── libnative/   # JNI native bridge layer
├── example/         # Example app
└── test/            # Unit tests
```

### Communication Mechanism

Flutter communicates with the Android native side through two channels:

- `MethodChannel('flutter_usbcamera')` — For Dart calling native methods (open/close camera, capture, record, etc.)
- `EventChannel('flutter_usbcamera/events')` — For native pushing events to Dart (device plug/unplug, camera state changes, capture callbacks, etc.)

The preview is embedded via `PlatformViewLink` + Hybrid Composition, with viewType `flutter_usbcamera/cameraview`.

### Core Classes

| Class | Responsibility |
|-------|---------------|
| `UsbCameraController` | Single camera controller, manages USB registration, permissions, camera open/close, capture, parameter adjustment, effects |
| `MultiCameraController` | Multi-camera controller, supports opening multiple USB cameras simultaneously with independent capture/recording control |
| `UsbCameraPreview` | Preview widget, uses Android PlatformView (Hybrid Composition) to render TextureView |
| `CameraEvent` | Event model, encapsulates all events pushed from the native layer (device plug/unplug, state changes, capture callbacks) |
| `CameraRequest` | Camera open parameter configuration (resolution, render mode, preview format, rotation) |
| `FlutterUsbcameraPlugin` | Android native plugin entry (Kotlin), handles MethodChannel calls and bridges to the AUSBC library |

### Local Development

1. Clone the repository:

```bash
git clone https://github.com/iminsoftware/flutter_usbcamera.git
cd flutter_usbcamera
```

2. Install dependencies:

```bash
flutter pub get
cd example && flutter pub get
```

3. Run the example app (requires a connected Android device):

```bash
cd example
flutter run
```

4. Run tests:

```bash
flutter test
```

### Native Layer Development

Android native code is located in the `android/` directory with three submodules:

- `libuvc` — C implementation of the UVC protocol, compiled to `.so` files via NDK, handles low-level USB video stream parsing
- `libnative` — JNI bridge layer, connecting Java/Kotlin layer with libuvc
- `libausbc` — Kotlin wrapper based on [AndroidUSBCamera](https://github.com/jiangdongguo/AndroidUSBCamera), providing high-level APIs for camera lifecycle management, preview rendering, and capture

After modifying native code, rebuild in the example project:

```bash
cd example
flutter clean
flutter run
```

### Adding New MethodChannel Methods

1. Add a new case in `onMethodCall` in `FlutterUsbcameraPlugin.kt`
2. Add the corresponding Dart method in `UsbCameraController` or `MultiCameraController`
3. Define new data models in `models.dart` if needed
4. Update exports in `flutter_usbcamera.dart` if new files are added

### Adding New Event Types

1. Add the new type to the `CameraEventType` enum
2. Send the corresponding event from the Android side via `EventChannel`'s `EventSink`
3. `CameraEvent.fromMap` will automatically parse the new event type (ensure the `event` field name matches the enum name)

### Publishing

```bash
# Check for issues before publishing
flutter pub publish --dry-run

# Publish to pub.dev
flutter pub publish
```

After publishing, transfer the package to the `imin.sg` publisher on the [pub.dev](https://pub.dev) package admin page.

### Contributing

1. Fork this repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes: `git commit -m 'feat: add your feature'`
4. Push the branch: `git push origin feature/your-feature`
5. Submit a Pull Request

Please ensure:
- Code passes `flutter analyze`
- New features include corresponding documentation
- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/)

## License

BSD 3-Clause License
