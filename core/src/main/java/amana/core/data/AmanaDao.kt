package amana.core.data

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import amana.core.AmanaConstants
import amana.core.models.*
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import java.util.UUID
import kotlin.math.round

/**
 * الوصول المباشر لقاعدة بيانات الهاتف (SQLite).
 * يُستخدم داخل ContentProvider فقط. كل منطق الأعمال يعيش هنا.
 */
class AmanaDao(context: Context) {

    private val helper = AmanaDbHelper(context)
    private val gson = Gson()
    private val listType = object : TypeToken<List<String>>() {}.type

    private fun listToJson(list: List<String>): String = gson.toJson(list)
    private fun jsonToList(json: String?): List<String> =
        if (json.isNullOrBlank()) emptyList() else gson.fromJson(json, listType)

    // ---------------- Users ----------------

    fun ensureUser(user: User) {
        val db = helper.writableDatabase
        val cursor = db.rawQuery("SELECT id FROM users WHERE id=?", arrayOf(user.id))
        val exists = cursor.moveToFirst()
        cursor.close()
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
        if (exists) {
            db.update("users", values, "id=?", arrayOf(user.id))
        } else {
            db.insert("users", null, values)
        }
        if (user.role == UserRole.PROVIDER) {
            ensureProviderProfile(user.id)
        }
    }

    fun updateUserRole(userId: String, role: UserRole) {
        val db = helper.writableDatabase
        db.execSQL("UPDATE users SET role=? WHERE id=?", arrayOf(role.name, userId))
        if (role == UserRole.PROVIDER) ensureProviderProfile(userId)
    }

    fun completeRegistration(userId: String, fullName: String, city: String, district: String) {
        helper.writableDatabase.execSQL(
            "UPDATE users SET fullName=?, city=?, district=? WHERE id=?",
            arrayOf(fullName, city, district, userId)
        )
    }

    fun getUser(userId: String): User? {
        val c = helper.readableDatabase.rawQuery("SELECT * FROM users WHERE id=?", arrayOf(userId))
        val user = if (c.moveToFirst()) cursorToUser(c) else null
        c.close()
        return user
    }

    fun getUserByPhone(phone: String): User? {
        val c = helper.readableDatabase.rawQuery(
            "SELECT * FROM users WHERE phoneNumber=?", arrayOf(phone)
        )
        val user = if (c.moveToFirst()) cursorToUser(c) else null
        c.close()
        return user
    }

    fun getUsers(): List<User> {
        val list = mutableListOf<User>()
        val c = helper.readableDatabase.rawQuery("SELECT * FROM users ORDER BY createdAt DESC", null)
        while (c.moveToNext()) list.add(cursorToUser(c))
        c.close()
        return list
    }

    private fun cursorToUser(c: Cursor) = User(
        id = c.getString(c.getColumnIndexOrThrow("id")),
        fullName = c.getString(c.getColumnIndexOrThrow("fullName")) ?: "",
        phoneNumber = c.getString(c.getColumnIndexOrThrow("phoneNumber")) ?: "",
        role = runCatching { UserRole.valueOf(c.getString(c.getColumnIndexOrThrow("role"))) }
            .getOrDefault(UserRole.CUSTOMER),
        city = c.getString(c.getColumnIndexOrThrow("city")) ?: "",
        district = c.getString(c.getColumnIndexOrThrow("district")) ?: "",
        avatarUrl = c.getString(c.getColumnIndexOrThrow("avatarUrl")) ?: "",
        status = runCatching { UserStatus.valueOf(c.getString(c.getColumnIndexOrThrow("status"))) }
            .getOrDefault(UserStatus.ACTIVE),
        createdAt = c.getLong(c.getColumnIndexOrThrow("createdAt"))
    )

    // ---------------- Provider profiles ----------------

    private fun ensureProviderProfile(userId: String) {
        val db = helper.writableDatabase
        val c = db.rawQuery("SELECT userId FROM provider_profiles WHERE userId=?", arrayOf(userId))
        val exists = c.moveToFirst()
        c.close()
        if (!exists) {
            val values = ContentValues().apply {
                put("userId", userId)
                put("bio", "")
                put("skills", "[]")
                put("walletBalance", 0.0)
                put("ratingAvg", 0.0)
                put("isVerified", 0)
                put("identityDocs", "[]")
                put("specialty", "")
            }
            db.insert("provider_profiles", null, values)
        }
    }

    fun saveProviderProfile(profile: ProviderProfile, specialty: String) {
        ensureProviderProfile(profile.userId)
        val values = ContentValues().apply {
            put("bio", profile.bio)
            put("skills", listToJson(profile.skills))
            put("ratingAvg", profile.ratingAvg)
            put("isVerified", if (profile.isVerified) 1 else 0)
            put("identityDocs", listToJson(profile.identityDocs))
            put("specialty", specialty)
        }
        helper.writableDatabase.update(
            "provider_profiles", values, "userId=?", arrayOf(profile.userId)
        )
    }

    fun setProviderVerified(userId: String, verified: Boolean) {
        ensureProviderProfile(userId)
        helper.writableDatabase.execSQL(
            "UPDATE provider_profiles SET isVerified=? WHERE userId=?",
            arrayOf(if (verified) 1 else 0, userId)
        )
    }

    fun getProviderProfile(userId: String): ProviderProfile? {
        val c = helper.readableDatabase.rawQuery(
            "SELECT * FROM provider_profiles WHERE userId=?", arrayOf(userId)
        )
        val p = if (c.moveToFirst()) cursorToProfile(c) else null
        c.close()
        return p
    }

    fun getProviderProfiles(): List<ProviderProfile> {
        val list = mutableListOf<ProviderProfile>()
        val c = helper.readableDatabase.rawQuery("SELECT * FROM provider_profiles", null)
        while (c.moveToNext()) list.add(cursorToProfile(c))
        c.close()
        return list
    }

    private fun cursorToProfile(c: Cursor) = ProviderProfile(
        userId = c.getString(c.getColumnIndexOrThrow("userId")),
        bio = c.getString(c.getColumnIndexOrThrow("bio")) ?: "",
        skills = jsonToList(c.getString(c.getColumnIndexOrThrow("skills"))),
        walletBalance = c.getDouble(c.getColumnIndexOrThrow("walletBalance")),
        ratingAvg = c.getDouble(c.getColumnIndexOrThrow("ratingAvg")),
        isVerified = c.getInt(c.getColumnIndexOrThrow("isVerified")) == 1,
        identityDocs = jsonToList(c.getString(c.getColumnIndexOrThrow("identityDocs")))
    )

    /** المزودون القريبون = مزودون حقيقيون مسجّلون في القاعدة. */
    fun getNearbyProviders(): List<ProviderListing> {
        val list = mutableListOf<ProviderListing>()
        val c = helper.readableDatabase.rawQuery(
            """SELECT u.id, u.fullName, u.city, u.district, p.bio, p.skills,
                      p.ratingAvg, p.isVerified, p.specialty
               FROM users u JOIN provider_profiles p ON u.id = p.userId
               WHERE u.role = 'PROVIDER'""", null
        )
        while (c.moveToNext()) {
            val skills = jsonToList(c.getString(c.getColumnIndexOrThrow("skills")))
            val bio = c.getString(c.getColumnIndexOrThrow("bio")) ?: ""
            val specialty = c.getString(c.getColumnIndexOrThrow("specialty")) ?: ""
            val id = c.getString(c.getColumnIndexOrThrow("id"))
            val minPrice = minServicePrice(id)
            list.add(
                ProviderListing(
                    id = id,
                    name = c.getString(c.getColumnIndexOrThrow("fullName")) ?: "",
                    serviceTitle = specialty.ifBlank { bio.ifBlank { skills.joinToString("، ") } },
                    rating = c.getDouble(c.getColumnIndexOrThrow("ratingAvg")),
                    priceFrom = minPrice,
                    isAvailable = c.getInt(c.getColumnIndexOrThrow("isVerified")) == 1,
                    availabilityText = if (c.getInt(c.getColumnIndexOrThrow("isVerified")) == 1) "معتمد" else "بانتظار الاعتماد",
                    city = c.getString(c.getColumnIndexOrThrow("district"))
                        ?: c.getString(c.getColumnIndexOrThrow("city")) ?: ""
                )
            )
        }
        c.close()
        return list
    }

    private fun minServicePrice(providerId: String): Double {
        val c = helper.readableDatabase.rawQuery(
            "SELECT MIN(basePrice) FROM services WHERE providerId=?", arrayOf(providerId)
        )
        val price = if (c.moveToFirst() && !c.isNull(0)) c.getDouble(0) else 0.0
        c.close()
        return price
    }

    // ---------------- Categories & Services ----------------

    fun getCategories(): List<ServiceCategory> {
        val list = mutableListOf<ServiceCategory>()
        val c = helper.readableDatabase.rawQuery("SELECT * FROM categories", null)
        while (c.moveToNext()) {
            list.add(
                ServiceCategory(
                    id = c.getString(c.getColumnIndexOrThrow("id")),
                    name = c.getString(c.getColumnIndexOrThrow("name")),
                    iconEmoji = c.getString(c.getColumnIndexOrThrow("iconEmoji"))
                )
            )
        }
        c.close()
        return list
    }

    fun addService(service: Service): String {
        val id = service.id.ifBlank { "svc_${UUID.randomUUID()}" }
        val values = ContentValues().apply {
            put("id", id)
            put("providerId", service.providerId)
            put("serviceName", service.serviceName)
            put("basePrice", service.basePrice)
            put("description", service.description)
        }
        helper.writableDatabase.insert("services", null, values)
        return id
    }

    fun getServices(): List<Service> = queryServices(null, null)
    fun getServicesForProvider(providerId: String): List<Service> =
        queryServices("providerId=?", arrayOf(providerId))

    private fun queryServices(where: String?, args: Array<String>?): List<Service> {
        val list = mutableListOf<Service>()
        val sql = "SELECT * FROM services" + (where?.let { " WHERE $it" } ?: "")
        val c = helper.readableDatabase.rawQuery(sql, args)
        while (c.moveToNext()) {
            list.add(
                Service(
                    id = c.getString(c.getColumnIndexOrThrow("id")),
                    providerId = c.getString(c.getColumnIndexOrThrow("providerId")),
                    serviceName = c.getString(c.getColumnIndexOrThrow("serviceName")),
                    basePrice = c.getDouble(c.getColumnIndexOrThrow("basePrice")),
                    description = c.getString(c.getColumnIndexOrThrow("description")) ?: ""
                )
            )
        }
        c.close()
        return list
    }

    // ---------------- Orders ----------------

    fun createOrder(order: Order): String {
        val id = order.id.ifBlank { "order_${UUID.randomUUID()}" }
        val values = ContentValues().apply {
            put("id", id)
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
        helper.writableDatabase.insert("orders", null, values)
        // إشعار للمزود بوجود طلب جديد
        if (order.providerId.isNotBlank()) {
            addNotification(
                AppNotification(
                    id = "n_${UUID.randomUUID()}",
                    userId = order.providerId,
                    title = "طلب جديد",
                    body = "لديك طلب جديد: ${order.serviceName}",
                    timeAgo = "الآن",
                    type = "ORDER",
                    isRead = false
                )
            )
        }
        return id
    }

    fun updateOrderStatus(orderId: String, status: OrderStatus) {
        val completedAt = if (status == OrderStatus.COMPLETED) System.currentTimeMillis() else null
        val db = helper.writableDatabase
        if (completedAt != null) {
            db.execSQL(
                "UPDATE orders SET status=?, completedAt=? WHERE id=?",
                arrayOf(status.name, completedAt, orderId)
            )
        } else {
            db.execSQL("UPDATE orders SET status=? WHERE id=?", arrayOf(status.name, orderId))
        }
    }

    fun getOrder(orderId: String): Order? {
        val c = helper.readableDatabase.rawQuery("SELECT * FROM orders WHERE id=?", arrayOf(orderId))
        val o = if (c.moveToFirst()) cursorToOrder(c) else null
        c.close()
        return o
    }

    fun getAllOrders(): List<Order> = queryOrders(null, null)
    fun getOrdersForCustomer(id: String) = queryOrders("customerId=?", arrayOf(id))
    fun getOrdersForProvider(id: String) = queryOrders("providerId=?", arrayOf(id))
    fun getNewOrdersForProvider(id: String) =
        queryOrders("providerId=? AND status='PENDING'", arrayOf(id))

    fun getActiveOrdersForProvider(id: String) = queryOrders(
        "providerId=? AND status IN ('ACCEPTED','IN_PROGRESS','NEGOTIATING')", arrayOf(id)
    )

    private fun queryOrders(where: String?, args: Array<String>?): List<Order> {
        val list = mutableListOf<Order>()
        val sql = "SELECT * FROM orders" + (where?.let { " WHERE $it" } ?: "") +
            " ORDER BY createdAt DESC"
        val c = helper.readableDatabase.rawQuery(sql, args)
        while (c.moveToNext()) list.add(cursorToOrder(c))
        c.close()
        return list
    }

    private fun cursorToOrder(c: Cursor) = Order(
        id = c.getString(c.getColumnIndexOrThrow("id")),
        customerId = c.getString(c.getColumnIndexOrThrow("customerId")) ?: "",
        providerId = c.getString(c.getColumnIndexOrThrow("providerId")) ?: "",
        serviceId = c.getString(c.getColumnIndexOrThrow("serviceId")) ?: "",
        serviceName = c.getString(c.getColumnIndexOrThrow("serviceName")) ?: "",
        status = runCatching { OrderStatus.valueOf(c.getString(c.getColumnIndexOrThrow("status"))) }
            .getOrDefault(OrderStatus.PENDING),
        agreedPrice = c.getDouble(c.getColumnIndexOrThrow("agreedPrice")),
        commissionAmount = c.getDouble(c.getColumnIndexOrThrow("commissionAmount")),
        customerLat = c.getDouble(c.getColumnIndexOrThrow("customerLat")),
        customerLng = c.getDouble(c.getColumnIndexOrThrow("customerLng")),
        providerLat = c.getDouble(c.getColumnIndexOrThrow("providerLat")),
        providerLng = c.getDouble(c.getColumnIndexOrThrow("providerLng")),
        createdAt = c.getLong(c.getColumnIndexOrThrow("createdAt")),
        completedAt = if (c.isNull(c.getColumnIndexOrThrow("completedAt"))) null
        else c.getLong(c.getColumnIndexOrThrow("completedAt"))
    )

    // ---------------- Messages ----------------

    fun addMessage(message: Message) {
        val values = ContentValues().apply {
            put("id", message.id.ifBlank { "msg_${UUID.randomUUID()}" })
            put("orderId", message.orderId)
            put("senderId", message.senderId)
            put("content", message.content)
            put("type", message.type.name)
            put("timestamp", message.timestamp)
        }
        helper.writableDatabase.insert("messages", null, values)
    }

    fun getMessages(orderId: String): List<Message> {
        val list = mutableListOf<Message>()
        val c = helper.readableDatabase.rawQuery(
            "SELECT * FROM messages WHERE orderId=? ORDER BY timestamp ASC", arrayOf(orderId)
        )
        while (c.moveToNext()) {
            list.add(
                Message(
                    id = c.getString(c.getColumnIndexOrThrow("id")),
                    orderId = c.getString(c.getColumnIndexOrThrow("orderId")),
                    senderId = c.getString(c.getColumnIndexOrThrow("senderId")),
                    content = c.getString(c.getColumnIndexOrThrow("content")) ?: "",
                    type = runCatching { MessageType.valueOf(c.getString(c.getColumnIndexOrThrow("type"))) }
                        .getOrDefault(MessageType.TEXT),
                    timestamp = c.getLong(c.getColumnIndexOrThrow("timestamp"))
                )
            )
        }
        c.close()
        return list
    }

    // ---------------- Wallet / Transactions / Codes ----------------

    fun getWalletBalance(userId: String): Double {
        val c = helper.readableDatabase.rawQuery(
            "SELECT walletBalance FROM provider_profiles WHERE userId=?", arrayOf(userId)
        )
        val bal = if (c.moveToFirst()) c.getDouble(0) else 0.0
        c.close()
        return bal
    }

    fun getTransactionsForProvider(userId: String): List<Transaction> {
        val list = mutableListOf<Transaction>()
        val c = helper.readableDatabase.rawQuery(
            "SELECT * FROM transactions WHERE walletOwnerId=? ORDER BY createdAt DESC",
            arrayOf(userId)
        )
        while (c.moveToNext()) {
            list.add(
                Transaction(
                    id = c.getString(c.getColumnIndexOrThrow("id")),
                    walletOwnerId = c.getString(c.getColumnIndexOrThrow("walletOwnerId")),
                    amount = c.getDouble(c.getColumnIndexOrThrow("amount")),
                    type = runCatching { TransactionType.valueOf(c.getString(c.getColumnIndexOrThrow("type"))) }
                        .getOrDefault(TransactionType.DEPOSIT),
                    orderId = c.getString(c.getColumnIndexOrThrow("orderId")),
                    referenceNumber = c.getString(c.getColumnIndexOrThrow("referenceNumber")) ?: "",
                    createdAt = c.getLong(c.getColumnIndexOrThrow("createdAt"))
                )
            )
        }
        c.close()
        return list
    }

    fun generateRechargeCode(amount: Double): String {
        val code = RechargeCodeHelper.generateCode(amount)
        val values = ContentValues().apply {
            put("code", code)
            put("amount", amount)
            put("isUsed", 0)
            put("createdAt", System.currentTimeMillis())
        }
        helper.writableDatabase.insertWithOnConflict(
            "recharge_codes", null, values, android.database.sqlite.SQLiteDatabase.CONFLICT_IGNORE
        )
        return code
    }

    fun getAllRechargeCodes(): List<RechargeCode> {
        val list = mutableListOf<RechargeCode>()
        val c = helper.readableDatabase.rawQuery(
            "SELECT * FROM recharge_codes ORDER BY createdAt DESC", null
        )
        while (c.moveToNext()) {
            list.add(
                RechargeCode(
                    code = c.getString(c.getColumnIndexOrThrow("code")),
                    amount = c.getDouble(c.getColumnIndexOrThrow("amount")),
                    isUsed = c.getInt(c.getColumnIndexOrThrow("isUsed")) == 1,
                    usedBy = c.getString(c.getColumnIndexOrThrow("usedBy"))
                )
            )
        }
        c.close()
        return list
    }

    /** يُرجع JSON: {"ok":true,"amount":x} أو {"ok":false,"error":"..."} */
    fun redeemCode(code: String, userId: String): RedeemOutcomeInternal {
        val normalized = code.uppercase().trim()
        val db = helper.writableDatabase

        val profileExists = getProviderProfile(userId) != null
        if (!profileExists) return RedeemOutcomeInternal(false, 0.0, "المحفظة متاحة لمقدمي الخدمة فقط")

        val c = db.rawQuery("SELECT amount, isUsed FROM recharge_codes WHERE code=?", arrayOf(normalized))
        if (c.moveToFirst()) {
            val amount = c.getDouble(0)
            val isUsed = c.getInt(1) == 1
            c.close()
            if (isUsed) return RedeemOutcomeInternal(false, 0.0, "هذا الكود تم استخدامه مسبقاً")
            db.execSQL("UPDATE recharge_codes SET isUsed=1, usedBy=? WHERE code=?", arrayOf(userId, normalized))
            applyRecharge(userId, amount, normalized)
            return RedeemOutcomeInternal(true, amount, null)
        }
        c.close()

        val parsedAmount = RechargeCodeHelper.parseAmount(normalized)
            ?: return RedeemOutcomeInternal(false, 0.0, "كود الشحن غير صحيح")

        val values = ContentValues().apply {
            put("code", normalized)
            put("amount", parsedAmount)
            put("isUsed", 1)
            put("usedBy", userId)
            put("createdAt", System.currentTimeMillis())
        }
        db.insertWithOnConflict(
            "recharge_codes", null, values, android.database.sqlite.SQLiteDatabase.CONFLICT_IGNORE
        )
        applyRecharge(userId, parsedAmount, normalized)
        return RedeemOutcomeInternal(true, parsedAmount, null)
    }

    private fun applyRecharge(userId: String, amount: Double, code: String) {
        val db = helper.writableDatabase
        val current = getWalletBalance(userId)
        val newBalance = round((current + amount) * 100) / 100
        db.execSQL(
            "UPDATE provider_profiles SET walletBalance=? WHERE userId=?",
            arrayOf(newBalance, userId)
        )
        val values = ContentValues().apply {
            put("id", "tx_${UUID.randomUUID()}")
            put("walletOwnerId", userId)
            put("amount", amount)
            put("type", TransactionType.DEPOSIT.name)
            put("referenceNumber", code)
            put("createdAt", System.currentTimeMillis())
        }
        db.insert("transactions", null, values)
    }

    /** يخصم العمولة عند إرسال عرض سعر. */
    fun sendPriceOffer(orderId: String, senderId: String, price: Double): PriceOfferOutcomeInternal {
        val order = getOrder(orderId)
            ?: return PriceOfferOutcomeInternal("error", errorMessage = "الطلب غير موجود")
        val commission = round(price * AmanaConstants.COMMISSION_RATE * 100) / 100
        val balance = getWalletBalance(senderId)
        if (balance < commission) {
            return PriceOfferOutcomeInternal(
                "insufficient", requiredCommission = commission, currentBalance = balance
            )
        }
        addMessage(
            Message(
                id = "msg_${UUID.randomUUID()}",
                orderId = orderId,
                senderId = senderId,
                content = price.toInt().toString(),
                type = MessageType.PRICE_OFFER,
                timestamp = System.currentTimeMillis()
            )
        )
        val db = helper.writableDatabase
        db.execSQL(
            "UPDATE orders SET agreedPrice=?, commissionAmount=?, status=? WHERE id=?",
            arrayOf(price, commission, OrderStatus.NEGOTIATING.name, orderId)
        )
        // خصم العمولة من محفظة المزود
        val newBalance = round((balance - commission) * 100) / 100
        db.execSQL(
            "UPDATE provider_profiles SET walletBalance=? WHERE userId=?",
            arrayOf(newBalance, senderId)
        )
        db.execSQL(
            "INSERT INTO transactions(id, walletOwnerId, amount, type, orderId, referenceNumber, createdAt) " +
                "VALUES(?,?,?,?,?,?,?)",
            arrayOf(
                "tx_${UUID.randomUUID()}", senderId, commission,
                TransactionType.COMMISSION_DEDUCTION.name, orderId,
                "COM-${orderId.takeLast(4)}", System.currentTimeMillis()
            )
        )
        return PriceOfferOutcomeInternal("success")
    }

    // ---------------- Disputes ----------------

    fun createDispute(dispute: Dispute): String {
        val id = dispute.id.ifBlank { "disp_${UUID.randomUUID()}" }
        val values = ContentValues().apply {
            put("id", id)
            put("orderId", dispute.orderId)
            put("reporterId", dispute.reporterId)
            put("reason", dispute.reason)
            put("adminNotes", dispute.adminNotes)
            put("status", dispute.status.name)
            put("createdAt", System.currentTimeMillis())
        }
        helper.writableDatabase.insert("disputes", null, values)
        return id
    }

    fun updateDisputeStatus(disputeId: String, status: DisputeStatus, notes: String) {
        helper.writableDatabase.execSQL(
            "UPDATE disputes SET status=?, adminNotes=? WHERE id=?",
            arrayOf(status.name, notes, disputeId)
        )
    }

    fun getDisputes(): List<Dispute> {
        val list = mutableListOf<Dispute>()
        val c = helper.readableDatabase.rawQuery("SELECT * FROM disputes ORDER BY createdAt DESC", null)
        while (c.moveToNext()) {
            list.add(
                Dispute(
                    id = c.getString(c.getColumnIndexOrThrow("id")),
                    orderId = c.getString(c.getColumnIndexOrThrow("orderId")) ?: "",
                    reporterId = c.getString(c.getColumnIndexOrThrow("reporterId")) ?: "",
                    reason = c.getString(c.getColumnIndexOrThrow("reason")) ?: "",
                    adminNotes = c.getString(c.getColumnIndexOrThrow("adminNotes")) ?: "",
                    status = runCatching { DisputeStatus.valueOf(c.getString(c.getColumnIndexOrThrow("status"))) }
                        .getOrDefault(DisputeStatus.OPEN)
                )
            )
        }
        c.close()
        return list
    }

    // ---------------- Reviews ----------------

    fun addReview(review: Review): String {
        val id = review.id.ifBlank { "rev_${UUID.randomUUID()}" }
        val values = ContentValues().apply {
            put("id", id)
            put("orderId", review.orderId)
            put("customerId", review.customerId)
            put("providerId", review.providerId)
            put("rating", review.rating)
            put("comment", review.comment)
            put("createdAt", review.createdAt)
        }
        helper.writableDatabase.insert("reviews", null, values)
        recomputeRating(review.providerId)
        return id
    }

    private fun recomputeRating(providerId: String) {
        val c = helper.readableDatabase.rawQuery(
            "SELECT AVG(rating) FROM reviews WHERE providerId=?", arrayOf(providerId)
        )
        val avg = if (c.moveToFirst() && !c.isNull(0)) c.getDouble(0) else 0.0
        c.close()
        helper.writableDatabase.execSQL(
            "UPDATE provider_profiles SET ratingAvg=? WHERE userId=?",
            arrayOf(round(avg * 10) / 10, providerId)
        )
    }

    fun getReviews(): List<Review> {
        val list = mutableListOf<Review>()
        val c = helper.readableDatabase.rawQuery("SELECT * FROM reviews ORDER BY createdAt DESC", null)
        while (c.moveToNext()) {
            list.add(
                Review(
                    id = c.getString(c.getColumnIndexOrThrow("id")),
                    orderId = c.getString(c.getColumnIndexOrThrow("orderId")) ?: "",
                    customerId = c.getString(c.getColumnIndexOrThrow("customerId")) ?: "",
                    providerId = c.getString(c.getColumnIndexOrThrow("providerId")) ?: "",
                    rating = c.getFloat(c.getColumnIndexOrThrow("rating")),
                    comment = c.getString(c.getColumnIndexOrThrow("comment")) ?: "",
                    createdAt = c.getLong(c.getColumnIndexOrThrow("createdAt"))
                )
            )
        }
        c.close()
        return list
    }

    // ---------------- Notifications ----------------

    fun addNotification(n: AppNotification) {
        val values = ContentValues().apply {
            put("id", n.id.ifBlank { "n_${UUID.randomUUID()}" })
            put("userId", n.userId)
            put("title", n.title)
            put("body", n.body)
            put("timeAgo", n.timeAgo)
            put("type", n.type)
            put("isRead", if (n.isRead) 1 else 0)
            put("createdAt", System.currentTimeMillis())
        }
        helper.writableDatabase.insert("notifications", null, values)
    }

    fun getNotifications(userId: String): List<AppNotification> {
        val list = mutableListOf<AppNotification>()
        val c = helper.readableDatabase.rawQuery(
            "SELECT * FROM notifications WHERE userId=? ORDER BY createdAt DESC", arrayOf(userId)
        )
        while (c.moveToNext()) {
            list.add(
                AppNotification(
                    id = c.getString(c.getColumnIndexOrThrow("id")),
                    userId = c.getString(c.getColumnIndexOrThrow("userId")),
                    title = c.getString(c.getColumnIndexOrThrow("title")) ?: "",
                    body = c.getString(c.getColumnIndexOrThrow("body")) ?: "",
                    timeAgo = c.getString(c.getColumnIndexOrThrow("timeAgo")) ?: "",
                    type = c.getString(c.getColumnIndexOrThrow("type")) ?: "",
                    isRead = c.getInt(c.getColumnIndexOrThrow("isRead")) == 1
                )
            )
        }
        c.close()
        return list
    }

    // ---------------- Admin ----------------

    fun getDashboardStats(): DashboardStats {
        val db = helper.readableDatabase
        fun count(sql: String, args: Array<String>? = null): Int {
            val c = db.rawQuery(sql, args)
            val n = if (c.moveToFirst()) c.getInt(0) else 0
            c.close()
            return n
        }
        val totalUsers = count("SELECT COUNT(*) FROM users")
        val totalProviders = count("SELECT COUNT(*) FROM users WHERE role='PROVIDER'")
        val totalCustomers = count("SELECT COUNT(*) FROM users WHERE role='CUSTOMER'")
        val activeOrders = count("SELECT COUNT(*) FROM orders WHERE status NOT IN ('COMPLETED','CANCELLED')")
        val openDisputes = count("SELECT COUNT(*) FROM disputes WHERE status='OPEN'")
        val pendingProviders = count("SELECT COUNT(*) FROM provider_profiles WHERE isVerified=0")
        val cc = db.rawQuery(
            "SELECT SUM(amount) FROM transactions WHERE type='COMMISSION_DEDUCTION'", null
        )
        val totalCommission = if (cc.moveToFirst() && !cc.isNull(0)) cc.getDouble(0) else 0.0
        cc.close()
        return DashboardStats(
            totalUsers = totalUsers,
            totalProviders = totalProviders,
            totalCustomers = totalCustomers,
            activeOrders = activeOrders,
            openDisputes = openDisputes,
            pendingProviders = pendingProviders,
            totalCommission = totalCommission
        )
    }

    fun getAdminAlerts(): List<AdminAlert> {
        val alerts = mutableListOf<AdminAlert>()
        val stats = getDashboardStats()
        if (stats.pendingProviders > 0) {
            alerts.add(
                AdminAlert(
                    "al_pending", "${stats.pendingProviders} مزود بانتظار الاعتماد",
                    "يرجى مراجعة مستندات المزودين الجدد", "الآن", "action"
                )
            )
        }
        if (stats.openDisputes > 0) {
            alerts.add(
                AdminAlert(
                    "al_disputes", "${stats.openDisputes} نزاع مفتوح",
                    "توجد نزاعات تحتاج إلى مراجعة", "الآن", "warning"
                )
            )
        }
        if (stats.activeOrders > 0) {
            alerts.add(
                AdminAlert(
                    "al_orders", "${stats.activeOrders} طلب نشط",
                    "طلبات قيد التنفيذ حالياً في المنصة", "الآن", "info"
                )
            )
        }
        return alerts
    }

    data class RedeemOutcomeInternal(val ok: Boolean, val amount: Double, val error: String?)
    data class PriceOfferOutcomeInternal(
        val status: String,
        val requiredCommission: Double = 0.0,
        val currentBalance: Double = 0.0,
        val errorMessage: String = ""
    )
}
