package com.somangchurch.readingjesus

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // SecurityProvider 초기화 - 오류 발생 시 앱이 종료되지 않도록 try-catch로 감싸기
        try {
            // 빌드 환경을 고려하여 필요한 경우 조건부로 초기화
            SecurityProvider.installProvider(this)
        } catch (e: Exception) {
            Log.e("MainActivity", "Error initializing SecurityProvider: ${e.message}")
        }
    }
} 