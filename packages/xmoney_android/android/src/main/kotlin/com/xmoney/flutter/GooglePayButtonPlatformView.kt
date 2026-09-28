package com.xmoney.flutter

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import androidx.activity.compose.LocalActivityResultRegistryOwner
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.compose.ui.unit.dp
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.lifecycleScope
import com.xmoney.googlepay.GooglePayButton
import com.xmoney.googlepay.GooglePayController
import com.xmoney.googlepay.GooglePayEvent
import com.xmoney.googlepay.rememberGooglePay
import com.xmoney.payments.config.PaymentConfig
import com.xmoney.payments.model.PaymentError
import com.xmoney.payments.model.PaymentIntent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

internal class GooglePayButtonPlatformView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    private val activityProvider: () -> FragmentActivity?,
    params: Map<String, Any?>,
) : PlatformView, MethodChannel.MethodCallHandler {
    private val frame = FrameLayout(context)
    private val composeView = ComposeView(context)
    private val buttonChannel =
        MethodChannel(messenger, "xmoney/google_pay_button/$viewId")
    private var configurationMap =
        params["configuration"] as? Map<String, Any?> ?: emptyMap()
    private var orderPayload = params["orderPayload"] as? String ?: ""
    private var orderChecksum = params["orderChecksum"] as? String ?: ""
    private var appearanceMap = params["appearance"] as? Map<String, Any?>
    private var isEnabled = params["isEnabled"] as? Boolean ?: true
    private var prepared by mutableStateOf<Pair<PaymentConfig, PaymentIntent>?>(null)
    private var controllerRef: GooglePayController? = null
    private var disabledState by mutableStateOf(false)
    private var lastAvailability: String? = null
    private var boundActivity: FragmentActivity? = null
    private val activityListener: () -> Unit = {
        val next = activityProvider()
        if (next != null && next !== boundActivity) {
            bindContent()
        }
    }

    init {
        buttonChannel.setMethodCallHandler(this)
        composeView.setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed)
        frame.addView(composeView)
        HostActivity.addListener(activityListener)
        bindContent()
    }

    private fun bindContent() {
        val hostActivity = activityProvider() ?: return
        boundActivity = hostActivity
        val (config, intent) = try {
            BridgeConfigParser.parse(configurationMap, orderPayload, orderChecksum)
        } catch (error: Exception) {
            emitResult(BridgeResults.failedMap("LOAD_ERROR", "Failed to load"))
            return
        }
        prepared = config to intent
        disabledState = !isEnabled
        composeView.setContent {
            val current = prepared ?: return@setContent
            androidx.compose.runtime.CompositionLocalProvider(
                LocalActivityResultRegistryOwner provides hostActivity,
            ) {
                val controller = rememberGooglePay(current.first) { result ->
                    emitResult(BridgeResults.resultToMap(result))
                    emitAvailability()
                }
                LaunchedEffect(controller) {
                    controllerRef = controller
                    emitEvent(mapOf("type" to "onReady"))
                    emitAvailability()
                }
                GooglePayButton(
                    controller = controller,
                    intent = current.second,
                    modifier = Modifier.fillMaxWidth().height(48.dp),
                    onEvent = { event ->
                        when (event) {
                            GooglePayEvent.Ready -> emitEvent(mapOf("type" to "onReady"))
                            is GooglePayEvent.Processing -> emitEvent(
                                mapOf(
                                    "type" to "onProcessing",
                                    "isProcessing" to event.isProcessing,
                                ),
                            )
                        }
                        emitAvailability()
                    },
                )
            }
        }
        composeView.alpha = if (disabledState) 0.4f else 1f
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "updateOrder" -> {
                @Suppress("UNCHECKED_CAST")
                val args = call.arguments as? Map<String, Any?>
                orderPayload = args?.get("orderPayload") as? String ?: orderPayload
                orderChecksum = args?.get("orderChecksum") as? String ?: orderChecksum
                updateOrder(result)
            }
            "updateAppearance" -> {
                @Suppress("UNCHECKED_CAST")
                val map = call.arguments as? Map<String, Any?>
                appearanceMap = map
                controllerRef?.updateAppearance(BridgeConfigParser.parseWalletAppearance(map))
                result.success(null)
            }
            "updateProps" -> {
                @Suppress("UNCHECKED_CAST")
                val args = call.arguments as? Map<String, Any?>
                configurationMap = args?.get("configuration") as? Map<String, Any?> ?: configurationMap
                orderPayload = args?.get("orderPayload") as? String ?: orderPayload
                orderChecksum = args?.get("orderChecksum") as? String ?: orderChecksum
                appearanceMap = args?.get("appearance") as? Map<String, Any?> ?: appearanceMap
                isEnabled = args?.get("isEnabled") as? Boolean ?: isEnabled
                disabledState = !isEnabled
                bindContent()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun updateOrder(result: MethodChannel.Result) {
        val controller = controllerRef
        val hostActivity = activityProvider()
        if (controller == null || hostActivity == null) {
            result.error("NOT_INITIALIZED", "Call init before present.", null)
            return
        }
        val intent = BridgeConfigParser.parseIntent(orderPayload, orderChecksum)
        hostActivity.lifecycleScope.launch {
            try {
                controller.updateOrder(intent)
                prepared = BridgeConfigParser.parse(configurationMap, orderPayload, orderChecksum)
                emitAvailability()
                result.success(null)
            } catch (error: CancellationException) {
                result.error("SUPERSEDED_UPDATE_ORDER", "Superseded by a newer updateOrder call", null)
            } catch (error: Exception) {
                val code = if (error is PaymentError) error.code else "PRESENT_ERROR"
                val message =
                    if (error is PaymentError) error.merchantMessage() else "Failed to present"
                result.error(code, message, null)
            }
        }
    }

    private fun emitAvailability() {
        val controller = controllerRef
        val body = mapOf(
            "type" to "onAvailability",
            "isAvailable" to (controller?.isAvailable ?: false),
            "isReady" to (controller?.isReady ?: false),
            "isOrderConsumed" to (controller?.isOrderConsumed ?: false),
            "isInteractionEnabled" to ((controller?.isInteractionEnabled ?: true) && !disabledState),
        )
        val key = body.toString()
        if (key == lastAvailability) return
        lastAvailability = key
        emitEvent(body)
    }

    private fun emitEvent(body: Map<String, Any?>) {
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            buttonChannel.invokeMethod("onEvent", mapOf("event" to BridgeJson.fromMap(body)))
        }
    }

    private fun emitResult(body: Map<String, Any?>) {
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            buttonChannel.invokeMethod("onResult", mapOf("result" to BridgeJson.fromMap(body)))
        }
    }

    override fun getView(): View = frame

    override fun dispose() {
        HostActivity.removeListener(activityListener)
        buttonChannel.setMethodCallHandler(null)
    }
}
