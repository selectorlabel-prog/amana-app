package amana.admin.ui

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.core.widget.doAfterTextChanged
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import amana.admin.AdminUserAdapter
import amana.admin.R
import amana.admin.databinding.FragmentAdminUsersBinding
import amana.core.data.MockDataStore
import amana.core.models.User
import amana.core.models.UserRole
import amana.core.models.UserStatus

class AdminUsersFragment : Fragment() {

    private var _binding: FragmentAdminUsersBinding? = null
    private val binding get() = _binding!!

    private var allUsers: List<User> = emptyList()

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentAdminUsersBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        binding.rvUsers.layoutManager = LinearLayoutManager(requireContext())
        allUsers = MockDataStore.getUsers()

        binding.etSearch.doAfterTextChanged { applyFilter() }
        binding.chipGroupRole.setOnCheckedStateChangeListener { _, _ -> applyFilter() }

        applyFilter()
    }

    private fun applyFilter() {
        val query = binding.etSearch.text?.toString()?.trim().orEmpty()
        val filtered = allUsers.filter { user ->
            val matchesRole = when (binding.chipGroupRole.checkedChipId) {
                R.id.chip_customers -> user.role == UserRole.CUSTOMER
                R.id.chip_providers -> user.role == UserRole.PROVIDER
                R.id.chip_suspended -> user.status == UserStatus.SUSPENDED
                else -> true
            }
            val matchesQuery = query.isEmpty() ||
                user.fullName.contains(query, ignoreCase = true) ||
                user.phoneNumber.contains(query, ignoreCase = true)
            matchesRole && matchesQuery
        }
        binding.rvUsers.adapter = AdminUserAdapter(filtered)
        binding.tvEmpty.visibility = if (filtered.isEmpty()) View.VISIBLE else View.GONE
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
