package amana.admin

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.appcompat.app.AlertDialog
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.RecyclerView
import amana.admin.databinding.ItemAdminOrderBinding
import amana.core.data.MockDataStore
import amana.core.models.Order

class AdminOrderAdapter(
    private val items: List<Order>
) : RecyclerView.Adapter<AdminOrderAdapter.ViewHolder>() {

    inner class ViewHolder(private val binding: ItemAdminOrderBinding) :
        RecyclerView.ViewHolder(binding.root) {
        fun bind(item: Order) {
            val ctx = binding.root.context
            binding.tvServiceName.text = item.serviceName.ifBlank { "خدمة" }
            binding.tvOrderId.text = "#${item.id}"
            binding.tvPrice.text = "${item.agreedPrice.toInt()} ج.س"
            binding.tvCommission.text = "${item.commissionAmount.toInt()} ج.س"

            binding.tvStatus.text = AdminDisplayHelper.orderStatusLabel(item.status)
            val (bg, color) = AdminDisplayHelper.orderStatusPill(item.status)
            binding.tvStatus.setBackgroundResource(bg)
            binding.tvStatus.setTextColor(ContextCompat.getColor(ctx, color))

            binding.root.setOnClickListener {
                val customer = MockDataStore.getUser(item.customerId)?.fullName ?: "—"
                val provider = MockDataStore.getUser(item.providerId)?.fullName ?: "—"
                AlertDialog.Builder(ctx)
                    .setTitle("تفاصيل الطلب #${item.id}")
                    .setMessage(
                        "الخدمة: ${item.serviceName}\n" +
                            "العميل: $customer\n" +
                            "المزود: $provider\n" +
                            "السعر: ${item.agreedPrice.toInt()} ج.س\n" +
                            "العمولة: ${item.commissionAmount.toInt()} ج.س\n" +
                            "الحالة: ${AdminDisplayHelper.orderStatusLabel(item.status)}"
                    )
                    .setPositiveButton("إغلاق", null)
                    .show()
            }
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = ItemAdminOrderBinding.inflate(
            LayoutInflater.from(parent.context), parent, false
        )
        return ViewHolder(binding)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) = holder.bind(items[position])
    override fun getItemCount(): Int = items.size
}
