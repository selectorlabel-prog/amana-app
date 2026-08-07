package amana.admin.ui

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.navigation.fragment.findNavController
import androidx.recyclerview.widget.LinearLayoutManager
import amana.admin.AdminAlertAdapter
import amana.admin.R
import amana.admin.databinding.FragmentAdminDashboardBinding
import amana.core.data.MockDataStore

class AdminDashboardFragment : Fragment() {

    private var _binding: FragmentAdminDashboardBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentAdminDashboardBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        val stats = MockDataStore.getDashboardStats()
        binding.tvStatUsers.text = formatCount(stats.totalUsers)
        binding.tvStatOrders.text = formatCount(stats.activeOrders)
        binding.tvStatDisputes.text = formatCount(stats.openDisputes)
        binding.tvStatCommission.text = "%,d".format(stats.totalCommission.toLong())

        val alerts = MockDataStore.getAdminAlerts()
        binding.rvAlerts.layoutManager = LinearLayoutManager(requireContext())
        binding.rvAlerts.adapter = AdminAlertAdapter(alerts)
        binding.tvAlertsEmpty.visibility = if (alerts.isEmpty()) View.VISIBLE else View.GONE

        binding.btnQuickProviders.setOnClickListener {
            findNavController().navigate(R.id.adminProvidersFragment)
        }
        binding.btnQuickDisputes.setOnClickListener {
            findNavController().navigate(R.id.adminDisputesFragment)
        }
    }

    private fun formatCount(value: Int): String = "%,d".format(value)

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
