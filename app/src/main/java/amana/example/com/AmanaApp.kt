package amana.example.com

import android.app.Application
import amana.core.data.MockDataStore
import amana.core.data.SessionManager

class AmanaApp : Application() {
    override fun onCreate() {
        super.onCreate()
        MockDataStore.init(this)
        SessionManager.init(this)
    }
}
