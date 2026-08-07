package com.amana.customer.ui.screens.auth

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.amana.core.models.User
import com.amana.customer.viewmodel.CustomerViewModel

@Composable
fun LoginScreen(
    viewModel: CustomerViewModel = viewModel(),
    onLoginSuccess: (User) -> Unit
) {
    var phoneNumber by remember { mutableStateOf("") }
    var fullName by remember { mutableStateOf("") }
    var city by remember { mutableStateOf("") }
    var district by remember { mutableStateOf("") }
    var isRegistering by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    
    val isLoading by viewModel.isLoading.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // Logo / Title
        Text(
            text = "🏪 أمانة",
            style = MaterialTheme.typography.displayLarge,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.padding(bottom = 8.dp)
        )
        
        Text(
            text = "منصة الخدمات المنزلية",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(bottom = 48.dp)
        )

        // Phone Number Field
        OutlinedTextField(
            value = phoneNumber,
            onValueChange = { phoneNumber = it },
            label = { Text("رقم الهاتف") },
            leadingIcon = { Icon(Icons.Default.Phone, contentDescription = null) },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
            modifier = Modifier.fillMaxWidth(),
            singleLine = true
        )

        Spacer(modifier = Modifier.height(16.dp))

        // Registration Fields
        if (isRegistering) {
            OutlinedTextField(
                value = fullName,
                onValueChange = { fullName = it },
                label = { Text("الاسم الكامل") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true
            )
            
            Spacer(modifier = Modifier.height(16.dp))
            
            OutlinedTextField(
                value = city,
                onValueChange = { city = it },
                label = { Text("المدينة") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true
            )
            
            Spacer(modifier = Modifier.height(16.dp))
            
            OutlinedTextField(
                value = district,
                onValueChange = { district = it },
                label = { Text("الحي") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true
            )
            
            Spacer(modifier = Modifier.height(24.dp))
        } else {
            Spacer(modifier = Modifier.height(24.dp))
        }

        // Error Message
        errorMessage?.let { error ->
            Text(
                text = error,
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(bottom = 16.dp)
            )
        }

        // Login/Register Button
        Button(
            onClick = {
                if (isRegistering) {
                    if (fullName.isNotBlank() && phoneNumber.isNotBlank() && 
                        city.isNotBlank() && district.isNotBlank()) {
                        viewModel.registerCustomer(fullName, phoneNumber, city, district) { success, error ->
                            if (success) {
                                viewModel.currentUser.value?.let { onLoginSuccess(it) }
                            } else {
                                errorMessage = error
                            }
                        }
                    } else {
                        errorMessage = "يرجى ملء جميع الحقول"
                    }
                } else {
                    if (phoneNumber.isNotBlank()) {
                        viewModel.loginWithPhone(phoneNumber) { success, error ->
                            if (success) {
                                viewModel.currentUser.value?.let { onLoginSuccess(it) }
                            } else {
                                errorMessage = error
                            }
                        }
                    } else {
                        errorMessage = "يرجى إدخال رقم الهاتف"
                    }
                }
            },
            modifier = Modifier.fillMaxWidth(),
            enabled = !isLoading
        ) {
            if (isLoading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    color = MaterialTheme.colorScheme.onPrimary
                )
            } else {
                Text(if (isRegistering) "تسجيل حساب جديد" else "تسجيل الدخول")
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Toggle between login and register
        TextButton(
            onClick = { 
                isRegistering = !isRegistering
                errorMessage = null
            }
        ) {
            Text(
                if (isRegistering) "لديك حساب؟ تسجيل الدخول" 
                else "ليس لديك حساب؟ سجل الآن"
            )
        }
    }
}
