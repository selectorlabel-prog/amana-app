package amana.admin

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import amana.admin.databinding.ItemAdminReviewBinding
import amana.core.models.Review

class AdminReviewAdapter(
    private val items: List<Review>
) : RecyclerView.Adapter<AdminReviewAdapter.ViewHolder>() {

    inner class ViewHolder(private val binding: ItemAdminReviewBinding) :
        RecyclerView.ViewHolder(binding.root) {
        fun bind(item: Review) {
            binding.tvAvatar.text = AdminDisplayHelper.initial(item.comment.take(1))
            binding.tvRating.text = "⭐ ${item.rating}/5"
            binding.tvComment.text = item.comment.ifEmpty { "بدون تعليق" }
            binding.tvOrderId.text = "طلب: ${item.orderId}"
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = ItemAdminReviewBinding.inflate(
            LayoutInflater.from(parent.context), parent, false
        )
        return ViewHolder(binding)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) = holder.bind(items[position])
    override fun getItemCount(): Int = items.size
}
