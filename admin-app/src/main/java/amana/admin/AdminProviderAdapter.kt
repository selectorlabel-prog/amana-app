package amana.admin

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.RecyclerView
import amana.admin.databinding.ItemAdminProviderBinding
import amana.core.data.MockDataStore
import amana.core.models.ProviderProfile
import amana.core.models.User

class AdminProviderAdapter(
    private val items: List<ProviderProfile>,
    private val users: List<User>,
    private val onVerify: (ProviderProfile) -> Unit
) : RecyclerView.Adapter<AdminProviderAdapter.ViewHolder>() {

    inner class ViewHolder(private val binding: ItemAdminProviderBinding) :
        RecyclerView.ViewHolder(binding.root) {
        fun bind(item: ProviderProfile) {
            val ctx = binding.root.context
            val user = users.find { it.id == item.userId }
            val name = user?.fullName?.ifBlank { null } ?: item.userId.ifBlank { "مزود خدمة" }
            binding.tvAvatar.text = AdminDisplayHelper.initial(name)
            binding.tvProviderName.text = name

            val skills = item.skills.joinToString("، ").ifBlank { item.bio.ifBlank { "لا يوجد وصف" } }
            val city = user?.city?.ifBlank { null }
            binding.tvBio.text = if (city != null) "$skills • $city" else skills

            binding.tvRating.text = "⭐ ${formatRating(item.ratingAvg)} • ${item.walletBalance.toInt()} ج.س"

            if (item.isVerified) {
                binding.tvVerified.text = "معتمد"
                binding.tvVerified.setBackgroundResource(R.drawable.bg_pill_success)
                binding.tvVerified.setTextColor(ContextCompat.getColor(ctx, R.color.success_green))
                binding.btnVerify.visibility = View.GONE
            } else {
                binding.tvVerified.text = "بانتظار الاعتماد"
                binding.tvVerified.setBackgroundResource(R.drawable.bg_pill_amber)
                binding.tvVerified.setTextColor(ContextCompat.getColor(ctx, R.color.secondary))
                binding.btnVerify.visibility = View.VISIBLE
            }

            binding.btnVerify.setOnClickListener {
                MockDataStore.setProviderVerified(item.userId, true)
                onVerify(item)
            }
        }
    }

    private fun formatRating(value: Double): String =
        if (value % 1.0 == 0.0) value.toInt().toString() else "%.1f".format(value)

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = ItemAdminProviderBinding.inflate(
            LayoutInflater.from(parent.context), parent, false
        )
        return ViewHolder(binding)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) = holder.bind(items[position])
    override fun getItemCount(): Int = items.size
}
