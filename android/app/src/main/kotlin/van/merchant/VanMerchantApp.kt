package van.merchant

import android.app.Activity
import android.app.Application
import android.os.Bundle
import android.util.Log
import com.facebook.FacebookSdk
import com.facebook.appevents.AppEventsLogger
import io.flutter.app.FlutterApplication
import kotlin.math.max
import van.merchant.R

class VanMerchantApp : FlutterApplication(), Application.ActivityLifecycleCallbacks {

    override fun onCreate() {
        super.onCreate()
        registerActivityLifecycleCallbacks(this)
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

    override fun onTerminate() {
        unregisterActivityLifecycleCallbacks(this)
        super.onTerminate()
    }

    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit

    override fun onActivityStarted(activity: Activity) {
        synchronized(this) {
            foregroundActivities++
            isAppVisible = foregroundActivities > 0
        }
    }

    override fun onActivityResumed(activity: Activity) = Unit

    override fun onActivityPaused(activity: Activity) = Unit

    override fun onActivityStopped(activity: Activity) {
        synchronized(this) {
            foregroundActivities = max(0, foregroundActivities - 1)
            isAppVisible = foregroundActivities > 0
        }
    }

    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit

    override fun onActivityDestroyed(activity: Activity) = Unit

    companion object {
        private const val TAG = "VanMerchantApp"
        @Volatile private var isAppVisible: Boolean = false
        @Volatile private var foregroundActivities: Int = 0

        @JvmStatic
        fun isAppInForeground(): Boolean = isAppVisible
    }
}
