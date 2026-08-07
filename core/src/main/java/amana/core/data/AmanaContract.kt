package amana.core.data

import android.net.Uri

/**
 * عقد مشترك بين تطبيق المستخدم وتطبيق المشرف.
 * قاعدة البيانات فعلية على الهاتف (SQLite) يملكها تطبيق المستخدم،
 * ويصل إليها تطبيق المشرف عبر ContentProvider بنفس هذا الـ authority.
 */
object AmanaContract {
    const val AUTHORITY = "amana.example.com.provider"
    val AUTHORITY_URI: Uri = Uri.parse("content://$AUTHORITY")

    const val KEY_PAYLOAD = "payload"
    const val KEY_RESULT = "result"
    const val KEY_ARG = "arg"

    // أسماء العمليات (RPC) عبر ContentResolver.call
    const val M_ENSURE_USER = "ensureUser"
    const val M_UPDATE_ROLE = "updateUserRole"
    const val M_GET_USER = "getUser"
    const val M_GET_USER_BY_PHONE = "getUserByPhone"
    const val M_COMPLETE_REGISTRATION = "completeRegistration"

    const val M_GET_CATEGORIES = "getCategories"
    const val M_GET_SERVICES = "getServices"
    const val M_ADD_SERVICE = "addService"
    const val M_GET_SERVICES_FOR_PROVIDER = "getServicesForProvider"

    const val M_GET_USERS = "getUsers"
    const val M_GET_PROVIDER_PROFILES = "getProviderProfiles"
    const val M_GET_PROVIDER_PROFILE = "getProviderProfile"
    const val M_SAVE_PROVIDER_PROFILE = "saveProviderProfile"
    const val M_SET_PROVIDER_VERIFIED = "setProviderVerified"
    const val M_GET_NEARBY_PROVIDERS = "getNearbyProviders"

    const val M_CREATE_ORDER = "createOrder"
    const val M_GET_ORDER = "getOrder"
    const val M_GET_ALL_ORDERS = "getAllOrders"
    const val M_GET_ORDERS_FOR_CUSTOMER = "getOrdersForCustomer"
    const val M_GET_ORDERS_FOR_PROVIDER = "getOrdersForProvider"
    const val M_GET_ACTIVE_ORDERS_FOR_PROVIDER = "getActiveOrdersForProvider"
    const val M_GET_NEW_ORDERS_FOR_PROVIDER = "getNewOrdersForProvider"
    const val M_UPDATE_ORDER_STATUS = "updateOrderStatus"

    const val M_GET_MESSAGES = "getMessages"
    const val M_ADD_MESSAGE = "addMessage"
    const val M_SEND_PRICE_OFFER = "sendPriceOffer"

    const val M_GET_WALLET_BALANCE = "getWalletBalance"
    const val M_GET_TRANSACTIONS = "getTransactionsForProvider"
    const val M_GENERATE_CODE = "generateRechargeCode"
    const val M_GET_ALL_CODES = "getAllRechargeCodes"
    const val M_REDEEM_CODE = "redeemCode"

    const val M_GET_DISPUTES = "getDisputes"
    const val M_CREATE_DISPUTE = "createDispute"
    const val M_UPDATE_DISPUTE = "updateDisputeStatus"

    const val M_GET_REVIEWS = "getReviews"
    const val M_ADD_REVIEW = "addReview"

    const val M_GET_NOTIFICATIONS = "getNotifications"
    const val M_ADD_NOTIFICATION = "addNotification"

    const val M_GET_DASHBOARD_STATS = "getDashboardStats"
    const val M_GET_ADMIN_ALERTS = "getAdminAlerts"

    const val M_PING = "ping"
}
