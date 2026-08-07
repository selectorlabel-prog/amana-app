package com.amana.core.models

import java.util.UUID

// Enums
enum class UserRole { CUSTOMER, PROVIDER, ADMIN, SUPER_ADMIN }
enum class UserStatus { ACTIVE, SUSPENDED, PENDING_VERIFICATION }
enum class OrderStatus { PENDING, NEGOTIATING, ACCEPTED, IN_PROGRESS, COMPLETED, CANCELLED }
enum class MessageType { TEXT, PRICE_OFFER, LOCATION, IMAGE }
enum class TransactionType { DEPOSIT, COMMISSION_DEDUCTION, REFUND }
enum class DisputeStatus { OPEN, UNDER_REVIEW, RESOLVED }

// جدول المستخدمين (Users Table)
data class User(
    val id: String = UUID.randomUUID().toString(),
    val fullName: String = "",
    val phoneNumber: String = "",
    val role: UserRole = UserRole.CUSTOMER,
    val city: String = "",
    val district: String = "",
    val avatarUrl: String = "",
    val status: UserStatus = UserStatus.ACTIVE,
    val createdAt: Long = System.currentTimeMillis()
)

// جدول ملفات مقدمي الخدمة (Provider_Profiles Table)
data class ProviderProfile(
    val userId: String = "",
    val bio: String = "",
    val skills: List<String> = emptyList(), // مصفوفة التخصصات
    var walletBalance: Double = 0.0, // رصيد العمولات الحالي
    val ratingAvg: Double = 0.0, // متوسط التقييم
    val isVerified: Boolean = false, // حالة التوثيق
    val identityDocs: List<String> = emptyList(), // روابط مستندات الهوية
    val totalEarnings: Double = 0.0,
    val completedOrders: Int = 0
)

// جدول الخدمات والأسعار (Services Table)
data class Service(
    val id: String = UUID.randomUUID().toString(),
    val providerId: String = "",
    val serviceName: String = "",
    val basePrice: Double = 0.0, // السعر التقديري
    val description: String = "" // توضيحات الخدمة
)

// تصنيفات الخدمات
data class ServiceCategory(
    val id: String = "",
    val name: String = "",
    val iconEmoji: String = ""
)

// جدول الطلبات (Orders Table)
data class Order(
    val id: String = UUID.randomUUID().toString(),
    val customerId: String = "",
    val providerId: String = "",
    val serviceId: String = "",
    val serviceName: String = "",
    var status: OrderStatus = OrderStatus.PENDING,
    var agreedPrice: Double = 0.0, // السعر المتفق عليه بعد الدردشة
    var commissionAmount: Double = 0.0, // قيمة العمولة المستقطعة (15%)
    val customerLat: Double = 0.0, // موقع العميل على الخريطة
    val customerLng: Double = 0.0,
    var providerLat: Double = 0.0,
    var providerLng: Double = 0.0,
    val createdAt: Long = System.currentTimeMillis(),
    var completedAt: Long? = null
)

// جدول المحادثات (Messages Table)
data class Message(
    val id: String = UUID.randomUUID().toString(),
    val orderId: String = "",
    val senderId: String = "",
    val content: String = "",
    val type: MessageType = MessageType.TEXT,
    val timestamp: Long = System.currentTimeMillis()
)

// جدول العمليات المالية (Transactions Table)
data class Transaction(
    val id: String = UUID.randomUUID().toString(),
    val walletOwnerId: String = "",
    val amount: Double = 0.0,
    val type: TransactionType = TransactionType.DEPOSIT,
    val orderId: String? = null, // رابط الطلب المرتبط بالعملية
    val referenceNumber: String = "", // رقم مرجع العملية
    val createdAt: Long = System.currentTimeMillis()
)

// جدول البلاغات والنزاعات (Disputes Table)
data class Dispute(
    val id: String = UUID.randomUUID().toString(),
    val orderId: String = "",
    val reporterId: String = "",
    val reason: String = "",
    val adminNotes: String = "",
    val status: DisputeStatus = DisputeStatus.OPEN,
    val createdAt: Long = System.currentTimeMillis()
)

// جدول التقييمات
data class Review(
    val id: String = UUID.randomUUID().toString(),
    val orderId: String = "",
    val customerId: String = "",
    val providerId: String = "",
    val rating: Float = 0.0f,
    val comment: String = "",
    val createdAt: Long = System.currentTimeMillis()
)

// كروت الشحن
data class RechargeCode(
    val code: String = "",
    val amount: Double = 0.0,
    var isUsed: Boolean = false,
    var usedBy: String? = null,
    val createdAt: Long = System.currentTimeMillis()
)

// الإشعارات
data class AppNotification(
    val id: String = UUID.randomUUID().toString(),
    val userId: String = "",
    val title: String = "",
    val body: String = "",
    val type: String = "",
    val isRead: Boolean = false,
    val createdAt: Long = System.currentTimeMillis()
)
