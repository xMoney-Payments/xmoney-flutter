package com.xmoney.flutter

import com.xmoney.payments.model.PaymentIntent
import kotlinx.coroutines.CompletableDeferred

/**
 * Gates for the Dart `updateOrderWith` calls in flight on one surface.
 *
 * A resolve or reject that arrives before `beginUpdateOrder` is kept until
 * that call reads the gate. Finished request ids are capped so a long
 * checkout cannot grow the set.
 */
internal class PendingOrders {
    private val gates = mutableMapOf<String, CompletableDeferred<PaymentIntent>>()
    private val finished = LinkedHashSet<String>()

    /** The gate for [requestId], or null when the request already finished. */
    fun gate(requestId: String): CompletableDeferred<PaymentIntent>? {
        if (requestId.isEmpty() || requestId in finished) return null
        return gates.getOrPut(requestId) { CompletableDeferred() }
    }

    /** Applies a Dart resolve. */
    fun settle(requestId: String, intent: PaymentIntent) {
        val deferred = gate(requestId) ?: return
        if (!deferred.isCompleted) deferred.complete(intent)
    }

    /** Applies a Dart reject. The previous order stays payable. */
    fun settleRejected(requestId: String) {
        val deferred = gate(requestId) ?: return
        if (!deferred.isCompleted) deferred.completeExceptionally(OrderCreationRejected())
    }

    fun close(requestId: String) {
        gates.remove(requestId)
        if (requestId.isNotEmpty() && finished.add(requestId) && finished.size > 32) {
            finished.remove(finished.iterator().next())
        }
    }

    /** Cancels gates still waiting, so a disposed view does not leak them. */
    fun cancelAll() {
        gates.values.forEach { if (!it.isCompleted) it.cancel() }
        gates.clear()
    }
}

/** Dart's `createOrder` failed. The previous order stays payable. */
internal class OrderCreationRejected : Exception("Order creation failed")
