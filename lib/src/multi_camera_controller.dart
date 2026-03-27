import 'package:flutter/services.dart';
import 'models.dart';
import 'usb_camera_controller.dart';

/// Controller for multi-road camera, equivalent to MultiCameraFragment
class MultiCameraController {
  static const MethodChannel _channel = MethodChannel('flutter_usbcamera');

  final Map<int, int> _textureIds = {};

  /// Get texture ID for a specific device
  int? getTextureId(int deviceId) => _textureIds[deviceId];

  /// All active texture IDs
  Map<int, int> get textureIds => Map.unmodifiable(_textureIds);

  /// Event stream (shared with UsbCameraController)
  Stream<CameraEvent> get events => UsbCameraController.events;

  /// Register USB monitor
  Future<bool> registerUsb() async {
    final result = await _channel.invokeMethod<bool>('registerUsb');
    return result ?? false;
  }

  /// Unregister USB monitor
  Future<bool> unregisterUsb() async {
    final result = await _channel.invokeMethod<bool>('unregisterUsb');
    _textureIds.clear();
    return result ?? false;
  }

  /// Get device list
  Future<List<UsbDevice>> getDeviceList() async {
    final result = await _channel.invokeMethod<List>('getDeviceList');
    if (result == null) return [];
    return result
        .map((e) => UsbDevice.fromMap(Map<dynamic, dynamic>.from(e)))
        .toList();
  }

  /// Request permission for a device
  Future<bool> requestPermission(int deviceId) async {
    final result = await _channel.invokeMethod<bool>('requestPermission', {
      'deviceId': deviceId,
    });
    return result ?? false;
  }

  /// Check permission
  Future<bool> hasPermission(int deviceId) async {
    final result = await _channel.invokeMethod<bool>('hasPermission', {
      'deviceId': deviceId,
    });
    return result ?? false;
  }

  /// Open a camera and get its texture ID
  Future<int> openCamera(
    int deviceId, {
    int previewWidth = 640,
    int previewHeight = 480,
  }) async {
    final result = await _channel.invokeMethod<Map>('openMultiCamera', {
      'deviceId': deviceId,
      'previewWidth': previewWidth,
      'previewHeight': previewHeight,
    });
    final textureId = result?['textureId'] as int? ?? -1;
    _textureIds[deviceId] = textureId;
    return textureId;
  }

  /// Close a specific camera
  Future<bool> closeCamera(int deviceId) async {
    final result = await _channel.invokeMethod<bool>('closeMultiCamera', {
      'deviceId': deviceId,
    });
    _textureIds.remove(deviceId);
    return result ?? false;
  }

  /// Capture image from a specific camera
  Future<bool> captureImage(int deviceId) async {
    final result = await _channel.invokeMethod<bool>('multiCaptureImage', {
      'deviceId': deviceId,
    });
    return result ?? false;
  }

  /// Start video capture from a specific camera
  Future<bool> captureVideoStart(int deviceId) async {
    final result = await _channel.invokeMethod<bool>('multiCaptureVideoStart', {
      'deviceId': deviceId,
    });
    return result ?? false;
  }

  /// Stop video capture from a specific camera
  Future<bool> captureVideoStop(int deviceId) async {
    final result = await _channel.invokeMethod<bool>('multiCaptureVideoStop', {
      'deviceId': deviceId,
    });
    return result ?? false;
  }

  /// Close all cameras
  Future<void> closeAllCameras() async {
    for (final deviceId in _textureIds.keys.toList()) {
      await closeCamera(deviceId);
    }
  }

  /// Dispose
  Future<void> dispose() async {
    await closeAllCameras();
    await unregisterUsb();
  }
}
