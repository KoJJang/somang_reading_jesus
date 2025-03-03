package com.example.somang_reading_jesus

import android.content.Context
import android.util.Log
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.common.GooglePlayServicesNotAvailableException
import com.google.android.gms.common.GooglePlayServicesRepairableException
import com.google.android.gms.security.ProviderInstaller

object SecurityProvider {
    private const val TAG = "SecurityProvider"

    fun installProvider(context: Context) {
        try {
            ProviderInstaller.installIfNeeded(context)
            Log.i(TAG, "Provider installed successfully")
        } catch (e: GooglePlayServicesRepairableException) {
            // Google Play Services is not installed, damaged, or outdated
            Log.e(TAG, "GooglePlayServicesRepairableException: ${e.message}")
            // Prompt the user to install/update/enable Google Play services
            GoogleApiAvailability.getInstance()
                .showErrorNotification(context, e.connectionStatusCode)
        } catch (e: GooglePlayServicesNotAvailableException) {
            // Google Play services is not available
            Log.e(TAG, "GooglePlayServicesNotAvailableException: ${e.message}")
        } catch (e: Exception) {
            // General exception occurred
            Log.e(TAG, "Unexpected error: ${e.message}")
        }
    }
} 