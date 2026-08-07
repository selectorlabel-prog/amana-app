package amana.example.com.ui.invoice

import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import amana.core.data.MockDataStore
import amana.example.com.databinding.ActivityInvoiceBinding
import amana.example.com.ui.payment.PaymentConfirmationActivity
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class InvoiceActivity : AppCompatActivity() {

    private lateinit var binding: ActivityInvoiceBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityInvoiceBinding.inflate(layoutInflater)
        setContentView(binding.root)

        val orderId = intent.getStringExtra("ORDER_ID") ?: return finish()
        val order = MockDataStore.getOrder(orderId) ?: return finish()

        val amount = if (order.agreedPrice > 0) order.agreedPrice else 0.0
        val customer = MockDataStore.getUser(order.customerId)?.fullName?.ifBlank { null } ?: "—"
        val provider = MockDataStore.getUser(order.providerId)?.fullName?.ifBlank { null } ?: "—"

        binding.tvInvoiceId.text = "رقم الفاتورة: #${order.id.uppercase()}"
        binding.tvCustomerName.text = customer
        binding.tvProviderName.text = provider
        binding.tvServiceName.text = order.serviceName.ifBlank { "خدمة" }
        binding.tvBaseAmount.text = String.format("%,.0f ج.س", amount)
        binding.tvTotalAmount.text = String.format("%,.0f ج.س", amount)
        val sdf = SimpleDateFormat("yyyy/MM/dd HH:mm", Locale.getDefault())
        binding.tvDate.text = "تاريخ الإصدار: ${sdf.format(Date(order.createdAt))}"

        binding.btnPrintInvoice.setOnClickListener {
            Toast.makeText(this, "معاينة فقط — طباعة PDF في النسخة النهائية", Toast.LENGTH_SHORT).show()
        }

        binding.btnConfirmPayment.setOnClickListener {
            startActivity(
                Intent(this, PaymentConfirmationActivity::class.java)
                    .putExtra("ORDER_ID", orderId)
            )
            finish()
        }
    }
}
