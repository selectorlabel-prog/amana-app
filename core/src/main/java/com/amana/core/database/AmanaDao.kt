package com.amana.core.database

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import com.amana.core.models.*
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken

/**
 * طبقة الوصول للبيانات (DAO)
 * تحتوي على جميع العمليات على قاعدة البيانات
 */
class AmanaDao(context: Context) {
    private val dbHelper = AmanaDbHelper(context)
    private val gson = Gson()

    // ============= User Operations =============
    
    fun insertUser(user: User): Long {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            put("id", user.id)
            put("fullName", user.fullName)
            put("phoneNumber", user.phoneNumber)
            put("role", user.role.name)
            put("city", user.city)
            put("district", user.district)
            put("avatarUrl", user.avatarUrl)
            put("status", user.status.name)
            put("createdAt", user.createdAt)
        }
        return db.insert("users", null, values)
    }

    fun getUserById(id: String): User? {
        val db = dbHelper.readableDatabase
        val cursor = db.query("users", null, "id = ?", arrayOf(id), null, null, null)
        return cursor.use { if (it.moveToFirst()) cursorToUser(it) else null }
    }

    fun getUserByPhone(phoneNumber: String): User? {
        val db = dbHelper.readableDatabase
        val cursor = db.query("users", null, "phoneNumber = ?", arrayOf(phoneNumber), null, null, null)
        return cursor.use { if (it.moveToFirst()) cursorToUser(it) else null }
    }

    fun getAllUsers(): List<User> {
        val db = dbHelper.readableDatabase
        val cursor = db.query("users", null, null, null, null, null, "createdAt DESC")
        return cursor.use { 
            val users = mutableListOf<User>()
            while (it.moveToNext()) {
                users.add(cursorToUser(it))
            }
            users
        }
    }

    fun updateUserStatus(userId: String, status: UserStatus): Int {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply { put("status", status.name) }
        return db.update("users", values, "id = ?", arrayOf(userId))
    }

    // ============= Provider Profile Operations =============
    
    fun insertProviderProfile(profile: ProviderProfile): Long {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            put("userId", profile.userId)
            put("bio", profile.bio)
            put("skills", gson.toJson(profile.skills))
            put("walletBalance", profile.walletBalance)
            put("ratingAvg", profile.ratingAvg)
            put("isVerified", if (profile.isVerified) 1 else 0)
            put("identityDocs", gson.toJson(profile.identityDocs))
            put("totalEarnings", profile.totalEarnings)
            put("completedOrders", profile.completedOrders)
        }
        return db.insert("provider_profiles", null, values)
    }

    fun getProviderProfile(userId: String): ProviderProfile? {
        val db = dbHelper.readableDatabase
        val cursor = db.query("provider_profiles", null, "userId = ?", arrayOf(userId), null, null, null)
        return cursor.use { if (it.moveToFirst()) cursorToProviderProfile(it) else null }
    }

    fun getAllProviders(): List<ProviderProfile> {
        val db = dbHelper.readableDatabase
        val cursor = db.query("provider_profiles", null, null, null, null, null, "ratingAvg DESC")
        return cursor.use {
            val providers = mutableListOf<ProviderProfile>()
            while (it.moveToNext()) {
                providers.add(cursorToProviderProfile(it))
            }
            providers
        }
    }

    fun updateWalletBalance(userId: String, newBalance: Double): Int {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply { put("walletBalance", newBalance) }
        return db.update("provider_profiles", values, "userId = ?", arrayOf(userId))
    }

    fun setProviderVerified(userId: String, verified: Boolean): Int {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply { put("isVerified", if (verified) 1 else 0) }
        return db.update("provider_profiles", values, "userId = ?", arrayOf(userId))
    }

    // ============= Service Operations =============
    
    fun insertService(service: Service): Long {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            put("id", service.id)
            put("providerId", service.providerId)
            put("serviceName", service.serviceName)
            put("basePrice", service.basePrice)
            put("description", service.description)
        }
        return db.insert("services", null, values)
    }

    fun getServicesByProviderId(providerId: String): List<Service> {
        val db = dbHelper.readableDatabase
        val cursor = db.query("services", null, "providerId = ?", arrayOf(providerId), null, null, null)
        return cursor.use {
            val services = mutableListOf<Service>()
            while (it.moveToNext()) {
                services.add(cursorToService(it))
            }
            services
        }
    }

    fun getAllCategories(): List<ServiceCategory> {
        val db = dbHelper.readableDatabase
        val cursor = db.query("categories", null, null, null, null, null, "name ASC")
        return cursor.use {
            val categories = mutableListOf<ServiceCategory>()
            while (it.moveToNext()) {
                categories.add(cursorToCategory(it))
            }
            categories
        }
    }

    // ============= Order Operations =============
    
    fun insertOrder(order: Order): Long {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            put("id", order.id)
            put("customerId", order.customerId)
            put("providerId", order.providerId)
            put("serviceId", order.serviceId)
            put("serviceName", order.serviceName)
            put("status", order.status.name)
            put("agreedPrice", order.agreedPrice)
            put("commissionAmount", order.commissionAmount)
            put("customerLat", order.customerLat)
            put("customerLng", order.customerLng)
            put("providerLat", order.providerLat)
            put("providerLng", order.providerLng)
            put("createdAt", order.createdAt)
            order.completedAt?.let { put("completedAt", it) }
        }
        return db.insert("orders", null, values)
    }

    fun getOrderById(orderId: String): Order? {
        val db = dbHelper.readableDatabase
        val cursor = db.query("orders", null, "id = ?", arrayOf(orderId), null, null, null)
        return cursor.use { if (it.moveToFirst()) cursorToOrder(it) else null }
    }

    fun getOrdersByCustomerId(customerId: String): List<Order> {
        val db = dbHelper.readableDatabase
        val cursor = db.query("orders", null, "customerId = ?", arrayOf(customerId), null, null, "createdAt DESC")
        return cursor.use {
            val orders = mutableListOf<Order>()
            while (it.moveToNext()) {
                orders.add(cursorToOrder(it))
            }
            orders
        }
    }

    fun getOrdersByProviderId(providerId: String): List<Order> {
        val db = dbHelper.readableDatabase
        val cursor = db.query("orders", null, "providerId = ?", arrayOf(providerId), null, null, "createdAt DESC")
        return cursor.use {
            val orders = mutableListOf<Order>()
            while (it.moveToNext()) {
                orders.add(cursorToOrder(it))
            }
            orders
        }
    }

    fun updateOrderStatus(orderId: String, status: OrderStatus): Int {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            put("status", status.name)
            if (status == OrderStatus.COMPLETED) {
                put("completedAt", System.currentTimeMillis())
            }
        }
        return db.update("orders", values, "id = ?", arrayOf(orderId))
    }

    fun updateOrderPrice(orderId: String, agreedPrice: Double, commissionAmount: Double): Int {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            put("agreedPrice", agreedPrice)
            put("commissionAmount", commissionAmount)
        }
        return db.update("orders", values, "id = ?", arrayOf(orderId))
    }

    // ============= Message Operations =============
    
    fun insertMessage(message: Message): Long {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            put("id", message.id)
            put("orderId", message.orderId)
            put("senderId", message.senderId)
            put("content", message.content)
            put("type", message.type.name)
            put("timestamp", message.timestamp)
        }
        return db.insert("messages", null, values)
    }

    fun getMessagesByOrderId(orderId: String): List<Message> {
        val db = dbHelper.readableDatabase
        val cursor = db.query("messages", null, "orderId = ?", arrayOf(orderId), null, null, "timestamp ASC")
        return cursor.use {
            val messages = mutableListOf<Message>()
            while (it.moveToNext()) {
                messages.add(cursorToMessage(it))
            }
            messages
        }
    }

    // ============= Transaction Operations =============
    
    fun insertTransaction(transaction: Transaction): Long {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            put("id", transaction.id)
            put("walletOwnerId", transaction.walletOwnerId)
            put("amount", transaction.amount)
            put("type", transaction.type.name)
            transaction.orderId?.let { put("orderId", it) }
            put("referenceNumber", transaction.referenceNumber)
            put("createdAt", transaction.createdAt)
        }
        return db.insert("transactions", null, values)
    }

    fun getTransactionsByUserId(userId: String): List<Transaction> {
        val db = dbHelper.readableDatabase
        val cursor = db.query("transactions", null, "walletOwnerId = ?", arrayOf(userId), null, null, "createdAt DESC")
        return cursor.use {
            val transactions = mutableListOf<Transaction>()
            while (it.moveToNext()) {
                transactions.add(cursorToTransaction(it))
            }
            transactions
        }
    }

    // ============= Dispute Operations =============
    
    fun insertDispute(dispute: Dispute): Long {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            put("id", dispute.id)
            put("orderId", dispute.orderId)
            put("reporterId", dispute.reporterId)
            put("reason", dispute.reason)
            put("adminNotes", dispute.adminNotes)
            put("status", dispute.status.name)
            put("createdAt", dispute.createdAt)
        }
        return db.insert("disputes", null, values)
    }

    fun getAllDisputes(): List<Dispute> {
        val db = dbHelper.readableDatabase
        val cursor = db.query("disputes", null, null, null, null, null, "createdAt DESC")
        return cursor.use {
            val disputes = mutableListOf<Dispute>()
            while (it.moveToNext()) {
                disputes.add(cursorToDispute(it))
            }
            disputes
        }
    }

    fun updateDisputeStatus(disputeId: String, status: DisputeStatus, adminNotes: String): Int {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            put("status", status.name)
            put("adminNotes", adminNotes)
        }
        return db.update("disputes", values, "id = ?", arrayOf(disputeId))
    }

    // ============= Review Operations =============
    
    fun insertReview(review: Review): Long {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            put("id", review.id)
            put("orderId", review.orderId)
            put("customerId", review.customerId)
            put("providerId", review.providerId)
            put("rating", review.rating)
            put("comment", review.comment)
            put("createdAt", review.createdAt)
        }
        return db.insert("reviews", null, values)
    }

    fun getReviewsByProviderId(providerId: String): List<Review> {
        val db = dbHelper.readableDatabase
        val cursor = db.query("reviews", null, "providerId = ?", arrayOf(providerId), null, null, "createdAt DESC")
        return cursor.use {
            val reviews = mutableListOf<Review>()
            while (it.moveToNext()) {
                reviews.add(cursorToReview(it))
            }
            reviews
        }
    }

    // ============= Recharge Code Operations =============
    
    fun insertRechargeCode(code: RechargeCode): Long {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            put("code", code.code)
            put("amount", code.amount)
            put("isUsed", if (code.isUsed) 1 else 0)
            code.usedBy?.let { put("usedBy", it) }
            put("createdAt", code.createdAt)
        }
        return db.insert("recharge_codes", null, values)
    }

    fun getRechargeCodeByCode(code: String): RechargeCode? {
        val db = dbHelper.readableDatabase
        val cursor = db.query("recharge_codes", null, "code = ?", arrayOf(code), null, null, null)
        return cursor.use { if (it.moveToFirst()) cursorToRechargeCode(it) else null }
    }

    fun markCodeAsUsed(code: String, userId: String): Int {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            put("isUsed", 1)
            put("usedBy", userId)
        }
        return db.update("recharge_codes", values, "code = ?", arrayOf(code))
    }

    // ============= Notification Operations =============
    
    fun insertNotification(notification: AppNotification): Long {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            put("id", notification.id)
            put("userId", notification.userId)
            put("title", notification.title)
            put("body", notification.body)
            put("type", notification.type)
            put("isRead", if (notification.isRead) 1 else 0)
            put("createdAt", notification.createdAt)
        }
        return db.insert("notifications", null, values)
    }

    fun getNotificationsByUserId(userId: String): List<AppNotification> {
        val db = dbHelper.readableDatabase
        val cursor = db.query("notifications", null, "userId = ?", arrayOf(userId), null, null, "createdAt DESC")
        return cursor.use {
            val notifications = mutableListOf<AppNotification>()
            while (it.moveToNext()) {
                notifications.add(cursorToNotification(it))
            }
            notifications
        }
    }

    fun markNotificationAsRead(notificationId: String): Int {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply { put("isRead", 1) }
        return db.update("notifications", values, "id = ?", arrayOf(notificationId))
    }

    // ============= Helper Methods: Cursor to Model =============
    
    private fun cursorToUser(cursor: Cursor) = User(
        id = cursor.getString(cursor.getColumnIndexOrThrow("id")),
        fullName = cursor.getString(cursor.getColumnIndexOrThrow("fullName")),
        phoneNumber = cursor.getString(cursor.getColumnIndexOrThrow("phoneNumber")),
        role = UserRole.valueOf(cursor.getString(cursor.getColumnIndexOrThrow("role"))),
        city = cursor.getString(cursor.getColumnIndexOrThrow("city")) ?: "",
        district = cursor.getString(cursor.getColumnIndexOrThrow("district")) ?: "",
        avatarUrl = cursor.getString(cursor.getColumnIndexOrThrow("avatarUrl")) ?: "",
        status = UserStatus.valueOf(cursor.getString(cursor.getColumnIndexOrThrow("status"))),
        createdAt = cursor.getLong(cursor.getColumnIndexOrThrow("createdAt"))
    )

    private fun cursorToProviderProfile(cursor: Cursor): ProviderProfile {
        val skillsJson = cursor.getString(cursor.getColumnIndexOrThrow("skills")) ?: "[]"
        val docsJson = cursor.getString(cursor.getColumnIndexOrThrow("identityDocs")) ?: "[]"
        val skillsType = object : TypeToken<List<String>>() {}.type
        val docsType = object : TypeToken<List<String>>() {}.type
        
        return ProviderProfile(
            userId = cursor.getString(cursor.getColumnIndexOrThrow("userId")),
            bio = cursor.getString(cursor.getColumnIndexOrThrow("bio")) ?: "",
            skills = gson.fromJson(skillsJson, skillsType),
            walletBalance = cursor.getDouble(cursor.getColumnIndexOrThrow("walletBalance")),
            ratingAvg = cursor.getDouble(cursor.getColumnIndexOrThrow("ratingAvg")),
            isVerified = cursor.getInt(cursor.getColumnIndexOrThrow("isVerified")) == 1,
            identityDocs = gson.fromJson(docsJson, docsType),
            totalEarnings = cursor.getDouble(cursor.getColumnIndexOrThrow("totalEarnings")),
            completedOrders = cursor.getInt(cursor.getColumnIndexOrThrow("completedOrders"))
        )
    }

    private fun cursorToService(cursor: Cursor) = Service(
        id = cursor.getString(cursor.getColumnIndexOrThrow("id")),
        providerId = cursor.getString(cursor.getColumnIndexOrThrow("providerId")),
        serviceName = cursor.getString(cursor.getColumnIndexOrThrow("serviceName")),
        basePrice = cursor.getDouble(cursor.getColumnIndexOrThrow("basePrice")),
        description = cursor.getString(cursor.getColumnIndexOrThrow("description")) ?: ""
    )

    private fun cursorToCategory(cursor: Cursor) = ServiceCategory(
        id = cursor.getString(cursor.getColumnIndexOrThrow("id")),
        name = cursor.getString(cursor.getColumnIndexOrThrow("name")),
        iconEmoji = cursor.getString(cursor.getColumnIndexOrThrow("iconEmoji")) ?: ""
    )

    private fun cursorToOrder(cursor: Cursor) = Order(
        id = cursor.getString(cursor.getColumnIndexOrThrow("id")),
        customerId = cursor.getString(cursor.getColumnIndexOrThrow("customerId")),
        providerId = cursor.getString(cursor.getColumnIndexOrThrow("providerId")),
        serviceId = cursor.getString(cursor.getColumnIndexOrThrow("serviceId")),
        serviceName = cursor.getString(cursor.getColumnIndexOrThrow("serviceName")),
        status = OrderStatus.valueOf(cursor.getString(cursor.getColumnIndexOrThrow("status"))),
        agreedPrice = cursor.getDouble(cursor.getColumnIndexOrThrow("agreedPrice")),
        commissionAmount = cursor.getDouble(cursor.getColumnIndexOrThrow("commissionAmount")),
        customerLat = cursor.getDouble(cursor.getColumnIndexOrThrow("customerLat")),
        customerLng = cursor.getDouble(cursor.getColumnIndexOrThrow("customerLng")),
        providerLat = cursor.getDouble(cursor.getColumnIndexOrThrow("providerLat")),
        providerLng = cursor.getDouble(cursor.getColumnIndexOrThrow("providerLng")),
        createdAt = cursor.getLong(cursor.getColumnIndexOrThrow("createdAt")),
        completedAt = cursor.getLongOrNull(cursor.getColumnIndexOrThrow("completedAt"))
    )

    private fun cursorToMessage(cursor: Cursor) = Message(
        id = cursor.getString(cursor.getColumnIndexOrThrow("id")),
        orderId = cursor.getString(cursor.getColumnIndexOrThrow("orderId")),
        senderId = cursor.getString(cursor.getColumnIndexOrThrow("senderId")),
        content = cursor.getString(cursor.getColumnIndexOrThrow("content")),
        type = MessageType.valueOf(cursor.getString(cursor.getColumnIndexOrThrow("type"))),
        timestamp = cursor.getLong(cursor.getColumnIndexOrThrow("timestamp"))
    )

    private fun cursorToTransaction(cursor: Cursor) = Transaction(
        id = cursor.getString(cursor.getColumnIndexOrThrow("id")),
        walletOwnerId = cursor.getString(cursor.getColumnIndexOrThrow("walletOwnerId")),
        amount = cursor.getDouble(cursor.getColumnIndexOrThrow("amount")),
        type = TransactionType.valueOf(cursor.getString(cursor.getColumnIndexOrThrow("type"))),
        orderId = cursor.getStringOrNull(cursor.getColumnIndexOrThrow("orderId")),
        referenceNumber = cursor.getString(cursor.getColumnIndexOrThrow("referenceNumber")) ?: "",
        createdAt = cursor.getLong(cursor.getColumnIndexOrThrow("createdAt"))
    )

    private fun cursorToDispute(cursor: Cursor) = Dispute(
        id = cursor.getString(cursor.getColumnIndexOrThrow("id")),
        orderId = cursor.getString(cursor.getColumnIndexOrThrow("orderId")),
        reporterId = cursor.getString(cursor.getColumnIndexOrThrow("reporterId")),
        reason = cursor.getString(cursor.getColumnIndexOrThrow("reason")),
        adminNotes = cursor.getString(cursor.getColumnIndexOrThrow("adminNotes")) ?: "",
        status = DisputeStatus.valueOf(cursor.getString(cursor.getColumnIndexOrThrow("status"))),
        createdAt = cursor.getLong(cursor.getColumnIndexOrThrow("createdAt"))
    )

    private fun cursorToReview(cursor: Cursor) = Review(
        id = cursor.getString(cursor.getColumnIndexOrThrow("id")),
        orderId = cursor.getString(cursor.getColumnIndexOrThrow("orderId")),
        customerId = cursor.getString(cursor.getColumnIndexOrThrow("customerId")),
        providerId = cursor.getString(cursor.getColumnIndexOrThrow("providerId")),
        rating = cursor.getFloat(cursor.getColumnIndexOrThrow("rating")),
        comment = cursor.getString(cursor.getColumnIndexOrThrow("comment")) ?: "",
        createdAt = cursor.getLong(cursor.getColumnIndexOrThrow("createdAt"))
    )

    private fun cursorToRechargeCode(cursor: Cursor) = RechargeCode(
        code = cursor.getString(cursor.getColumnIndexOrThrow("code")),
        amount = cursor.getDouble(cursor.getColumnIndexOrThrow("amount")),
        isUsed = cursor.getInt(cursor.getColumnIndexOrThrow("isUsed")) == 1,
        usedBy = cursor.getStringOrNull(cursor.getColumnIndexOrThrow("usedBy")),
        createdAt = cursor.getLong(cursor.getColumnIndexOrThrow("createdAt"))
    )

    private fun cursorToNotification(cursor: Cursor) = AppNotification(
        id = cursor.getString(cursor.getColumnIndexOrThrow("id")),
        userId = cursor.getString(cursor.getColumnIndexOrThrow("userId")),
        title = cursor.getString(cursor.getColumnIndexOrThrow("title")),
        body = cursor.getString(cursor.getColumnIndexOrThrow("body")),
        type = cursor.getString(cursor.getColumnIndexOrThrow("type")),
        isRead = cursor.getInt(cursor.getColumnIndexOrThrow("isRead")) == 1,
        createdAt = cursor.getLong(cursor.getColumnIndexOrThrow("createdAt"))
    )

    private fun Cursor.getStringOrNull(columnIndex: Int): String? {
        return if (isNull(columnIndex)) null else getString(columnIndex)
    }

    private fun Cursor.getLongOrNull(columnIndex: Int): Long? {
        return if (isNull(columnIndex)) null else getLong(columnIndex)
    }

    fun close() {
        dbHelper.close()
    }
}
