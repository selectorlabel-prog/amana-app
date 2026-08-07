package com.amana.provider.ui.screens.orders

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
import com.amana.core.models.Order
import com.amana.core.models.OrderStatus
import com.amana.provider.viewmodel.ProviderViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProviderOrdersScreen(
    viewModel: ProviderViewModel
) {
    val newOrders by viewModel.newOrders.collectAsState()
    val activeOrders by viewModel.activeOrders.collectAsState()
    var selectedTabIndex by remember { mutableStateOf(0) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("الطلبات") },
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
        ) {
            TabRow(selectedTabIndex = selectedTabIndex) {
                Tab(
                    selected = selectedTabIndex == 0,
                    onClick = { selectedTabIndex = 0 },
                    text = { Text("جديدة (${newOrders.size})") }
                )
                Tab(
                    selected = selectedTabIndex == 1,
                    onClick = { selectedTabIndex = 1 },
                    text = { Text("نشطة (${activeOrders.size})") }
                )
            }

            when (selectedTabIndex) {
                0 -> OrdersList(
                    orders = newOrders,
                    viewModel = viewModel,
                    isNew = true
                )
                1 -> OrdersList(
                    orders = activeOrders,
                    viewModel = viewModel,
                    isNew = false
                )
            }
        }
    }
}

@Composable
fun OrdersList(
    orders: List<Order>,
    viewModel: ProviderViewModel,
    isNew: Boolean
) {
    if (orders.isEmpty()) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            Text(
                if (isNew) "لا توجد طلبات جديدة" else "لا توجد طلبات نشطة",
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    } else {
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(orders) { order ->
                ProviderOrderCard(
                    order = order,
                    viewModel = viewModel,
                    isNew = isNew
                )
            }
        }
    }
}

@Composable
fun ProviderOrderCard(
    order: Order,
    viewModel: ProviderViewModel,
    isNew: Boolean
) {
    var showPriceDialog by remember { mutableStateOf(false) }
    var priceOffer by remember { mutableStateOf("") }
    var showStartDialog by remember { mutableStateOf(false) }
    var showCompleteDialog by remember { mutableStateOf(false) }

    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = order.serviceName,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                
                when (order.status) {
                    OrderStatus.PENDING -> Badge { Text("جديد") }
                    OrderStatus.NEGOTIATING -> Badge(containerColor = MaterialTheme.colorScheme.tertiary) { Text("تفاوض") }
                    OrderStatus.ACCEPTED -> Badge(containerColor = MaterialTheme.colorScheme.primary) { Text("مقبول") }
                    OrderStatus.IN_PROGRESS -> Badge(containerColor = MaterialTheme.colorScheme.secondary) { Text("جاري") }
                    else -> {}
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            if (order.agreedPrice > 0) {
                Text(
                    "السعر المتفق عليه: ${order.agreedPrice} ريال",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    "العمولة: ${order.commissionAmount} ريال (15%)",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error
                )
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Actions based on status
            when (order.status) {
                OrderStatus.PENDING -> {
                    Button(
                        onClick = { showPriceDialog = true },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Icon(Icons.Default.Send, contentDescription = null)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("إرسال عرض سعر")
                    }
                }
                OrderStatus.ACCEPTED -> {
                    Button(
                        onClick = { showStartDialog = true },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Icon(Icons.Default.PlayArrow, contentDescription = null)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("بدء العمل")
                    }
                }
                OrderStatus.IN_PROGRESS -> {
                    Button(
                        onClick = { showCompleteDialog = true },
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = MaterialTheme.colorScheme.secondary
                        )
                    ) {
                        Icon(Icons.Default.CheckCircle, contentDescription = null)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("إتمام الطلب")
                    }
                }
                else -> {}
            }
        }
    }

    // Price Offer Dialog
    if (showPriceDialog) {
        AlertDialog(
            onDismissRequest = { showPriceDialog = false },
            title = { Text("إرسال عرض سعر") },
            text = {
                Column {
                    Text("أدخل السعر المطلوب للخدمة:")
                    Spacer(modifier = Modifier.height(8.dp))
                    OutlinedTextField(
                        value = priceOffer,
                        onValueChange = { priceOffer = it },
                        label = { Text("السعر (ريال)") },
                        modifier = Modifier.fillMaxWidth()
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        "* سيتم خصم 15% عمولة من رصيدك",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error
                    )
                }
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        val price = priceOffer.toDoubleOrNull()
                        if (price != null && price > 0) {
                            viewModel.sendPriceOffer(order.id, price) { success, error ->
                                if (!success) {
                                    // Show error
                                }
                            }
                            showPriceDialog = false
                        }
                    }
                ) {
                    Text("إرسال")
                }
            },
            dismissButton = {
                TextButton(onClick = { showPriceDialog = false }) {
                    Text("إلغاء")
                }
            }
        )
    }

    // Start Order Confirmation
    if (showStartDialog) {
        AlertDialog(
            onDismissRequest = { showStartDialog = false },
            title = { Text("بدء العمل") },
            text = { Text("هل أنت جاهز للبدء في تنفيذ هذا الطلب؟") },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.startOrder(order.id) { _, _ -> }
                        showStartDialog = false
                    }
                ) {
                    Text("نعم، ابدأ")
                }
            },
            dismissButton = {
                TextButton(onClick = { showStartDialog = false }) {
                    Text("إلغاء")
                }
            }
        )
    }

    // Complete Order Confirmation
    if (showCompleteDialog) {
        AlertDialog(
            onDismissRequest = { showCompleteDialog = false },
            title = { Text("إتمام الطلب") },
            text = { Text("هل أنت متأكد من إتمام هذا الطلب؟ سيتم خصم العمولة من رصيدك.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.completeOrder(order.id) { _, _ -> }
                        showCompleteDialog = false
                    }
                ) {
                    Text("نعم، أكمل")
                }
            },
            dismissButton = {
                TextButton(onClick = { showCompleteDialog = false }) {
                    Text("إلغاء")
                }
            }
        )
    }
}
