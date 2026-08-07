package amana.admin

import android.app.Application
import amana.core.data.MockDataStore
import amana.core.data.SessionManager

class AdminApp : Application() {
    override fun onCreate() {
        super.onCreate()
        MockDataStore.init(this)
        SessionManager.init(this)
    }
}
