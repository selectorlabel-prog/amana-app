package amana.admin

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.appcompat.app.AlertDialog
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.RecyclerView
import amana.admin.databinding.ItemAdminUserBinding
import amana.core.models.User
import amana.core.models.UserStatus

class AdminUserAdapter(
    private val items: List<User>
) : RecyclerView.Adapter<AdminUserAdapter.ViewHolder>() {

    inner class ViewHolder(private val binding: ItemAdminUserBinding) :
        RecyclerView.ViewHolder(binding.root) {
        fun bind(item: User) {
            val ctx = binding.root.context
            binding.tvAvatar.text = AdminDisplayHelper.initial(item.fullName)
            binding.tvName.text = item.fullName.ifBlank { "مستخدم" }
            val city = item.city.ifBlank { "غير محدد" }
            binding.tvRole.text = "${AdminDisplayHelper.roleLabel(item.role)} • $city"
            binding.tvPhone.text = item.phoneNumber.ifBlank { "لا يوجد رقم هاتف" }

            binding.tvStatus.text = AdminDisplayHelper.userStatusLabel(item.status)
            val (bg, textColor) = when (item.status) {
                UserStatus.ACTIVE -> R.drawable.bg_pill_success to R.color.success_green
                UserStatus.SUSPENDED -> R.drawable.bg_pill_error to R.color.error
                UserStatus.PENDING_VERIFICATION -> R.drawable.bg_pill_amber to R.color.secondary
            }
            binding.tvStatus.setBackgroundResource(bg)
            binding.tvStatus.setTextColor(ContextCompat.getColor(ctx, textColor))

            binding.root.setOnClickListener {
                AlertDialog.Builder(ctx)
                    .setTitle(item.fullName.ifBlank { "مستخدم" })
                    .setMessage(
                        "الدور: ${AdminDisplayHelper.roleLabel(item.role)}\n" +
                            "الهاتف: ${item.phoneNumber.ifBlank { "—" }}\n" +
                            "المدينة: ${item.city.ifBlank { "—" }}\n" +
                            "الحي: ${item.district.ifBlank { "—" }}\n" +
                            "الحالة: ${AdminDisplayHelper.userStatusLabel(item.status)}"
                    )
                    .setPositiveButton("إغلاق", null)
                    .show()
            }
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = ItemAdminUserBinding.inflate(
            LayoutInflater.from(parent.context), parent, false
        )
        return ViewHolder(binding)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) = holder.bind(items[position])
    override fun getItemCount(): Int = items.size
}
