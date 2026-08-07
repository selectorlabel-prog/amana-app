package amana.admin

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.RecyclerView
import amana.admin.databinding.ItemAdminTransactionBinding
import amana.core.models.Transaction
import amana.core.models.TransactionType

class AdminTransactionAdapter(
    private val items: List<Transaction>
) : RecyclerView.Adapter<AdminTransactionAdapter.ViewHolder>() {

    inner class ViewHolder(private val binding: ItemAdminTransactionBinding) :
        RecyclerView.ViewHolder(binding.root) {
        fun bind(item: Transaction) {
            val ctx = binding.root.context
            val (label, icon, colorRes, sign) = when (item.type) {
                TransactionType.DEPOSIT ->
                    Quad("إيداع", "💰", R.color.success_green, "+")
                TransactionType.COMMISSION_DEDUCTION ->
                    Quad("خصم عمولة", "🧾", R.color.secondary, "-")
                TransactionType.REFUND ->
                    Quad("استرداد", "↩️", R.color.error, "-")
            }
            binding.tvIcon.text = icon
            binding.tvAction.text = label
            binding.tvDetail.text = item.orderId?.let { "طلب: $it" }
                ?: item.referenceNumber.ifBlank { "مرجع غير متوفر" }
            binding.tvAmount.text = "$sign ${item.amount.toInt()} ج.س"
            binding.tvAmount.setTextColor(ContextCompat.getColor(ctx, colorRes))
        }
    }

    private data class Quad(
        val label: String,
        val icon: String,
        val colorRes: Int,
        val sign: String
    )

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = ItemAdminTransactionBinding.inflate(
            LayoutInflater.from(parent.context), parent, false
        )
        return ViewHolder(binding)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) = holder.bind(items[position])
    override fun getItemCount(): Int = items.size
}
