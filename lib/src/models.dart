/// USB device information
class UsbDevice {
  final int deviceId;
  final String deviceName;
  final int vendorId;
  final int productId;
  final String productName;

  UsbDevice({
    required this.deviceId,
    required this.deviceName,
    required this.vendorId,
    required this.productId,
    this.productName = '',
  });

  factory UsbDevice.fromMap(Map<dynamic, dynamic> map) {
    return UsbDevice(
      deviceId: map['deviceId'] as int,
      deviceName: map['deviceName'] as String? ?? '',
      vendorId: map['vendorId'] as int? ?? 0,
      productId: map['productId'] as int? ?? 0,
      productName: map['productName'] as String? ?? '',
    );
  }

  @override
  String toString() =>
      'UsbDevice(id: $deviceId, name: $deviceName, vid: $vendorId, pid: $productId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UsbDevice && deviceId == other.deviceId;

  @override
  int get hashCode => deviceId.hashCode;
}

/// Camera preview size
class PreviewSize {
  final int width;
  final int height;

  const PreviewSize({required this.width, required this.height});

  factory PreviewSize.fromMap(Map<dynamic, dynamic> map) {
    return PreviewSize(
      width: map['width'] as int,
      height: map['height'] as int,
    );
  }

  double get aspectRatio => width / height;

  @override
  String toString() => '${width}x$height';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PreviewSize && width == other.width && height == other.height;

  @override
  int get hashCode => width.hashCode ^ height.hashCode;
}

/// Camera state
enum CameraState { opened, closed, error }

/// Camera render mode
enum RenderMode { normal, opengl }

/// Preview format
enum PreviewFormat { mjpeg, yuyv }

/// Rotate type
enum RotateType { angle0, angle90, angle180, angle270 }

/// Camera event types
enum CameraEventType {
  onAttachDev,
  onDetachDev,
  onConnectDev,
  onDisConnectDev,
  onCancelDev,
  onCameraState,
  onCaptureBegin,
  onCaptureError,
  onCaptureComplete,
  onPlayMicBegin,
  onPlayMicError,
  onPlayMicComplete,
  onMultiCameraState,
}

/// Camera event
class CameraEvent {
  final CameraEventType type;
  final int? deviceId;
  final String? state;
  final String? message;
  final String? path;
  final String? error;
  final String? captureType;
  final Map<dynamic, dynamic> raw;

  CameraEvent({
    required this.type,
    this.deviceId,
    this.state,
    this.message,
    this.path,
    this.error,
    this.captureType,
    required this.raw,
  });

  factory CameraEvent.fromMap(Map<dynamic, dynamic> map) {
    final eventStr = map['event'] as String;
    final type = CameraEventType.values.firstWhere(
      (e) => e.name == eventStr,
      orElse: () => CameraEventType.onCameraState,
    );
    return CameraEvent(
      type: type,
      deviceId: map['deviceId'] as int?,
      state: map['state'] as String?,
      message: map['message'] as String?,
      path: map['path'] as String?,
      error: map['error'] as String?,
      captureType: map['type'] as String?,
      raw: map,
    );
  }
}

/// Camera open request
class CameraRequest {
  final int previewWidth;
  final int previewHeight;
  final RenderMode renderMode;
  final PreviewFormat previewFormat;
  final RotateType rotateType;

  const CameraRequest({
    this.previewWidth = 640,
    this.previewHeight = 480,
    this.renderMode = RenderMode.opengl,
    this.previewFormat = PreviewFormat.mjpeg,
    this.rotateType = RotateType.angle0,
  });
}

/// Effect IDs matching the Android side
class EffectId {
  static const int blackWhite = 100;
  static const int soul = 200;
  static const int zoom = 300;
}

/// Effect classify IDs
class EffectClassifyId {
  static const int filter = 1;
  static const int animation = 2;
}
