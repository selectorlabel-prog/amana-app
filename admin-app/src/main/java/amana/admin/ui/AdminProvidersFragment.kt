package amana.admin.ui

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.core.widget.doAfterTextChanged
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import amana.admin.AdminProviderAdapter
import amana.admin.R
import amana.admin.databinding.FragmentAdminProvidersBinding
import amana.core.data.MockDataStore
import amana.core.models.ProviderProfile
import amana.core.models.User

class AdminProvidersFragment : Fragment() {

    private var _binding: FragmentAdminProvidersBinding? = null
    private val binding get() = _binding!!

    private var allProviders: List<ProviderProfile> = emptyList()
    private var allUsers: List<User> = emptyList()

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentAdminProvidersBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        binding.rvProviders.layoutManager = LinearLayoutManager(requireContext())
        reload()

        binding.etSearch.doAfterTextChanged { applyFilter() }
        binding.chipGroupStatus.setOnCheckedStateChangeListener { _, _ -> applyFilter() }
    }

    private fun reload() {
        allProviders = MockDataStore.getProviderProfiles()
        allUsers = MockDataStore.getUsers()
        applyFilter()
    }

    private fun applyFilter() {
        val query = binding.etSearch.text?.toString()?.trim().orEmpty()
        val filtered = allProviders.filter { p ->
            val matchesStatus = when (binding.chipGroupStatus.checkedChipId) {
                R.id.chip_pending -> !p.isVerified
                R.id.chip_verified -> p.isVerified
                else -> true
            }
            val name = allUsers.find { it.id == p.userId }?.fullName ?: p.userId
            val matchesQuery = query.isEmpty() || name.contains(query, ignoreCase = true)
            matchesStatus && matchesQuery
        }
        binding.rvProviders.adapter = AdminProviderAdapter(filtered, allUsers) {
            Toast.makeText(requireContext(), "تم اعتماد المزود", Toast.LENGTH_SHORT).show()
            reload()
        }
        binding.tvEmpty.visibility = if (filtered.isEmpty()) View.VISIBLE else View.GONE
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
