package com.amana.customer

import android.content.Context
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.amana.customer.ui.screens.auth.LoginScreen
import com.amana.customer.ui.screens.home.HomeScreen
import com.amana.customer.ui.screens.orders.OrdersScreen
import com.amana.customer.ui.screens.profile.ProfileScreen
import com.amana.customer.viewmodel.CustomerViewModel

sealed class Screen(val route: String, val title: String, val icon: androidx.compose.ui.graphics.vector.ImageVector? = null) {
    object Login : Screen("login", "تسجيل الدخول")
    object Home : Screen("home", "الرئيسية", Icons.Default.Home)
    object Orders : Screen("orders", "طلباتي", Icons.Default.ShoppingBag)
    object Profile : Screen("profile", "الملف الشخصي", Icons.Default.Person)
    object ServiceList : Screen("service_list/{categoryId}", "الخدمات")
    object OrderDetails : Screen("order_details/{orderId}", "تفاصيل الطلب")
    object Chat : Screen("chat/{orderId}", "المحادثة")
}

@Composable
fun CustomerApp() {
    val context = LocalContext.current
    val viewModel: CustomerViewModel = viewModel()
    val navController = rememberNavController()
    
    val currentUser by viewModel.currentUser.collectAsState()
    val isLoggedIn = currentUser != null

    if (isLoggedIn) {
        MainScaffold(navController = navController, viewModel = viewModel)
    } else {
        LoginScreen(
            onLoginSuccess = { user ->
                viewModel.setCurrentUser(user)
            }
        )
    }
}

@Composable
fun MainScaffold(
    navController: NavHostController,
    viewModel: CustomerViewModel
) {
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    val bottomNavItems = listOf(
        Screen.Home,
        Screen.Orders,
        Screen.Profile
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
            startDestination = Screen.Home.route,
            modifier = Modifier.padding(paddingValues)
        ) {
            composable(Screen.Home.route) {
                HomeScreen(
                    viewModel = viewModel,
                    onCategoryClick = { categoryId ->
                        navController.navigate("service_list/$categoryId")
                    }
                )
            }
            composable(Screen.Orders.route) {
                OrdersScreen(
                    viewModel = viewModel,
                    onOrderClick = { orderId ->
                        navController.navigate("order_details/$orderId")
                    }
                )
            }
            composable(Screen.Profile.route) {
                ProfileScreen(
                    viewModel = viewModel,
                    onLogout = {
                        viewModel.logout()
                    }
                )
            }
        }
    }
}
