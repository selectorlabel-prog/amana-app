package amana.admin

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.RecyclerView
import amana.admin.databinding.ItemAdminRechargeCodeBinding
import amana.core.models.RechargeCode

class AdminRechargeCodeAdapter(
    private val items: List<RechargeCode>
) : RecyclerView.Adapter<AdminRechargeCodeAdapter.ViewHolder>() {

    inner class ViewHolder(private val binding: ItemAdminRechargeCodeBinding) :
        RecyclerView.ViewHolder(binding.root) {
        fun bind(item: RechargeCode) {
            val ctx = binding.root.context
            binding.tvCode.text = item.code
            binding.tvAmount.text = "${item.amount.toInt()} ج.س"
            if (item.isUsed) {
                binding.tvUsed.text = "مستخدم"
                binding.tvUsed.setBackgroundResource(R.drawable.adm_bg_pill_neutral)
                binding.tvUsed.setTextColor(ContextCompat.getColor(ctx, R.color.on_surface_variant))
            } else {
                binding.tvUsed.text = "متاح"
                binding.tvUsed.setBackgroundResource(R.drawable.bg_pill_success)
                binding.tvUsed.setTextColor(ContextCompat.getColor(ctx, R.color.success_green))
            }
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = ItemAdminRechargeCodeBinding.inflate(
            LayoutInflater.from(parent.context), parent, false
        )
        return ViewHolder(binding)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) = holder.bind(items[position])
    override fun getItemCount(): Int = items.size
}
