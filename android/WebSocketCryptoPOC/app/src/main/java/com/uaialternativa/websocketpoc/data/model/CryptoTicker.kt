package com.uaialternativa.websocketpoc.data.model

// Represents a cryptocurrency ticker with current and previous price for UI feedback

data class CryptoTicker(
    val productId: String,
    val price: Double,
    val lastPrice: Double? = null // For color feedback
) 