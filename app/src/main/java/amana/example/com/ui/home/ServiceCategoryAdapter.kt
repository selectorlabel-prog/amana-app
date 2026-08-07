package amana.example.com.ui.home

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import amana.core.models.ServiceCategory
import amana.example.com.databinding.ItemServiceCategoryBinding

class ServiceCategoryAdapter(
    private val items: List<ServiceCategory>,
    private val onClick: ((ServiceCategory) -> Unit)? = null
) : RecyclerView.Adapter<ServiceCategoryAdapter.ViewHolder>() {

    inner class ViewHolder(private val binding: ItemServiceCategoryBinding) :
        RecyclerView.ViewHolder(binding.root) {
        fun bind(item: ServiceCategory) {
            binding.tvEmoji.text = item.iconEmoji
            binding.tvName.text = item.name
            binding.root.setOnClickListener { onClick?.invoke(item) }
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = ItemServiceCategoryBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        return ViewHolder(binding)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) = holder.bind(items[position])
    override fun getItemCount(): Int = items.size
}
