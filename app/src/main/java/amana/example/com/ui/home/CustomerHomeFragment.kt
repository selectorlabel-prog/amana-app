package amana.example.com.ui.home

import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.core.os.bundleOf
import androidx.fragment.app.Fragment
import androidx.navigation.fragment.findNavController
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.LinearLayoutManager
import amana.core.data.MockDataStore
import amana.core.data.SessionManager
import amana.core.models.Order
import amana.core.models.OrderStatus
import amana.example.com.R
import amana.example.com.databinding.FragmentCustomerHomeBinding
import amana.example.com.ui.tracking.TrackingActivity

class CustomerHomeFragment : Fragment() {

    private var _binding: FragmentCustomerHomeBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentCustomerHomeBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        SessionManager.init(requireContext().applicationContext)
        MockDataStore.init(requireContext())

        val firstName = SessionManager.currentUser?.fullName
            ?.trim()?.split(" ")?.firstOrNull().orEmpty()
        binding.tvGreeting.text = if (firstName.isNotBlank())
            "مرحباً $firstName، كيف يمكننا مساعدتك؟"
        else "مرحباً، كيف يمكننا مساعدتك اليوم؟"

        binding.rvCategories.layoutManager = GridLayoutManager(requireContext(), 4)
        binding.rvCategories.adapter = ServiceCategoryAdapter(MockDataStore.getCategories()) {
            findNavController().navigate(R.id.nav_search)
        }

        binding.etSearch.setOnClickListener { findNavController().navigate(R.id.nav_search) }
        binding.btnSearch.setOnClickListener { findNavController().navigate(R.id.nav_search) }
        binding.tvViewAll.setOnClickListener { findNavController().navigate(R.id.nav_search) }
        binding.tvProvidersMore.setOnClickListener { findNavController().navigate(R.id.nav_search) }

        // العروض التجريبية غير مفعّلة في وضع البيانات الحقيقية
        binding.btnTrackOrder.visibility = View.GONE
    }

    override fun onResume() {
        super.onResume()
        renderProviders()
        renderActiveOrder()
    }

    private fun renderProviders() {
        val providers = MockDataStore.getNearbyProviders()
        binding.tvProvidersEmpty.visibility = if (providers.isEmpty()) View.VISIBLE else View.GONE
        binding.rvProviders.visibility = if (providers.isEmpty()) View.GONE else View.VISIBLE
        binding.rvProviders.layoutManager =
            LinearLayoutManager(requireContext(), LinearLayoutManager.HORIZONTAL, false)
        binding.rvProviders.adapter = ProviderListingAdapter(providers) { provider ->
            findNavController().navigate(
                R.id.nav_service_detail,
                bundleOf("providerId" to provider.id)
            )
        }
    }

    private fun renderActiveOrder() {
        val active = MockDataStore.getOrdersForCustomer(SessionManager.userId)
            .firstOrNull { it.status != OrderStatus.COMPLETED && it.status != OrderStatus.CANCELLED }
        if (active == null) {
            binding.cardActiveOrder.visibility = View.GONE
            return
        }
        binding.cardActiveOrder.visibility = View.VISIBLE
        binding.tvActiveService.text = active.serviceName
        binding.tvActiveStatus.text = statusText(active)
        val open = View.OnClickListener {
            startActivity(
                Intent(requireContext(), TrackingActivity::class.java)
                    .putExtra("ORDER_ID", active.id)
            )
        }
        binding.cardActiveOrder.setOnClickListener(open)
        binding.tvTrackOrder.setOnClickListener(open)
    }

    private fun statusText(order: Order): String = when (order.status) {
        OrderStatus.PENDING -> "بانتظار قبول المزود"
        OrderStatus.NEGOTIATING -> "قيد التفاوض على السعر"
        OrderStatus.ACCEPTED -> "تم القبول - في الطريق إليك"
        OrderStatus.IN_PROGRESS -> "جاري تنفيذ الخدمة"
        else -> ""
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
