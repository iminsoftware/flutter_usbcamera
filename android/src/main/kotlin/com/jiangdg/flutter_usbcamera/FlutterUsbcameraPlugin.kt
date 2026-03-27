package com.jiangdg.flutter_usbcamera

import android.app.Activity
import android.content.Context
import android.graphics.SurfaceTexture
import android.hardware.usb.UsbDevice
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec
import com.jiangdg.ausbc.MultiCameraClient
import com.jiangdg.ausbc.callback.*
import com.jiangdg.ausbc.camera.CameraUVC
import com.jiangdg.ausbc.camera.bean.CameraRequest
import com.jiangdg.ausbc.render.effect.AbstractEffect
import com.jiangdg.ausbc.render.effect.EffectBlackWhite
import com.jiangdg.ausbc.render.effect.EffectSoul
import com.jiangdg.ausbc.render.effect.EffectZoom
import com.jiangdg.ausbc.render.env.RotateType
import com.jiangdg.ausbc.widget.AspectRatioTextureView
import com.jiangdg.ausbc.widget.IAspectRatio
import com.jiangdg.usb.USBMonitor

class FlutterUsbcameraPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null
    private var activity: Activity? = null

    private var mCameraClient: MultiCameraClient? = null
    private var mCurrentCamera: CameraUVC? = null
    private val mCameraMap = hashMapOf<Int, CameraUVC>()
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // The PlatformView that holds the real Android TextureView
    private var mCameraView: AspectRatioTextureView? = null
    private var mCameraViewContainer: FrameLayout? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        flutterPluginBinding = binding
        channel = MethodChannel(binding.binaryMessenger, "flutter_usbcamera")
        channel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "flutter_usbcamera/events")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        // Register PlatformView factory
        binding.platformViewRegistry.registerViewFactory(
            "flutter_usbcamera/cameraview",
            UsbCameraViewFactory(this)
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        flutterPluginBinding = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }
    override fun onDetachedFromActivity() {
        closeAllCameras()
        activity = null
    }

    // Called by PlatformView when created
    internal fun onCameraViewCreated(container: FrameLayout, cameraView: AspectRatioTextureView) {
        mCameraViewContainer = container
        mCameraView = cameraView
    }

    internal fun getActivity(): Activity? = activity

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${Build.VERSION.RELEASE}")
            "registerUsb" -> registerUsb(result)
            "unregisterUsb" -> unregisterUsb(result)
            "getDeviceList" -> getDeviceList(result)
            "hasPermission" -> hasPermission(call, result)
            "requestPermission" -> requestPermission(call, result)
            "openCamera" -> openCamera(call, result)
            "closeCamera" -> closeCamera(call, result)
            "captureImage" -> captureImage(call, result)
            "captureVideoStart" -> captureVideoStart(call, result)
            "captureVideoStop" -> captureVideoStop(call, result)
            "captureAudioStart" -> captureAudioStart(call, result)
            "captureAudioStop" -> captureAudioStop(call, result)
            "captureStreamStart" -> result.success(true)
            "captureStreamStop" -> result.success(true)
            "startPlayMic" -> startPlayMic(call, result)
            "stopPlayMic" -> stopPlayMic(call, result)
            "getAllPreviewSizes" -> getAllPreviewSizes(call, result)
            "updateResolution" -> updateResolution(call, result)
            "setRotateType" -> setRotateType(call, result)
            "setAutoFocus" -> { mCurrentCamera?.setAutoFocus(call.argument<Boolean>("enable") ?: true); result.success(true) }
            "setAutoWhiteBalance" -> { mCurrentCamera?.setAutoWhiteBalance(call.argument<Boolean>("enable") ?: true); result.success(true) }
            "setBrightness" -> { mCurrentCamera?.setBrightness(call.argument<Int>("value") ?: 0); result.success(true) }
            "setContrast" -> { mCurrentCamera?.setContrast(call.argument<Int>("value") ?: 0); result.success(true) }
            "setZoom" -> { mCurrentCamera?.setZoom(call.argument<Int>("value") ?: 0); result.success(true) }
            "setGain" -> { mCurrentCamera?.setGain(call.argument<Int>("value") ?: 0); result.success(true) }
            "setGamma" -> { mCurrentCamera?.setGamma(call.argument<Int>("value") ?: 0); result.success(true) }
            "setSharpness" -> { mCurrentCamera?.setSharpness(call.argument<Int>("value") ?: 0); result.success(true) }
            "setSaturation" -> { mCurrentCamera?.setSaturation(call.argument<Int>("value") ?: 0); result.success(true) }
            "setHue" -> { mCurrentCamera?.setHue(call.argument<Int>("value") ?: 0); result.success(true) }
            "getBrightness" -> result.success(mCurrentCamera?.getBrightness())
            "getContrast" -> result.success(mCurrentCamera?.getContrast())
            "getZoom" -> result.success(mCurrentCamera?.getZoom())
            "getGain" -> result.success(mCurrentCamera?.getGain())
            "getGamma" -> result.success(mCurrentCamera?.getGamma())
            "getSharpness" -> result.success(mCurrentCamera?.getSharpness())
            "getSaturation" -> result.success(mCurrentCamera?.getSaturation())
            "getHue" -> result.success(mCurrentCamera?.getHue())
            "isCameraOpened" -> result.success(mCurrentCamera?.isCameraOpened() ?: false)
            "isRecording" -> result.success(mCurrentCamera?.isRecording() ?: false)
            "sendCameraCommand" -> { mCurrentCamera?.sendCameraCommand(call.argument<Int>("command") ?: 0); result.success(null) }
            "addRenderEffect" -> addRenderEffect(call, result)
            "removeRenderEffect" -> removeRenderEffect(call, result)
            "updateRenderEffect" -> updateRenderEffect(call, result)
            else -> result.notImplemented()
        }
    }

    private fun sendEvent(event: Map<String, Any?>) {
        mainHandler.post { eventSink?.success(event) }
    }

    private fun registerUsb(result: Result) {
        val ctx = activity ?: run { result.error("NO_ACTIVITY", "Activity not available", null); return }
        mCameraClient = MultiCameraClient(ctx, object : IDeviceConnectCallBack {
            override fun onAttachDev(device: UsbDevice?) {
                device ?: return
                if (!mCameraMap.containsKey(device.deviceId)) {
                    mCameraMap[device.deviceId] = CameraUVC(ctx, device)
                }
                sendEvent(mapOf(
                    "event" to "onAttachDev",
                    "deviceId" to device.deviceId,
                    "deviceName" to device.deviceName,
                    "vendorId" to device.vendorId,
                    "productId" to device.productId,
                    "productName" to (device.productName ?: "")
                ))
            }
            override fun onDetachDec(device: UsbDevice?) {
                device ?: return
                mCameraMap.remove(device.deviceId)?.setUsbControlBlock(null)
                if (mCurrentCamera?.getUsbDevice()?.deviceId == device.deviceId) {
                    mCurrentCamera = null
                }
                sendEvent(mapOf("event" to "onDetachDev", "deviceId" to device.deviceId))
            }
            override fun onConnectDev(device: UsbDevice?, ctrlBlock: USBMonitor.UsbControlBlock?) {
                device ?: return; ctrlBlock ?: return
                mCameraMap[device.deviceId]?.setUsbControlBlock(ctrlBlock)
                sendEvent(mapOf("event" to "onConnectDev", "deviceId" to device.deviceId))
            }
            override fun onDisConnectDec(device: UsbDevice?, ctrlBlock: USBMonitor.UsbControlBlock?) {
                device ?: return
                mCameraMap[device.deviceId]?.closeCamera()
                if (mCurrentCamera?.getUsbDevice()?.deviceId == device.deviceId) {
                    mCurrentCamera = null
                }
                sendEvent(mapOf("event" to "onDisConnectDev", "deviceId" to device.deviceId))
            }
            override fun onCancelDev(device: UsbDevice?) {
                device ?: return
                sendEvent(mapOf("event" to "onCancelDev", "deviceId" to device.deviceId))
            }
        })
        mCameraClient?.register()
        result.success(true)
    }

    private fun unregisterUsb(result: Result) {
        closeAllCameras()
        mCameraClient?.unRegister()
        mCameraClient?.destroy()
        mCameraClient = null
        mCameraMap.clear()
        result.success(true)
    }

    private fun getDeviceList(result: Result) {
        val list = mCameraMap.values.map { camera ->
            val dev = camera.getUsbDevice()
            mapOf(
                "deviceId" to dev.deviceId,
                "deviceName" to dev.deviceName,
                "vendorId" to dev.vendorId,
                "productId" to dev.productId,
                "productName" to (dev.productName ?: "")
            )
        }
        result.success(list)
    }

    private fun hasPermission(call: MethodCall, result: Result) {
        val deviceId = call.argument<Int>("deviceId") ?: run {
            result.error("INVALID_ARG", "deviceId required", null); return
        }
        result.success(mCameraClient?.hasPermission(mCameraMap[deviceId]?.getUsbDevice()) ?: false)
    }

    private fun requestPermission(call: MethodCall, result: Result) {
        val deviceId = call.argument<Int>("deviceId") ?: run {
            result.error("INVALID_ARG", "deviceId required", null); return
        }
        result.success(mCameraClient?.requestPermission(mCameraMap[deviceId]?.getUsbDevice()) ?: false)
    }

    // === Key change: openCamera now uses the real Android TextureView (PlatformView) ===
    // This is exactly how the Android project does it — CameraFragment provides a TextureView,
    // AUSBC renders to it with full OpenGL pipeline support.
    private fun openCamera(call: MethodCall, result: Result) {
        val deviceId = call.argument<Int>("deviceId") ?: run {
            result.error("INVALID_ARG", "deviceId required", null); return
        }
        val previewWidth = call.argument<Int>("previewWidth") ?: 640
        val previewHeight = call.argument<Int>("previewHeight") ?: 480
        val renderMode = call.argument<String>("renderMode") ?: "opengl"
        val previewFormat = call.argument<String>("previewFormat") ?: "mjpeg"
        val rotateAngle = call.argument<Int>("rotateAngle") ?: 0

        val camera = mCameraMap[deviceId] ?: run {
            result.error("NOT_FOUND", "Camera not found for deviceId $deviceId", null); return
        }

        val cameraView = mCameraView ?: run {
            result.error("NO_VIEW", "Camera view not ready. Add UsbCameraPreview widget first.", null); return
        }

        val cameraRequest = CameraRequest.Builder()
            .setPreviewWidth(previewWidth)
            .setPreviewHeight(previewHeight)
            .setRenderMode(
                if (renderMode == "normal") CameraRequest.RenderMode.NORMAL
                else CameraRequest.RenderMode.OPENGL
            )
            .setDefaultRotateType(
                when (rotateAngle) {
                    90 -> RotateType.ANGLE_90
                    180 -> RotateType.ANGLE_180
                    270 -> RotateType.ANGLE_270
                    else -> RotateType.ANGLE_0
                }
            )
            .setAudioSource(CameraRequest.AudioSource.SOURCE_AUTO)
            .setPreviewFormat(
                if (previewFormat == "yuyv") CameraRequest.PreviewFormat.FORMAT_YUYV
                else CameraRequest.PreviewFormat.FORMAT_MJPEG
            )
            .setAspectRatioShow(true)
            .setCaptureRawImage(false)
            .setRawPreviewData(false)
            .create()

        camera.setCameraStateCallBack(object : ICameraStateCallBack {
            override fun onCameraState(
                self: MultiCameraClient.ICamera,
                code: ICameraStateCallBack.State,
                msg: String?
            ) {
                val stateStr = when (code) {
                    ICameraStateCallBack.State.OPENED -> "opened"
                    ICameraStateCallBack.State.CLOSED -> "closed"
                    ICameraStateCallBack.State.ERROR -> "error"
                }
                sendEvent(mapOf(
                    "event" to "onCameraState",
                    "deviceId" to deviceId,
                    "state" to stateStr,
                    "message" to (msg ?: "")
                ))
            }
        })

        // Pass the real Android TextureView — exactly like CameraFragment does
        camera.openCamera(cameraView, cameraRequest)
        mCurrentCamera = camera
        result.success(mapOf("textureId" to 0))
    }

    private fun closeCamera(call: MethodCall, result: Result) {
        val deviceId = call.argument<Int>("deviceId")
        if (deviceId != null) {
            mCameraMap[deviceId]?.closeCamera()
            if (mCurrentCamera?.getUsbDevice()?.deviceId == deviceId) {
                mCurrentCamera = null
            }
        } else {
            mCurrentCamera?.closeCamera()
            mCurrentCamera = null
        }
        result.success(true)
    }

    private fun captureImage(call: MethodCall, result: Result) {
        val path = call.argument<String>("path")
        mCurrentCamera?.captureImage(object : ICaptureCallBack {
            override fun onBegin() { sendEvent(mapOf("event" to "onCaptureBegin", "type" to "image")) }
            override fun onError(error: String?) { sendEvent(mapOf("event" to "onCaptureError", "type" to "image", "error" to (error ?: ""))) }
            override fun onComplete(path: String?) { sendEvent(mapOf("event" to "onCaptureComplete", "type" to "image", "path" to (path ?: ""))) }
        }, path) ?: run { result.error("NO_CAMERA", "No camera opened", null); return }
        result.success(true)
    }

    private fun captureVideoStart(call: MethodCall, result: Result) {
        val path = call.argument<String>("path")
        val duration = call.argument<Int>("durationInSec")?.toLong() ?: 0L
        mCurrentCamera?.captureVideoStart(object : ICaptureCallBack {
            override fun onBegin() { sendEvent(mapOf("event" to "onCaptureBegin", "type" to "video")) }
            override fun onError(error: String?) { sendEvent(mapOf("event" to "onCaptureError", "type" to "video", "error" to (error ?: ""))) }
            override fun onComplete(path: String?) { sendEvent(mapOf("event" to "onCaptureComplete", "type" to "video", "path" to (path ?: ""))) }
        }, path, duration) ?: run { result.error("NO_CAMERA", "No camera opened", null); return }
        result.success(true)
    }

    private fun captureVideoStop(call: MethodCall, result: Result) {
        mCurrentCamera?.captureVideoStop()
        result.success(true)
    }

    private fun captureAudioStart(call: MethodCall, result: Result) {
        val path = call.argument<String>("path")
        mCurrentCamera?.captureAudioStart(object : ICaptureCallBack {
            override fun onBegin() { sendEvent(mapOf("event" to "onCaptureBegin", "type" to "audio")) }
            override fun onError(error: String?) { sendEvent(mapOf("event" to "onCaptureError", "type" to "audio", "error" to (error ?: ""))) }
            override fun onComplete(path: String?) { sendEvent(mapOf("event" to "onCaptureComplete", "type" to "audio", "path" to (path ?: ""))) }
        }, path) ?: run { result.error("NO_CAMERA", "No camera opened", null); return }
        result.success(true)
    }

    private fun captureAudioStop(call: MethodCall, result: Result) {
        mCurrentCamera?.captureAudioStop()
        result.success(true)
    }

    private fun startPlayMic(call: MethodCall, result: Result) {
        mCurrentCamera?.startPlayMic(object : IPlayCallBack {
            override fun onBegin() { sendEvent(mapOf("event" to "onPlayMicBegin")) }
            override fun onError(error: String) { sendEvent(mapOf("event" to "onPlayMicError", "error" to error)) }
            override fun onComplete() { sendEvent(mapOf("event" to "onPlayMicComplete")) }
        })
        result.success(true)
    }

    private fun stopPlayMic(call: MethodCall, result: Result) {
        mCurrentCamera?.stopPlayMic()
        result.success(true)
    }

    private fun getAllPreviewSizes(call: MethodCall, result: Result) {
        val sizes = mCurrentCamera?.getAllPreviewSizes()?.map {
            mapOf("width" to it.width, "height" to it.height)
        } ?: emptyList()
        result.success(sizes)
    }

    private fun updateResolution(call: MethodCall, result: Result) {
        val width = call.argument<Int>("width") ?: run { result.error("INVALID_ARG", "width required", null); return }
        val height = call.argument<Int>("height") ?: run { result.error("INVALID_ARG", "height required", null); return }
        mCurrentCamera?.updateResolution(width, height)
        result.success(true)
    }

    private fun setRotateType(call: MethodCall, result: Result) {
        val angle = call.argument<Int>("angle") ?: 0
        mCurrentCamera?.setRotateType(when (angle) {
            90 -> RotateType.ANGLE_90; 180 -> RotateType.ANGLE_180; 270 -> RotateType.ANGLE_270; else -> RotateType.ANGLE_0
        })
        result.success(true)
    }

    private fun addRenderEffect(call: MethodCall, result: Result) {
        val effectId = call.argument<Int>("effectId") ?: run { result.error("INVALID_ARG", "effectId required", null); return }
        val ctx = activity ?: run { result.error("NO_ACTIVITY", "Activity not available", null); return }
        getEffectById(ctx, effectId)?.let { mCurrentCamera?.addRenderEffect(it); result.success(true) }
            ?: result.error("NOT_FOUND", "Effect not found", null)
    }

    private fun removeRenderEffect(call: MethodCall, result: Result) {
        val effectId = call.argument<Int>("effectId") ?: run { result.error("INVALID_ARG", "effectId required", null); return }
        val ctx = activity ?: run { result.error("NO_ACTIVITY", "Activity not available", null); return }
        getEffectById(ctx, effectId)?.let { mCurrentCamera?.removeRenderEffect(it); result.success(true) }
            ?: result.error("NOT_FOUND", "Effect not found", null)
    }

    private fun updateRenderEffect(call: MethodCall, result: Result) {
        val classifyId = call.argument<Int>("classifyId") ?: run { result.error("INVALID_ARG", "classifyId required", null); return }
        val effectId = call.argument<Int>("effectId")
        val ctx = activity ?: run { result.error("NO_ACTIVITY", "Activity not available", null); return }
        val effect = if (effectId != null) getEffectById(ctx, effectId) else null
        mCurrentCamera?.updateRenderEffect(classifyId, effect)
        result.success(true)
    }

    private fun getEffectById(ctx: Context, effectId: Int): AbstractEffect? = when (effectId) {
        EffectBlackWhite.ID -> EffectBlackWhite(ctx)
        EffectZoom.ID -> EffectZoom(ctx)
        EffectSoul.ID -> EffectSoul(ctx)
        else -> null
    }

    private fun closeAllCameras() {
        mCurrentCamera?.closeCamera()
        mCurrentCamera = null
        mCameraMap.values.forEach { it.closeCamera() }
    }
}


// PlatformView factory — creates the real Android TextureView for camera preview
class UsbCameraViewFactory(private val plugin: FlutterUsbcameraPlugin) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return UsbCameraPlatformView(context, plugin)
    }
}

// PlatformView — wraps AspectRatioTextureView, exactly like CameraFragment does
class UsbCameraPlatformView(
    context: Context,
    private val plugin: FlutterUsbcameraPlugin
) : PlatformView {
    private val container: FrameLayout = FrameLayout(context)
    private val cameraView: AspectRatioTextureView = AspectRatioTextureView(context)

    init {
        container.setBackgroundColor(android.graphics.Color.BLACK)
        container.addView(cameraView, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT,
            Gravity.CENTER
        ))
        plugin.onCameraViewCreated(container, cameraView)
    }

    override fun getView(): View = container

    override fun dispose() {
        // View cleanup handled by Flutter
    }
}
