package amana.core.data

import android.content.Context
import android.content.pm.PackageManager
import android.os.Bundle
import amana.core.models.*
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken

/**
 * واجهة البيانات الموحّدة.
 * - تطبيق المستخدم (مالك القاعدة): وصول مباشر لـ AmanaDao — بدون ContentProvider دائري.
 * - تطبيق المشرف: RPC عبر ContentProvider.
 */
class AmanaRepository(context: Context) {

    private val appContext = context.applicationContext
    private val gson = Gson()
    private val localDao: AmanaDao? = if (isDbOwner(appContext)) AmanaDao(appContext) else null

    private fun rpc(method: String, arg: String? = null, payload: String? = null): String? {
        val extras = Bundle().apply { payload?.let { putString(AmanaContract.KEY_PAYLOAD, it) } }
        return try {
            val result = appContext.contentResolver.call(
                AmanaContract.AUTHORITY_URI, method, arg, extras
            )
            result?.getString(AmanaContract.KEY_RESULT)
        } catch (e: Exception) {
            null
        }
    }

    fun isAvailable(): Boolean = localDao != null || rpc(AmanaContract.M_PING) == "true"

    private inline fun <reified T> parse(json: String?): T? =
        if (json.isNullOrBlank() || json == "null") null else gson.fromJson(json, T::class.java)

    private inline fun <reified T> parseList(json: String?): List<T> {
        if (json.isNullOrBlank() || json == "null") return emptyList()
        val type = TypeToken.getParameterized(List::class.java, T::class.java).type
        return gson.fromJson(json, type)
    }

    // ---------------- Users ----------------
    fun ensureUser(user: User) {
        localDao?.ensureUser(user)
            ?: rpc(AmanaContract.M_ENSURE_USER, payload = gson.toJson(user))
    }

    fun updateUserRole(userId: String, role: UserRole) {
        localDao?.updateUserRole(userId, role)
            ?: rpc(AmanaContract.M_UPDATE_ROLE, payload = gson.toJson(AmanaProvider.RoleUpdate(userId, role.name)))
    }

    fun completeRegistration(userId: String, fullName: String, city: String, district: String) {
        localDao?.completeRegistration(userId, fullName, city, district)
            ?: rpc(AmanaContract.M_COMPLETE_REGISTRATION,
                payload = gson.toJson(AmanaProvider.Registration(userId, fullName, city, district)))
    }

    fun getUser(userId: String): User? =
        localDao?.getUser(userId) ?: parse(rpc(AmanaContract.M_GET_USER, arg = userId))

    fun getUserByPhone(phone: String): User? =
        localDao?.getUserByPhone(phone) ?: parse(rpc(AmanaContract.M_GET_USER_BY_PHONE, arg = phone))

    fun getUsers(): List<User> =
        localDao?.getUsers() ?: parseList(rpc(AmanaContract.M_GET_USERS))

    // ---------------- Categories & services ----------------
    fun getCategories(): List<ServiceCategory> =
        localDao?.getCategories() ?: parseList(rpc(AmanaContract.M_GET_CATEGORIES))

    fun getServices(): List<Service> =
        localDao?.getServices() ?: parseList(rpc(AmanaContract.M_GET_SERVICES))

    fun getServicesForProvider(providerId: String): List<Service> =
        localDao?.getServicesForProvider(providerId)
            ?: parseList(rpc(AmanaContract.M_GET_SERVICES_FOR_PROVIDER, arg = providerId))

    fun addService(service: Service): String? =
        localDao?.addService(service) ?: rpc(AmanaContract.M_ADD_SERVICE, payload = gson.toJson(service))

    // ---------------- Provider profiles ----------------
    fun getProviderProfiles(): List<ProviderProfile> =
        localDao?.getProviderProfiles() ?: parseList(rpc(AmanaContract.M_GET_PROVIDER_PROFILES))

    fun getProviderProfile(userId: String): ProviderProfile? =
        localDao?.getProviderProfile(userId) ?: parse(rpc(AmanaContract.M_GET_PROVIDER_PROFILE, arg = userId))

    fun saveProviderProfile(profile: ProviderProfile, specialty: String) {
        localDao?.saveProviderProfile(profile, specialty)
            ?: rpc(AmanaContract.M_SAVE_PROVIDER_PROFILE,
                payload = gson.toJson(AmanaProvider.ProfileSave(profile, specialty)))
    }

    fun setProviderVerified(userId: String, verified: Boolean) {
        localDao?.setProviderVerified(userId, verified)
            ?: rpc(AmanaContract.M_SET_PROVIDER_VERIFIED,
                payload = gson.toJson(AmanaProvider.VerifyUpdate(userId, verified)))
    }

    fun getNearbyProviders(): List<ProviderListing> =
        localDao?.getNearbyProviders() ?: parseList(rpc(AmanaContract.M_GET_NEARBY_PROVIDERS))

    // ---------------- Orders ----------------
    fun createOrder(order: Order): String? =
        localDao?.createOrder(order) ?: rpc(AmanaContract.M_CREATE_ORDER, payload = gson.toJson(order))

    fun getOrder(orderId: String): Order? =
        localDao?.getOrder(orderId) ?: parse(rpc(AmanaContract.M_GET_ORDER, arg = orderId))

    fun getAllOrders(): List<Order> =
        localDao?.getAllOrders() ?: parseList(rpc(AmanaContract.M_GET_ALL_ORDERS))

    fun getOrdersForCustomer(id: String): List<Order> =
        localDao?.getOrdersForCustomer(id) ?: parseList(rpc(AmanaContract.M_GET_ORDERS_FOR_CUSTOMER, arg = id))

    fun getOrdersForProvider(id: String): List<Order> =
        localDao?.getOrdersForProvider(id) ?: parseList(rpc(AmanaContract.M_GET_ORDERS_FOR_PROVIDER, arg = id))

    fun getActiveOrdersForProvider(id: String): List<Order> =
        localDao?.getActiveOrdersForProvider(id)
            ?: parseList(rpc(AmanaContract.M_GET_ACTIVE_ORDERS_FOR_PROVIDER, arg = id))

    fun getNewOrdersForProvider(id: String): List<Order> =
        localDao?.getNewOrdersForProvider(id)
            ?: parseList(rpc(AmanaContract.M_GET_NEW_ORDERS_FOR_PROVIDER, arg = id))

    fun updateOrderStatus(orderId: String, status: OrderStatus) {
        localDao?.updateOrderStatus(orderId, status)
            ?: rpc(AmanaContract.M_UPDATE_ORDER_STATUS,
                payload = gson.toJson(AmanaProvider.OrderStatusUpdate(orderId, status.name)))
    }

    // ---------------- Messages ----------------
    fun getMessages(orderId: String): List<Message> =
        localDao?.getMessages(orderId) ?: parseList(rpc(AmanaContract.M_GET_MESSAGES, arg = orderId))

    fun addMessage(message: Message) {
        localDao?.addMessage(message)
            ?: rpc(AmanaContract.M_ADD_MESSAGE, payload = gson.toJson(message))
    }

    sealed class PriceOfferResult {
        data class Success(val nothing: Boolean = true) : PriceOfferResult()
        data class InsufficientBalance(val requiredCommission: Double, val currentBalance: Double) : PriceOfferResult()
        data class Error(val message: String) : PriceOfferResult()
    }

    fun sendPriceOffer(orderId: String, senderId: String, price: Double): PriceOfferResult {
        if (localDao != null) {
            val outcome = localDao.sendPriceOffer(orderId, senderId, price)
            return when (outcome.status) {
                "success" -> PriceOfferResult.Success()
                "insufficient" -> PriceOfferResult.InsufficientBalance(outcome.requiredCommission, outcome.currentBalance)
                else -> PriceOfferResult.Error(outcome.errorMessage)
            }
        }
        val json = rpc(AmanaContract.M_SEND_PRICE_OFFER,
            payload = gson.toJson(AmanaProvider.PriceOffer(orderId, senderId, price)))
        val outcome = parse<AmanaDao.PriceOfferOutcomeInternal>(json)
            ?: return PriceOfferResult.Error("تعذّر الاتصال بقاعدة البيانات")
        return when (outcome.status) {
            "success" -> PriceOfferResult.Success()
            "insufficient" -> PriceOfferResult.InsufficientBalance(outcome.requiredCommission, outcome.currentBalance)
            else -> PriceOfferResult.Error(outcome.errorMessage)
        }
    }

    // ---------------- Wallet ----------------
    fun getWalletBalance(userId: String): Double =
        localDao?.getWalletBalance(userId)
            ?: rpc(AmanaContract.M_GET_WALLET_BALANCE, arg = userId)?.toDoubleOrNull() ?: 0.0

    fun getTransactionsForProvider(userId: String): List<Transaction> =
        localDao?.getTransactionsForProvider(userId)
            ?: parseList(rpc(AmanaContract.M_GET_TRANSACTIONS, arg = userId))

    fun generateRechargeCode(amount: Double): String? =
        localDao?.generateRechargeCode(amount) ?: rpc(AmanaContract.M_GENERATE_CODE, arg = amount.toString())

    fun getAllRechargeCodes(): List<RechargeCode> =
        localDao?.getAllRechargeCodes() ?: parseList(rpc(AmanaContract.M_GET_ALL_CODES))

    sealed class RedeemResult {
        data class Success(val amount: Double) : RedeemResult()
        data class Error(val message: String) : RedeemResult()
    }

    fun redeemCode(code: String, userId: String): RedeemResult {
        if (localDao != null) {
            val outcome = localDao.redeemCode(code, userId)
            return if (outcome.ok) RedeemResult.Success(outcome.amount)
            else RedeemResult.Error(outcome.error ?: "خطأ غير معروف")
        }
        val json = rpc(AmanaContract.M_REDEEM_CODE,
            payload = gson.toJson(AmanaProvider.RedeemRequest(code, userId)))
        val outcome = parse<AmanaDao.RedeemOutcomeInternal>(json)
            ?: return RedeemResult.Error("تعذّر الاتصال بقاعدة البيانات")
        return if (outcome.ok) RedeemResult.Success(outcome.amount)
        else RedeemResult.Error(outcome.error ?: "خطأ غير معروف")
    }

    // ---------------- Disputes ----------------
    fun getDisputes(): List<Dispute> =
        localDao?.getDisputes() ?: parseList(rpc(AmanaContract.M_GET_DISPUTES))

    fun createDispute(dispute: Dispute): String? =
        localDao?.createDispute(dispute) ?: rpc(AmanaContract.M_CREATE_DISPUTE, payload = gson.toJson(dispute))

    fun updateDisputeStatus(disputeId: String, status: DisputeStatus, notes: String) {
        localDao?.updateDisputeStatus(disputeId, status, notes)
            ?: rpc(AmanaContract.M_UPDATE_DISPUTE,
                payload = gson.toJson(AmanaProvider.DisputeUpdate(disputeId, status.name, notes)))
    }

    // ---------------- Reviews ----------------
    fun getReviews(): List<Review> =
        localDao?.getReviews() ?: parseList(rpc(AmanaContract.M_GET_REVIEWS))

    fun addReview(review: Review): String? =
        localDao?.addReview(review) ?: rpc(AmanaContract.M_ADD_REVIEW, payload = gson.toJson(review))

    // ---------------- Notifications ----------------
    fun getNotifications(userId: String): List<AppNotification> =
        localDao?.getNotifications(userId) ?: parseList(rpc(AmanaContract.M_GET_NOTIFICATIONS, arg = userId))

    fun addNotification(n: AppNotification) {
        localDao?.addNotification(n)
            ?: rpc(AmanaContract.M_ADD_NOTIFICATION, payload = gson.toJson(n))
    }

    // ---------------- Admin ----------------
    fun getDashboardStats(): DashboardStats =
        localDao?.getDashboardStats() ?: parse(rpc(AmanaContract.M_GET_DASHBOARD_STATS)) ?: DashboardStats()

    fun getAdminAlerts(): List<AdminAlert> =
        localDao?.getAdminAlerts() ?: parseList(rpc(AmanaContract.M_GET_ADMIN_ALERTS))

    fun adminLogin(email: String, password: String): Boolean =
        email.equals(amana.core.AmanaConstants.ADMIN_EMAIL, ignoreCase = true) &&
            password == amana.core.AmanaConstants.ADMIN_PASSWORD

    companion object {
        private const val DB_OWNER_PACKAGE = "amana.example.com"

        fun isDbOwner(context: Context): Boolean {
            val info = context.packageManager.resolveContentProvider(
                AmanaContract.AUTHORITY,
                PackageManager.GET_META_DATA
            )
            return info?.packageName == context.packageName ||
                context.packageName == DB_OWNER_PACKAGE
        }

        @Volatile private var instance: AmanaRepository? = null

        fun get(context: Context): AmanaRepository =
            instance ?: synchronized(this) {
                instance ?: AmanaRepository(context.applicationContext).also { instance = it }
            }
    }
}
