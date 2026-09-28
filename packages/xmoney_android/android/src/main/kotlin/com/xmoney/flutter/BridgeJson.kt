package com.xmoney.flutter

import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

internal object BridgeJson {
    fun toMap(json: String): Map<String, Any?> {
        if (json.isBlank() || json == "null") return emptyMap()
        return JSONObject(json).toMap()
    }

    fun fromMap(map: Map<String, Any?>): String = mapToJson(map).toString()

    @Suppress("UNCHECKED_CAST")
    private fun JSONObject.toMap(): Map<String, Any?> {
        val map = hashMapOf<String, Any?>()
        keys().forEach { key -> map[key] = unwrap(get(key)) }
        return map
    }

    private fun JSONArray.toList(): List<Any?> = (0 until length()).map { unwrap(get(it)) }

    private fun unwrap(value: Any?): Any? = when (value) {
        null, JSONObject.NULL -> null
        is JSONObject -> value.toMap()
        is JSONArray -> value.toList()
        else -> value
    }

    @Suppress("UNCHECKED_CAST")
    private fun mapToJson(map: Map<String, Any?>): JSONObject {
        val obj = JSONObject()
        map.forEach { (key, value) -> obj.put(key, wrap(value)) }
        return obj
    }

    @Suppress("UNCHECKED_CAST")
    private fun wrap(value: Any?): Any = when (value) {
        null -> JSONObject.NULL
        is Map<*, *> -> mapToJson(value as Map<String, Any?>)
        is List<*> -> JSONArray(value.map { wrap(it) })
        else -> value
    }
}

internal object CardHolderVerificationBridge {
    private val pending = ConcurrentHashMap<String, CountDownLatch>()
    private val answers = ConcurrentHashMap<String, Boolean>()
    private var flutterChannel: MethodChannel? = null

    fun attach(channel: MethodChannel) {
        flutterChannel = channel
    }

    fun ask(chvId: String, result: com.xmoney.payments.model.CardHolderVerificationResult): Boolean {
        val requestId = java.util.UUID.randomUUID().toString()
        val latch = CountDownLatch(1)
        pending[requestId] = latch
        val resultJson = BridgeJson.fromMap(
            mapOf(
                "status" to result.status.raw,
                "firstNameStatus" to result.firstNameStatus?.raw,
                "middleNameStatus" to result.middleNameStatus?.raw,
                "lastNameStatus" to result.lastNameStatus?.raw,
            ),
        )
        val channel = flutterChannel
        if (channel == null) {
            pending.remove(requestId)
            return false
        }
        val payload = mapOf(
            "chvId" to chvId,
            "requestId" to requestId,
            "resultJson" to resultJson,
        )
        // The native SDK needs a Boolean before it returns. The merchant
        // answer arrives on xmoney/chv, which is registered on a background
        // task queue, so this wait does not pump the main looper.
        try {
            channel.invokeMethod("onCardHolderVerification", payload)
        } catch (_: Exception) {
            pending.remove(requestId)
            return false
        }
        latch.await(CHV_WAIT_SECONDS, TimeUnit.SECONDS)
        pending.remove(requestId)
        return answers.remove(requestId) ?: false
    }

    fun answer(requestId: String, accepted: Boolean) {
        answers[requestId] = accepted
        pending[requestId]?.countDown()
    }
}

private const val CHV_WAIT_SECONDS = 2L
