package com.amana.provider

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.amana.provider.ui.screens.auth.ProviderLoginScreen
import com.amana.provider.ui.screens.home.ProviderHomeScreen
import com.amana.provider.ui.screens.orders.ProviderOrdersScreen
import com.amana.provider.ui.screens.wallet.WalletScreen
import com.amana.provider.ui.screens.profile.ProviderProfileScreen
import com.amana.provider.viewmodel.ProviderViewModel

sealed class ProviderScreen(val route: String, val title: String, val icon: androidx.compose.ui.graphics.vector.ImageVector? = null) {
    object Login : ProviderScreen("login", "تسجيل الدخول")
    object Home : ProviderScreen("home", "الرئيسية", Icons.Default.Home)
    object Orders : ProviderScreen("orders", "الطلبات", Icons.Default.Assignment)
    object Wallet : ProviderScreen("wallet", "المحفظة", Icons.Default.AccountBalanceWallet)
    object Profile : ProviderScreen("profile", "الملف الشخصي", Icons.Default.Person)
}

@Composable
fun ProviderApp() {
    val viewModel: ProviderViewModel = viewModel()
    val navController = rememberNavController()
    
    val currentUser by viewModel.currentUser.collectAsState()
    val isLoggedIn = currentUser != null

    if (isLoggedIn) {
        ProviderMainScaffold(navController = navController, viewModel = viewModel)
    } else {
        ProviderLoginScreen(
            onLoginSuccess = { user ->
                viewModel.setCurrentUser(user)
            }
        )
    }
}

@Composable
fun ProviderMainScaffold(
    navController: NavHostController,
    viewModel: ProviderViewModel
) {
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    val bottomNavItems = listOf(
        ProviderScreen.Home,
        ProviderScreen.Orders,
        ProviderScreen.Wallet,
        ProviderScreen.Profile
    )

    Scaffold(
        bottomBar = {
            if (currentRoute in bottomNavItems.map { it.route }) {
                NavigationBar {
                    bottomNavItems.forEach { screen ->
                        NavigationBarItem(
                            icon = { screen.icon?.let { Icon(it, contentDescription = screen.title) } },
                            label = { Text(screen.title) },
                            selected = currentRoute == screen.route,
                            onClick = {
                                navController.navigate(screen.route) {
                                    popUpTo(navController.graph.startDestinationId) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            }
                        )
                    }
                }
            }
        }
    ) { paddingValues ->
        NavHost(
            navController = navController,
            startDestination = ProviderScreen.Home.route,
            modifier = Modifier.padding(paddingValues)
        ) {
            composable(ProviderScreen.Home.route) {
                ProviderHomeScreen(viewModel = viewModel)
            }
            composable(ProviderScreen.Orders.route) {
                ProviderOrdersScreen(viewModel = viewModel)
            }
            composable(ProviderScreen.Wallet.route) {
                WalletScreen(viewModel = viewModel)
            }
            composable(ProviderScreen.Profile.route) {
                ProviderProfileScreen(
                    viewModel = viewModel,
                    onLogout = {
                        viewModel.logout()
                    }
                )
            }
        }
    }
}
