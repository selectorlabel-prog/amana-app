package amana.example.com.ui.wallet

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import amana.core.data.MockDataStore
import amana.core.data.SessionManager
import amana.core.models.UserRole
import amana.example.com.databinding.FragmentWalletBinding
import amana.example.com.ui.home.TransactionAdapter

class WalletFragment : Fragment() {

    private var _binding: FragmentWalletBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentWalletBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        if (SessionManager.userRole != UserRole.PROVIDER) {
            binding.tvProviderOnly.visibility = View.VISIBLE
            binding.layoutRecharge.visibility = View.GONE
        }

        binding.btnRecharge.setOnClickListener {
            val code = binding.etRechargeCode.text.toString().uppercase().trim()
            if (code.isEmpty()) {
                binding.etRechargeCode.error = "يرجى إدخال الكود"
                return@setOnClickListener
            }
            redeemCode(code)
        }

        refreshBalance()
    }

    override fun onResume() {
        super.onResume()
        refreshBalance()
    }

    private fun refreshBalance() {
        val userId = SessionManager.userId
        val balance = MockDataStore.getWalletBalance(userId)
        binding.tvBalance.text = String.format("%,.0f SDG", balance)

        val transactions = MockDataStore.getTransactionsForProvider(userId)
        binding.tvEmptyTransactions.visibility =
            if (transactions.isEmpty()) View.VISIBLE else View.GONE
        binding.rvTransactions.layoutManager = LinearLayoutManager(requireContext())
        binding.rvTransactions.adapter = TransactionAdapter(transactions)
    }

    private fun redeemCode(code: String) {
        when (val result = MockDataStore.redeemCode(code, SessionManager.userId)) {
            is MockDataStore.RedeemResult.Success -> {
                Toast.makeText(context, "تم شحن ${result.amount.toInt()} SDG بنجاح!", Toast.LENGTH_LONG).show()
                binding.etRechargeCode.text?.clear()
                refreshBalance()
            }
            is MockDataStore.RedeemResult.Error -> {
                Toast.makeText(context, result.message, Toast.LENGTH_LONG).show()
            }
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
