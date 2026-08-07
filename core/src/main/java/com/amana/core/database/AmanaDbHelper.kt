package com.amana.core.database

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/**
 * قاعدة بيانات أمانة - SQLite
 * تخزن جميع البيانات محلياً على الجهاز
 */
class AmanaDbHelper(context: Context) :
    SQLiteOpenHelper(context.applicationContext, DB_NAME, null, DB_VERSION) {

    override fun onCreate(db: SQLiteDatabase) {
        // جدول المستخدمين (Users Table)
        db.execSQL("""
            CREATE TABLE users(
                id TEXT PRIMARY KEY,
                fullName TEXT NOT NULL,
                phoneNumber TEXT UNIQUE NOT NULL,
                role TEXT NOT NULL,
                city TEXT,
                district TEXT,
                avatarUrl TEXT,
                status TEXT NOT NULL,
                createdAt INTEGER NOT NULL
            )
        """)

        // جدول ملفات مقدمي الخدمة (Provider_Profiles Table)
        db.execSQL("""
            CREATE TABLE provider_profiles(
                userId TEXT PRIMARY KEY,
                bio TEXT,
                skills TEXT,
                walletBalance REAL NOT NULL DEFAULT 0,
                ratingAvg REAL NOT NULL DEFAULT 0,
                isVerified INTEGER NOT NULL DEFAULT 0,
                identityDocs TEXT,
                totalEarnings REAL NOT NULL DEFAULT 0,
                completedOrders INTEGER NOT NULL DEFAULT 0,
                FOREIGN KEY(userId) REFERENCES users(id) ON DELETE CASCADE
            )
        """)

        // جدول الخدمات والأسعار (Services Table)
        db.execSQL("""
            CREATE TABLE services(
                id TEXT PRIMARY KEY,
                providerId TEXT NOT NULL,
                serviceName TEXT NOT NULL,
                basePrice REAL NOT NULL,
                description TEXT,
                FOREIGN KEY(providerId) REFERENCES users(id) ON DELETE CASCADE
            )
        """)

        // تصنيفات الخدمات
        db.execSQL("""
            CREATE TABLE categories(
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                iconEmoji TEXT
            )
        """)

        // جدول الطلبات (Orders Table)
        db.execSQL("""
            CREATE TABLE orders(
                id TEXT PRIMARY KEY,
                customerId TEXT NOT NULL,
                providerId TEXT NOT NULL,
                serviceId TEXT NOT NULL,
                serviceName TEXT NOT NULL,
                status TEXT NOT NULL,
                agreedPrice REAL NOT NULL DEFAULT 0,
                commissionAmount REAL NOT NULL DEFAULT 0,
                customerLat REAL NOT NULL,
                customerLng REAL NOT NULL,
                providerLat REAL NOT NULL DEFAULT 0,
                providerLng REAL NOT NULL DEFAULT 0,
                createdAt INTEGER NOT NULL,
                completedAt INTEGER,
                FOREIGN KEY(customerId) REFERENCES users(id),
                FOREIGN KEY(providerId) REFERENCES users(id),
                FOREIGN KEY(serviceId) REFERENCES services(id)
            )
        """)

        // جدول المحادثات (Messages Table)
        db.execSQL("""
            CREATE TABLE messages(
                id TEXT PRIMARY KEY,
                orderId TEXT NOT NULL,
                senderId TEXT NOT NULL,
                content TEXT NOT NULL,
                type TEXT NOT NULL,
                timestamp INTEGER NOT NULL,
                FOREIGN KEY(orderId) REFERENCES orders(id) ON DELETE CASCADE,
                FOREIGN KEY(senderId) REFERENCES users(id)
            )
        """)

        // جدول العمليات المالية (Transactions Table)
        db.execSQL("""
            CREATE TABLE transactions(
                id TEXT PRIMARY KEY,
                walletOwnerId TEXT NOT NULL,
                amount REAL NOT NULL,
                type TEXT NOT NULL,
                orderId TEXT,
                referenceNumber TEXT,
                createdAt INTEGER NOT NULL,
                FOREIGN KEY(walletOwnerId) REFERENCES users(id),
                FOREIGN KEY(orderId) REFERENCES orders(id)
            )
        """)

        // جدول البلاغات والنزاعات (Disputes Table)
        db.execSQL("""
            CREATE TABLE disputes(
                id TEXT PRIMARY KEY,
                orderId TEXT NOT NULL,
                reporterId TEXT NOT NULL,
                reason TEXT NOT NULL,
                adminNotes TEXT,
                status TEXT NOT NULL,
                createdAt INTEGER NOT NULL,
                FOREIGN KEY(orderId) REFERENCES orders(id),
                FOREIGN KEY(reporterId) REFERENCES users(id)
            )
        """)

        // جدول التقييمات
        db.execSQL("""
            CREATE TABLE reviews(
                id TEXT PRIMARY KEY,
                orderId TEXT NOT NULL UNIQUE,
                customerId TEXT NOT NULL,
                providerId TEXT NOT NULL,
                rating REAL NOT NULL,
                comment TEXT,
                createdAt INTEGER NOT NULL,
                FOREIGN KEY(orderId) REFERENCES orders(id),
                FOREIGN KEY(customerId) REFERENCES users(id),
                FOREIGN KEY(providerId) REFERENCES users(id)
            )
        """)

        // كروت الشحن
        db.execSQL("""
            CREATE TABLE recharge_codes(
                code TEXT PRIMARY KEY,
                amount REAL NOT NULL,
                isUsed INTEGER NOT NULL DEFAULT 0,
                usedBy TEXT,
                createdAt INTEGER NOT NULL,
                FOREIGN KEY(usedBy) REFERENCES users(id)
            )
        """)

        // الإشعارات
        db.execSQL("""
            CREATE TABLE notifications(
                id TEXT PRIMARY KEY,
                userId TEXT NOT NULL,
                title TEXT NOT NULL,
                body TEXT NOT NULL,
                type TEXT NOT NULL,
                isRead INTEGER NOT NULL DEFAULT 0,
                createdAt INTEGER NOT NULL,
                FOREIGN KEY(userId) REFERENCES users(id) ON DELETE CASCADE
            )
        """)

        // إنشاء الفهارس لتحسين الأداء
        db.execSQL("CREATE INDEX idx_orders_customer ON orders(customerId)")
        db.execSQL("CREATE INDEX idx_orders_provider ON orders(providerId)")
        db.execSQL("CREATE INDEX idx_orders_status ON orders(status)")
        db.execSQL("CREATE INDEX idx_messages_order ON messages(orderId)")
        db.execSQL("CREATE INDEX idx_transactions_wallet ON transactions(walletOwnerId)")
        db.execSQL("CREATE INDEX idx_notifications_user ON notifications(userId)")

        // إدراج البيانات المرجعية (تصنيفات الخدمات)
        seedReferenceData(db)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // في حالة الترقية، نحذف الجداول ونعيد إنشاءها
        val tables = listOf(
            "notifications", "recharge_codes", "reviews", "disputes",
            "transactions", "messages", "orders", "services",
            "categories", "provider_profiles", "users"
        )
        tables.forEach { db.execSQL("DROP TABLE IF EXISTS $it") }
        onCreate(db)
    }

    /**
     * إدراج البيانات المرجعية (تصنيفات الخدمات)
     */
    private fun seedReferenceData(db: SQLiteDatabase) {
        val categories = listOf(
            Triple("1", "سباكة", "🔧"),
            Triple("2", "كهرباء", "⚡"),
            Triple("3", "تكييف", "❄️"),
            Triple("4", "دهان", "🎨"),
            Triple("5", "نظافة", "🧹"),
            Triple("6", "توصيل", "🚚"),
            Triple("7", "نجارة", "🪚"),
            Triple("8", "حدادة", "🔨"),
            Triple("9", "صيانة", "🔧"),
            Triple("10", "أخرى", "⭐")
        )
        
        categories.forEach { (id, name, icon) ->
            db.execSQL(
                "INSERT INTO categories(id, name, iconEmoji) VALUES(?,?,?)",
                arrayOf(id, name, icon)
            )
        }
    }

    companion object {
        const val DB_NAME = "amana.db"
        const val DB_VERSION = 1
    }
}
