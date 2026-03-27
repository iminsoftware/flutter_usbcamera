import 'package:flutter/services.dart';
import 'flutter_usbcamera_platform_interface.dart';

class MethodChannelFlutterUsbcamera extends FlutterUsbcameraPlatform {
  final methodChannel = const MethodChannel('flutter_usbcamera');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
