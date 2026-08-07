package amana.admin.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import amana.admin.AdminRechargeCodeAdapter
import amana.admin.databinding.FragmentAdminRechargeBinding
import amana.core.data.MockDataStore

class AdminRechargeFragment : Fragment() {

    private var _binding: FragmentAdminRechargeBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentAdminRechargeBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        binding.rvCodes.layoutManager = LinearLayoutManager(requireContext())
        loadCodes()

        binding.btnGenerateCode.setOnClickListener {
            val amountStr = binding.etAmount.text.toString()
            if (amountStr.isEmpty()) {
                binding.etAmount.error = "أدخل المبلغ"
                return@setOnClickListener
            }
            val amount = amountStr.toDoubleOrNull()
            if (amount == null || amount <= 0) {
                Toast.makeText(requireContext(), "مبلغ غير صحيح", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }
            val code = MockDataStore.generateRechargeCode(amount)
            if (code.isBlank()) {
                Toast.makeText(requireContext(), "تعذّر توليد الكود", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }
            binding.cardResult.visibility = View.VISIBLE
            binding.tvGeneratedCode.text = code
            Toast.makeText(requireContext(), "تم توليد الكود", Toast.LENGTH_SHORT).show()
            loadCodes()
        }

        binding.btnCopyCode.setOnClickListener {
            val code = binding.tvGeneratedCode.text?.toString().orEmpty()
            if (code.isNotBlank()) {
                val clipboard = requireContext()
                    .getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                clipboard.setPrimaryClip(ClipData.newPlainText("code", code))
                Toast.makeText(requireContext(), "تم نسخ الكود", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun loadCodes() {
        val codes = MockDataStore.getAllRechargeCodes()
        binding.rvCodes.adapter = AdminRechargeCodeAdapter(codes)
        binding.tvCodesEmpty.visibility = if (codes.isEmpty()) View.VISIBLE else View.GONE
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
