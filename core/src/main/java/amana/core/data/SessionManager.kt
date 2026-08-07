package amana.core.data

import android.content.Context
import android.content.SharedPreferences
import amana.core.models.User
import amana.core.models.UserRole
import amana.core.models.UserStatus

object SessionManager {

    private lateinit var prefs: SharedPreferences
    private lateinit var repo: AmanaRepository
    private var initialized = false

    private var cachedUserId: String = ""
    private var cachedProfileComplete: Boolean = false
    private var cachedPendingPhone: String = ""

    private const val PREFS = "amana_session"
    private const val KEY_USER_ID = "user_id"
    private const val KEY_PENDING_PHONE = "pending_phone"
    private const val KEY_PROFILE_COMPLETE = "profile_complete"

    fun init(context: Context) {
        val app = context.applicationContext
        if (!initialized) {
            prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            repo = AmanaRepository.get(app)
            cachedUserId = prefs.getString(KEY_USER_ID, "") ?: ""
            cachedProfileComplete = prefs.getBoolean(KEY_PROFILE_COMPLETE, false)
            cachedPendingPhone = prefs.getString(KEY_PENDING_PHONE, "") ?: ""
            initialized = true
        }
    }

    private fun requireInit() {
        check(initialized) { "SessionManager.init() لم يُستدعَ — أعد تشغيل التطبيق" }
    }

    val pendingPhone: String
        get() {
            requireInit()
            return cachedPendingPhone
        }

    var isProfileComplete: Boolean
        get() {
            requireInit()
            return cachedProfileComplete
        }
        private set(value) {
            cachedProfileComplete = value
            if (initialized) {
                prefs.edit().putBoolean(KEY_PROFILE_COMPLETE, value).commit()
            }
        }

    val currentUser: User?
        get() {
            requireInit()
            return if (cachedUserId.isBlank()) null else repo.getUser(cachedUserId)
        }

    val isLoggedIn: Boolean
        get() {
            requireInit()
            return cachedUserId.isNotBlank()
        }

    val userId: String
        get() {
            requireInit()
            return cachedUserId
        }

    val userRole: UserRole
        get() = currentUser?.role ?: UserRole.CUSTOMER

    fun needsRegistration(): Boolean = isLoggedIn && !isProfileComplete

    fun setPendingPhone(phone: String) {
        requireInit()
        cachedPendingPhone = normalizePhone(phone)
        prefs.edit().putString(KEY_PENDING_PHONE, cachedPendingPhone).commit()
    }

    fun completeLogin(phone: String): User {
        requireInit()
        val normalized = normalizePhone(phone)
        if (normalized.isBlank()) {
            throw IllegalStateException("رقم الهاتف فارغ")
        }

        val existing = repo.getUserByPhone(normalized)
        if (existing != null) {
            cachedUserId = existing.id
            cachedProfileComplete = existing.fullName.isNotBlank()
            prefs.edit()
                .putString(KEY_USER_ID, cachedUserId)
                .putBoolean(KEY_PROFILE_COMPLETE, cachedProfileComplete)
                .commit()
            return existing
        }

        val newId = "user_${normalized.filter { it.isDigit() }}"
        val user = User(
            id = newId,
            phoneNumber = normalized,
            fullName = "",
            city = "",
            district = "",
            status = UserStatus.ACTIVE
        )
        repo.ensureUser(user)
        val saved = repo.getUser(newId)
            ?: throw IllegalStateException("فشل حفظ المستخدم في قاعدة البيانات")

        cachedUserId = newId
        cachedProfileComplete = false
        prefs.edit()
            .putString(KEY_USER_ID, newId)
            .putBoolean(KEY_PROFILE_COMPLETE, false)
            .commit()
        return saved
    }

    fun completeRegistration(fullName: String, city: String, district: String) {
        requireInit()
        val id = cachedUserId
        if (id.isBlank()) throw IllegalStateException("لا توجد جلسة نشطة")
        repo.completeRegistration(id, fullName, city, district)
        cachedProfileComplete = true
        prefs.edit().putBoolean(KEY_PROFILE_COMPLETE, true).commit()
    }

    fun setRole(role: UserRole) {
        requireInit()
        val id = cachedUserId
        if (id.isBlank()) throw IllegalStateException("لا توجد جلسة نشطة")
        repo.updateUserRole(id, role)
    }

    fun logout() {
        if (!initialized) return
        cachedUserId = ""
        cachedProfileComplete = false
        cachedPendingPhone = ""
        prefs.edit()
            .remove(KEY_USER_ID)
            .remove(KEY_PENDING_PHONE)
            .remove(KEY_PROFILE_COMPLETE)
            .commit()
    }

    fun normalizePhone(input: String): String {
        var phone = input.trim().replace(" ", "")
        if (phone.startsWith("0")) phone = "+249${phone.drop(1)}"
        if (phone.startsWith("249")) phone = "+$phone"
        if (!phone.startsWith("+") && phone.length == 9) phone = "+249$phone"
        return phone
    }

    fun isValidSudanPhone(phone: String): Boolean {
        val normalized = normalizePhone(phone)
        return normalized.matches(Regex("^\\+249[0-9]{9}$"))
    }
}
