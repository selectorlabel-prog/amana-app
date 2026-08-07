package amana.example.com.ui.profile

import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.navigation.fragment.findNavController
import amana.core.data.MockDataStore
import amana.core.data.SessionManager
import amana.core.models.UserRole
import amana.example.com.R
import amana.example.com.databinding.FragmentProfileBinding
import amana.example.com.ui.auth.PhoneAuthActivity

class ProfileFragment : Fragment() {

    private var _binding: FragmentProfileBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentProfileBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        SessionManager.init(requireContext().applicationContext)
        MockDataStore.init(requireContext())
        val user = SessionManager.currentUser
        binding.tvName.text = user?.fullName?.takeIf { it.isNotBlank() } ?: "زائر"
        binding.tvPhone.text = user?.phoneNumber?.takeIf { it.isNotBlank() } ?: "لم يتم إضافة رقم"
        val location = listOfNotNull(
            user?.city?.takeIf { it.isNotBlank() },
            user?.district?.takeIf { it.isNotBlank() }
        ).joinToString(" - ")
        binding.tvLocation.text = location.ifBlank { "لم يتم تحديد الموقع" }

        if (SessionManager.userRole == UserRole.PROVIDER) {
            binding.tvWallet.visibility = View.VISIBLE
            val balance = MockDataStore.getWalletBalance(SessionManager.userId)
            binding.tvWallet.text = "رصيد المحفظة: ${String.format("%,.0f", balance)} SDG"
        }

        binding.btnSettings.setOnClickListener {
            findNavController().navigate(R.id.nav_settings)
        }
        binding.btnSupport.setOnClickListener {
            findNavController().navigate(R.id.nav_support)
        }
        binding.btnLogout.setOnClickListener {
            SessionManager.logout()
            startActivity(Intent(requireContext(), PhoneAuthActivity::class.java))
            requireActivity().finish()
        }
    }

    override fun onResume() {
        super.onResume()
        if (SessionManager.userRole == UserRole.PROVIDER) {
            val balance = MockDataStore.getWalletBalance(SessionManager.userId)
            binding.tvWallet.text = "رصيد المحفظة: ${String.format("%,.0f", balance)} SDG"
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
