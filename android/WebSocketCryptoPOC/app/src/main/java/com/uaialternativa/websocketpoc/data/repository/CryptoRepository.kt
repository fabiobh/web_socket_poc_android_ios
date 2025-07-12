package com.uaialternativa.websocketpoc.data.repository

import com.uaialternativa.websocketpoc.data.model.CoinbaseWebSocketMessage
import com.uaialternativa.websocketpoc.data.model.CryptoTicker
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json
import okhttp3.*

class CryptoRepository {
    private val client = OkHttpClient()
    private val _tickers = MutableStateFlow<List<CryptoTicker>>(emptyList())
    val tickers: StateFlow<List<CryptoTicker>> = _tickers.asStateFlow()

    private val json = Json { ignoreUnknownKeys = true }
    private var lastPrices = mutableMapOf<String, Double>()
    private var orderedProductIds = listOf<String>()

    fun connect(productIds: List<String>) {
        orderedProductIds = productIds
        // Initialize the list with empty tickers to maintain order
        _tickers.value = productIds.map { productId ->
            CryptoTicker(productId = productId, price = 0.0, lastPrice = null)
        }
        val request = Request.Builder()
            .url("wss://ws-feed.exchange.coinbase.com")
            .build()

        val listener = object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                val productIdsJson = productIds.joinToString(",") { "\"$it\"" }
                val subscribeMessage = """
                    {
                        "type": "subscribe",
                        "channels": [{
                            "name": "ticker",
                            "product_ids": [$productIdsJson]
                        }]
                    }
                """.trimIndent()
                webSocket.send(subscribeMessage)
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                val message = try {
                    json.decodeFromString<CoinbaseWebSocketMessage>(text)
                } catch (e: Exception) {
                    null
                }
                if (message?.type == "ticker" && message.productId != null && message.price != null) {
                    val price = message.price.toDoubleOrNull() ?: return
                    val lastPrice = lastPrices[message.productId]
                    lastPrices[message.productId] = price
                    val newTicker = CryptoTicker(
                        productId = message.productId,
                        price = price,
                        lastPrice = lastPrice
                    )
                    // Update the ticker in place to maintain order
                    _tickers.value = _tickers.value.map { ticker ->
                        if (ticker.productId == message.productId) newTicker else ticker
                    }
                }
            }
        }

        client.newWebSocket(request, listener)
    }
} 