package com.uaialternativa.websocketpoc.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.uaialternativa.websocketpoc.data.model.CryptoTicker
import com.uaialternativa.websocketpoc.viewmodel.CryptoViewModel

@Composable
fun CryptoListScreen(viewModel: CryptoViewModel) {
    val tickers = viewModel.tickers.collectAsState().value

    Surface(color = MaterialTheme.colorScheme.background) {
        Column(modifier = Modifier.fillMaxSize()) {
            Text(
                text = "Live Crypto Prices",
                style = MaterialTheme.typography.headlineSmall,
                modifier = Modifier.padding(16.dp)
            )
            LazyColumn {
                items(tickers) { ticker ->
                    CryptoTickerRow(ticker)
                }
            }
        }
    }
}

@Composable
fun CryptoTickerRow(ticker: CryptoTicker) {
    val color = when {
        ticker.lastPrice == null -> Color.Unspecified
        ticker.price > ticker.lastPrice -> Color(0xFF4CAF50) // Green
        ticker.price < ticker.lastPrice -> Color(0xFFF44336) // Red
        else -> Color.Unspecified
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(color.copy(alpha = 0.1f))
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = ticker.productId,
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.weight(1f)
        )
        Text(
            text = "${ticker.price}",
            style = MaterialTheme.typography.titleLarge
        )
    }
} 