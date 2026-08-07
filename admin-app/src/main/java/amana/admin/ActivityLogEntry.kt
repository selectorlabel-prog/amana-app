package amana.admin

data class ActivityLogEntry(
    val action: String,
    val detail: String,
    val timeAgo: String
)
