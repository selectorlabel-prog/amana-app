package com.amana.core.repository

import android.content.Context
import com.amana.core.database.AmanaDao
import com.amana.core.models.*
import java.util.UUID

/**
 * مستودع أمانة - يحتوي على منطق الأعمال
 * Repository Pattern
 */
class AmanaRepository(context: Context) {
    private val dao = AmanaDao(context)

    companion object {
        const val COMMISSION_RATE = 0.15 // 15% عمولة
    }

    // ============= User & Authentication =============
    
    fun registerUser(fullName: String, phoneNumber: String, role: UserRole, city: String, district: String): User {
        // Check if user already exists
        val existing = dao.getUserByPhone(phoneNumber)
        if (existing != null) throw Exception("رقم الهاتف مسجل مسبقاً")

        val user = User(
            fullName = fullName,
            phoneNumber = phoneNumber,
            role = role,
            city = city,
            district = district,
            status = if (role == UserRole.PROVIDER) UserStatus.PENDING_VERIFICATION else UserStatus.ACTIVE
        )
        
        dao.insertUser(user)
        
        // If provider, create profile
        if (role == UserRole.PROVIDER) {
            val profile = ProviderProfile(userId = user.id)
            dao.insertProviderProfile(profile)
        }
        
        return user
    }

    fun loginUser(phoneNumber: String): User? {
        return dao.getUserByPhone(phoneNumber)
    }

    fun updateProviderProfile(profile: ProviderProfile) {
        dao.insertProviderProfile(profile) // Uses REPLACE strategy
    }

    // ============= Order Management =============
    
    /**
     * إنشاء طلب جديد من قبل العميل
     */
    fun createOrder(
        customerId: String,
        providerId: String,
        serviceId: String,
        serviceName: String,
        customerLat: Double,
        customerLng: Double
    ): Order {
        val order = Order(
            customerId = customerId,
            providerId = providerId,
            serviceId = serviceId,
            serviceName = serviceName,
            status = OrderStatus.PENDING,
            customerLat = customerLat,
            customerLng = customerLng
        )
        
        dao.insertOrder(order)
        
        // Send notification to provider
        dao.insertNotification(
            AppNotification(
                userId = providerId,
                title = "طلب جديد",
                body = "لديك طلب جديد من عميل لخدمة $serviceName",
                type = "NEW_ORDER"
            )
        )
        
        return order
    }

    /**
     * إرسال عرض سعر من مقدم الخدمة
     * يتم التحقق من رصيد المحفظة قبل الإرسال
     */
    fun sendPriceOffer(
        orderId: String,
        providerId: String,
        offeredPrice: Double
    ): Result<Message> {
        // Calculate commission
        val commissionAmount = offeredPrice * COMMISSION_RATE
        
        // Check provider wallet balance
        val profile = dao.getProviderProfile(providerId)
            ?: return Result.failure(Exception("ملف مقدم الخدمة غير موجود"))
        
        if (profile.walletBalance < commissionAmount) {
            return Result.failure(Exception("رصيد المحفظة غير كافٍ. يجب شحن ${commissionAmount} ريال على الأقل"))
        }
        
        // Update order with agreed price
        dao.updateOrderPrice(orderId, offeredPrice, commissionAmount)
        dao.updateOrderStatus(orderId, OrderStatus.NEGOTIATING)
        
        // Send price offer message
        val message = Message(
            orderId = orderId,
            senderId = providerId,
            content = "عرض السعر: $offeredPrice ريال",
            type = MessageType.PRICE_OFFER
        )
        dao.insertMessage(message)
        
        // Notify customer
        val order = dao.getOrderById(orderId)
        order?.let {
            dao.insertNotification(
                AppNotification(
                    userId = it.customerId,
                    title = "عرض سعر جديد",
                    body = "تم استلام عرض سعر: $offeredPrice ريال",
                    type = "PRICE_OFFER"
                )
            )
        }
        
        return Result.success(message)
    }

    /**
     * قبول عرض السعر من قبل العميل
     */
    fun acceptPriceOffer(orderId: String): Result<Order> {
        val order = dao.getOrderById(orderId)
            ?: return Result.failure(Exception("الطلب غير موجود"))
        
        dao.updateOrderStatus(orderId, OrderStatus.ACCEPTED)
        
        // Notify provider
        dao.insertNotification(
            AppNotification(
                userId = order.providerId,
                title = "تم قبول العرض",
                body = "قام العميل بقبول عرضك",
                type = "OFFER_ACCEPTED"
            )
        )
        
        return Result.success(order.copy(status = OrderStatus.ACCEPTED))
    }

    /**
     * بدء العمل على الطلب
     */
    fun startOrder(orderId: String): Result<Order> {
        dao.updateOrderStatus(orderId, OrderStatus.IN_PROGRESS)
        val order = dao.getOrderById(orderId)
            ?: return Result.failure(Exception("الطلب غير موجود"))
        
        // Notify customer
        dao.insertNotification(
            AppNotification(
                userId = order.customerId,
                title = "بدأ العمل",
                body = "مقدم الخدمة في الطريق إليك",
                type = "ORDER_STARTED"
            )
        )
        
        return Result.success(order)
    }

    /**
     * إتمام الطلب وخصم العمولة
     */
    fun completeOrder(orderId: String): Result<Order> {
        val order = dao.getOrderById(orderId)
            ?: return Result.failure(Exception("الطلب غير موجود"))
        
        val profile = dao.getProviderProfile(order.providerId)
            ?: return Result.failure(Exception("ملف مقدم الخدمة غير موجود"))
        
        // Deduct commission
        val newBalance = profile.walletBalance - order.commissionAmount
        if (newBalance < 0) {
            return Result.failure(Exception("خطأ في الرصيد"))
        }
        
        dao.updateWalletBalance(order.providerId, newBalance)
        
        // Record transaction
        dao.insertTransaction(
            Transaction(
                walletOwnerId = order.providerId,
                amount = -order.commissionAmount,
                type = TransactionType.COMMISSION_DEDUCTION,
                orderId = orderId,
                referenceNumber = "COM-${UUID.randomUUID().toString().substring(0, 8)}"
            )
        )
        
        // Update order status
        dao.updateOrderStatus(orderId, OrderStatus.COMPLETED)
        
        // Update provider stats
        dao.insertProviderProfile(
            profile.copy(
                walletBalance = newBalance,
                totalEarnings = profile.totalEarnings + order.agreedPrice,
                completedOrders = profile.completedOrders + 1
            )
        )
        
        // Notify customer
        dao.insertNotification(
            AppNotification(
                userId = order.customerId,
                title = "تم إكمال الطلب",
                body = "يرجى تقييم مقدم الخدمة",
                type = "ORDER_COMPLETED"
            )
        )
        
        return Result.success(order.copy(status = OrderStatus.COMPLETED))
    }

    /**
     * إلغاء الطلب
     */
    fun cancelOrder(orderId: String, reason: String = ""): Result<Order> {
        dao.updateOrderStatus(orderId, OrderStatus.CANCELLED)
        val order = dao.getOrderById(orderId)
            ?: return Result.failure(Exception("الطلب غير موجود"))
        
        return Result.success(order)
    }

    // ============= Messaging =============
    
    fun sendMessage(orderId: String, senderId: String, content: String, type: MessageType = MessageType.TEXT): Message {
        val message = Message(
            orderId = orderId,
            senderId = senderId,
            content = content,
            type = type
        )
        dao.insertMessage(message)
        
        // Notify recipient
        val order = dao.getOrderById(orderId)
        order?.let {
            val recipientId = if (senderId == it.customerId) it.providerId else it.customerId
            dao.insertNotification(
                AppNotification(
                    userId = recipientId,
                    title = "رسالة جديدة",
                    body = content.take(50),
                    type = "NEW_MESSAGE"
                )
            )
        }
        
        return message
    }

    fun getMessages(orderId: String): List<Message> {
        return dao.getMessagesByOrderId(orderId)
    }

    // ============= Wallet & Recharge =============
    
    /**
     * شحن المحفظة باستخدام كود
     */
    fun redeemRechargeCode(userId: String, codeStr: String): Result<Double> {
        val code = dao.getRechargeCodeByCode(codeStr)
            ?: return Result.failure(Exception("كود غير صحيح"))
        
        if (code.isUsed) {
            return Result.failure(Exception("الكود مستخدم مسبقاً"))
        }
        
        // Mark code as used
        dao.markCodeAsUsed(codeStr, userId)
        
        // Add balance
        val profile = dao.getProviderProfile(userId)
            ?: return Result.failure(Exception("ملف مقدم الخدمة غير موجود"))
        
        val newBalance = profile.walletBalance + code.amount
        dao.updateWalletBalance(userId, newBalance)
        
        // Record transaction
        dao.insertTransaction(
            Transaction(
                walletOwnerId = userId,
                amount = code.amount,
                type = TransactionType.DEPOSIT,
                referenceNumber = codeStr
            )
        )
        
        return Result.success(newBalance)
    }

    /**
     * إنشاء كود شحن (للإدارة فقط)
     */
    fun generateRechargeCode(amount: Double): RechargeCode {
        val code = "AMANA-${UUID.randomUUID().toString().substring(0, 8).uppercase()}"
        val rechargeCode = RechargeCode(
            code = code,
            amount = amount
        )
        dao.insertRechargeCode(rechargeCode)
        return rechargeCode
    }

    fun getTransactions(userId: String): List<Transaction> {
        return dao.getTransactionsByUserId(userId)
    }

    // ============= Reviews =============
    
    fun addReview(orderId: String, customerId: String, providerId: String, rating: Float, comment: String): Result<Review> {
        val review = Review(
            orderId = orderId,
            customerId = customerId,
            providerId = providerId,
            rating = rating,
            comment = comment
        )
        
        dao.insertReview(review)
        
        // Update provider rating
        val reviews = dao.getReviewsByProviderId(providerId)
        val avgRating = reviews.map { it.rating }.average()
        
        val profile = dao.getProviderProfile(providerId)
        profile?.let {
            dao.insertProviderProfile(it.copy(ratingAvg = avgRating))
        }
        
        return Result.success(review)
    }

    fun getProviderReviews(providerId: String): List<Review> {
        return dao.getReviewsByProviderId(providerId)
    }

    // ============= Disputes =============
    
    fun createDispute(orderId: String, reporterId: String, reason: String): Dispute {
        val dispute = Dispute(
            orderId = orderId,
            reporterId = reporterId,
            reason = reason
        )
        dao.insertDispute(dispute)
        return dispute
    }

    fun getAllDisputes(): List<Dispute> {
        return dao.getAllDisputes()
    }

    fun resolveDispute(disputeId: String, adminNotes: String): Result<Dispute> {
        dao.updateDisputeStatus(disputeId, DisputeStatus.RESOLVED, adminNotes)
        return Result.success(Dispute(id = disputeId, orderId = "", reporterId = "", reason = "", adminNotes = adminNotes, status = DisputeStatus.RESOLVED))
    }

    // ============= Query Methods =============
    
    fun getUser(userId: String) = dao.getUserById(userId)
    fun getUserByPhone(phone: String) = dao.getUserByPhone(phone)
    fun getAllUsers() = dao.getAllUsers()
    fun getProviderProfile(userId: String) = dao.getProviderProfile(userId)
    fun getAllProviders() = dao.getAllProviders()
    fun getServicesByProviderId(providerId: String) = dao.getServicesByProviderId(providerId)
    fun getAllCategories() = dao.getAllCategories()
    fun getOrder(orderId: String) = dao.getOrderById(orderId)
    fun getCustomerOrders(customerId: String) = dao.getOrdersByCustomerId(customerId)
    fun getProviderOrders(providerId: String) = dao.getOrdersByProviderId(providerId)
    fun getNotifications(userId: String) = dao.getNotificationsByUserId(userId)
    fun markNotificationRead(notificationId: String) = dao.markNotificationAsRead(notificationId)
    
    fun close() {
        dao.close()
    }
}
