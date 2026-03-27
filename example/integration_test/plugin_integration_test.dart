import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_usbcamera/flutter_usbcamera.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('UsbCameraController can be created', (tester) async {
    final controller = UsbCameraController();
    expect(controller.textureId, isNull);
    expect(controller.isRegistered, isFalse);
  });
}
