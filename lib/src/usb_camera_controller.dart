import 'dart:async';
import 'package:flutter/services.dart';
import 'models.dart';

/// Controller for a single UVC camera, equivalent to CameraFragment/CameraActivity
class UsbCameraController {
  static const MethodChannel _channel = MethodChannel('flutter_usbcamera');
  static const EventChannel _eventChannel = EventChannel(
    'flutter_usbcamera/events',
  );

  static Stream<CameraEvent>? _eventStream;

  /// Event stream for all camera events
  static Stream<CameraEvent> get events {
    _eventStream ??= _eventChannel.receiveBroadcastStream().map((event) {
      return CameraEvent.fromMap(Map<dynamic, dynamic>.from(event));
    });
    return _eventStream!;
  }

  int? _textureId;
  int? _currentDeviceId;
  bool _isRegistered = false;

  /// Current texture ID for rendering
  int? get textureId => _textureId;

  /// Current device ID
  int? get currentDeviceId => _currentDeviceId;

  /// Whether USB monitor is registered
  bool get isRegistered => _isRegistered;

  /// Register USB monitor to start listening for device events
  Future<bool> registerUsb() async {
    final result = await _channel.invokeMethod<bool>('registerUsb');
    _isRegistered = result ?? false;
    return _isRegistered;
  }

  /// Unregister USB monitor
  Future<bool> unregisterUsb() async {
    final result = await _channel.invokeMethod<bool>('unregisterUsb');
    _isRegistered = false;
    _textureId = null;
    _currentDeviceId = null;
    return result ?? false;
  }

  /// Get list of connected USB devices
  Future<List<UsbDevice>> getDeviceList() async {
    final result = await _channel.invokeMethod<List>('getDeviceList');
    if (result == null) return [];
    return result
        .map((e) => UsbDevice.fromMap(Map<dynamic, dynamic>.from(e)))
        .toList();
  }

  /// Check if device has permission
  Future<bool> hasPermission(int deviceId) async {
    final result = await _channel.invokeMethod<bool>('hasPermission', {
      'deviceId': deviceId,
    });
    return result ?? false;
  }

  /// Request permission for a device
  Future<bool> requestPermission(int deviceId) async {
    final result = await _channel.invokeMethod<bool>('requestPermission', {
      'deviceId': deviceId,
    });
    return result ?? false;
  }

  /// Open camera and get texture ID for preview
  Future<int> openCamera(
    int deviceId, {
    CameraRequest request = const CameraRequest(),
  }) async {
    final result = await _channel.invokeMethod<Map>('openCamera', {
      'deviceId': deviceId,
      'previewWidth': request.previewWidth,
      'previewHeight': request.previewHeight,
      'renderMode': request.renderMode == RenderMode.opengl
          ? 'opengl'
          : 'normal',
      'previewFormat': request.previewFormat == PreviewFormat.yuyv
          ? 'yuyv'
          : 'mjpeg',
      'rotateAngle': _rotateTypeToAngle(request.rotateType),
    });
    _textureId = result?['textureId'] as int? ?? -1;
    _currentDeviceId = deviceId;
    return _textureId!;
  }

  /// Close camera
  Future<bool> closeCamera({int? deviceId}) async {
    final result = await _channel.invokeMethod<bool>('closeCamera', {
      'deviceId': deviceId,
    });
    _textureId = null;
    if (deviceId == null || deviceId == _currentDeviceId) {
      _currentDeviceId = null;
    }
    return result ?? false;
  }

  /// Check if camera is opened
  Future<bool> isCameraOpened() async {
    final result = await _channel.invokeMethod<bool>('isCameraOpened');
    return result ?? false;
  }

  /// Check if recording
  Future<bool> isRecording() async {
    final result = await _channel.invokeMethod<bool>('isRecording');
    return result ?? false;
  }

  /// Capture image
  Future<bool> captureImage({String? path}) async {
    final result = await _channel.invokeMethod<bool>('captureImage', {
      'path': path,
    });
    return result ?? false;
  }

  /// Start video capture
  Future<bool> captureVideoStart({String? path, int durationInSec = 0}) async {
    final result = await _channel.invokeMethod<bool>('captureVideoStart', {
      'path': path,
      'durationInSec': durationInSec,
    });
    return result ?? false;
  }

  /// Stop video capture
  Future<bool> captureVideoStop() async {
    final result = await _channel.invokeMethod<bool>('captureVideoStop');
    return result ?? false;
  }

  /// Start audio capture (MP3)
  Future<bool> captureAudioStart({String? path}) async {
    final result = await _channel.invokeMethod<bool>('captureAudioStart', {
      'path': path,
    });
    return result ?? false;
  }

  /// Stop audio capture
  Future<bool> captureAudioStop() async {
    final result = await _channel.invokeMethod<bool>('captureAudioStop');
    return result ?? false;
  }

  /// Start H264/AAC stream capture
  Future<bool> captureStreamStart() async {
    final result = await _channel.invokeMethod<bool>('captureStreamStart');
    return result ?? false;
  }

  /// Stop stream capture
  Future<bool> captureStreamStop() async {
    final result = await _channel.invokeMethod<bool>('captureStreamStop');
    return result ?? false;
  }

  /// Start playing mic audio in real-time
  Future<bool> startPlayMic() async {
    final result = await _channel.invokeMethod<bool>('startPlayMic');
    return result ?? false;
  }

  /// Stop playing mic
  Future<bool> stopPlayMic() async {
    final result = await _channel.invokeMethod<bool>('stopPlayMic');
    return result ?? false;
  }

  /// Get all supported preview sizes
  Future<List<PreviewSize>> getAllPreviewSizes() async {
    final result = await _channel.invokeMethod<List>('getAllPreviewSizes');
    if (result == null) return [];
    return result
        .map((e) => PreviewSize.fromMap(Map<dynamic, dynamic>.from(e)))
        .toList();
  }

  /// Update camera resolution
  Future<bool> updateResolution(int width, int height) async {
    final result = await _channel.invokeMethod<bool>('updateResolution', {
      'width': width,
      'height': height,
    });
    return result ?? false;
  }

  /// Set camera rotation angle
  Future<bool> setRotateType(RotateType type) async {
    final result = await _channel.invokeMethod<bool>('setRotateType', {
      'angle': _rotateTypeToAngle(type),
    });
    return result ?? false;
  }

  // Camera parameter controls
  Future<bool> setAutoFocus(bool enable) async {
    return await _channel.invokeMethod<bool>('setAutoFocus', {
          'enable': enable,
        }) ??
        false;
  }

  Future<bool> setAutoWhiteBalance(bool enable) async {
    return await _channel.invokeMethod<bool>('setAutoWhiteBalance', {
          'enable': enable,
        }) ??
        false;
  }

  Future<bool> setBrightness(int value) async {
    return await _channel.invokeMethod<bool>('setBrightness', {
          'value': value,
        }) ??
        false;
  }

  Future<int?> getBrightness() async {
    return await _channel.invokeMethod<int>('getBrightness');
  }

  Future<bool> setContrast(int value) async {
    return await _channel.invokeMethod<bool>('setContrast', {'value': value}) ??
        false;
  }

  Future<int?> getContrast() async {
    return await _channel.invokeMethod<int>('getContrast');
  }

  Future<bool> setZoom(int value) async {
    return await _channel.invokeMethod<bool>('setZoom', {'value': value}) ??
        false;
  }

  Future<int?> getZoom() async {
    return await _channel.invokeMethod<int>('getZoom');
  }

  Future<bool> setGain(int value) async {
    return await _channel.invokeMethod<bool>('setGain', {'value': value}) ??
        false;
  }

  Future<int?> getGain() async {
    return await _channel.invokeMethod<int>('getGain');
  }

  Future<bool> setGamma(int value) async {
    return await _channel.invokeMethod<bool>('setGamma', {'value': value}) ??
        false;
  }

  Future<int?> getGamma() async {
    return await _channel.invokeMethod<int>('getGamma');
  }

  Future<bool> setSharpness(int value) async {
    return await _channel.invokeMethod<bool>('setSharpness', {
          'value': value,
        }) ??
        false;
  }

  Future<int?> getSharpness() async {
    return await _channel.invokeMethod<int>('getSharpness');
  }

  Future<bool> setSaturation(int value) async {
    return await _channel.invokeMethod<bool>('setSaturation', {
          'value': value,
        }) ??
        false;
  }

  Future<int?> getSaturation() async {
    return await _channel.invokeMethod<int>('getSaturation');
  }

  Future<bool> setHue(int value) async {
    return await _channel.invokeMethod<bool>('setHue', {'value': value}) ??
        false;
  }

  Future<int?> getHue() async {
    return await _channel.invokeMethod<int>('getHue');
  }

  /// Send custom command to camera
  Future<void> sendCameraCommand(int command) async {
    await _channel.invokeMethod('sendCameraCommand', {'command': command});
  }

  /// Add render effect
  Future<bool> addRenderEffect(int effectId) async {
    return await _channel.invokeMethod<bool>('addRenderEffect', {
          'effectId': effectId,
        }) ??
        false;
  }

  /// Remove render effect
  Future<bool> removeRenderEffect(int effectId) async {
    return await _channel.invokeMethod<bool>('removeRenderEffect', {
          'effectId': effectId,
        }) ??
        false;
  }

  /// Update render effect
  Future<bool> updateRenderEffect(int classifyId, {int? effectId}) async {
    return await _channel.invokeMethod<bool>('updateRenderEffect', {
          'classifyId': classifyId,
          'effectId': effectId,
        }) ??
        false;
  }

  /// Switch to a different camera
  Future<int> switchCamera(
    int deviceId, {
    CameraRequest request = const CameraRequest(),
  }) async {
    await closeCamera();
    await Future.delayed(const Duration(milliseconds: 500));
    await requestPermission(deviceId);
    // The actual open will happen via onConnectDev event
    _currentDeviceId = deviceId;
    return _textureId ?? -1;
  }

  /// Dispose controller
  Future<void> dispose() async {
    await closeCamera();
    await unregisterUsb();
  }

  int _rotateTypeToAngle(RotateType type) {
    switch (type) {
      case RotateType.angle90:
        return 90;
      case RotateType.angle180:
        return 180;
      case RotateType.angle270:
        return 270;
      default:
        return 0;
    }
  }
}
