import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Widget to display UVC camera preview using Android PlatformView.
/// Uses Hybrid Composition to properly support OpenGL rendering.
class UsbCameraPreview extends StatefulWidget {
  final double? width;
  final double? height;
  final Widget? placeholder;

  const UsbCameraPreview({
    super.key,
    this.width,
    this.height,
    this.placeholder,
  });

  @override
  State<UsbCameraPreview> createState() => _UsbCameraPreviewState();
}

class _UsbCameraPreviewState extends State<UsbCameraPreview> {
  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return widget.placeholder ?? _buildPlaceholder();
    }
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: PlatformViewLink(
        viewType: 'flutter_usbcamera/cameraview',
        surfaceFactory: (context, controller) {
          return AndroidViewSurface(
            controller: controller as AndroidViewController,
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          );
        },
        onCreatePlatformView: (PlatformViewCreationParams params) {
          final controller = PlatformViewsService.initSurfaceAndroidView(
            id: params.id,
            viewType: 'flutter_usbcamera/cameraview',
            layoutDirection: TextDirection.ltr,
          );
          controller.addOnPlatformViewCreatedListener(params.onPlatformViewCreated);
          controller.create();
          return controller;
        },
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.black,
      child: const Center(
        child: Icon(Icons.videocam_off, color: Colors.white54, size: 48),
      ),
    );
  }
}
