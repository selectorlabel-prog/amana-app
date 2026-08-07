package amana.example.com

import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import androidx.navigation.fragment.NavHostFragment
import androidx.navigation.ui.setupWithNavController
import amana.core.data.MockDataStore
import amana.core.data.SessionManager
import amana.example.com.databinding.ActivityMainBinding
import amana.example.com.ui.auth.PhoneAuthActivity

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        SessionManager.init(applicationContext)
        MockDataStore.init(applicationContext)

        if (!SessionManager.isLoggedIn) {
            Toast.makeText(this, "انتهت الجلسة — سجّل الدخول مجدداً", Toast.LENGTH_LONG).show()
            startActivity(Intent(this, PhoneAuthActivity::class.java))
            finish()
            return
        }

        try {
            window.statusBarColor = ContextCompat.getColor(this, R.color.primary)
            WindowCompat.getInsetsController(window, window.decorView).isAppearanceLightStatusBars = false

            binding = ActivityMainBinding.inflate(layoutInflater)
            setContentView(binding.root)
            setSupportActionBar(binding.toolbar)
            binding.toolbar.setBackgroundColor(ContextCompat.getColor(this, R.color.primary))
            binding.toolbar.setTitleTextColor(ContextCompat.getColor(this, R.color.on_primary))

            val navHost = supportFragmentManager
                .findFragmentById(R.id.nav_host_fragment) as NavHostFragment
            val navController = navHost.navController
            val graph = navController.navInflater.inflate(R.navigation.mobile_navigation)

            val roleExtra = intent.getStringExtra("USER_ROLE")
            val isProvider = roleExtra == "PROVIDER" || SessionManager.userRole == amana.core.models.UserRole.PROVIDER

            if (isProvider) {
                graph.setStartDestination(R.id.nav_provider_home)
                binding.bottomNav.menu.clear()
                binding.bottomNav.inflateMenu(R.menu.bottom_navigation_provider)
                binding.toolbar.title = "أمانة — مزود"
            } else {
                graph.setStartDestination(R.id.nav_customer_home)
                binding.bottomNav.menu.clear()
                binding.bottomNav.inflateMenu(R.menu.bottom_navigation_customer)
                binding.toolbar.title = "أمانة"
            }

            navController.graph = graph
            binding.bottomNav.setupWithNavController(navController)

            if (intent.getBooleanExtra("OPEN_WALLET", false)) {
                binding.bottomNav.selectedItemId = R.id.nav_wallet
            }
        } catch (e: Exception) {
            Toast.makeText(this, "خطأ في فتح التطبيق: ${e.message}", Toast.LENGTH_LONG).show()
            startActivity(Intent(this, amana.example.com.ui.gateway.GatewayActivity::class.java))
            finish()
        }
    }
}
