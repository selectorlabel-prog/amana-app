package amana.example.com.ui.auth

import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import amana.core.AmanaConstants
import amana.core.data.MockDataStore
import amana.core.data.SessionManager
import amana.example.com.R
import amana.example.com.databinding.ActivityPhoneAuthBinding
import amana.example.com.ui.gateway.GatewayActivity

class PhoneAuthActivity : AppCompatActivity() {

    private lateinit var binding: ActivityPhoneAuthBinding
    private var isOtpSent = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        SessionManager.init(applicationContext)
        MockDataStore.init(applicationContext)
        applyBrandChrome()

        if (SessionManager.isLoggedIn) {
            openNextScreen(clearStack = true)
            return
        }

        binding = ActivityPhoneAuthBinding.inflate(layoutInflater)
        setContentView(binding.root)

        binding.tvSubtitle.text = "وضع التجربة: استخدم الكود ${AmanaConstants.MOCK_OTP}"

        binding.btnAction.setOnClickListener {
            if (!isOtpSent) {
                val phone = binding.etPhone.text.toString().trim()
                if (!SessionManager.isValidSudanPhone(phone)) {
                    Toast.makeText(this, "أدخل رقماً سودانياً صحيحاً (9 أرقام)", Toast.LENGTH_SHORT).show()
                    return@setOnClickListener
                }
                SessionManager.setPendingPhone(phone)
                isOtpSent = true
                binding.tilPhone.visibility = View.GONE
                binding.tilOtp.visibility = View.VISIBLE
                binding.btnAction.text = "تأكيد الكود"
                binding.tvSubtitle.text = "تم إرسال كود وهمي: ${AmanaConstants.MOCK_OTP}"
            } else {
                verifyOtp(binding.etOtp.text.toString().trim())
            }
        }
    }

    private fun applyBrandChrome() {
        window.statusBarColor = ContextCompat.getColor(this, R.color.primary)
        WindowCompat.getInsetsController(window, window.decorView).isAppearanceLightStatusBars = false
    }

    private fun verifyOtp(otp: String) {
        if (otp != AmanaConstants.MOCK_OTP) {
            Toast.makeText(this, "الكود غير صحيح. استخدم ${AmanaConstants.MOCK_OTP}", Toast.LENGTH_LONG).show()
            return
        }
        try {
            SessionManager.completeLogin(SessionManager.pendingPhone)
        } catch (e: Exception) {
            Toast.makeText(this, "خطأ تسجيل الدخول: ${e.message}", Toast.LENGTH_LONG).show()
            return
        }
        if (!SessionManager.isLoggedIn) {
            Toast.makeText(this, "خطأ في الجلسة. أعد المحاولة.", Toast.LENGTH_LONG).show()
            return
        }
        openNextScreen(clearStack = true)
    }

    private fun openNextScreen(clearStack: Boolean) {
        val next = if (SessionManager.needsRegistration()) {
            Intent(this, CustomerRegistrationActivity::class.java)
        } else {
            Intent(this, GatewayActivity::class.java)
        }
        if (clearStack) {
            next.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        }
        startActivity(next)
        finish()
    }
}
