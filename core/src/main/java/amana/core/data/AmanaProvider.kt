package amana.core.data

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import android.os.Bundle
import amana.core.models.*
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken

/**
 * الجسر الرسمي لمشاركة قاعدة بيانات الهاتف بين تطبيق المستخدم وتطبيق المشرف.
 * يُصرَّح به في تطبيق المستخدم فقط (يملك القاعدة)، ويصل إليه تطبيق المشرف
 * عبر نفس الـ authority. كل العمليات RPC عبر call().
 */
class AmanaProvider : ContentProvider() {

    private lateinit var dao: AmanaDao
    private val gson = Gson()

    override fun onCreate(): Boolean {
        dao = AmanaDao(context!!)
        return true
    }

    override fun call(method: String, arg: String?, extras: Bundle?): Bundle {
        val result = Bundle()
        try {
            val payload = extras?.getString(AmanaContract.KEY_PAYLOAD)
            val json: String = when (method) {
            AmanaContract.M_PING -> "true"

            AmanaContract.M_ENSURE_USER -> {
                dao.ensureUser(gson.fromJson(payload, User::class.java)); "true"
            }
            AmanaContract.M_UPDATE_ROLE -> {
                val obj = gson.fromJson(payload, RoleUpdate::class.java)
                dao.updateUserRole(obj.userId, UserRole.valueOf(obj.role)); "true"
            }
            AmanaContract.M_COMPLETE_REGISTRATION -> {
                val obj = gson.fromJson(payload, Registration::class.java)
                dao.completeRegistration(obj.userId, obj.fullName, obj.city, obj.district); "true"
            }
            AmanaContract.M_GET_USER -> gson.toJson(dao.getUser(arg ?: ""))
            AmanaContract.M_GET_USER_BY_PHONE -> gson.toJson(dao.getUserByPhone(arg ?: ""))
            AmanaContract.M_GET_USERS -> gson.toJson(dao.getUsers())

            AmanaContract.M_GET_CATEGORIES -> gson.toJson(dao.getCategories())
            AmanaContract.M_GET_SERVICES -> gson.toJson(dao.getServices())
            AmanaContract.M_GET_SERVICES_FOR_PROVIDER -> gson.toJson(dao.getServicesForProvider(arg ?: ""))
            AmanaContract.M_ADD_SERVICE -> dao.addService(gson.fromJson(payload, Service::class.java))

            AmanaContract.M_GET_PROVIDER_PROFILES -> gson.toJson(dao.getProviderProfiles())
            AmanaContract.M_GET_PROVIDER_PROFILE -> gson.toJson(dao.getProviderProfile(arg ?: ""))
            AmanaContract.M_SAVE_PROVIDER_PROFILE -> {
                val obj = gson.fromJson(payload, ProfileSave::class.java)
                dao.saveProviderProfile(obj.profile, obj.specialty); "true"
            }
            AmanaContract.M_SET_PROVIDER_VERIFIED -> {
                val obj = gson.fromJson(payload, VerifyUpdate::class.java)
                dao.setProviderVerified(obj.userId, obj.verified); "true"
            }
            AmanaContract.M_GET_NEARBY_PROVIDERS -> gson.toJson(dao.getNearbyProviders())

            AmanaContract.M_CREATE_ORDER -> dao.createOrder(gson.fromJson(payload, Order::class.java))
            AmanaContract.M_GET_ORDER -> gson.toJson(dao.getOrder(arg ?: ""))
            AmanaContract.M_GET_ALL_ORDERS -> gson.toJson(dao.getAllOrders())
            AmanaContract.M_GET_ORDERS_FOR_CUSTOMER -> gson.toJson(dao.getOrdersForCustomer(arg ?: ""))
            AmanaContract.M_GET_ORDERS_FOR_PROVIDER -> gson.toJson(dao.getOrdersForProvider(arg ?: ""))
            AmanaContract.M_GET_ACTIVE_ORDERS_FOR_PROVIDER -> gson.toJson(dao.getActiveOrdersForProvider(arg ?: ""))
            AmanaContract.M_GET_NEW_ORDERS_FOR_PROVIDER -> gson.toJson(dao.getNewOrdersForProvider(arg ?: ""))
            AmanaContract.M_UPDATE_ORDER_STATUS -> {
                val obj = gson.fromJson(payload, OrderStatusUpdate::class.java)
                dao.updateOrderStatus(obj.orderId, OrderStatus.valueOf(obj.status)); "true"
            }

            AmanaContract.M_GET_MESSAGES -> gson.toJson(dao.getMessages(arg ?: ""))
            AmanaContract.M_ADD_MESSAGE -> {
                dao.addMessage(gson.fromJson(payload, Message::class.java)); "true"
            }
            AmanaContract.M_SEND_PRICE_OFFER -> {
                val obj = gson.fromJson(payload, PriceOffer::class.java)
                gson.toJson(dao.sendPriceOffer(obj.orderId, obj.senderId, obj.price))
            }

            AmanaContract.M_GET_WALLET_BALANCE -> dao.getWalletBalance(arg ?: "").toString()
            AmanaContract.M_GET_TRANSACTIONS -> gson.toJson(dao.getTransactionsForProvider(arg ?: ""))
            AmanaContract.M_GENERATE_CODE -> dao.generateRechargeCode((arg ?: "0").toDouble())
            AmanaContract.M_GET_ALL_CODES -> gson.toJson(dao.getAllRechargeCodes())
            AmanaContract.M_REDEEM_CODE -> {
                val obj = gson.fromJson(payload, RedeemRequest::class.java)
                gson.toJson(dao.redeemCode(obj.code, obj.userId))
            }

            AmanaContract.M_GET_DISPUTES -> gson.toJson(dao.getDisputes())
            AmanaContract.M_CREATE_DISPUTE -> dao.createDispute(gson.fromJson(payload, Dispute::class.java))
            AmanaContract.M_UPDATE_DISPUTE -> {
                val obj = gson.fromJson(payload, DisputeUpdate::class.java)
                dao.updateDisputeStatus(obj.disputeId, DisputeStatus.valueOf(obj.status), obj.notes); "true"
            }

            AmanaContract.M_GET_REVIEWS -> gson.toJson(dao.getReviews())
            AmanaContract.M_ADD_REVIEW -> dao.addReview(gson.fromJson(payload, Review::class.java))

            AmanaContract.M_GET_NOTIFICATIONS -> gson.toJson(dao.getNotifications(arg ?: ""))
            AmanaContract.M_ADD_NOTIFICATION -> {
                dao.addNotification(gson.fromJson(payload, AppNotification::class.java)); "true"
            }

            AmanaContract.M_GET_DASHBOARD_STATS -> gson.toJson(dao.getDashboardStats())
            AmanaContract.M_GET_ADMIN_ALERTS -> gson.toJson(dao.getAdminAlerts())

            else -> "null"
            }
            result.putString(AmanaContract.KEY_RESULT, json)
        } catch (e: Exception) {
            result.putString(AmanaContract.KEY_RESULT, "null")
        }
        return result
    }

    // ContentProvider الأساسية غير مستخدمة (نعتمد على call فقط)
    override fun query(uri: Uri, p: Array<out String>?, s: String?, sa: Array<out String>?, o: String?): Cursor? = null
    override fun getType(uri: Uri): String? = null
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, s: String?, sa: Array<out String>?): Int = 0
    override fun update(uri: Uri, values: ContentValues?, s: String?, sa: Array<out String>?): Int = 0

    // نماذج مساعدة لنقل البيانات RPC
    data class RoleUpdate(val userId: String, val role: String)
    data class Registration(val userId: String, val fullName: String, val city: String, val district: String)
    data class ProfileSave(val profile: ProviderProfile, val specialty: String)
    data class VerifyUpdate(val userId: String, val verified: Boolean)
    data class OrderStatusUpdate(val orderId: String, val status: String)
    data class PriceOffer(val orderId: String, val senderId: String, val price: Double)
    data class RedeemRequest(val code: String, val userId: String)
    data class DisputeUpdate(val disputeId: String, val status: String, val notes: String)
}
