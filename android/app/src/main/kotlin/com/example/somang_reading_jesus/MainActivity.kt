package com.example.somang_reading_jesus

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // SecurityProvider 초기화
        SecurityProvider.installProvider(this)
    }
}
