package com.amana.customer.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.amana.core.models.*
import com.amana.core.repository.AmanaRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class CustomerViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = AmanaRepository(application)

    private val _currentUser = MutableStateFlow<User?>(null)
    val currentUser: StateFlow<User?> = _currentUser.asStateFlow()

    private val _categories = MutableStateFlow<List<ServiceCategory>>(emptyList())
    val categories: StateFlow<List<ServiceCategory>> = _categories.asStateFlow()

    private val _myOrders = MutableStateFlow<List<Order>>(emptyList())
    val myOrders: StateFlow<List<Order>> = _myOrders.asStateFlow()

    private val _providers = MutableStateFlow<List<ProviderProfile>>(emptyList())
    val providers: StateFlow<List<ProviderProfile>> = _providers.asStateFlow()

    private val _messages = MutableStateFlow<List<Message>>(emptyList())
    val messages: StateFlow<List<Message>> = _messages.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    init {
        loadCategories()
    }

    fun setCurrentUser(user: User) {
        _currentUser.value = user
        loadMyOrders()
    }

    fun logout() {
        _currentUser.value = null
        _myOrders.value = emptyList()
    }

    fun loginWithPhone(phoneNumber: String, onResult: (Boolean, String?) -> Unit) {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                val user = repository.getUserByPhone(phoneNumber)
                if (user != null && user.role == UserRole.CUSTOMER) {
                    _currentUser.value = user
                    loadMyOrders()
                    onResult(true, null)
                } else {
                    onResult(false, "المستخدم غير موجود أو ليس عميلاً")
                }
            } catch (e: Exception) {
                onResult(false, e.message)
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun registerCustomer(
        fullName: String,
        phoneNumber: String,
        city: String,
        district: String,
        onResult: (Boolean, String?) -> Unit
    ) {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                val user = repository.registerUser(
                    fullName = fullName,
                    phoneNumber = phoneNumber,
                    role = UserRole.CUSTOMER,
                    city = city,
                    district = district
                )
                _currentUser.value = user
                onResult(true, null)
            } catch (e: Exception) {
                onResult(false, e.message)
            } finally {
                _isLoading.value = false
            }
        }
    }

    private fun loadCategories() {
        viewModelScope.launch {
            try {
                _categories.value = repository.getAllCategories()
            } catch (e: Exception) {
                _errorMessage.value = e.message
            }
        }
    }

    fun loadProviders() {
        viewModelScope.launch {
            try {
                _providers.value = repository.getAllProviders().filter { it.isVerified }
            } catch (e: Exception) {
                _errorMessage.value = e.message
            }
        }
    }

    private fun loadMyOrders() {
        viewModelScope.launch {
            try {
                _currentUser.value?.let { user ->
                    _myOrders.value = repository.getCustomerOrders(user.id)
                }
            } catch (e: Exception) {
                _errorMessage.value = e.message
            }
        }
    }

    fun createOrder(
        providerId: String,
        serviceId: String,
        serviceName: String,
        lat: Double,
        lng: Double,
        onResult: (Boolean, String?) -> Unit
    ) {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                _currentUser.value?.let { user ->
                    val order = repository.createOrder(
                        customerId = user.id,
                        providerId = providerId,
                        serviceId = serviceId,
                        serviceName = serviceName,
                        customerLat = lat,
                        customerLng = lng
                    )
                    loadMyOrders()
                    onResult(true, order.id)
                }
            } catch (e: Exception) {
                onResult(false, e.message)
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun acceptPriceOffer(orderId: String, onResult: (Boolean, String?) -> Unit) {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                val result = repository.acceptPriceOffer(orderId)
                if (result.isSuccess) {
                    loadMyOrders()
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

    fun loadMessages(orderId: String) {
        viewModelScope.launch {
            try {
                _messages.value = repository.getMessages(orderId)
            } catch (e: Exception) {
                _errorMessage.value = e.message
            }
        }
    }

    fun sendMessage(orderId: String, content: String) {
        viewModelScope.launch {
            try {
                _currentUser.value?.let { user ->
                    repository.sendMessage(orderId, user.id, content)
                    loadMessages(orderId)
                }
            } catch (e: Exception) {
                _errorMessage.value = e.message
            }
        }
    }

    fun submitReview(
        orderId: String,
        providerId: String,
        rating: Float,
        comment: String,
        onResult: (Boolean, String?) -> Unit
    ) {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                _currentUser.value?.let { user ->
                    val result = repository.addReview(
                        orderId = orderId,
                        customerId = user.id,
                        providerId = providerId,
                        rating = rating,
                        comment = comment
                    )
                    if (result.isSuccess) {
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

    fun reportDispute(orderId: String, reason: String, onResult: (Boolean, String?) -> Unit) {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                _currentUser.value?.let { user ->
                    repository.createDispute(orderId, user.id, reason)
                    onResult(true, null)
                }
            } catch (e: Exception) {
                onResult(false, e.message)
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun clearError() {
        _errorMessage.value = null
    }

    override fun onCleared() {
        super.onCleared()
        repository.close()
    }
}
