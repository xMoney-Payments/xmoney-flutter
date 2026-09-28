package com.xmoney.flutter

import org.junit.Assert.assertEquals
import org.junit.Test

class BridgeConfigParserTest {
    @Test
    fun parseConfig_readsPublicKey() {
        val config = BridgeConfigParser.parseConfig(
            mapOf("publicKey" to "pk_test_example"),
        )
        assertEquals("pk_test_example", config.publicKey)
    }

    @Test
    fun parseIntent_roundTripsPayload() {
        val intent = BridgeConfigParser.parseIntent("payload", "checksum")
        assertEquals("payload", intent.orderPayload)
        assertEquals("checksum", intent.orderChecksum)
    }

    @Test
    fun parseWalletAppearance_readsEnums() {
        val appearance = BridgeConfigParser.parseWalletAppearance(
            mapOf(
                "color" to "black",
                "type" to "pay",
                "radius" to 12,
            ),
        )
        assertEquals(com.xmoney.payments.config.WalletButtonColor.BLACK, appearance.color)
        assertEquals(com.xmoney.payments.config.WalletButtonType.PAY, appearance.type)
        assertEquals(12f, appearance.radius)
    }

    @Test
    fun parseCardHolderVerification_requiresName() {
        val card = BridgeConfigParser.parseConfig(
            mapOf(
                "publicKey" to "pk_test_x",
                "card" to mapOf(
                    "cardHolderVerification" to mapOf(
                        "name" to mapOf(
                            "firstName" to "Jane",
                            "lastName" to "Doe",
                        ),
                        "chvId" to "chv_1",
                    ),
                ),
            ),
        ).card
        assertEquals("Jane", card.cardHolderVerification?.name?.firstName)
    }
}
