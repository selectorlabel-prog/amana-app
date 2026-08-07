package amana.admin

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.RecyclerView
import amana.core.data.MockDataStore
import amana.core.models.Dispute
import amana.core.models.DisputeStatus
import amana.core.models.User
import amana.admin.databinding.ItemDisputeBinding

class DisputeAdapter(
    private val items: List<Dispute>,
    private val users: List<User> = emptyList(),
    private val onStatusChanged: () -> Unit = {}
) : RecyclerView.Adapter<DisputeAdapter.ViewHolder>() {

    inner class ViewHolder(private val binding: ItemDisputeBinding) :
        RecyclerView.ViewHolder(binding.root) {
        fun bind(item: Dispute) {
            val ctx = binding.root.context
            binding.tvReason.text = item.reason.ifBlank { "نزاع بدون وصف" }
            val reporter = users.find { it.id == item.reporterId }?.fullName
            binding.tvReporter.text = "المبلّغ: ${reporter ?: item.reporterId.ifBlank { "غير معروف" }}"
            binding.tvOrderId.text = "#${item.orderId}"

            binding.tvStatus.text = AdminDisplayHelper.disputeStatusLabel(item.status)
            val (bg, color) = AdminDisplayHelper.disputeStatusPill(item.status)
            binding.tvStatus.setBackgroundResource(bg)
            binding.tvStatus.setTextColor(ContextCompat.getColor(ctx, color))

            val resolved = item.status == DisputeStatus.RESOLVED
            binding.btnReview.visibility = if (resolved) View.GONE else View.VISIBLE
            binding.btnResolve.visibility = if (resolved) View.GONE else View.VISIBLE

            binding.btnReview.setOnClickListener {
                MockDataStore.updateDisputeStatus(item.id, DisputeStatus.UNDER_REVIEW)
                onStatusChanged()
            }
            binding.btnResolve.setOnClickListener {
                MockDataStore.updateDisputeStatus(item.id, DisputeStatus.RESOLVED)
                onStatusChanged()
            }
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = ItemDisputeBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        return ViewHolder(binding)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) = holder.bind(items[position])
    override fun getItemCount(): Int = items.size
}
