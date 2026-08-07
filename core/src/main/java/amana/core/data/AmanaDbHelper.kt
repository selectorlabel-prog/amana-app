package amana.core.data

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/**
 * قاعدة بيانات الهاتف المحلية (بلا إنترنت / بلا خادم).
 * تُخزّن على الجهاز نفسه وتُشارَك بين تطبيق المستخدم وتطبيق المشرف
 * عبر ContentProvider.
 */
class AmanaDbHelper(context: Context) :
    SQLiteOpenHelper(context.applicationContext, DB_NAME, null, DB_VERSION) {

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """CREATE TABLE users(
                id TEXT PRIMARY KEY, fullName TEXT, phoneNumber TEXT,
                role TEXT, city TEXT, district TEXT, avatarUrl TEXT,
                status TEXT, createdAt INTEGER)"""
        )
        db.execSQL(
            """CREATE TABLE provider_profiles(
                userId TEXT PRIMARY KEY, bio TEXT, skills TEXT,
                walletBalance REAL, ratingAvg REAL, isVerified INTEGER,
                identityDocs TEXT, specialty TEXT)"""
        )
        db.execSQL(
            """CREATE TABLE services(
                id TEXT PRIMARY KEY, providerId TEXT, serviceName TEXT,
                basePrice REAL, description TEXT)"""
        )
        db.execSQL(
            """CREATE TABLE categories(
                id TEXT PRIMARY KEY, name TEXT, iconEmoji TEXT)"""
        )
        db.execSQL(
            """CREATE TABLE orders(
                id TEXT PRIMARY KEY, customerId TEXT, providerId TEXT,
                serviceId TEXT, serviceName TEXT, status TEXT,
                agreedPrice REAL, commissionAmount REAL,
                customerLat REAL, customerLng REAL,
                providerLat REAL, providerLng REAL,
                createdAt INTEGER, completedAt INTEGER)"""
        )
        db.execSQL(
            """CREATE TABLE messages(
                id TEXT PRIMARY KEY, orderId TEXT, senderId TEXT,
                content TEXT, type TEXT, timestamp INTEGER)"""
        )
        db.execSQL(
            """CREATE TABLE transactions(
                id TEXT PRIMARY KEY, walletOwnerId TEXT, amount REAL,
                type TEXT, orderId TEXT, referenceNumber TEXT, createdAt INTEGER)"""
        )
        db.execSQL(
            """CREATE TABLE disputes(
                id TEXT PRIMARY KEY, orderId TEXT, reporterId TEXT,
                reason TEXT, adminNotes TEXT, status TEXT, createdAt INTEGER)"""
        )
        db.execSQL(
            """CREATE TABLE recharge_codes(
                code TEXT PRIMARY KEY, amount REAL, isUsed INTEGER,
                usedBy TEXT, createdAt INTEGER)"""
        )
        db.execSQL(
            """CREATE TABLE reviews(
                id TEXT PRIMARY KEY, orderId TEXT, customerId TEXT,
                providerId TEXT, rating REAL, comment TEXT, createdAt INTEGER)"""
        )
        db.execSQL(
            """CREATE TABLE notifications(
                id TEXT PRIMARY KEY, userId TEXT, title TEXT, body TEXT,
                timeAgo TEXT, type TEXT, isRead INTEGER, createdAt INTEGER)"""
        )
        seedReferenceData(db)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        val tables = listOf(
            "users", "provider_profiles", "services", "categories", "orders",
            "messages", "transactions", "disputes", "recharge_codes",
            "reviews", "notifications"
        )
        tables.forEach { db.execSQL("DROP TABLE IF EXISTS $it") }
        onCreate(db)
    }

    /** بيانات مرجعية ثابتة فقط (تصنيفات الخدمات). لا مستخدمين وهميين. */
    private fun seedReferenceData(db: SQLiteDatabase) {
        val categories = listOf(
            Triple("1", "سباكة", "\uD83D\uDD27"),
            Triple("2", "كهرباء", "\u26A1"),
            Triple("3", "تكييف", "\u2744\uFE0F"),
            Triple("4", "دهان", "\uD83C\uDFA8"),
            Triple("5", "نظافة", "\uD83E\uDDF9"),
            Triple("6", "توصيل", "\uD83D\uDE9A"),
            Triple("7", "نجارة", "\uD83E\uDE9A"),
            Triple("8", "حدادة", "\uD83D\uDD28")
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
