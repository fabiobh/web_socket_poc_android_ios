package com.uaialternativa.websocketpoc

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.uaialternativa.websocketpoc.ui.CryptoListScreen
import com.uaialternativa.websocketpoc.viewmodel.CryptoViewModel
import com.uaialternativa.websocketpoc.ui.theme.WebSocketPOCTheme

class MainActivity : ComponentActivity() {
    private val viewModel = CryptoViewModel()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            WebSocketPOCTheme {
                CryptoListScreen(viewModel)
            }
        }
    }
}