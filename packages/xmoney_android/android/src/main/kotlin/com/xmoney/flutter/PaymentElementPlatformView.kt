package com.xmoney.flutter

import android.content.Context
import android.graphics.Rect
import android.view.Choreographer
import android.view.View
import android.view.ViewTreeObserver
import android.widget.FrameLayout
import androidx.activity.compose.LocalActivityResultRegistryOwner
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.lifecycleScope
import com.xmoney.paymentelement.EmbeddedEvent
import com.xmoney.paymentelement.EmbeddedPaymentController
import com.xmoney.paymentelement.PaymentElement
import com.xmoney.paymentelement.rememberEmbeddedPayment
import com.xmoney.payments.config.AppearanceConfig
import com.xmoney.payments.config.UserInterfaceStyle
import com.xmoney.payments.model.PaymentError
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

internal class PaymentElementPlatformView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    private val activityProvider: () -> FragmentActivity?,
    params: Map<String, Any?>,
) : PlatformView, MethodChannel.MethodCallHandler {
    private val frame = FrameLayout(context)
    private val composeView = ComposeView(context)
    private var controllerRef: EmbeddedPaymentController? = null
    private var configuration: Map<String, Any?>? =
        params["configuration"] as? Map<String, Any?>
    private var orderPayload: String = params["orderPayload"] as? String ?: ""
    private var orderChecksum: String = params["orderChecksum"] as? String ?: ""
    private var prepared by mutableStateOf<Pair<com.xmoney.payments.config.PaymentConfig, com.xmoney.payments.model.PaymentIntent>?>(null)
    private val elementChannel =
        MethodChannel(messenger, "xmoney/payment_element/$viewId")
    private var lastOrderConsumed: Boolean? = null
    private var lastInteractionEnabled: Boolean? = null
    private var didSendReady = false
    private var boundActivity: FragmentActivity? = null
    private var lastKeyboardReport = ""
    private var trackingFocus = false
    private var closedOverlapPx = -1
    private val keyboardListener = ViewTreeObserver.OnGlobalLayoutListener { reportKeyboard() }
    private val focusCallback = object : Choreographer.FrameCallback {
        override fun doFrame(frameTimeNanos: Long) {
            if (!trackingFocus) return
            reportKeyboard()
            if (trackingFocus) {
                Choreographer.getInstance().postFrameCallback(this)
            }
        }
    }
    private val activityListener: () -> Unit = {
        val next = activityProvider()
        if (next != null && next !== boundActivity) {
            bindFromParams()
        }
    }

    init {
        elementChannel.setMethodCallHandler(this)
        composeView.setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed)
        frame.addView(composeView)
        frame.viewTreeObserver.addOnGlobalLayoutListener(keyboardListener)
        HostActivity.addListener(activityListener)
        bindFromParams()
    }

    private fun reportKeyboard() {
        if (!frame.isAttachedToWindow) return
        val rootHeight = frame.rootView.height
        if (rootHeight <= 0) return
        val visibleFrame = Rect()
        frame.getWindowVisibleDisplayFrame(visibleFrame)
        val overlapPx = (rootHeight - visibleFrame.bottom).coerceAtLeast(0)
        if (closedOverlapPx < 0 || overlapPx < closedOverlapPx) {
            closedOverlapPx = overlapPx
        }
        val density = frame.resources.displayMetrics.density
        if (density <= 0f) return
        val keyboardPx = overlapPx - closedOverlapPx
        if (keyboardPx < 100) {
            trackingFocus = false
            if (lastKeyboardReport.isEmpty() || lastKeyboardReport == "hidden") return
            lastKeyboardReport = "hidden"
            elementChannel.invokeMethod("onKeyboard", mapOf("visible" to false))
            return
        }
        val keyboardTop = visibleFrame.bottom / density
        val focused = frame.findFocus()
        val fieldRect = Rect()
        focused?.getFocusedRect(fieldRect)
        val loc = IntArray(2)
        val target = focused ?: frame
        target.getLocationOnScreen(loc)
        val fieldTop = if (focused != null && fieldRect.height() > 0) {
            (loc[1] + fieldRect.top) / density
        } else {
            loc[1] / density
        }
        val fieldBottom = if (focused != null && fieldRect.height() > 0) {
            (loc[1] + fieldRect.bottom) / density
        } else {
            (loc[1] + target.height) / density
        }
        val report = "${keyboardTop.toInt()}-${fieldTop.toInt()}-${fieldBottom.toInt()}"
        if (report == lastKeyboardReport) return
        lastKeyboardReport = report
        if (!trackingFocus) {
            trackingFocus = true
            Choreographer.getInstance().postFrameCallback(focusCallback)
        }
        elementChannel.invokeMethod(
            "onKeyboard",
            mapOf(
                "visible" to true,
                "keyboardTop" to keyboardTop.toDouble(),
                "fieldTop" to fieldTop.toDouble(),
                "fieldBottom" to fieldBottom.toDouble(),
            ),
        )
    }

    private fun bindFromParams() {
        val hostActivity = activityProvider() ?: return
        boundActivity = hostActivity
        didSendReady = false
        val (config, intent) = try {
            BridgeConfigParser.parse(
                configuration.orEmpty(),
                orderPayload,
                orderChecksum,
            )
        } catch (error: Exception) {
            emitResult(BridgeResults.failedMap("LOAD_ERROR", "Failed to load"))
            return
        }
        prepared = config to intent
        composeView.setContent {
            val current = prepared ?: return@setContent
            androidx.compose.runtime.CompositionLocalProvider(
                LocalActivityResultRegistryOwner provides hostActivity,
            ) {
                val controller = rememberEmbeddedPayment(current.first) { result ->
                    emitResult(BridgeResults.resultToMap(result))
                    emitAvailabilityIfChanged(controllerRef)
                }
                LaunchedEffect(controller) {
                    controllerRef = controller
                    emitAvailabilityIfChanged(controller)
                }
                PaymentElement(
                    controller = controller,
                    intent = current.second,
                    modifier = Modifier
                        .fillMaxWidth()
                        .wrapContentHeight(unbounded = true)
                        .onSizeChanged { size ->
                            if (size.height > 0) {
                                val dp = size.height / frame.resources.displayMetrics.density
                                elementChannel.invokeMethod(
                                    "onHeight",
                                    mapOf("height" to dp),
                                )
                            }
                        },
                    onEvent = { event ->
                        when (event) {
                            EmbeddedEvent.Ready -> {
                                // Ready fires when bind finishes, while the loader
                                // is still the composed child. Post twice so the
                                // form has been laid out before the skeleton hides.
                                composeView.post {
                                    composeView.post {
                                        publishReady(controller)
                                    }
                                }
                            }
                            is EmbeddedEvent.Processing -> {
                                emitEvent(
                                    mapOf(
                                        "type" to "onProcessing",
                                        "isProcessing" to event.isProcessing,
                                    ),
                                )
                                emitAvailabilityIfChanged(controller)
                            }
                        }
                    },
                )
            }
        }
    }

    private fun publishReady(controller: EmbeddedPaymentController) {
        if (didSendReady) return
        didSendReady = true
        emitEvent(mapOf("type" to "onReady"))
        emitAvailabilityIfChanged(controller)
    }

    private fun emitAvailabilityIfChanged(controller: EmbeddedPaymentController?) {
        val ref = controller ?: controllerRef ?: return
        val consumed = ref.isOrderConsumed
        val enabled = ref.isInteractionEnabled
        if (lastOrderConsumed == consumed && lastInteractionEnabled == enabled) {
            return
        }
        lastOrderConsumed = consumed
        lastInteractionEnabled = enabled
        emitEvent(
            mapOf(
                "type" to "onAvailability",
                "isOrderConsumed" to consumed,
                "isInteractionEnabled" to enabled,
            ),
        )
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "confirm" -> {
                controllerRef?.confirm()
                result.success(null)
            }
            "updateOrder" -> {
                @Suppress("UNCHECKED_CAST")
                val args = call.arguments as? Map<String, Any?>
                orderPayload = args?.get("orderPayload") as? String ?: orderPayload
                orderChecksum = args?.get("orderChecksum") as? String ?: orderChecksum
                updateOrder(result)
            }
            "updateAppearance" -> {
                @Suppress("UNCHECKED_CAST")
                val args = call.arguments as? Map<String, Any?>
                @Suppress("UNCHECKED_CAST")
                val appearance = args?.get("appearance") as? Map<String, Any?>
                controllerRef?.updateAppearance(AppearanceConfig.from(appearance))
                result.success(null)
            }
            "updateLocale" -> {
                val locale = (call.arguments as? Map<*, *>)?.get("locale") as? String
                if (locale != null) controllerRef?.updateLocale(locale)
                result.success(null)
            }
            "updateStyle" -> {
                val style = (call.arguments as? Map<*, *>)?.get("style") as? String
                if (style != null) {
                    controllerRef?.updateStyle(UserInterfaceStyle.from(style))
                }
                result.success(null)
            }
            "updateWalletAppearance" -> {
                @Suppress("UNCHECKED_CAST")
                val args = call.arguments as? Map<String, Any?>
                @Suppress("UNCHECKED_CAST")
                val google = args?.get("googlePay") as? Map<String, Any?>
                controllerRef?.updateWalletAppearance(
                    BridgeConfigParser.parseWalletAppearance(google),
                )
                result.success(null)
            }
            "updateAll" -> {
                @Suppress("UNCHECKED_CAST")
                val args = call.arguments as? Map<String, Any?>
                configuration = args?.get("configuration") as? Map<String, Any?>
                orderPayload = args?.get("orderPayload") as? String ?: orderPayload
                orderChecksum = args?.get("orderChecksum") as? String ?: orderChecksum
                lastOrderConsumed = null
                lastInteractionEnabled = null
                didSendReady = false
                bindFromParams()
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
                emitAvailabilityIfChanged(controller)
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

    private fun emitEvent(body: Map<String, Any?>) {
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            elementChannel.invokeMethod("onEvent", mapOf("event" to BridgeJson.fromMap(body)))
        }
    }

    private fun emitResult(body: Map<String, Any?>) {
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            elementChannel.invokeMethod("onResult", mapOf("result" to BridgeJson.fromMap(body)))
        }
    }

    override fun getView(): View = frame

    override fun dispose() {
        trackingFocus = false
        val observer = frame.viewTreeObserver
        if (observer.isAlive) {
            observer.removeOnGlobalLayoutListener(keyboardListener)
        }
        HostActivity.removeListener(activityListener)
        elementChannel.setMethodCallHandler(null)
    }
}
