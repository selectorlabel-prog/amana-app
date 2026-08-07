package amana.example.com.ui.home

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import amana.core.models.Transaction
import amana.core.models.TransactionType
import amana.example.com.R
import amana.example.com.databinding.ItemTransactionBinding

class TransactionAdapter(
    private val items: List<Transaction>
) : RecyclerView.Adapter<TransactionAdapter.ViewHolder>() {

    inner class ViewHolder(private val binding: ItemTransactionBinding) :
        RecyclerView.ViewHolder(binding.root) {
        fun bind(item: Transaction) {
            val context = binding.root.context
            val isCredit = item.type != TransactionType.COMMISSION_DEDUCTION
            val prefix = if (isCredit) "+" else "-"

            binding.tvTitle.text = when (item.type) {
                TransactionType.DEPOSIT -> "شحن محفظة"
                TransactionType.COMMISSION_DEDUCTION -> "خصم عمولة"
                TransactionType.REFUND -> "استرداد"
            }
            binding.tvAmount.text = String.format("%s%,d SDG", prefix, kotlin.math.abs(item.amount).toInt())
            binding.tvAmount.setTextColor(
                context.getColor(if (isCredit) R.color.success_green else R.color.error)
            )
            binding.tvIcon.text = if (isCredit) "↑" else "↓"
            binding.tvIcon.setBackgroundResource(
                if (isCredit) R.drawable.bg_icon_circle_secondary else R.drawable.bg_icon_circle_neutral
            )
            binding.tvReference.text =
                if (item.referenceNumber.isBlank()) "معاملة" else item.referenceNumber
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = ItemTransactionBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        return ViewHolder(binding)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) = holder.bind(items[position])
    override fun getItemCount(): Int = items.size
}
