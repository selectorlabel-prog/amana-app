package amana.admin

import android.content.Intent
import android.widget.Toast
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import androidx.navigation.fragment.NavHostFragment
import androidx.navigation.ui.AppBarConfiguration
import androidx.navigation.ui.navigateUp
import androidx.navigation.ui.setupActionBarWithNavController
import androidx.navigation.ui.setupWithNavController
import amana.admin.databinding.ActivityAdminMainBinding
import amana.core.data.MockDataStore

class AdminMainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityAdminMainBinding
    private lateinit var appBarConfiguration: AppBarConfiguration

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        MockDataStore.init(applicationContext)

        if (!MockDataStore.isAdminLoggedIn()) {
            startActivity(Intent(this, AdminLoginActivity::class.java))
            finish()
            return
        }

        if (!MockDataStore.isAvailable()) {
            Toast.makeText(
                this,
                "تطبيق أمانة غير مثبّت — لن تظهر بيانات المستخدمين والطلبات",
                Toast.LENGTH_LONG
            ).show()
        }

        binding = ActivityAdminMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        setSupportActionBar(binding.toolbar)
        binding.toolbar.setBackgroundColor(ContextCompat.getColor(this, R.color.primary))
        binding.toolbar.setTitleTextColor(ContextCompat.getColor(this, R.color.on_primary))
        window.statusBarColor = ContextCompat.getColor(this, R.color.primary)
        WindowCompat.getInsetsController(window, window.decorView).isAppearanceLightStatusBars = false

        val navHost = supportFragmentManager
            .findFragmentById(R.id.nav_host_fragment) as NavHostFragment
        val navController = navHost.navController

        appBarConfiguration = AppBarConfiguration(
            setOf(
                R.id.adminDashboardFragment,
                R.id.adminUsersFragment,
                R.id.adminProvidersFragment,
                R.id.adminOrdersFragment,
                R.id.adminRechargeFragment,
                R.id.adminDisputesFragment,
                R.id.adminCommissionsFragment,
                R.id.adminReviewsFragment,
                R.id.adminReportsFragment,
                R.id.adminSettingsFragment,
                R.id.adminLogsFragment
            ),
            binding.drawerLayout
        )

        setupActionBarWithNavController(navController, appBarConfiguration)
        binding.navView.setupWithNavController(navController)
        binding.bottomNav.setupWithNavController(navController)

        binding.navView.getHeaderView(0).findViewById<com.google.android.material.button.MaterialButton>(
            R.id.btn_drawer_logout
        ).setOnClickListener {
            logout()
        }
    }

    override fun onSupportNavigateUp(): Boolean {
        val navHost = supportFragmentManager
            .findFragmentById(R.id.nav_host_fragment) as NavHostFragment
        return navHost.navController.navigateUp(appBarConfiguration) ||
            super.onSupportNavigateUp()
    }

    override fun onBackPressed() {
        if (binding.drawerLayout.isDrawerOpen(androidx.core.view.GravityCompat.START)) {
            binding.drawerLayout.closeDrawer(androidx.core.view.GravityCompat.START)
        } else {
            @Suppress("DEPRECATION")
            super.onBackPressed()
        }
    }

    private fun logout() {
        MockDataStore.adminLogout()
        startActivity(Intent(this, AdminLoginActivity::class.java))
        finish()
    }
}
