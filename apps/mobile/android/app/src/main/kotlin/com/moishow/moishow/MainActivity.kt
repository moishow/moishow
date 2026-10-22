package com.moishow.moishow

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel("moishow_work", "모이쇼 업무와 대화", NotificationManager.IMPORTANCE_DEFAULT)
            )
        }
    }
    private val identityScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.moishow/identity")
            .setMethodCallHandler { call, result ->
                if (call.method != "googleSignIn") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val clientId = call.argument<String>("serverClientId")
                val nonce = call.argument<String>("nonce")
                if (clientId.isNullOrBlank() || nonce.isNullOrBlank()) {
                    result.error("GOOGLE_CONFIGURATION_MISSING", "Google client ID and server nonce are required", null)
                    return@setMethodCallHandler
                }
                identityScope.launch {
                    try {
                        val option = GetSignInWithGoogleOption.Builder(clientId).setNonce(nonce).build()
                        val request = GetCredentialRequest.Builder().addCredentialOption(option).build()
                        val response = CredentialManager.create(this@MainActivity).getCredential(this@MainActivity, request)
                        val credential = GoogleIdTokenCredential.createFrom(response.credential.data)
                        result.success(credential.idToken)
                    } catch (error: Exception) {
                        result.error("GOOGLE_AUTH_FAILED", error.localizedMessage ?: "Google sign-in failed", null)
                    }
                }
            }
    }
    override fun onDestroy() {
        identityScope.cancel()
        super.onDestroy()
    }
}
