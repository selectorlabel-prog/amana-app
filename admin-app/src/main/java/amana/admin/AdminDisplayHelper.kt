package amana.admin

import amana.core.models.DisputeStatus
import amana.core.models.OrderStatus
import amana.core.models.UserRole
import amana.core.models.UserStatus

object AdminDisplayHelper {

    fun roleLabel(role: UserRole): String = when (role) {
        UserRole.CUSTOMER -> "عميل"
        UserRole.PROVIDER -> "مزود خدمة"
        UserRole.ADMIN -> "مشرف"
        UserRole.SUPER_ADMIN -> "مشرف عام"
    }

    fun userStatusLabel(status: UserStatus): String = when (status) {
        UserStatus.ACTIVE -> "نشط"
        UserStatus.SUSPENDED -> "موقوف"
        UserStatus.PENDING_VERIFICATION -> "بانتظار التوثيق"
    }

    fun initial(name: String): String {
        val c = name.trim().firstOrNull() ?: return "؟"
        return c.uppercaseChar().toString()
    }

    fun orderStatusLabel(status: OrderStatus): String = when (status) {
        OrderStatus.PENDING -> "قيد الانتظار"
        OrderStatus.NEGOTIATING -> "قيد التفاوض"
        OrderStatus.ACCEPTED -> "مقبول"
        OrderStatus.IN_PROGRESS -> "قيد التنفيذ"
        OrderStatus.COMPLETED -> "مكتمل"
        OrderStatus.CANCELLED -> "ملغي"
    }

    fun disputeStatusLabel(status: DisputeStatus): String = when (status) {
        DisputeStatus.OPEN -> "مفتوح"
        DisputeStatus.UNDER_REVIEW -> "قيد المراجعة"
        DisputeStatus.RESOLVED -> "تم الحل"
    }

    /** Returns (pillDrawableRes, textColorRes) for an order status. */
    fun orderStatusPill(status: OrderStatus): Pair<Int, Int> = when (status) {
        OrderStatus.COMPLETED ->
            R.drawable.bg_pill_success to R.color.success_green
        OrderStatus.CANCELLED ->
            R.drawable.bg_pill_error to R.color.error
        OrderStatus.PENDING, OrderStatus.NEGOTIATING ->
            R.drawable.bg_pill_amber to R.color.secondary
        OrderStatus.ACCEPTED, OrderStatus.IN_PROGRESS ->
            R.drawable.bg_pill_primary to R.color.primary
    }

    /** Returns (pillDrawableRes, textColorRes) for a dispute status. */
    fun disputeStatusPill(status: DisputeStatus): Pair<Int, Int> = when (status) {
        DisputeStatus.OPEN -> R.drawable.bg_pill_error to R.color.error
        DisputeStatus.UNDER_REVIEW -> R.drawable.bg_pill_amber to R.color.secondary
        DisputeStatus.RESOLVED -> R.drawable.bg_pill_success to R.color.success_green
    }
}
