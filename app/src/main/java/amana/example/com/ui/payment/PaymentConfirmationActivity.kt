package amana.example.com.ui.payment

import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import amana.core.data.MockDataStore
import amana.example.com.MainActivity
import amana.example.com.databinding.ActivityPaymentConfirmationBinding
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class PaymentConfirmationActivity : AppCompatActivity() {

    private lateinit var binding: ActivityPaymentConfirmationBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityPaymentConfirmationBinding.inflate(layoutInflater)
        setContentView(binding.root)

        val orderId = intent.getStringExtra("ORDER_ID") ?: return finish()
        val order = MockDataStore.getOrder(orderId) ?: return finish()
        val amount = if (order.agreedPrice > 0) order.agreedPrice else 0.0
        val providerName = MockDataStore.getUser(order.providerId)?.fullName?.ifBlank { null } ?: "مزود الخدمة"
        val service = order.serviceName.ifBlank { "خدمة" }

        binding.tvInvoiceId.text = "INV-${orderId.uppercase().replace("ORDER_", "")}"
        binding.tvProvider.text = "$providerName ($service)"
        binding.tvTotal.text = String.format("%,.0f ج.س", amount)
        val sdf = SimpleDateFormat("d MMMM yyyy", Locale("ar"))
        binding.tvDate.text = sdf.format(Date(order.createdAt))

        binding.btnDownload.setOnClickListener {
            Toast.makeText(this, "معاينة — تحميل PDF في النسخة النهائية", Toast.LENGTH_SHORT).show()
        }

        binding.btnHome.setOnClickListener {
            startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP))
            finish()
        }
    }
}
