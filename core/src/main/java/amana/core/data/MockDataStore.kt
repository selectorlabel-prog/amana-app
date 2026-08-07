package amana.core.data

import android.content.Context
import amana.core.models.*

/**
 * طبقة توافق تُبقي الواجهة القديمة لكنها توجّه كل العمليات إلى قاعدة بيانات
 * الهاتف المشتركة عبر AmanaRepository (ContentProvider). بلا إنترنت وبلا خادم.
 *
 * يجب استدعاء init(context) مرة واحدة عند بدء التطبيق.
 */
object MockDataStore {

    private lateinit var repo: AmanaRepository
    private var adminLoggedIn = false

    fun init(context: Context) {
        if (!this::repo.isInitialized) {
            repo = AmanaRepository.get(context)
        }
    }

    fun repository(): AmanaRepository = repo
    fun isAvailable(): Boolean = repo.isAvailable()

    /** إعادة محاولة الاتصال بقاعدة بيانات تطبيق المستخدم */
    fun pingProvider(): Boolean = repo.isAvailable()

    fun ensureUserExists(user: User) { repo.ensureUser(user) }
    fun updateUserRole(userId: String, role: UserRole) { repo.updateUserRole(userId, role) }

    fun getCategories(): List<ServiceCategory> = repo.getCategories()
    fun getServices(): List<Service> = repo.getServices()
    fun getServicesForProvider(providerId: String): List<Service> = repo.getServicesForProvider(providerId)
    fun addService(service: Service): String? = repo.addService(service)
    fun getUsers(): List<User> = repo.getUsers()
    fun getUser(userId: String): User? = repo.getUser(userId)
    fun getProviderProfiles(): List<ProviderProfile> = repo.getProviderProfiles()
    fun getProviderProfile(userId: String): ProviderProfile? = repo.getProviderProfile(userId)
    fun saveProviderProfile(profile: ProviderProfile, specialty: String = "") =
        repo.saveProviderProfile(profile, specialty)
    fun setProviderVerified(userId: String, verified: Boolean) = repo.setProviderVerified(userId, verified)
    fun getDisputes(): List<Dispute> = repo.getDisputes()
    fun createDispute(dispute: Dispute): String? = repo.createDispute(dispute)
    fun updateDisputeStatus(id: String, status: DisputeStatus, notes: String = "") =
        repo.updateDisputeStatus(id, status, notes)
    fun getNearbyProviders(): List<ProviderListing> = repo.getNearbyProviders()
    fun getNotifications(userId: String): List<AppNotification> = repo.getNotifications(userId)
    fun addNotification(n: AppNotification) = repo.addNotification(n)
    fun getAdminAlerts(): List<AdminAlert> = repo.getAdminAlerts()
    fun getReviews(): List<Review> = repo.getReviews()
    fun addReview(review: Review): String? = repo.addReview(review)

    fun createOrder(order: Order): String? = repo.createOrder(order)
    fun updateOrderStatus(orderId: String, status: OrderStatus) = repo.updateOrderStatus(orderId, status)
    fun getNewOrdersForProvider(providerId: String): List<Order> = repo.getNewOrdersForProvider(providerId)
    fun getAllOrders(): List<Order> = repo.getAllOrders()
    fun getWalletBalance(userId: String): Double = repo.getWalletBalance(userId)
    fun getOrdersForCustomer(customerId: String): List<Order> = repo.getOrdersForCustomer(customerId)
    fun getOrdersForProvider(providerId: String): List<Order> = repo.getOrdersForProvider(providerId)
    fun getActiveOrdersForProvider(providerId: String): List<Order> = repo.getActiveOrdersForProvider(providerId)
    fun getOrder(orderId: String): Order? = repo.getOrder(orderId)
    fun getMessages(orderId: String): List<Message> = repo.getMessages(orderId)
    fun addMessage(message: Message) { repo.addMessage(message) }
    fun getTransactionsForProvider(providerId: String): List<Transaction> =
        repo.getTransactionsForProvider(providerId)

    fun generateRechargeCode(amount: Double): String = repo.generateRechargeCode(amount) ?: ""
    fun getAllRechargeCodes(): List<RechargeCode> = repo.getAllRechargeCodes()

    sealed class RedeemResult {
        data class Success(val amount: Double) : RedeemResult()
        data class Error(val message: String) : RedeemResult()
    }

    fun redeemCode(code: String, userId: String): RedeemResult =
        when (val r = repo.redeemCode(code, userId)) {
            is AmanaRepository.RedeemResult.Success -> RedeemResult.Success(r.amount)
            is AmanaRepository.RedeemResult.Error -> RedeemResult.Error(r.message)
        }

    sealed class PriceOfferResult {
        data class Success(val message: Message) : PriceOfferResult()
        data class InsufficientBalance(val requiredCommission: Double, val currentBalance: Double) : PriceOfferResult()
        data class Error(val message: String) : PriceOfferResult()
    }

    fun sendPriceOffer(orderId: String, senderId: String, price: Double): PriceOfferResult =
        when (val r = repo.sendPriceOffer(orderId, senderId, price)) {
            is AmanaRepository.PriceOfferResult.Success ->
                PriceOfferResult.Success(Message(orderId = orderId, senderId = senderId, content = price.toInt().toString(), type = MessageType.PRICE_OFFER))
            is AmanaRepository.PriceOfferResult.InsufficientBalance ->
                PriceOfferResult.InsufficientBalance(r.requiredCommission, r.currentBalance)
            is AmanaRepository.PriceOfferResult.Error -> PriceOfferResult.Error(r.message)
        }

    fun adminLogin(email: String, password: String): Boolean {
        val ok = repo.adminLogin(email, password)
        adminLoggedIn = ok
        return ok
    }

    fun isAdminLoggedIn(): Boolean = adminLoggedIn
    fun adminLogout() { adminLoggedIn = false }

    fun getDashboardStats(): DashboardStats = repo.getDashboardStats()
}
