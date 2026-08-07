package amana.example.com.ui.review

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.fragment.app.DialogFragment
import amana.core.models.Review
import amana.example.com.databinding.DialogReviewBinding
import java.util.UUID

class ReviewDialogFragment : DialogFragment() {

    private var _binding: DialogReviewBinding? = null
    private val binding get() = _binding!!

    private var orderId: String = ""
    private var providerId: String = ""
    private var customerId: String = ""

    companion object {
        fun newInstance(orderId: String, providerId: String, customerId: String): ReviewDialogFragment {
            return ReviewDialogFragment().apply {
                this.orderId = orderId
                this.providerId = providerId
                this.customerId = customerId
            }
        }
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        _binding = DialogReviewBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        binding.btnSubmitReview.setOnClickListener {
            submitReview(binding.ratingBar.rating, binding.etComment.text.toString())
        }
    }

    private fun submitReview(rating: Float, comment: String) {
        Review(
            id = UUID.randomUUID().toString(),
            orderId = orderId,
            customerId = customerId,
            providerId = providerId,
            rating = rating,
            comment = comment
        )
        Toast.makeText(context, "شكراً لتقييمك!", Toast.LENGTH_SHORT).show()
        dismiss()
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
