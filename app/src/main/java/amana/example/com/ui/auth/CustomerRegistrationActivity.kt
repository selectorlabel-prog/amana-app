package amana.example.com.ui.auth

import android.content.Intent
import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import amana.core.data.SessionManager
import amana.example.com.R
import amana.example.com.databinding.ActivityCustomerRegistrationBinding
import amana.example.com.ui.auth.PhoneAuthActivity
import amana.example.com.ui.gateway.GatewayActivity

class CustomerRegistrationActivity : AppCompatActivity() {

    private lateinit var binding: ActivityCustomerRegistrationBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        SessionManager.init(applicationContext)
        amana.core.data.MockDataStore.init(applicationContext)
        window.statusBarColor = ContextCompat.getColor(this, R.color.primary)
        WindowCompat.getInsetsController(window, window.decorView).isAppearanceLightStatusBars = false
        binding = ActivityCustomerRegistrationBinding.inflate(layoutInflater)
        setContentView(binding.root)

        if (!SessionManager.isLoggedIn) {
            Toast.makeText(this, "انتهت الجلسة — سجّل الدخول مجدداً", Toast.LENGTH_LONG).show()
            startActivity(Intent(this, PhoneAuthActivity::class.java))
            finish()
            return
        }

        binding.etPhone.setText(
            SessionManager.pendingPhone.ifEmpty {
                SessionManager.currentUser?.phoneNumber ?: ""
            }
        )

        val cities = listOf("الخرطوم", "الخرطوم بحري", "أم درمان", "ود مدني", "بورتسودان")
        binding.spinnerCity.adapter = ArrayAdapter(
            this,
            android.R.layout.simple_spinner_dropdown_item,
            cities
        )

        binding.btnBack.setOnClickListener {
            SessionManager.logout()
            startActivity(
                Intent(this, PhoneAuthActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            )
            finish()
        }

        binding.btnRegister.setOnClickListener {
            val name = binding.etFullName.text.toString().trim()
            val district = binding.etDistrict.text.toString().trim()
            val city = binding.spinnerCity.selectedItem?.toString() ?: ""

            if (name.length < 3) {
                Toast.makeText(this, "أدخل الاسم الكامل", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }
            if (district.isEmpty()) {
                Toast.makeText(this, "أدخل اسم الحي", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }
            if (!binding.cbTerms.isChecked) {
                Toast.makeText(this, "يجب الموافقة على الشروط", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            try {
                SessionManager.completeRegistration(name, city, district)
            } catch (e: Exception) {
                Toast.makeText(this, "فشل التسجيل: ${e.message}", Toast.LENGTH_LONG).show()
                return@setOnClickListener
            }
            Toast.makeText(this, "تم إنشاء حسابك بنجاح", Toast.LENGTH_SHORT).show()
            startActivity(
                Intent(this, GatewayActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            )
            finish()
        }
    }
}
