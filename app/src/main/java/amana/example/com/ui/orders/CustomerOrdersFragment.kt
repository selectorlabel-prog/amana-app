package amana.example.com.ui.orders

import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import amana.core.data.MockDataStore
import amana.core.data.SessionManager
import amana.core.models.Order
import amana.core.models.OrderStatus
import amana.example.com.R
import amana.example.com.databinding.FragmentCustomerOrdersBinding
import amana.example.com.databinding.ItemCustomerOrderBinding
import amana.example.com.ui.chat.ChatActivity
import amana.example.com.ui.tracking.TrackingActivity
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class CustomerOrdersFragment : Fragment() {

    private var _binding: FragmentCustomerOrdersBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentCustomerOrdersBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        render()
    }

    override fun onResume() {
        super.onResume()
        render()
    }

    private fun render() {
        val orders = MockDataStore.getOrdersForCustomer(SessionManager.userId)
            .sortedByDescending { it.createdAt }
        if (orders.isEmpty()) {
            binding.tvEmpty.visibility = View.VISIBLE
            binding.rvOrders.visibility = View.GONE
            return
        }
        binding.tvEmpty.visibility = View.GONE
        binding.rvOrders.visibility = View.VISIBLE
        val providerNames = MockDataStore.getNearbyProviders().associate { it.id to it.name }
        binding.rvOrders.layoutManager = LinearLayoutManager(requireContext())
        binding.rvOrders.adapter = CustomerOrderAdapter(orders, providerNames)
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }

    private class CustomerOrderAdapter(
        private val items: List<Order>,
        private val providerNames: Map<String, String>
    ) : RecyclerView.Adapter<CustomerOrderAdapter.ViewHolder>() {

        private val dateFormat = SimpleDateFormat("d MMM yyyy • hh:mm a", Locale("ar"))

        inner class ViewHolder(private val binding: ItemCustomerOrderBinding) :
            RecyclerView.ViewHolder(binding.root) {
            fun bind(order: Order) {
                val ctx = binding.root.context
                binding.tvServiceName.text = order.serviceName.ifBlank { "طلب خدمة" }
                binding.tvProvider.text = providerNames[order.providerId] ?: "مزود الخدمة"
                binding.tvStatus.text = orderStatusLabel(order.status)
                binding.tvStatus.setBackgroundResource(statusPill(order.status))
                binding.tvStatus.setTextColor(ContextCompat.getColor(ctx, statusTextColor(order.status)))
                binding.tvDate.text = dateFormat.format(Date(order.createdAt))
                binding.tvPrice.text = if (order.agreedPrice > 0)
                    "${order.agreedPrice.toInt()} ج.س" else "قيد التفاوض"
                binding.btnChat.setOnClickListener {
                    ctx.startActivity(
                        Intent(ctx, ChatActivity::class.java).putExtra("ORDER_ID", order.id)
                    )
                }
                binding.btnTracking.setOnClickListener {
                    ctx.startActivity(
                        Intent(ctx, TrackingActivity::class.java).putExtra("ORDER_ID", order.id)
                    )
                }
            }
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            val binding = ItemCustomerOrderBinding.inflate(LayoutInflater.from(parent.context), parent, false)
            return ViewHolder(binding)
        }

        override fun onBindViewHolder(holder: ViewHolder, position: Int) = holder.bind(items[position])
        override fun getItemCount(): Int = items.size

        private fun orderStatusLabel(status: OrderStatus): String = when (status) {
            OrderStatus.PENDING -> "قيد الانتظار"
            OrderStatus.NEGOTIATING -> "قيد التفاوض"
            OrderStatus.ACCEPTED -> "مقبول"
            OrderStatus.IN_PROGRESS -> "جاري التنفيذ"
            OrderStatus.COMPLETED -> "مكتمل"
            OrderStatus.CANCELLED -> "ملغي"
        }

        private fun statusPill(status: OrderStatus): Int = when (status) {
            OrderStatus.COMPLETED -> R.drawable.bg_pill_success
            OrderStatus.CANCELLED -> R.drawable.bg_pill_error
            OrderStatus.PENDING, OrderStatus.NEGOTIATING -> R.drawable.bg_pill_amber
            else -> R.drawable.bg_pill_primary
        }

        private fun statusTextColor(status: OrderStatus): Int = when (status) {
            OrderStatus.COMPLETED -> R.color.success_green
            OrderStatus.CANCELLED -> R.color.error
            OrderStatus.PENDING, OrderStatus.NEGOTIATING -> R.color.secondary
            else -> R.color.primary
        }
    }
}
