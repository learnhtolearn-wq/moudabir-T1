package com.moudabbir.moudabbir

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth on
// Android — it needs a FragmentActivity host to show the biometric prompt.
//
// FLAG_SECURE blocks screenshots, screen recording, and the recent-apps
// thumbnail app-wide — always on since every screen can show financial data.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
        super.onCreate(savedInstanceState)
    }
}
