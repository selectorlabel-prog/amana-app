package amana.admin

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.RecyclerView
import amana.admin.databinding.ItemAdminAlertBinding
import amana.core.models.AdminAlert

class AdminAlertAdapter(
    private val items: List<AdminAlert>
) : RecyclerView.Adapter<AdminAlertAdapter.ViewHolder>() {

    inner class ViewHolder(private val binding: ItemAdminAlertBinding) :
        RecyclerView.ViewHolder(binding.root) {
        fun bind(item: AdminAlert) {
            binding.tvAlertTitle.text = item.title
            binding.tvAlertBody.text = item.body
            binding.tvAlertTime.text = item.timeAgo
            val color = when (item.level) {
                "warning" -> R.color.warning_amber
                "action" -> R.color.primary
                "error" -> R.color.error
                else -> R.color.outline
            }
            binding.tvAlertIcon.text = when (item.level) {
                "warning" -> "⚠️"
                "action" -> "👤"
                "error" -> "🚫"
                else -> "🔔"
            }
            binding.alertIndicator.setBackgroundColor(
                ContextCompat.getColor(binding.root.context, color)
            )
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = ItemAdminAlertBinding.inflate(
            LayoutInflater.from(parent.context), parent, false
        )
        return ViewHolder(binding)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) = holder.bind(items[position])
    override fun getItemCount(): Int = items.size
}
