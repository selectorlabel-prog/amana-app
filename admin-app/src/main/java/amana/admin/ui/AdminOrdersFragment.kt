package amana.admin.ui

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import amana.admin.AdminOrderAdapter
import amana.admin.R
import amana.admin.databinding.FragmentAdminOrdersBinding
import amana.core.data.MockDataStore
import amana.core.models.Order
import amana.core.models.OrderStatus

class AdminOrdersFragment : Fragment() {

    private var _binding: FragmentAdminOrdersBinding? = null
    private val binding get() = _binding!!

    private var allOrders: List<Order> = emptyList()

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentAdminOrdersBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        binding.rvOrders.layoutManager = LinearLayoutManager(requireContext())
        allOrders = MockDataStore.getAllOrders()
        binding.tvOrdersCount.text = "إجمالي ${allOrders.size} طلب على المنصة"

        binding.chipGroupStatus.setOnCheckedStateChangeListener { _, _ -> applyFilter() }
        applyFilter()
    }

    private fun applyFilter() {
        val activeStatuses = setOf(
            OrderStatus.PENDING, OrderStatus.NEGOTIATING,
            OrderStatus.ACCEPTED, OrderStatus.IN_PROGRESS
        )
        val filtered = allOrders.filter { order ->
            when (binding.chipGroupStatus.checkedChipId) {
                R.id.chip_active -> order.status in activeStatuses
                R.id.chip_completed -> order.status == OrderStatus.COMPLETED
                R.id.chip_cancelled -> order.status == OrderStatus.CANCELLED
                else -> true
            }
        }
        binding.rvOrders.adapter = AdminOrderAdapter(filtered)
        binding.tvEmpty.visibility = if (filtered.isEmpty()) View.VISIBLE else View.GONE
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
