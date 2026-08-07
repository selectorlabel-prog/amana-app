package amana.example.com.ui.gateway



import android.content.Intent

import android.os.Bundle

import android.widget.Toast

import androidx.appcompat.app.AppCompatActivity

import androidx.core.content.ContextCompat

import androidx.core.view.WindowCompat

import amana.core.data.MockDataStore

import amana.core.data.SessionManager

import amana.core.models.UserRole

import amana.example.com.MainActivity

import amana.example.com.R

import amana.example.com.ui.auth.CustomerRegistrationActivity

import amana.example.com.ui.auth.PhoneAuthActivity

import amana.example.com.databinding.ActivityGatewayBinding



class GatewayActivity : AppCompatActivity() {



    private lateinit var binding: ActivityGatewayBinding



    companion object {

        private const val ADMIN_PACKAGE = "amana.admin"

    }



    override fun onCreate(savedInstanceState: Bundle?) {

        super.onCreate(savedInstanceState)

        SessionManager.init(applicationContext)

        MockDataStore.init(applicationContext)

        applyBrandChrome()



        if (!SessionManager.isLoggedIn) {

            Toast.makeText(this, "يرجى تسجيل الدخول أولاً", Toast.LENGTH_SHORT).show()

            startActivity(

                Intent(this, PhoneAuthActivity::class.java)

                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)

            )

            finish()

            return

        }



        if (SessionManager.needsRegistration()) {

            startActivity(Intent(this, CustomerRegistrationActivity::class.java))

            finish()

            return

        }



        binding = ActivityGatewayBinding.inflate(layoutInflater)

        setContentView(binding.root)



        binding.cardCustomer.setOnClickListener {

            startWithRole(UserRole.CUSTOMER)

        }



        binding.cardProvider.setOnClickListener {

            startWithRole(UserRole.PROVIDER)

        }



        binding.tvAdminAccess.setOnClickListener {

            openAdminApp()

        }

    }



    private fun applyBrandChrome() {

        window.statusBarColor = ContextCompat.getColor(this, R.color.primary)

        WindowCompat.getInsetsController(window, window.decorView).isAppearanceLightStatusBars = false

    }



    private fun startWithRole(role: UserRole) {

        val user = SessionManager.currentUser

        if (user == null) {

            Toast.makeText(this, "انتهت الجلسة — سجّل الدخول مجدداً", Toast.LENGTH_LONG).show()

            startActivity(

                Intent(this, PhoneAuthActivity::class.java)

                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)

            )

            finish()

            return

        }

        try {

            SessionManager.setRole(role)

            if (role == UserRole.PROVIDER) {

                MockDataStore.ensureUserExists(user)

            }

        } catch (e: Exception) {

            Toast.makeText(this, "خطأ: ${e.message}", Toast.LENGTH_LONG).show()

            return

        }

        startActivity(

            Intent(this, MainActivity::class.java).putExtra("USER_ROLE", role.name)

        )

        finish()

    }



    private fun openAdminApp() {

        val launch = packageManager.getLaunchIntentForPackage(ADMIN_PACKAGE)

        if (launch != null) {

            startActivity(launch)

        } else {

            Toast.makeText(

                this,

                "ثبّت تطبيق «أمانة - المشرف» (amana.admin) على نفس الجهاز أولاً",

                Toast.LENGTH_LONG

            ).show()

        }

    }

}


