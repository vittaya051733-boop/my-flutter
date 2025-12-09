package van.merchant

import android.util.Log
import com.facebook.FacebookSdk
import com.facebook.appevents.AppEventsLogger
import io.flutter.app.FlutterApplication
import van.merchant.R

class VanMerchantApp : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        val appId = getString(R.string.facebook_app_id).trim()
        if (appId.isEmpty()) {
            Log.w(TAG, "Facebook App ID missing. Skipping SDK initialization.")
            return
        }

        FacebookSdk.setApplicationId(appId)
        val clientToken = getString(R.string.facebook_client_token).trim()
        if (clientToken.isNotEmpty()) {
            FacebookSdk.setClientToken(clientToken)
        }

        FacebookSdk.sdkInitialize(applicationContext)
        AppEventsLogger.activateApp(this)
    }

    companion object {
        private const val TAG = "VanMerchantApp"
    }
}
