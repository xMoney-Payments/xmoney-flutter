package com.xmoney.flutter

import android.content.Context
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.compose.ui.unit.dp
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.lifecycleScope
import com.xmoney.googlepay.GooglePayButton
import com.xmoney.googlepay.GooglePayController
import com.xmoney.googlepay.GooglePayEvent
import com.xmoney.googlepay.rememberGooglePay
import com.xmoney.payments.config.PaymentConfig
import com.xmoney.payments.config.WalletAppearance
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
    private val frame = TouchGuardFrame(context)
    private val frameFocusability = frame.descendantFocusability
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
    private val orders = PendingOrders()
    private var disabledState by mutableStateOf(false)
    private var lastAvailability: String? = null
    private var didSendReady = false
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
        didSendReady = false
        val (config, intent) = try {
            BridgeConfigParser.parse(configurationMap, orderPayload, orderChecksum)
        } catch (error: Exception) {
            emitResult(BridgeResults.failedMap("LOAD_ERROR", "Failed to load"))
            return
        }
        prepared = config to intent
        applyDisabled()
        composeView.setContent {
            val current = prepared ?: return@setContent
            androidx.compose.runtime.CompositionLocalProvider(
                LocalContext provides hostActivity,
                LocalActivityResultRegistryOwner provides hostActivity,
            ) {
                val controller = rememberGooglePay(current.first) { result ->
                    emitResult(BridgeResults.resultToMap(result))
                    emitAvailability()
                }
                LaunchedEffect(controller) {
                    controllerRef = controller
                    appearanceMap?.let {
                        controller.updateAppearance(BridgeConfigParser.parseWalletAppearance(it))
                    }
                }
                GooglePayButton(
                    controller = controller,
                    intent = current.second,
                    modifier = Modifier.fillMaxWidth().height(48.dp),
                    onEvent = { event ->
                        when (event) {
                            GooglePayEvent.Ready -> {
                                didSendReady = true
                                emitAvailability()
                                emitEvent(mapOf("type" to "onReady"))
                            }
                            is GooglePayEvent.Processing -> {
                                emitEvent(
                                    mapOf(
                                        "type" to "onProcessing",
                                        "isProcessing" to event.isProcessing,
                                    ),
                                )
                                emitAvailability()
                            }
                            is GooglePayEvent.UpdateFailed -> {
                                emitEvent(
                                    mapOf(
                                        "type" to "onUpdateFailed",
                                        "code" to event.error.code,
                                        "message" to event.error.merchantMessage(),
                                    ),
                                )
                                emitAvailability()
                            }
                        }
                    },
                )
            }
        }
    }

    private fun applyDisabled() {
        disabledState = !isEnabled
        frame.swallowTouches = disabledState
        composeView.alpha = if (disabledState) 0.4f else 1f
        if (disabledState) {
            frame.descendantFocusability = ViewGroup.FOCUS_BLOCK_DESCENDANTS
            if (composeView.hasFocus()) composeView.clearFocus()
            composeView.importantForAccessibility =
                View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
        } else {
            frame.descendantFocusability = frameFocusability
            composeView.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_AUTO
        }
    }

    /// Widget appearance wins. Otherwise keep the style from the configuration,
    /// which [rememberGooglePay] already applied at mount.
    private fun walletAppearance(): WalletAppearance? =
        appearanceMap?.let { BridgeConfigParser.parseWalletAppearance(it) }
            ?: prepared?.first?.paymentMethods?.googlePay?.appearance

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "updateOrder" -> {
                @Suppress("UNCHECKED_CAST")
                val args = call.arguments as? Map<String, Any?>
                orderPayload = args?.get("orderPayload") as? String ?: orderPayload
                orderChecksum = args?.get("orderChecksum") as? String ?: orderChecksum
                updateOrder(result)
            }
            "beginUpdateOrder" -> beginUpdateOrder(requestId(call), result)
            "resolveOrder" -> {
                val requestId = requestId(call)
                val args = call.arguments as? Map<*, *>
                orders.settle(
                    requestId,
                    BridgeConfigParser.parseIntent(
                        args?.get("orderPayload") as? String ?: "",
                        args?.get("orderChecksum") as? String ?: "",
                    ),
                )
                result.success(null)
            }
            "rejectOrder" -> {
                orders.settleRejected(requestId(call))
                result.success(null)
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
                @Suppress("UNCHECKED_CAST")
                val nextConfiguration =
                    args?.get("configuration") as? Map<String, Any?> ?: configurationMap
                val configurationChanged = nextConfiguration != configurationMap
                configurationMap = nextConfiguration
                orderPayload = args?.get("orderPayload") as? String ?: orderPayload
                orderChecksum = args?.get("orderChecksum") as? String ?: orderChecksum
                appearanceMap = args?.get("appearance") as? Map<String, Any?> ?: appearanceMap
                isEnabled = args?.get("isEnabled") as? Boolean ?: isEnabled
                if (configurationChanged) {
                    bindContent()
                } else {
                    applyDisabled()
                    walletAppearance()?.let { controllerRef?.updateAppearance(it) }
                    emitAvailability()
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun requestId(call: MethodCall): String {
        return (call.arguments as? Map<*, *>)?.get("requestId") as? String ?: ""
    }

    /// Locks the wallet button, then waits for Dart to resolve or reject the order.
    private fun beginUpdateOrder(requestId: String, result: MethodChannel.Result) {
        val deferred = orders.gate(requestId)
        val controller = controllerRef
        val hostActivity = activityProvider()
        if (deferred == null || controller == null || hostActivity == null) {
            orders.close(requestId)
            result.error("NOT_INITIALIZED", "Call init before present.", null)
            return
        }
        hostActivity.lifecycleScope.launch {
            try {
                val bound = controller.updateOrder {
                    emitAvailability()
                    deferred.await()
                }
                val nextPayload = bound.orderPayload
                val nextChecksum = bound.orderChecksum
                val next = BridgeConfigParser.parse(
                    configurationMap,
                    nextPayload,
                    nextChecksum,
                )
                orderPayload = nextPayload
                orderChecksum = nextChecksum
                prepared = next
                emitAvailability()
                result.success(null)
            } catch (_: OrderCreationRejected) {
                if (!didSendReady) rebindMountOrder(controller, hostActivity)
                result.error("ORDER_CREATION_FAILED", "Order creation failed", null)
            } catch (_: CancellationException) {
                result.error(
                    "SUPERSEDED_UPDATE_ORDER",
                    "Superseded by a newer updateOrder call",
                    null,
                )
            } catch (error: PaymentError.PaymentInProgress) {
                result.error("PAYMENT_IN_PROGRESS", error.merchantMessage(), null)
            } catch (error: PaymentError) {
                result.error(error.code, error.merchantMessage(), null)
            } catch (_: Exception) {
                result.error("PRESENT_ERROR", "Failed to present", null)
            } finally {
                orders.close(requestId)
            }
        }
    }

    /// The first bind was cancelled before Ready. Bind the mount order again so
    /// the button can draw. A failed first bind is reported by the controller.
    private fun rebindMountOrder(
        controller: GooglePayController,
        hostActivity: FragmentActivity,
    ) {
        hostActivity.lifecycleScope.launch {
            try {
                controller.updateOrder(
                    BridgeConfigParser.parseIntent(orderPayload, orderChecksum),
                )
            } catch (error: CancellationException) {
                throw error
            } catch (_: Exception) {
                // The native controller reports a failed first bind.
            }
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
            } catch (error: PaymentError.PaymentInProgress) {
                result.error("PAYMENT_IN_PROGRESS", error.merchantMessage(), null)
            } catch (error: PaymentError) {
                result.error(error.code, error.merchantMessage(), null)
            } catch (error: Exception) {
                result.error("PRESENT_ERROR", "Failed to present", null)
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
        orders.cancelAll()
        HostActivity.removeListener(activityListener)
        buttonChannel.setMethodCallHandler(null)
    }
}

/** Swallows touches while the merchant has disabled the button. */
private class TouchGuardFrame(context: Context) : FrameLayout(context) {
    var swallowTouches = false

    override fun onInterceptTouchEvent(ev: MotionEvent): Boolean {
        return swallowTouches || super.onInterceptTouchEvent(ev)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        return if (swallowTouches) true else super.onTouchEvent(event)
    }
}
