package amana.core.data

object RechargeCodeHelper {
    /** Generates a code that both admin-app and user-app can validate without shared storage. */
    fun generateCode(amount: Double): String {
        val amountInt = amount.toInt()
        val checksum = checksum(amountInt)
        return "AMN$amountInt$checksum"
    }

    fun parseAmount(code: String): Double? {
        val normalized = code.uppercase().trim()
        if (!normalized.startsWith("AMN")) return null
        val body = normalized.removePrefix("AMN")
        if (body.length < 5) return null
        val checksumStr = body.takeLast(4)
        val amountStr = body.dropLast(4)
        val amount = amountStr.toIntOrNull() ?: return null
        val checksum = checksumStr.toIntOrNull() ?: return null
        if (checksum(amount) != checksum) return null
        if (amount <= 0) return null
        return amount.toDouble()
    }

    private fun checksum(amount: Int): Int {
        return ((amount * 31 + 7919) % 10000).toString().padStart(4, '0').toInt()
    }
}
