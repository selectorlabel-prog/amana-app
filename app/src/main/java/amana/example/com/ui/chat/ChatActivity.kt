package amana.example.com.ui.chat

import android.os.Bundle
import android.view.View
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import amana.core.AmanaConstants
import amana.core.data.MockDataStore
import amana.core.data.SessionManager
import amana.core.models.Message
import amana.core.models.MessageType
import amana.core.models.UserRole
import amana.example.com.databinding.ActivityChatBinding
import java.util.UUID

class ChatActivity : AppCompatActivity() {

    private lateinit var binding: ActivityChatBinding
    private lateinit var adapter: ChatAdapter
    private var orderId = "order_1"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityChatBinding.inflate(layoutInflater)
        setContentView(binding.root)

        orderId = intent.getStringExtra("ORDER_ID") ?: "order_1"
        setSupportActionBar(binding.toolbarChat)
        MockDataStore.getOrder(orderId)?.let { order ->
            val otherId = if (SessionManager.userRole == UserRole.PROVIDER) order.customerId else order.providerId
            val otherName = MockDataStore.getUser(otherId)?.fullName?.ifBlank { null }
                ?: order.serviceName.ifBlank { "محادثة الطلب" }
            supportActionBar?.title = otherName
            supportActionBar?.subtitle = "طلب #${order.id.uppercase()}"
        }

        setupRecyclerView()
        refreshMessages()

        binding.btnSend.setOnClickListener {
            val text = binding.etMessage.text.toString().trim()
            if (text.isNotEmpty()) sendMessage(text)
        }

        if (SessionManager.userRole == UserRole.PROVIDER) {
            binding.btnPriceOffer.visibility = View.VISIBLE
            binding.btnPriceOffer.setOnClickListener { showPriceOfferDialog() }
        }
    }

    private fun setupRecyclerView() {
        adapter = ChatAdapter(SessionManager.userId)
        binding.rvMessages.layoutManager = LinearLayoutManager(this).apply { stackFromEnd = true }
        binding.rvMessages.adapter = adapter
    }

    private fun refreshMessages() {
        val messages = MockDataStore.getMessages(orderId)
        adapter.submitList(messages)
        binding.tvEmptyChat.visibility = if (messages.isEmpty()) View.VISIBLE else View.GONE
        if (messages.isNotEmpty()) {
            binding.rvMessages.scrollToPosition(messages.size - 1)
        }
    }

    private fun sendMessage(content: String) {
        val message = Message(
            id = UUID.randomUUID().toString(),
            orderId = orderId,
            senderId = SessionManager.userId,
            content = content,
            type = MessageType.TEXT
        )
        MockDataStore.addMessage(message)
        binding.etMessage.text.clear()
        refreshMessages()
    }

    private fun showPriceOfferDialog() {
        val input = android.widget.EditText(this).apply {
            hint = "السعر بالجنيه (SDG)"
            inputType = android.text.InputType.TYPE_CLASS_NUMBER
        }
        AlertDialog.Builder(this)
            .setTitle("إرسال عرض سعر")
            .setMessage("العمولة ${(AmanaConstants.COMMISSION_RATE * 100).toInt()}% تُخصم عند قبول العرض")
            .setView(input)
            .setPositiveButton("إرسال") { _, _ ->
                val price = input.text.toString().toDoubleOrNull()
                if (price == null || price <= 0) {
                    Toast.makeText(this, "أدخل سعراً صحيحاً", Toast.LENGTH_SHORT).show()
                    return@setPositiveButton
                }
                submitPriceOffer(price)
            }
            .setNegativeButton("إلغاء", null)
            .show()
    }

    private fun submitPriceOffer(price: Double) {
        when (val result = MockDataStore.sendPriceOffer(orderId, SessionManager.userId, price)) {
            is MockDataStore.PriceOfferResult.Success -> {
                Toast.makeText(this, "تم إرسال عرض $price SDG", Toast.LENGTH_SHORT).show()
                refreshMessages()
            }
            is MockDataStore.PriceOfferResult.InsufficientBalance -> {
                AlertDialog.Builder(this)
                    .setTitle("رصيد غير كافٍ")
                    .setMessage(
                        "تحتاج ${result.requiredCommission} SDG عمولة.\n" +
                            "رصيدك: ${result.currentBalance} SDG\n\n" +
                            "يرجى شحن المحفظة بكود من المشرف."
                    )
                    .setPositiveButton("حسناً", null)
                    .show()
            }
            is MockDataStore.PriceOfferResult.Error -> {
                Toast.makeText(this, result.message, Toast.LENGTH_SHORT).show()
            }
        }
    }
}
