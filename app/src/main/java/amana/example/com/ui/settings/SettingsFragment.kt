package amana.example.com.ui.settings

import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import amana.core.data.SessionManager
import amana.example.com.databinding.FragmentSettingsBinding
import amana.example.com.ui.auth.PhoneAuthActivity

class SettingsFragment : Fragment() {

    private var _binding: FragmentSettingsBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentSettingsBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        val user = SessionManager.currentUser
        binding.tvAccountName.text = user?.fullName?.takeIf { it.isNotBlank() } ?: "زائر"
        val sub = listOfNotNull(
            user?.phoneNumber?.takeIf { it.isNotBlank() },
            user?.city?.takeIf { it.isNotBlank() }
        ).joinToString(" • ")
        binding.tvAccountSub.text = sub.ifBlank { "أكمل بيانات حسابك" }

        binding.btnLogout.setOnClickListener {
            SessionManager.logout()
            startActivity(Intent(requireContext(), PhoneAuthActivity::class.java))
            requireActivity().finish()
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
