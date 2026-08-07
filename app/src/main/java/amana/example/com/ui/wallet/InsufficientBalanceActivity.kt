package amana.example.com.ui.wallet

import android.content.Intent
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import amana.core.AmanaConstants
import amana.core.data.MockDataStore
import amana.core.data.SessionManager
import amana.example.com.MainActivity
import amana.example.com.databinding.ActivityInsufficientBalanceBinding

class InsufficientBalanceActivity : AppCompatActivity() {

    private lateinit var binding: ActivityInsufficientBalanceBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityInsufficientBalanceBinding.inflate(layoutInflater)
        setContentView(binding.root)

        val orderPrice = intent.getDoubleExtra("ORDER_PRICE", 20000.0)
        val commission = orderPrice * AmanaConstants.COMMISSION_RATE
        val balance = MockDataStore.getWalletBalance(SessionManager.userId)
        val required = (commission - balance).coerceAtLeast(0.0)

        binding.tvCurrentBalance.text = String.format("%,.0f ج.س", balance)
        binding.tvCommission.text = String.format("%,.0f ج.س", commission)
        binding.tvRequired.text = String.format("%,.0f ج.س", required)

        binding.btnClose.setOnClickListener { finish() }
        binding.btnBack.setOnClickListener { finish() }
        binding.btnRecharge.setOnClickListener {
            startActivity(
                Intent(this, MainActivity::class.java)
                    .putExtra("OPEN_WALLET", true)
                    .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            )
            finish()
        }
    }
}
