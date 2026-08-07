package amana.example.com.ui.service

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.RadioButton
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.navigation.fragment.findNavController
import amana.core.data.MockDataStore
import amana.core.data.SessionManager
import amana.core.models.Order
import amana.core.models.OrderStatus
import amana.core.models.Service
import amana.example.com.R
import amana.example.com.databinding.FragmentServiceDetailBinding

class ServiceDetailFragment : Fragment() {

    private var _binding: FragmentServiceDetailBinding? = null
    private val binding get() = _binding!!
    private var services: List<Service> = emptyList()
    private var providerId: String = ""

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentServiceDetailBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        SessionManager.init(requireContext().applicationContext)
        MockDataStore.init(requireContext())

        val serviceId = arguments?.getString("serviceId").orEmpty()
        providerId = arguments?.getString("providerId").orEmpty()

        if (providerId.isBlank() && serviceId.isNotBlank()) {
            providerId = MockDataStore.getServices().find { it.id == serviceId }?.providerId.orEmpty()
        }

        val provider = if (providerId.isNotBlank()) MockDataStore.getNearbyProviders()
            .find { it.id == providerId } else null

        binding.tvProviderName.text = provider?.name ?: "مزود الخدمة"
        binding.tvProviderMeta.text = provider?.let { "${it.serviceTitle} • ${it.city}" } ?: ""
        binding.tvRating.text = provider?.let { "★ ${it.rating}" } ?: ""

        services = if (providerId.isNotBlank())
            MockDataStore.getServicesForProvider(providerId)
        else MockDataStore.getServices()

        renderServices(serviceId)

        binding.btnBook.setOnClickListener { submitOrder() }
    }

    private fun renderServices(preselectId: String) {
        binding.rgServices.removeAllViews()
        if (services.isEmpty()) {
            binding.tvNoServices.visibility = View.VISIBLE
            binding.btnBook.isEnabled = false
            return
        }
        binding.tvNoServices.visibility = View.GONE
        binding.btnBook.isEnabled = true
        services.forEachIndexed { index, service ->
            val rb = RadioButton(requireContext()).apply {
                id = View.generateViewId()
                text = "${service.serviceName}  —  ${service.basePrice.toInt()} SDG"
                textSize = 15f
                setPadding(8, 24, 8, 24)
                tag = service.id
                isChecked = service.id == preselectId || (preselectId.isBlank() && index == 0)
            }
            binding.rgServices.addView(rb)
        }
    }

    private fun submitOrder() {
        if (!SessionManager.isLoggedIn) {
            Toast.makeText(context, "يرجى تسجيل الدخول أولاً", Toast.LENGTH_SHORT).show()
            return
        }
        val checkedId = binding.rgServices.checkedRadioButtonId
        val selected = binding.rgServices.findViewById<RadioButton>(checkedId)
        val serviceId = selected?.tag as? String
        val service = services.find { it.id == serviceId } ?: services.firstOrNull()
        if (service == null) {
            Toast.makeText(context, "لا توجد خدمة متاحة للحجز", Toast.LENGTH_SHORT).show()
            return
        }

        val order = Order(
            customerId = SessionManager.userId,
            providerId = providerId.ifBlank { service.providerId },
            serviceId = service.id,
            serviceName = service.serviceName,
            status = OrderStatus.PENDING,
            agreedPrice = service.basePrice,
            createdAt = System.currentTimeMillis()
        )
        val orderId = MockDataStore.createOrder(order)
        if (orderId.isNullOrBlank()) {
            Toast.makeText(context, "تعذّر إنشاء الطلب", Toast.LENGTH_SHORT).show()
            return
        }
        Toast.makeText(context, "تم إرسال طلبك إلى المزود بنجاح", Toast.LENGTH_LONG).show()
        findNavController().navigate(R.id.nav_customer_orders)
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
