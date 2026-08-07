package amana.example.com.ui.home

import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.navigation.fragment.findNavController
import androidx.recyclerview.widget.LinearLayoutManager
import amana.core.data.MockDataStore
import amana.core.data.SessionManager
import amana.core.models.TransactionType
import amana.example.com.R
import amana.example.com.databinding.FragmentProviderHomeBinding
import amana.example.com.ui.chat.ChatActivity

class ProviderHomeFragment : Fragment() {

    private var _binding: FragmentProviderHomeBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentProviderHomeBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        SessionManager.init(requireContext().applicationContext)
        MockDataStore.init(requireContext())

        val user = SessionManager.currentUser
        binding.tvWelcome.text = "مرحباً، ${user?.fullName ?: "مقدم الخدمة"}"

        binding.btnWallet.setOnClickListener {
            findNavController().navigate(R.id.nav_wallet)
        }

        binding.switchWorkMode.setOnCheckedChangeListener { _, isChecked ->
            binding.tvStatus.text = if (isChecked) {
                "أنت متصل الآن وجاهز لاستقبال الطلبات"
            } else {
                "وضع العمل متوقف — لن تصلك طلبات جديدة"
            }
            binding.tvStatus.setTextColor(
                requireContext().getColor(
                    if (isChecked) R.color.success_green else R.color.outline
                )
            )
        }

        binding.btnEarnings.setOnClickListener {
            findNavController().navigate(R.id.nav_provider_earnings)
        }
        binding.btnOnboarding.setOnClickListener {
            findNavController().navigate(R.id.nav_provider_onboarding)
        }

        refreshDashboard()
    }

    override fun onResume() {
        super.onResume()
        refreshDashboard()
    }

    private fun refreshDashboard() {
        try {
            val userId = SessionManager.userId
            if (userId.isBlank()) return
        val balance = MockDataStore.getWalletBalance(userId)
        val activeOrders = MockDataStore.getActiveOrdersForProvider(userId)
        val transactions = MockDataStore.getTransactionsForProvider(userId)

        val totalEarnings = transactions
            .filter { it.type == TransactionType.DEPOSIT }
            .sumOf { it.amount }
        val rating = MockDataStore.getProviderProfile(userId)?.ratingAvg ?: 0.0

        binding.tvBalance.text = String.format("%,.0f SDG", balance)
        binding.tvTodayOrders.text = activeOrders.size.toString()
        binding.tvWeekEarnings.text = String.format("%,.0f", totalEarnings)
        binding.tvRating.text = String.format("%.1f", rating)

        if (activeOrders.isEmpty()) {
            binding.rvActiveOrders.visibility = View.GONE
            binding.tvNoOrders.visibility = View.VISIBLE
        } else {
            binding.rvActiveOrders.visibility = View.VISIBLE
            binding.tvNoOrders.visibility = View.GONE
            binding.rvActiveOrders.layoutManager = LinearLayoutManager(requireContext())
            binding.rvActiveOrders.adapter = OrderSummaryAdapter(activeOrders) { order ->
                startActivity(
                    Intent(requireContext(), ChatActivity::class.java).putExtra("ORDER_ID", order.id)
                )
            }
        }

        binding.rvRecentTransactions.layoutManager = LinearLayoutManager(requireContext())
        binding.rvRecentTransactions.adapter = TransactionAdapter(transactions)
        } catch (e: Exception) {
            binding.tvNoOrders.visibility = View.VISIBLE
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
