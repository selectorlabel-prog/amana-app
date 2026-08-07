package com.amana.provider.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.amana.core.models.*
import com.amana.core.repository.AmanaRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class ProviderViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = AmanaRepository(application)

    private val _currentUser = MutableStateFlow<User?>(null)
    val currentUser: StateFlow<User?> = _currentUser.asStateFlow()

    private val _providerProfile = MutableStateFlow<ProviderProfile?>(null)
    val providerProfile: StateFlow<ProviderProfile?> = _providerProfile.asStateFlow()

    private val _newOrders = MutableStateFlow<List<Order>>(emptyList())
    val newOrders: StateFlow<List<Order>> = _newOrders.asStateFlow()

    private val _activeOrders = MutableStateFlow<List<Order>>(emptyList())
    val activeOrders: StateFlow<List<Order>> = _activeOrders.asStateFlow()

    private val _transactions = MutableStateFlow<List<Transaction>>(emptyList())
    val transactions: StateFlow<List<Transaction>> = _transactions.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    fun setCurrentUser(user: User) {
        _currentUser.value = user
        loadProviderProfile()
        loadOrders()
        loadTransactions()
    }

    fun logout() {
        _currentUser.value = null
        _providerProfile.value = null
        _newOrders.value = emptyList()
        _activeOrders.value = emptyList()
    }

    fun loginWithPhone(phoneNumber: String, onResult: (Boolean, String?) -> Unit) {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                val user = repository.getUserByPhone(phoneNumber)
                if (user != null && user.role == UserRole.PROVIDER) {
                    _currentUser.value = user
                    loadProviderProfile()
                    loadOrders()
                    loadTransactions()
                    onResult(true, null)
                } else {
                    onResult(false, "المستخدم غير موجود أو ليس مقدم خدمة")
                }
            } catch (e: Exception) {
                onResult(false, e.message)
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun registerProvider(
        fullName: String,
        phoneNumber: String,
        city: String,
        district: String,
        bio: String,
        skills: List<String>,
        onResult: (Boolean, String?) -> Unit
    ) {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                val user = repository.registerUser(
                    fullName = fullName,
                    phoneNumber = phoneNumber,
                    role = UserRole.PROVIDER,
                    city = city,
                    district = district
                )
                
                // Update provider profile
                val profile = ProviderProfile(
                    userId = user.id,
                    bio = bio,
                    skills = skills
                )
                repository.updateProviderProfile(profile)
                
                _currentUser.value = user
                _providerProfile.value = profile
                onResult(true, null)
            } catch (e: Exception) {
                onResult(false, e.message)
            } finally {
                _isLoading.value = false
            }
        }
    }

    private fun loadProviderProfile() {
        viewModelScope.launch {
            try {
                _currentUser.value?.let { user ->
                    _providerProfile.value = repository.getProviderProfile(user.id)
                }
            } catch (e: Exception) {
                _errorMessage.value = e.message
            }
        }
    }

    private fun loadOrders() {
        viewModelScope.launch {
            try {
                _currentUser.value?.let { user ->
                    val allOrders = repository.getProviderOrders(user.id)
                    _newOrders.value = allOrders.filter { 
                        it.status == OrderStatus.PENDING || it.status == OrderStatus.NEGOTIATING 
                    }
                    _activeOrders.value = allOrders.filter { 
                        it.status == OrderStatus.ACCEPTED || it.status == OrderStatus.IN_PROGRESS 
                    }
                }
            } catch (e: Exception) {
                _errorMessage.value = e.message
            }
        }
    }

    private fun loadTransactions() {
        viewModelScope.launch {
            try {
                _currentUser.value?.let { user ->
                    _transactions.value = repository.getTransactions(user.id)
                }
            } catch (e: Exception) {
                _errorMessage.value = e.message
            }
        }
    }

    /**
     * إرسال عرض سعر (مع التحقق من الرصيد)
     */
    fun sendPriceOffer(orderId: String, offeredPrice: Double, onResult: (Boolean, String?) -> Unit) {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                _currentUser.value?.let { user ->
                    val result = repository.sendPriceOffer(orderId, user.id, offeredPrice)
                    if (result.isSuccess) {
                        loadOrders()
                        loadProviderProfile()
                        onResult(true, null)
                    } else {
                        onResult(false, result.exceptionOrNull()?.message)
                    }
                }
            } catch (e: Exception) {
                onResult(false, e.message)
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun startOrder(orderId: String, onResult: (Boolean, String?) -> Unit) {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                val result = repository.startOrder(orderId)
                if (result.isSuccess) {
                    loadOrders()
                    onResult(true, null)
                } else {
                    onResult(false, result.exceptionOrNull()?.message)
                }
            } catch (e: Exception) {
                onResult(false, e.message)
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun completeOrder(orderId: String, onResult: (Boolean, String?) -> Unit) {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                val result = repository.completeOrder(orderId)
                if (result.isSuccess) {
                    loadOrders()
                    loadProviderProfile()
                    loadTransactions()
                    onResult(true, null)
                } else {
                    onResult(false, result.exceptionOrNull()?.message)
                }
            } catch (e: Exception) {
                onResult(false, e.message)
            } finally {
                _isLoading.value = false
            }
        }
    }

    /**
     * شحن المحفظة
     */
    fun rechargeWallet(code: String, onResult: (Boolean, Double?, String?) -> Unit) {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                _currentUser.value?.let { user ->
                    val result = repository.redeemRechargeCode(user.id, code)
                    if (result.isSuccess) {
                        loadProviderProfile()
                        loadTransactions()
                        onResult(true, result.getOrNull(), null)
                    } else {
                        onResult(false, null, result.exceptionOrNull()?.message)
                    }
                }
            } catch (e: Exception) {
                onResult(false, null, e.message)
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun refreshData() {
        loadProviderProfile()
        loadOrders()
        loadTransactions()
    }

    fun clearError() {
        _errorMessage.value = null
    }

    override fun onCleared() {
        super.onCleared()
        repository.close()
    }
}
