package amana.admin.ui

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import amana.admin.AdminReviewAdapter
import amana.admin.databinding.FragmentAdminReviewsBinding
import amana.core.data.MockDataStore

class AdminReviewsFragment : Fragment() {

    private var _binding: FragmentAdminReviewsBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentAdminReviewsBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        val reviews = MockDataStore.getReviews()
        binding.tvEmpty.visibility = if (reviews.isEmpty()) View.VISIBLE else View.GONE
        binding.rvReviews.layoutManager = LinearLayoutManager(requireContext())
        binding.rvReviews.adapter = AdminReviewAdapter(reviews)
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
