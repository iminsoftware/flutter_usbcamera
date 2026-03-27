import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'flutter_usbcamera_method_channel.dart';

abstract class FlutterUsbcameraPlatform extends PlatformInterface {
  FlutterUsbcameraPlatform() : super(token: _token);
  static final Object _token = Object();
  static FlutterUsbcameraPlatform _instance = MethodChannelFlutterUsbcamera();
  static FlutterUsbcameraPlatform get instance => _instance;
  static set instance(FlutterUsbcameraPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }
}
