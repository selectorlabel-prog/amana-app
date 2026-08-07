package amana.admin.ui

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import amana.admin.AdminTransactionAdapter
import amana.admin.databinding.FragmentAdminReportsBinding
import amana.core.data.MockDataStore
import amana.core.models.TransactionType
import amana.core.models.UserRole

class AdminReportsFragment : Fragment() {

    private var _binding: FragmentAdminReportsBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentAdminReportsBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        val transactions = allTransactions()
        val revenue = transactions
            .filter { it.type == TransactionType.DEPOSIT }
            .sumOf { it.amount }
        val stats = MockDataStore.getDashboardStats()

        binding.tvTotalRevenue.text = "${revenue.toInt()} ج.س"
        binding.tvActiveUsers.text = stats.totalUsers.toString()

        binding.tvEmpty.visibility = if (transactions.isEmpty()) View.VISIBLE else View.GONE
        binding.rvTransactions.layoutManager = LinearLayoutManager(requireContext())
        binding.rvTransactions.adapter = AdminTransactionAdapter(transactions)
    }

    private fun allTransactions() =
        MockDataStore.getUsers()
            .filter { it.role == UserRole.PROVIDER }
            .flatMap { MockDataStore.getTransactionsForProvider(it.id) }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
