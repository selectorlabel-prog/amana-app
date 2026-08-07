package amana.example.com.ui.home

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.RecyclerView
import amana.core.models.ProviderListing
import amana.example.com.R
import amana.example.com.databinding.ItemProviderCardBinding

class ProviderListingAdapter(
    private val items: List<ProviderListing>,
    private val onClick: ((ProviderListing) -> Unit)? = null
) : RecyclerView.Adapter<ProviderListingAdapter.ViewHolder>() {

    inner class ViewHolder(private val binding: ItemProviderCardBinding) :
        RecyclerView.ViewHolder(binding.root) {
        fun bind(item: ProviderListing) {
            binding.tvName.text = item.name
            binding.tvServiceTitle.text = item.serviceTitle
            binding.tvRating.text = "★ ${item.rating}"
            binding.tvPrice.text = "يبدأ من ${item.priceFrom.toInt()} ج.س"
            binding.tvAvailability.text = item.availabilityText
            val colorRes = if (item.isAvailable) R.color.success_green else R.color.outline
            binding.tvAvailability.setTextColor(ContextCompat.getColor(binding.root.context, colorRes))
            binding.root.setOnClickListener { onClick?.invoke(item) }
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = ItemProviderCardBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        return ViewHolder(binding)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) = holder.bind(items[position])
    override fun getItemCount(): Int = items.size
}
