package amana.admin

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.Uri
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.View
import android.view.animation.AnimationUtils
import androidx.activity.addCallback
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.google.android.material.snackbar.Snackbar
import amana.core.data.MockDataStore
import amana.admin.databinding.ActivityAdminLoginBinding

class AdminLoginActivity : AppCompatActivity() {

    private lateinit var binding: ActivityAdminLoginBinding
    private var isLoggingIn = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        MockDataStore.init(applicationContext)

        binding = ActivityAdminLoginBinding.inflate(layoutInflater)
        setContentView(binding.root)

        setupDebugHint()
        setupPlaceholders()
        setupListeners()
        updateProviderBanner()

        binding.root.startAnimation(AnimationUtils.loadAnimation(this, R.anim.fade_in))

        onBackPressedDispatcher.addCallback(this) {
            if (!isLoggingIn) {
                isEnabled = false
                onBackPressedDispatcher.onBackPressed()
            }
        }

        if (MockDataStore.isAdminLoggedIn()) {
            openDashboard()
            return
        }
    }

    override fun onResume() {
        super.onResume()
        updateProviderBanner()
    }

    private fun setupDebugHint() {
        val isDebug = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        binding.tvDemoHint.visibility = if (isDebug) View.VISIBLE else View.GONE
    }

    private fun setupPlaceholders() {
        binding.etEmail.hint = getString(R.string.email_hint)
        binding.etPassword.hint = getString(R.string.password_hint)
    }

    private fun setupListeners() {
        binding.btnLogin.setOnClickListener { attemptLogin() }
        binding.tvContactSupervisor.setOnClickListener { contactSupervisor() }
        binding.supportLink.setOnClickListener { contactSupport() }
        binding.btnProviderRetry.setOnClickListener { retryProviderConnection() }

        binding.etEmail.addTextChangedListener(clearErrorWatcher { clearFieldError(isEmail = true) })
        binding.etPassword.addTextChangedListener(clearErrorWatcher { clearFieldError(isEmail = false) })
    }

    private fun clearErrorWatcher(onClear: () -> Unit) = object : TextWatcher {
        override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
        override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = onClear()
        override fun afterTextChanged(s: Editable?) = Unit
    }

    private fun updateProviderBanner() {
        val connected = MockDataStore.pingProvider()
        binding.providerBanner.visibility = if (connected) View.GONE else View.VISIBLE
    }

    private fun retryProviderConnection() {
        MockDataStore.init(applicationContext)
        if (MockDataStore.pingProvider()) {
            binding.providerBanner.visibility = View.GONE
            Snackbar.make(binding.root, R.string.provider_connected, Snackbar.LENGTH_SHORT)
                .setBackgroundTint(ContextCompat.getColor(this, R.color.primary))
                .setTextColor(ContextCompat.getColor(this, R.color.on_primary))
                .show()
        } else {
            binding.providerBanner.startAnimation(
                AnimationUtils.loadAnimation(this, android.R.anim.slide_in_left).apply { duration = 200 }
            )
            showProviderMissingDialog()
        }
    }

    private fun attemptLogin() {
        if (isLoggingIn) return

        clearFieldErrors()

        if (!MockDataStore.pingProvider()) {
            updateProviderBanner()
            binding.scrollContent.smoothScrollTo(0, 0)
            showProviderMissingDialog()
            return
        }

        val email = binding.etEmail.text.toString().trim()
        val password = binding.etPassword.text.toString()
        var hasError = false

        if (email.isEmpty()) {
            showFieldError(isEmail = true, getString(R.string.email_error_empty))
            hasError = true
        }
        if (password.isEmpty()) {
            showFieldError(isEmail = false, getString(R.string.password_error_empty))
            hasError = true
        }
        if (hasError) return

        setLoading(true)

        binding.root.postDelayed({
            val success = MockDataStore.adminLogin(email, password)
            setLoading(false)
            if (success) {
                openDashboard()
            } else {
                showFieldError(isEmail = true, getString(R.string.login_error))
                binding.tilPassword.error = " "
                binding.tilPassword.isErrorEnabled = true
            }
        }, 600)
    }

    private fun clearFieldErrors() {
        clearFieldError(isEmail = true)
        clearFieldError(isEmail = false)
    }

    private fun clearFieldError(isEmail: Boolean) {
        if (isEmail) {
            binding.tvEmailError.visibility = View.GONE
            binding.tilEmail.isErrorEnabled = false
            binding.tilEmail.error = null
        } else {
            binding.tvPasswordError.visibility = View.GONE
            binding.tilPassword.isErrorEnabled = false
            binding.tilPassword.error = null
        }
    }

    private fun showFieldError(isEmail: Boolean, message: String) {
        if (isEmail) {
            binding.tvEmailError.text = message
            binding.tvEmailError.visibility = View.VISIBLE
            binding.tilEmail.isErrorEnabled = true
            binding.tilEmail.error = " "
        } else {
            binding.tvPasswordError.text = message
            binding.tvPasswordError.visibility = View.VISIBLE
            binding.tilPassword.isErrorEnabled = true
            binding.tilPassword.error = " "
        }
    }

    private fun setLoading(loading: Boolean) {
        isLoggingIn = loading
        binding.btnLogin.isEnabled = !loading
        binding.btnLogin.text = if (loading) getString(R.string.login_loading) else getString(R.string.login_button)
        binding.btnLogin.icon = if (loading) null else ContextCompat.getDrawable(this, R.drawable.ic_login)
        binding.loginProgress.visibility = if (loading) View.VISIBLE else View.GONE
        binding.etEmail.isEnabled = !loading
        binding.etPassword.isEnabled = !loading
        binding.tvContactSupervisor.isEnabled = !loading
    }

    private fun showProviderMissingDialog() {
        AlertDialog.Builder(this)
            .setTitle(R.string.provider_missing_title)
            .setMessage(R.string.provider_missing_message)
            .setPositiveButton(R.string.provider_retry) { _, _ -> retryProviderConnection() }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    private fun contactSupervisor() {
        val email = getString(R.string.supervisor_email)
        if (!openEmailIntent(email, "طلب مساعدة — بوابة الإدارة")) {
            copyEmail(email)
        }
    }

    private fun contactSupport() {
        val email = getString(R.string.support_email)
        if (!openEmailIntent(email, "دعم فني — بوابة الإدارة")) {
            copyEmail(email)
        }
    }

    private fun openEmailIntent(email: String, subject: String): Boolean {
        val intent = Intent(Intent.ACTION_SENDTO).apply {
            data = Uri.parse("mailto:$email")
            putExtra(Intent.EXTRA_SUBJECT, subject)
        }
        return if (intent.resolveActivity(packageManager) != null) {
            startActivity(intent)
            true
        } else {
            false
        }
    }

    private fun copyEmail(email: String) {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText("email", email))
        Snackbar.make(binding.root, R.string.support_email_copied, Snackbar.LENGTH_SHORT).show()
    }

    private fun openDashboard() {
        if (!MockDataStore.pingProvider()) {
            updateProviderBanner()
            showProviderMissingDialog()
            return
        }
        startActivity(
            Intent(this, AdminMainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }
        )
        overridePendingTransition(R.anim.fade_in, R.anim.fade_out)
        finish()
    }
}
