package amana.admin

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import amana.admin.databinding.ItemAdminLogBinding

class AdminLogAdapter(
    private val items: List<ActivityLogEntry>
) : RecyclerView.Adapter<AdminLogAdapter.ViewHolder>() {

    inner class ViewHolder(private val binding: ItemAdminLogBinding) :
        RecyclerView.ViewHolder(binding.root) {
        fun bind(item: ActivityLogEntry) {
            binding.tvAction.text = item.action
            binding.tvDetail.text = item.detail
            binding.tvTime.text = item.timeAgo
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = ItemAdminLogBinding.inflate(
            LayoutInflater.from(parent.context), parent, false
        )
        return ViewHolder(binding)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) = holder.bind(items[position])
    override fun getItemCount(): Int = items.size
}
