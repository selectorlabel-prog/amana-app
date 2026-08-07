package amana.admin.ui

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import amana.admin.DisputeAdapter
import amana.admin.databinding.FragmentAdminDisputesBinding
import amana.core.data.MockDataStore
import amana.core.models.DisputeStatus

class AdminDisputesFragment : Fragment() {

    private var _binding: FragmentAdminDisputesBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentAdminDisputesBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        binding.rvDisputes.layoutManager = LinearLayoutManager(requireContext())
        reload()
    }

    private fun reload() {
        val disputes = MockDataStore.getDisputes()
        val users = MockDataStore.getUsers()

        val open = disputes.count { it.status == DisputeStatus.OPEN }
        val review = disputes.count { it.status == DisputeStatus.UNDER_REVIEW }
        val resolved = disputes.count { it.status == DisputeStatus.RESOLVED }

        binding.tvDisputeCount.text = "$open نزاع مفتوح من ${disputes.size} إجمالي"
        binding.tvStatOpen.text = open.toString()
        binding.tvStatReview.text = review.toString()
        binding.tvStatResolved.text = resolved.toString()

        binding.rvDisputes.adapter = DisputeAdapter(disputes, users) { reload() }
        binding.tvEmpty.visibility = if (disputes.isEmpty()) View.VISIBLE else View.GONE
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
