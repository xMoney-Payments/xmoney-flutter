package com.xmoney.flutter

import androidx.fragment.app.FragmentActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.common.StandardMethodCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.util.concurrent.CopyOnWriteArrayList

internal object HostActivity {
    private val listeners = CopyOnWriteArrayList<() -> Unit>()

    @Volatile
    var activity: FragmentActivity? = null
        private set

    fun update(next: FragmentActivity?) {
        activity = next
        listeners.forEach { it() }
    }

    fun addListener(listener: () -> Unit) {
        listeners.add(listener)
    }

    fun removeListener(listener: () -> Unit) {
        listeners.remove(listener)
    }
}

class XMoneyPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var hostChannel: MethodChannel
    private lateinit var flutterChannel: MethodChannel
    private lateinit var chvChannel: MethodChannel
    private val sheetHolder = PaymentSheetHolder()
    private val googlePayHolder = GooglePayHolder()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        hostChannel = MethodChannel(binding.binaryMessenger, "xmoney/host")
        flutterChannel = MethodChannel(binding.binaryMessenger, "xmoney/flutter")
        val chvQueue = binding.binaryMessenger.makeBackgroundTaskQueue()
        chvChannel = MethodChannel(
            binding.binaryMessenger,
            "xmoney/chv",
            StandardMethodCodec.INSTANCE,
            chvQueue,
        )
        hostChannel.setMethodCallHandler(this)
        chvChannel.setMethodCallHandler { call, result ->
            if (call.method != "answerCardHolderVerification") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            @Suppress("UNCHECKED_CAST")
            val args = call.arguments as? Map<String, Any?>
            val requestId = args?.get("requestId") as? String ?: ""
            val accepted = args?.get("accepted") as? Boolean ?: false
            CardHolderVerificationBridge.answer(requestId, accepted)
            result.success(null)
        }
        CardHolderVerificationBridge.attach(flutterChannel)

        binding.platformViewRegistry.registerViewFactory(
            "xmoney/payment_element",
            PaymentElementViewFactory(binding.binaryMessenger) { HostActivity.activity },
        )
        binding.platformViewRegistry.registerViewFactory(
            "xmoney/google_pay_button",
            GooglePayButtonViewFactory(binding.binaryMessenger) { HostActivity.activity },
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        hostChannel.setMethodCallHandler(null)
        chvChannel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initPaymentSheet" -> {
                val json = call.arguments as? String ?: ""
                XMoneyBridge.initPaymentSheet(json, sheetHolder)
                result.success(null)
            }
            "presentPaymentSheet" -> {
                val json = call.arguments as? String ?: ""
                XMoneyBridge.presentPaymentSheet(
                    HostActivity.activity,
                    json,
                    flutterChannel,
                    sheetHolder,
                    result,
                )
            }
            "dismissPaymentSheet" -> {
                XMoneyBridge.dismiss(sheetHolder)
                result.success(null)
            }
            "initApplePay" -> result.success(null)
            "presentApplePay" -> {
                result.success(
                    BridgeJson.fromMap(
                        BridgeResults.failedMap(
                            "APPLE_PAY",
                            "Apple Pay is only available on iOS.",
                        ),
                    ),
                )
            }
            "dismissApplePay" -> result.success(null)
            "getApplePayState" -> {
                result.success(
                    BridgeJson.fromMap(
                        mapOf(
                            "isAvailable" to false,
                            "isReady" to false,
                            "isOrderConsumed" to false,
                            "isInteractionEnabled" to true,
                        ),
                    ),
                )
            }
            "updateApplePayOrder" -> {
                result.error("APPLE_PAY", "Apple Pay is only available on iOS.", null)
            }
            "initGooglePay" -> {
                val json = call.arguments as? String ?: ""
                XMoneyBridge.initGooglePay(json, googlePayHolder)
                result.success(null)
            }
            "presentGooglePay" -> {
                val json = call.arguments as? String ?: ""
                XMoneyBridge.presentGooglePay(
                    HostActivity.activity,
                    json,
                    flutterChannel,
                    googlePayHolder,
                    result,
                )
            }
            "dismissGooglePay" -> {
                XMoneyBridge.dismissGooglePay(googlePayHolder)
                result.success(null)
            }
            "getGooglePayState" -> {
                val json = call.arguments as? String
                XMoneyBridge.getGooglePayState(HostActivity.activity, json, googlePayHolder, result)
            }
            "updateGooglePayOrder" -> {
                val json = call.arguments as? String ?: ""
                XMoneyBridge.updateGooglePayOrder(HostActivity.activity, json, googlePayHolder, result)
            }
            else -> result.notImplemented()
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        HostActivity.update(binding.activity as? FragmentActivity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        HostActivity.update(null)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        HostActivity.update(binding.activity as? FragmentActivity)
    }

    override fun onDetachedFromActivity() {
        HostActivity.update(null)
    }
}

private class PaymentElementViewFactory(
    private val messenger: io.flutter.plugin.common.BinaryMessenger,
    private val activityProvider: () -> FragmentActivity?,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: android.content.Context, id: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val params = args as? Map<String, Any?> ?: emptyMap()
        return PaymentElementPlatformView(
            context,
            messenger,
            id,
            activityProvider,
            params,
        )
    }
}

private class GooglePayButtonViewFactory(
    private val messenger: io.flutter.plugin.common.BinaryMessenger,
    private val activityProvider: () -> FragmentActivity?,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: android.content.Context, id: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val params = args as? Map<String, Any?> ?: emptyMap()
        return GooglePayButtonPlatformView(
            context,
            messenger,
            id,
            activityProvider,
            params,
        )
    }
}
