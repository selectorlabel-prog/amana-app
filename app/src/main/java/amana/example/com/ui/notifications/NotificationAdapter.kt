package amana.example.com.ui.notifications

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import amana.core.models.AppNotification
import amana.example.com.databinding.ItemNotificationBinding

class NotificationAdapter(
    private val items: List<AppNotification>
) : RecyclerView.Adapter<NotificationAdapter.ViewHolder>() {

    inner class ViewHolder(private val binding: ItemNotificationBinding) :
        RecyclerView.ViewHolder(binding.root) {
        fun bind(item: AppNotification) {
            binding.tvTitle.text = item.title
            binding.tvBody.text = item.body
            binding.tvTime.text = item.timeAgo
            binding.tvIcon.text = iconFor(item.type)
            binding.root.alpha = if (item.isRead) 0.7f else 1f
        }

        private fun iconFor(type: String): String = when (type.lowercase()) {
            "order", "booking" -> "🧾"
            "offer", "price", "price_offer" -> "🏷️"
            "wallet", "payment" -> "💰"
            "arrival", "tracking" -> "🚗"
            "completed", "success" -> "✅"
            "chat", "message" -> "💬"
            "warning", "alert" -> "⚠️"
            else -> "🔔"
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = ItemNotificationBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        return ViewHolder(binding)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) = holder.bind(items[position])
    override fun getItemCount(): Int = items.size
}
