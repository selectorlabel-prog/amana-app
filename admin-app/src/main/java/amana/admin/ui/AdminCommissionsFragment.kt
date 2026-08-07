package amana.admin.ui

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import amana.admin.AdminTransactionAdapter
import amana.admin.databinding.FragmentAdminCommissionsBinding
import amana.core.data.MockDataStore
import amana.core.models.TransactionType
import amana.core.models.UserRole

class AdminCommissionsFragment : Fragment() {

    private var _binding: FragmentAdminCommissionsBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentAdminCommissionsBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        val stats = MockDataStore.getDashboardStats()
        binding.tvTotalCommission.text = "${stats.totalCommission.toInt()} ج.س"
        binding.tvStatProviders.text = stats.totalProviders.toString()
        binding.tvStatOrders.text = stats.activeOrders.toString()

        val commissions = allTransactions()
            .filter { it.type == TransactionType.COMMISSION_DEDUCTION }

        binding.tvEmpty.visibility = if (commissions.isEmpty()) View.VISIBLE else View.GONE
        binding.rvCommissions.layoutManager = LinearLayoutManager(requireContext())
        binding.rvCommissions.adapter = AdminTransactionAdapter(commissions)
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
