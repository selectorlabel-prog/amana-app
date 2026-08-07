package amana.example.com.ui.home

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import amana.core.models.Order
import amana.example.com.databinding.ItemOrderSummaryBinding

class OrderSummaryAdapter(
    private val items: List<Order>,
    private val onClick: (Order) -> Unit
) : RecyclerView.Adapter<OrderSummaryAdapter.ViewHolder>() {

    inner class ViewHolder(private val binding: ItemOrderSummaryBinding) :
        RecyclerView.ViewHolder(binding.root) {
        fun bind(order: Order) {
            binding.tvServiceName.text = order.serviceName
            binding.tvStatus.text = order.status.name
            binding.root.setOnClickListener { onClick(order) }
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = ItemOrderSummaryBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        return ViewHolder(binding)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) = holder.bind(items[position])
    override fun getItemCount(): Int = items.size
}
