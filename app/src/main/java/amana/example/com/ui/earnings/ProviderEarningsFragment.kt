package amana.example.com.ui.earnings

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import amana.core.data.MockDataStore
import amana.core.data.SessionManager
import amana.core.models.OrderStatus
import amana.core.models.TransactionType
import amana.example.com.databinding.FragmentProviderEarningsBinding
import amana.example.com.ui.home.TransactionAdapter

class ProviderEarningsFragment : Fragment() {

    private var _binding: FragmentProviderEarningsBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentProviderEarningsBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        refreshEarnings()
    }

    override fun onResume() {
        super.onResume()
        refreshEarnings()
    }

    private fun refreshEarnings() {
        val userId = SessionManager.userId
        val transactions = MockDataStore.getTransactionsForProvider(userId)

        val revenue = transactions
            .filter { it.type == TransactionType.DEPOSIT }
            .sumOf { it.amount }
        val commission = transactions
            .filter { it.type == TransactionType.COMMISSION_DEDUCTION }
            .sumOf { kotlin.math.abs(it.amount) }
        val netProfit = revenue - commission
        val completedCount = MockDataStore.getOrdersForProvider(userId)
            .count { it.status == OrderStatus.COMPLETED }

        binding.tvTotalEarnings.text = String.format("%,.0f", netProfit)
        binding.tvRevenue.text = String.format("%,.0f", revenue)
        binding.tvCommission.text = String.format("-%,.0f", commission)
        binding.tvCompletedCount.text = "$completedCount طلب مكتمل"

        binding.tvEmptyTransactions.visibility =
            if (transactions.isEmpty()) View.VISIBLE else View.GONE
        binding.rvTransactions.layoutManager = LinearLayoutManager(requireContext())
        binding.rvTransactions.adapter = TransactionAdapter(transactions)
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
