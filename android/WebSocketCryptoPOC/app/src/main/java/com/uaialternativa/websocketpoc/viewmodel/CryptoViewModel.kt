package com.uaialternativa.websocketpoc.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.uaialternativa.websocketpoc.data.model.CryptoTicker
import com.uaialternativa.websocketpoc.data.repository.CryptoRepository
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class CryptoViewModel : ViewModel() {
    private val repository = CryptoRepository()
    val tickers: StateFlow<List<CryptoTicker>> = repository.tickers

    init {
        // Default: BTC, ETH, SOL
        viewModelScope.launch {
            repository.connect(listOf("BTC-USD", "ETH-USD", "SOL-USD"))
        }
    }
} 