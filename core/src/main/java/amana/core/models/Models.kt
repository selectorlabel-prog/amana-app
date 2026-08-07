package amana.core.models

enum class UserRole { CUSTOMER, PROVIDER, ADMIN, SUPER_ADMIN }
enum class UserStatus { ACTIVE, SUSPENDED, PENDING_VERIFICATION }
enum class OrderStatus { PENDING, NEGOTIATING, ACCEPTED, IN_PROGRESS, COMPLETED, CANCELLED }
enum class MessageType { TEXT, PRICE_OFFER, LOCATION, IMAGE }
enum class TransactionType { DEPOSIT, COMMISSION_DEDUCTION, REFUND }
enum class DisputeStatus { OPEN, UNDER_REVIEW, RESOLVED }

data class User(
    val id: String = "",
    val fullName: String = "",
    val phoneNumber: String = "",
    val role: UserRole = UserRole.CUSTOMER,
    val city: String = "",
    val district: String = "",
    val avatarUrl: String = "",
    val status: UserStatus = UserStatus.ACTIVE,
    val createdAt: Long = System.currentTimeMillis()
)

data class ProviderProfile(
    val userId: String = "",
    val bio: String = "",
    val skills: List<String> = emptyList(),
    var walletBalance: Double = 0.0,
    val ratingAvg: Double = 0.0,
    val isVerified: Boolean = false,
    val identityDocs: List<String> = emptyList()
)

data class Service(
    val id: String = "",
    val providerId: String = "",
    val serviceName: String = "",
    val basePrice: Double = 0.0,
    val description: String = ""
)

data class ServiceCategory(
    val id: String = "",
    val name: String = "",
    val iconEmoji: String = ""
)

data class Order(
    val id: String = "",
    val customerId: String = "",
    val providerId: String = "",
    val serviceId: String = "",
    val serviceName: String = "",
    var status: OrderStatus = OrderStatus.PENDING,
    var agreedPrice: Double = 0.0,
    var commissionAmount: Double = 0.0,
    val customerLat: Double = 15.5007,
    val customerLng: Double = 32.5599,
    var providerLat: Double = 15.5107,
    var providerLng: Double = 32.5499,
    val createdAt: Long = System.currentTimeMillis(),
    var completedAt: Long? = null
)

data class Message(
    val id: String = "",
    val orderId: String = "",
    val senderId: String = "",
    val content: String = "",
    val type: MessageType = MessageType.TEXT,
    val timestamp: Long = System.currentTimeMillis()
)

data class Transaction(
    val id: String = "",
    val walletOwnerId: String = "",
    val amount: Double = 0.0,
    val type: TransactionType = TransactionType.DEPOSIT,
    val orderId: String? = null,
    val referenceNumber: String = "",
    val createdAt: Long = System.currentTimeMillis()
)

data class Dispute(
    val id: String = "",
    val orderId: String = "",
    val reporterId: String = "",
    val reason: String = "",
    val adminNotes: String = "",
    val status: DisputeStatus = DisputeStatus.OPEN
)

data class RechargeCode(
    val code: String = "",
    val amount: Double = 0.0,
    var isUsed: Boolean = false,
    var usedBy: String? = null
)

data class Review(
    val id: String = "",
    val orderId: String = "",
    val customerId: String = "",
    val providerId: String = "",
    val rating: Float = 0.0f,
    val comment: String = "",
    val createdAt: Long = System.currentTimeMillis()
)

data class ProviderListing(
    val id: String = "",
    val name: String = "",
    val serviceTitle: String = "",
    val rating: Double = 0.0,
    val priceFrom: Double = 0.0,
    val isAvailable: Boolean = true,
    val availabilityText: String = "متاح الآن",
    val city: String = "الخرطوم"
)

data class AppNotification(
    val id: String = "",
    val userId: String = "",
    val title: String = "",
    val body: String = "",
    val timeAgo: String = "",
    val type: String = "",
    val isRead: Boolean = false
)

data class AdminAlert(
    val id: String = "",
    val title: String = "",
    val body: String = "",
    val timeAgo: String = "",
    val level: String = "info"
)

data class DashboardStats(
    val totalUsers: Int = 0,
    val totalProviders: Int = 0,
    val activeOrders: Int = 0,
    val openDisputes: Int = 0,
    val totalCommission: Double = 0.0,
    val totalCustomers: Int = 0,
    val pendingProviders: Int = 0
)
