package amana.admin.ui

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import amana.admin.ActivityLogEntry
import amana.admin.AdminLogAdapter
import amana.admin.databinding.FragmentAdminLogsBinding
import amana.core.data.MockDataStore

class AdminLogsFragment : Fragment() {

    private var _binding: FragmentAdminLogsBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentAdminLogsBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        val logs = buildLogs()
        binding.tvEmpty.visibility = if (logs.isEmpty()) View.VISIBLE else View.GONE
        binding.rvLogs.layoutManager = LinearLayoutManager(requireContext())
        binding.rvLogs.adapter = AdminLogAdapter(logs)
    }

    private fun buildLogs(): List<ActivityLogEntry> {
        val entries = mutableListOf<ActivityLogEntry>()
        MockDataStore.getAllRechargeCodes().take(3).forEach { code ->
            entries.add(ActivityLogEntry("توليد كود شحن", "كود ${code.code} — ${code.amount.toInt()} ج.س", "حديث"))
        }
        MockDataStore.getDisputes().take(3).forEach { d ->
            entries.add(ActivityLogEntry("مراجعة نزاع", "${d.id}: ${d.reason}", "حديث"))
        }
        MockDataStore.getProviderProfiles().filter { it.isVerified }.take(2).forEach { p ->
            val name = MockDataStore.getUser(p.userId)?.fullName ?: p.userId
            entries.add(ActivityLogEntry("اعتماد مزود", "تم اعتماد $name", "حديث"))
        }
        if (entries.isEmpty()) {
            entries.add(ActivityLogEntry("تسجيل دخول", "admin@amana.sd — لوحة التحكم", "الآن"))
        }
        return entries
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
