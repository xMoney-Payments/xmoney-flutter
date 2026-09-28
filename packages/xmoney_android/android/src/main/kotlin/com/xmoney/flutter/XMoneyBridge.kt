package com.xmoney.flutter

import android.app.Activity
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.lifecycleScope
import com.xmoney.googlepay.GooglePay
import com.xmoney.googlepay.GooglePayEvent
import com.xmoney.payments.config.AppearanceConfig
import com.xmoney.payments.config.CardConfig
import com.xmoney.payments.config.CardGrouping
import com.xmoney.payments.config.CardHolderName
import com.xmoney.payments.config.CardHolderVerification
import com.xmoney.payments.config.CardInputsConfig
import com.xmoney.payments.config.GooglePayConfig
import com.xmoney.payments.config.OptionsConfig
import com.xmoney.payments.config.PaymentConfig
import com.xmoney.payments.config.PaymentMethodsConfig
import com.xmoney.payments.config.SavedCardsConfig
import com.xmoney.payments.config.SubmitButtonConfig
import com.xmoney.payments.config.SubmitButtonType
import com.xmoney.payments.config.UserInterfaceStyle
import com.xmoney.payments.config.ValidationMode
import com.xmoney.payments.config.WalletAppearance
import com.xmoney.payments.config.WalletButtonColor
import com.xmoney.payments.config.WalletButtonType
import com.xmoney.payments.model.OrderChecksum
import com.xmoney.payments.model.OrderPayload
import com.xmoney.payments.model.PaymentError
import com.xmoney.payments.model.PaymentIntent
import com.xmoney.payments.model.PaymentResult
import com.xmoney.payments.model.Transaction
import com.xmoney.payments.model.TransactionCustomer
import com.xmoney.paymentsheet.PaymentSheet
import com.xmoney.paymentsheet.PaymentSheetEvent
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import org.json.JSONObject

internal object XMoneyBridge {
    fun initPaymentSheet(json: String, sheetHolder: PaymentSheetHolder) {
        val dict = BridgeJson.toMap(json)
        sheetHolder.configuration = BridgeConfigParser.parseConfig(dict)
        sheetHolder.sheet = null
        sheetHolder.presentGeneration += 1
    }

    fun presentPaymentSheet(
        activity: Activity?,
        intentJson: String,
        flutterChannel: MethodChannel,
        sheetHolder: PaymentSheetHolder,
        result: MethodChannel.Result,
    ) {
        val dict = BridgeJson.toMap(intentJson)
        val requestId = dict["requestId"] as? String ?: ""
        val payload = dict["orderPayload"] as? String ?: ""
        val checksum = dict["orderChecksum"] as? String ?: ""
        val fragmentActivity = activity as? FragmentActivity
        if (fragmentActivity == null) {
            result.error("NO_PRESENTER", "Unable to present from the current screen.", null)
            return
        }
        val configuration = sheetHolder.configuration
        if (configuration == null) {
            result.error("NOT_INITIALIZED", "Call init before present.", null)
            return
        }
        fragmentActivity.runOnUiThread {
            try {
                val intent = BridgeConfigParser.parseIntent(payload, checksum)
                sheetHolder.sheet?.dismiss()
                val generation = ++sheetHolder.presentGeneration
                val sheet = PaymentSheet(configuration).also { sheetHolder.sheet = it }
                sheet.present(
                    activity = fragmentActivity,
                    intent = intent,
                    onEvent = { event -> emitSheetEvent(flutterChannel, event, requestId) },
                    onResult = { paymentResult ->
                        if (sheetHolder.presentGeneration == generation) {
                            sheetHolder.sheet = null
                        }
                        result.success(BridgeJson.fromMap(BridgeResults.resultToMap(paymentResult)))
                    },
                )
            } catch (error: Exception) {
                rejectNative(result, error)
            }
        }
    }

    fun dismiss(sheetHolder: PaymentSheetHolder) {
        sheetHolder.sheet?.dismiss()
    }

    fun initGooglePay(json: String, holder: GooglePayHolder) {
        val dict = BridgeJson.toMap(json)
        holder.configuration = BridgeConfigParser.parseConfig(dict)
        holder.googlePay = GooglePay(holder.configuration!!)
        holder.lastIntent = null
        holder.isAvailable = false
        holder.isReady = false
    }

    fun presentGooglePay(
        activity: Activity?,
        intentJson: String,
        flutterChannel: MethodChannel,
        holder: GooglePayHolder,
        result: MethodChannel.Result,
    ) {
        val dict = BridgeJson.toMap(intentJson)
        val requestId = dict["requestId"] as? String ?: ""
        val payload = dict["orderPayload"] as? String ?: ""
        val checksum = dict["orderChecksum"] as? String ?: ""
        val fragmentActivity = activity as? FragmentActivity
        if (fragmentActivity == null) {
            result.error("NO_PRESENTER", "Unable to present from the current screen.", null)
            return
        }
        val configuration = holder.configuration
        if (configuration == null) {
            result.error("NOT_INITIALIZED", "Call init before present.", null)
            return
        }
        fragmentActivity.runOnUiThread {
            try {
                val intent = BridgeConfigParser.parseIntent(payload, checksum)
                holder.lastIntent = intent
                holder.googlePay?.dismiss()
                val googlePay = holder.googlePay ?: GooglePay(configuration).also {
                    holder.googlePay = it
                }
                googlePay.present(
                    activity = fragmentActivity,
                    intent = intent,
                    onEvent = { event -> emitGooglePayEvent(flutterChannel, event, requestId) },
                    onResult = { paymentResult ->
                        result.success(BridgeJson.fromMap(BridgeResults.resultToMap(paymentResult)))
                    },
                )
            } catch (error: Exception) {
                rejectNative(result, error)
            }
        }
    }

    fun dismissGooglePay(holder: GooglePayHolder) {
        holder.googlePay?.dismiss()
    }

    fun updateGooglePayOrder(
        activity: Activity?,
        intentJson: String,
        holder: GooglePayHolder,
        result: MethodChannel.Result,
    ) {
        val dict = BridgeJson.toMap(intentJson)
        val payload = dict["orderPayload"] as? String ?: ""
        val checksum = dict["orderChecksum"] as? String ?: ""
        val fragmentActivity = activity as? FragmentActivity
        if (fragmentActivity == null) {
            result.error("NO_PRESENTER", "Unable to present from the current screen.", null)
            return
        }
        val googlePay = holder.googlePay
        if (googlePay == null) {
            result.error("NOT_INITIALIZED", "Call init before present.", null)
            return
        }
        val intent = BridgeConfigParser.parseIntent(payload, checksum)
        holder.lastIntent = intent
        fragmentActivity.lifecycleScope.launch {
            try {
                googlePay.updateOrder(intent)
                result.success(null)
            } catch (error: Exception) {
                rejectNative(result, error)
            }
        }
    }

    fun getGooglePayState(
        activity: Activity?,
        intentJson: String?,
        holder: GooglePayHolder,
        result: MethodChannel.Result,
    ) {
        if (intentJson != null) {
            val dict = BridgeJson.toMap(intentJson)
            val payload = dict["orderPayload"] as? String ?: ""
            val checksum = dict["orderChecksum"] as? String ?: ""
            if (payload.isNotEmpty() && checksum.isNotEmpty()) {
                holder.lastIntent = BridgeConfigParser.parseIntent(payload, checksum)
            }
        }
        val configuration = holder.configuration
        val intent = holder.lastIntent
        val fragmentActivity = activity as? FragmentActivity
        if (configuration == null || intent == null || fragmentActivity == null) {
            result.success(BridgeJson.fromMap(holder.walletStateMap()))
            return
        }
        fragmentActivity.lifecycleScope.launch {
            try {
                val flags = GooglePay(configuration).availability(fragmentActivity, intent)
                holder.isAvailable = flags.isAvailable
                holder.isReady = flags.isReady
            } catch (_: Exception) {
            }
            result.success(BridgeJson.fromMap(holder.walletStateMap()))
        }
    }

    private fun emitSheetEvent(
        channel: MethodChannel,
        event: PaymentSheetEvent,
        requestId: String,
    ) {
        val body = when (event) {
            is PaymentSheetEvent.Ready -> mapOf("type" to "onReady")
            is PaymentSheetEvent.Processing -> mapOf(
                "type" to "onProcessing",
                "isProcessing" to event.isProcessing,
            )
        }
        emitEvent(channel, requestId, body)
    }

    private fun emitGooglePayEvent(
        channel: MethodChannel,
        event: GooglePayEvent,
        requestId: String,
    ) {
        val body = when (event) {
            is GooglePayEvent.Ready -> mapOf("type" to "onReady")
            is GooglePayEvent.Processing -> mapOf(
                "type" to "onProcessing",
                "isProcessing" to event.isProcessing,
            )
        }
        emitEvent(channel, requestId, body)
    }

    private fun emitEvent(
        channel: MethodChannel,
        requestId: String,
        body: Map<String, Any?>,
    ) {
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            channel.invokeMethod(
                "onNativeEvent",
                mapOf(
                    "requestId" to requestId,
                    "eventJson" to BridgeJson.fromMap(body),
                ),
            )
        }
    }

    private fun rejectNative(result: MethodChannel.Result, error: Throwable) {
        when (error) {
            is CancellationException ->
                result.error(
                    "SUPERSEDED_UPDATE_ORDER",
                    "Superseded by a newer updateOrder call",
                    null,
                )
            is PaymentError -> result.error(error.code, error.merchantMessage(), null)
            is IllegalStateException ->
                result.error("GOOGLE_PAY", error.message ?: "Google Pay is not presented", null)
            else -> result.error("PRESENT_ERROR", "Failed to present", null)
        }
    }
}

internal class PaymentSheetHolder {
    var configuration: PaymentConfig? = null
    var sheet: PaymentSheet? = null
    var presentGeneration = 0
}

internal class GooglePayHolder {
    var configuration: PaymentConfig? = null
    var googlePay: GooglePay? = null
    var lastIntent: PaymentIntent? = null
    var isAvailable: Boolean = false
    var isReady: Boolean = false
    var isOrderConsumed: Boolean = false
    var isInteractionEnabled: Boolean = true

    fun walletStateMap(): Map<String, Any?> = mapOf(
        "isAvailable" to isAvailable,
        "isReady" to isReady,
        "isOrderConsumed" to isOrderConsumed,
        "isInteractionEnabled" to isInteractionEnabled,
    )
}

internal object BridgeResults {
    fun resultToMap(result: PaymentResult): Map<String, Any?> = when (result) {
        is PaymentResult.Complete -> mapOf(
            "status" to "complete",
            "transaction" to transactionToMap(result.transaction),
        )
        is PaymentResult.Failed -> mapOf(
            "status" to "failed",
            "error" to mapOf(
                "code" to result.error.code,
                "message" to result.error.merchantMessage(),
            ),
        )
        is PaymentResult.Canceled -> mapOf("status" to "canceled")
    }

    fun failedMap(code: String, message: String): Map<String, Any?> = mapOf(
        "status" to "failed",
        "error" to mapOf("code" to code, "message" to message),
    )

    private fun transactionToMap(tx: Transaction): Map<String, Any?> {
        val map = hashMapOf<String, Any?>()
        tx.id?.let { map["id"] = it }
        tx.status?.let { map["status"] = it }
        tx.amount?.let { map["amount"] = it }
        tx.currencyKey?.let { map["currencyKey"] = it }
        tx.amountInEuro?.let { map["amountInEuro"] = it }
        tx.externalOrderId?.let { map["externalOrderId"] = it }
        tx.description?.let { map["description"] = it }
        tx.customerData?.let { map["customerData"] = customerToMap(it) }
        return map
    }

    private fun customerToMap(customer: TransactionCustomer): Map<String, Any?> {
        val map = hashMapOf<String, Any?>()
        customer.id?.let { map["id"] = it }
        customer.siteId?.let { map["siteId"] = it }
        customer.identifier?.let { map["identifier"] = it }
        customer.firstName?.let { map["firstName"] = it }
        customer.lastName?.let { map["lastName"] = it }
        customer.country?.let { map["country"] = it }
        customer.state?.let { map["state"] = it }
        customer.city?.let { map["city"] = it }
        customer.zipCode?.let { map["zipCode"] = it }
        customer.address?.let { map["address"] = it }
        customer.phone?.let { map["phone"] = it }
        customer.email?.let { map["email"] = it }
        map["isWhitelisted"] = customer.isWhitelisted
        customer.isWhitelistedUntil?.let { map["isWhitelistedUntil"] = it }
        customer.creationDate?.let { map["creationDate"] = it }
        customer.creationTimestamp?.let { map["creationTimestamp"] = it }
        return map
    }
}

internal object BridgeConfigParser {
    fun parseConfig(dict: Map<String, Any?>): PaymentConfig {
        return PaymentConfig(
            publicKey = dict.string("publicKey") ?: "",
            card = parseCard(dict.child("card")),
            paymentMethods = parsePaymentMethods(dict.child("paymentMethods")),
            options = parseOptions(dict.child("options")),
        )
    }

    fun parseIntent(orderPayload: String, orderChecksum: String): PaymentIntent {
        return PaymentIntent(OrderPayload(orderPayload), OrderChecksum(orderChecksum))
    }

    fun parse(
        config: Map<String, Any?>,
        orderPayload: String,
        orderChecksum: String,
    ): Pair<PaymentConfig, PaymentIntent> {
        return parseConfig(config) to parseIntent(orderPayload, orderChecksum)
    }

    private fun parseCard(dict: Map<String, Any?>?): CardConfig {
        if (dict == null) return CardConfig()
        val defaults = CardConfig()
        val saved = dict.child("savedCards")
        val savedCards = if (saved != null) {
            SavedCardsConfig(
                enabled = if (saved.has("enabled")) saved.bool("enabled", defaults.savedCards.enabled)
                else defaults.savedCards.enabled,
                optInVisible = if (saved.has("optInVisible")) {
                    saved.bool("optInVisible", defaults.savedCards.optInVisible)
                } else defaults.savedCards.optInVisible,
            )
        } else defaults.savedCards
        val inputs = dict.child("inputs")
        val grouping = inputs?.string("grouping")
        val cardInputs = if (grouping != null) {
            CardInputsConfig(grouping = CardGrouping.from(grouping))
        } else defaults.inputs
        val submit = dict.child("submitButton")
        val submitButton = if (submit != null) {
            SubmitButtonConfig(
                visible = if (submit.has("visible")) submit.bool("visible", defaults.submitButton.visible)
                else defaults.submitButton.visible,
                type = submit.string("type")?.let { SubmitButtonType.from(it) } ?: defaults.submitButton.type,
            )
        } else defaults.submitButton
        return CardConfig(
            savedCards = savedCards,
            cardHolderVerification = parseCardHolderVerification(dict.child("cardHolderVerification")),
            inputs = cardInputs,
            validationMode = dict.string("validationMode")?.let { ValidationMode.from(it) }
                ?: defaults.validationMode,
            submitButton = submitButton,
        )
    }

    private fun parseCardHolderVerification(dict: Map<String, Any?>?): CardHolderVerification? {
        val name = dict?.child("name") ?: return null
        val firstName = name.string("firstName") ?: return null
        val lastName = name.string("lastName") ?: return null
        val chvId = dict.string("chvId") ?: ""
        return CardHolderVerification(
            name = CardHolderName(
                firstName = firstName,
                middleName = name.string("middleName") ?: "",
                lastName = lastName,
            ),
            onCardHolderVerification = { result ->
                CardHolderVerificationBridge.ask(chvId, result)
            },
        )
    }

    private fun parsePaymentMethods(dict: Map<String, Any?>?): PaymentMethodsConfig {
        if (dict == null) return PaymentMethodsConfig()
        val googlePay = dict.child("googlePay")
        return PaymentMethodsConfig(
            googlePay = GooglePayConfig(
                enabled = googlePay.bool("enabled", GooglePayConfig().enabled),
                appearance = parseWalletAppearance(googlePay.child("appearance")),
            ),
        )
    }

    fun parseWalletAppearance(dict: Map<String, Any?>?): WalletAppearance {
        if (dict == null) return WalletAppearance()
        return WalletAppearance(
            color = WalletButtonColor.from(dict.string("color")),
            radius = dict.number("radius")?.toFloat(),
            type = WalletButtonType.from(dict.string("type")),
        )
    }

    private fun parseOptions(dict: Map<String, Any?>?): OptionsConfig {
        if (dict == null) return OptionsConfig()
        return OptionsConfig(
            locale = dict.string("locale") ?: OptionsConfig().locale,
            style = UserInterfaceStyle.from(dict.string("style")),
            appearance = AppearanceConfig.from(dict.child("appearance")),
        )
    }
}

@Suppress("UNCHECKED_CAST")
private fun Map<String, Any?>?.child(key: String): Map<String, Any?>? {
    val value = this?.get(key) ?: return null
    return value as? Map<String, Any?>
}

private fun Map<String, Any?>?.has(key: String): Boolean = this?.containsKey(key) == true

private fun Map<String, Any?>?.string(key: String): String? = this?.get(key) as? String

private fun Map<String, Any?>?.bool(key: String, default: Boolean): Boolean {
    val value = this?.get(key) ?: return default
    return when (value) {
        is Boolean -> value
        is Number -> value.toInt() != 0
        else -> default
    }
}

private fun Map<String, Any?>?.number(key: String): Number? = this?.get(key) as? Number
