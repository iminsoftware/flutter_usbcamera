import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_usbcamera/flutter_usbcamera.dart';

void main() {
  test('UsbDevice fromMap', () {
    final device = UsbDevice.fromMap({
      'deviceId': 1,
      'deviceName': '/dev/bus/usb/001/002',
      'vendorId': 0x1234,
      'productId': 0x5678,
      'productName': 'Test Camera',
    });
    expect(device.deviceId, 1);
    expect(device.vendorId, 0x1234);
    expect(device.productName, 'Test Camera');
  });

  test('PreviewSize fromMap', () {
    final size = PreviewSize.fromMap({'width': 1920, 'height': 1080});
    expect(size.width, 1920);
    expect(size.height, 1080);
    expect(size.aspectRatio, 1920 / 1080);
  });

  test('CameraRequest defaults', () {
    const request = CameraRequest();
    expect(request.previewWidth, 640);
    expect(request.previewHeight, 480);
    expect(request.renderMode, RenderMode.opengl);
    expect(request.previewFormat, PreviewFormat.mjpeg);
  });
}
