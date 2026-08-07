package com.amana.provider.ui.screens.wallet

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.amana.core.models.Transaction
import com.amana.core.models.TransactionType
import com.amana.provider.viewmodel.ProviderViewModel
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WalletScreen(
    viewModel: ProviderViewModel
) {
    val providerProfile by viewModel.providerProfile.collectAsState()
    val transactions by viewModel.transactions.collectAsState()
    var showRechargeDialog by remember { mutableStateOf(false) }
    var rechargeCode by remember { mutableStateOf("") }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("المحفظة") },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary
                )
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp)
        ) {
            // Balance Card
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer
                )
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        "الرصيد الحالي",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onPrimaryContainer
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        "${providerProfile?.walletBalance ?: 0.0} ريال",
                        style = MaterialTheme.typography.displayMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Recharge Button
            Button(
                onClick = { showRechargeDialog = true },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.secondary
                )
            ) {
                Icon(Icons.Default.Add, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text("شحن المحفظة")
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Warning Card
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.errorContainer
                )
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Default.Info,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.error
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Column {
                        Text(
                            "تذكير مهم",
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.error
                        )
                        Text(
                            "يجب أن يكون الرصيد كافياً لتغطية العمولة (15%) قبل إرسال عروض الأسعار",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onErrorContainer
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Transactions History
            Text(
                "سجل العمليات",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )

            Spacer(modifier = Modifier.height(12.dp))

            if (transactions.isEmpty()) {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(32.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            "لا توجد عمليات حتى الآن",
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(transactions) { transaction ->
                        TransactionItem(transaction)
                    }
                }
            }
        }

        // Recharge Dialog
        if (showRechargeDialog) {
            AlertDialog(
                onDismissRequest = {
                    showRechargeDialog = false
                    errorMessage = null
                },
                title = { Text("شحن المحفظة") },
                text = {
                    Column {
                        Text("أدخل كود الشحن:")
                        Spacer(modifier = Modifier.height(8.dp))
                        OutlinedTextField(
                            value = rechargeCode,
                            onValueChange = { rechargeCode = it },
                            label = { Text("كود الشحن") },
                            modifier = Modifier.fillMaxWidth()
                        )
                        errorMessage?.let { error ->
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                error,
                                color = MaterialTheme.colorScheme.error,
                                style = MaterialTheme.typography.bodySmall
                            )
                        }
                    }
                },
                confirmButton = {
                    TextButton(
                        onClick = {
                            viewModel.rechargeWallet(rechargeCode) { success, newBalance, error ->
                                if (success) {
                                    showRechargeDialog = false
                                    rechargeCode = ""
                                    errorMessage = null
                                } else {
                                    errorMessage = error
                                }
                            }
                        }
                    ) {
                        Text("شحن")
                    }
                },
                dismissButton = {
                    TextButton(
                        onClick = {
                            showRechargeDialog = false
                            rechargeCode = ""
                            errorMessage = null
                        }
                    ) {
                        Text("إلغاء")
                    }
                }
            )
        }
    }
}

@Composable
fun TransactionItem(transaction: Transaction) {
    Card(
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    when (transaction.type) {
                        TransactionType.DEPOSIT -> Icons.Default.Add
                        TransactionType.COMMISSION_DEDUCTION -> Icons.Default.Remove
                        TransactionType.REFUND -> Icons.Default.Refresh
                    },
                    contentDescription = null,
                    tint = if (transaction.type == TransactionType.DEPOSIT) 
                        MaterialTheme.colorScheme.secondary else MaterialTheme.colorScheme.error
                )
                Spacer(modifier = Modifier.width(12.dp))
                Column {
                    Text(
                        when (transaction.type) {
                            TransactionType.DEPOSIT -> "شحن رصيد"
                            TransactionType.COMMISSION_DEDUCTION -> "خصم عمولة"
                            TransactionType.REFUND -> "استرجاع"
                        },
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Medium
                    )
                    Text(
                        SimpleDateFormat("dd/MM/yyyy HH:mm", Locale("ar")).format(Date(transaction.createdAt)),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            
            Text(
                "${if (transaction.amount >= 0) "+" else ""}${transaction.amount} ر.س",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = if (transaction.amount >= 0) 
                    MaterialTheme.colorScheme.secondary else MaterialTheme.colorScheme.error
            )
        }
    }
}
