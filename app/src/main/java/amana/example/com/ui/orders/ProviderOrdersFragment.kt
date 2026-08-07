package amana.example.com.ui.orders

import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import amana.core.AmanaConstants
import amana.core.data.MockDataStore
import amana.core.data.SessionManager
import amana.core.models.AppNotification
import amana.core.models.Order
import amana.core.models.OrderStatus
import amana.example.com.databinding.FragmentProviderOrdersBinding
import amana.example.com.databinding.ItemProviderOrderBinding
import amana.example.com.ui.wallet.InsufficientBalanceActivity

class ProviderOrdersFragment : Fragment() {

    private var _binding: FragmentProviderOrdersBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentProviderOrdersBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        refreshOrders()
    }

    override fun onResume() {
        super.onResume()
        refreshOrders()
    }

    private fun refreshOrders() {
        val orders = MockDataStore.getNewOrdersForProvider(SessionManager.userId)
        binding.tvOrdersCount.text = "${orders.size} طلبات"
        if (orders.isEmpty()) {
            binding.tvEmpty.visibility = View.VISIBLE
            binding.rvOrders.visibility = View.GONE
        } else {
            binding.tvEmpty.visibility = View.GONE
            binding.rvOrders.visibility = View.VISIBLE
            binding.rvOrders.layoutManager = LinearLayoutManager(requireContext())
            binding.rvOrders.adapter = ProviderOrderAdapter(
                orders,
                onAccept = { order -> acceptOrder(order) },
                onReject = { order -> rejectOrder(order) }
            )
        }
    }

    private fun acceptOrder(order: Order) {
        val price = if (order.agreedPrice > 0) order.agreedPrice else 15000.0
        val commission = price * AmanaConstants.COMMISSION_RATE
        val balance = MockDataStore.getWalletBalance(SessionManager.userId)
        if (balance < commission) {
            startActivity(
                Intent(requireContext(), InsufficientBalanceActivity::class.java)
                    .putExtra("ORDER_PRICE", price)
            )
            return
        }
        MockDataStore.updateOrderStatus(order.id, OrderStatus.ACCEPTED)
        MockDataStore.addNotification(
            AppNotification(
                userId = order.customerId,
                title = "تم قبول طلبك",
                body = "قَبِل المزود طلبك: ${order.serviceName}",
                timeAgo = "الآن",
                type = "ORDER"
            )
        )
        Toast.makeText(context, "تم قبول الطلب", Toast.LENGTH_SHORT).show()
        refreshOrders()
    }

    private fun rejectOrder(order: Order) {
        MockDataStore.updateOrderStatus(order.id, OrderStatus.CANCELLED)
        MockDataStore.addNotification(
            AppNotification(
                userId = order.customerId,
                title = "تم رفض الطلب",
                body = "اعتذر المزود عن تنفيذ: ${order.serviceName}",
                timeAgo = "الآن",
                type = "ORDER"
            )
        )
        Toast.makeText(context, "تم رفض الطلب", Toast.LENGTH_SHORT).show()
        refreshOrders()
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }

    private class ProviderOrderAdapter(
        private val items: List<Order>,
        private val onAccept: (Order) -> Unit,
        private val onReject: (Order) -> Unit
    ) : RecyclerView.Adapter<ProviderOrderAdapter.ViewHolder>() {

        inner class ViewHolder(private val binding: ItemProviderOrderBinding) :
            RecyclerView.ViewHolder(binding.root) {
            fun bind(order: Order) {
                binding.tvServiceName.text = order.serviceName
                binding.tvStatus.text = when (order.status) {
                    OrderStatus.PENDING -> "طلب جديد - بانتظار قبولك"
                    else -> order.status.name
                }
                val price = if (order.agreedPrice > 0) order.agreedPrice else 0.0
                binding.tvPrice.text = if (price > 0) "${price.toInt()} SDG" else "السعر عند التفاوض"
                binding.btnAccept.setOnClickListener { onAccept(order) }
                binding.btnReject.setOnClickListener { onReject(order) }
            }
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            val binding = ItemProviderOrderBinding.inflate(LayoutInflater.from(parent.context), parent, false)
            return ViewHolder(binding)
        }

        override fun onBindViewHolder(holder: ViewHolder, position: Int) = holder.bind(items[position])
        override fun getItemCount(): Int = items.size
    }
}
