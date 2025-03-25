package com.somangchurch.readingjesus

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import androidx.multidex.MultiDex
import android.content.Context
import android.util.Log
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.FirebaseOptions
import com.google.firebase.appcheck.FirebaseAppCheck
import com.google.firebase.appcheck.playintegrity.PlayIntegrityAppCheckProviderFactory
import java.security.MessageDigest
import android.content.pm.PackageManager

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // DEBUG 로그 출력
        Log.d(TAG, "MainActivity onCreate")
        
        try {
            // SecurityProvider 초기화
            SecurityProvider.installProvider(this)
            Log.d(TAG, "SecurityProvider initialized successfully")
            
            // Firebase 초기화
            //if (FirebaseApp.getApps(this).isEmpty()) {
            //    FirebaseApp.initializeApp(this)
            //}
            
            // 중요: App Check 초기화 추가
            val firebaseAppCheck = FirebaseAppCheck.getInstance()
            firebaseAppCheck.installAppCheckProviderFactory(
                PlayIntegrityAppCheckProviderFactory.getInstance()
            )
            Log.d(TAG, "App Check initialized with Play Integrity Provider")
            
            // 현재 Firebase 앱 인스턴스 정보 로깅
            val app = FirebaseApp.getInstance()
            Log.d(TAG, "Firebase initialized: ${app.name}, options: ${app.options}")
            
            // Firebase Auth 초기화 상태 확인
            try {
                val auth = FirebaseAuth.getInstance()
                Log.d(TAG, "Firebase Auth initialized successfully")
                
                // 앱 패키지 정보 로깅
                logAppDetails()
            } catch (e: Exception) {
                Log.e(TAG, "Firebase Auth initialization error: ${e.message}")
                e.printStackTrace()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing Firebase components: ${e.message}")
            e.printStackTrace()
        }
    }
    
    // 앱 패키지 정보 및 서명 정보 로깅
    private fun logAppDetails() {
        try {
            val packageInfo = packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
            Log.d(TAG, "App Package: $packageName")
            Log.d(TAG, "App Version: ${packageInfo.versionName} (${packageInfo.versionCode})")
            
            // SHA-1 해시 출력 (Firebase 콘솔에 등록된 값과 비교 가능)
            val signatures = packageInfo.signatures
            if (signatures != null) {
                for (i in signatures.indices) {
                    val md = MessageDigest.getInstance("SHA-1")
                    md.update(signatures[i].toByteArray())
                    val sha1 = bytesToHex(md.digest())
                    Log.d(TAG, "App SHA-1: $sha1")
                    
                    // SHA-256 해시도 출력
                    val md256 = MessageDigest.getInstance("SHA-256")
                    md256.update(signatures[i].toByteArray())
                    val sha256 = bytesToHex(md256.digest())
                    Log.d(TAG, "App SHA-256: $sha256")
                }
            } else {
                Log.e(TAG, "App signatures is null")
            }
            
            // Firebase 프로젝트 정보 출력
            val options = FirebaseApp.getInstance().options
            Log.d(TAG, "Firebase Project ID: ${options.projectId}")
            Log.d(TAG, "Firebase App ID: ${options.applicationId}")
            Log.d(TAG, "Google API Key: ${options.apiKey}")
        } catch (e: Exception) {
            Log.e(TAG, "Error getting app details: ${e.message}")
            e.printStackTrace()
        }
    }
    
    private fun bytesToHex(bytes: ByteArray): String {
        val hexChars = "0123456789ABCDEF".toCharArray()
        val hexString = StringBuilder(bytes.size * 2)
        for (b in bytes) {
            val i = b.toInt() and 0xFF
            hexString.append(hexChars[i shr 4])
            hexString.append(hexChars[i and 0x0F])
            hexString.append(':')
        }
        return hexString.toString().dropLast(1) // 마지막 ':' 제거
    }
    
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        
        try {
            // 멀티덱스 지원 활성화
            MultiDex.install(this)
            Log.d(TAG, "MultiDex installed successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error installing MultiDex: ${e.message}")
        }
    }
} 