package com.uaialternativa.websocketpoc.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class CoinbaseWebSocketMessage(
    val type: String,
    @SerialName("product_id") val productId: String? = null,
    val price: String? = null
) 