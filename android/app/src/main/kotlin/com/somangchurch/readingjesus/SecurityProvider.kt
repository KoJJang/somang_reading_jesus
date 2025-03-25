package com.somangchurch.readingjesus

import android.content.Context
import android.util.Log

/**
 * SecurityProvider 간소화 - 보안 관련 기능을 최소화하여 인증 충돌 방지
 */
object SecurityProvider {
    private const val TAG = "SecurityProvider"
    private var isInitialized = false

    fun installProvider(context: Context) {
        // 중복 초기화 방지
        if (isInitialized) {
            return
        }
        
        isInitialized = true
        Log.i(TAG, "SecurityProvider initialized in minimal mode")
        
        // 안드로이드 패키지 정보 로깅
        try {
            val packageName = context.packageName
            val packageInfo = context.packageManager.getPackageInfo(packageName, 0)
            val versionName = packageInfo.versionName
            val versionCode = packageInfo.versionCode
            
            Log.i(TAG, "App package: $packageName, version: $versionName ($versionCode)")
        } catch (e: Exception) {
            Log.e(TAG, "Error getting package info: ${e.message}")
        }
    }
} 