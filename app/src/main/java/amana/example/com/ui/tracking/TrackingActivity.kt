package amana.example.com.ui.tracking

import android.location.Location
import android.os.Bundle
import android.view.View
import androidx.appcompat.app.AppCompatActivity
import amana.core.data.MockDataStore
import amana.core.models.Order
import amana.core.models.OrderStatus
import amana.example.com.databinding.ActivityTrackingBinding
import amana.example.com.ui.review.ReviewDialogFragment
import amana.example.com.utils.NotificationHelper
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.GoogleMap
import com.google.android.gms.maps.OnMapReadyCallback
import com.google.android.gms.maps.SupportMapFragment
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.Marker
import com.google.android.gms.maps.model.MarkerOptions

class TrackingActivity : AppCompatActivity(), OnMapReadyCallback {

    private lateinit var binding: ActivityTrackingBinding
    private var mMap: GoogleMap? = null
    private var orderId = "order_1"
    private lateinit var notificationHelper: NotificationHelper

    private var providerMarker: Marker? = null
    private var customerMarker: Marker? = null
    private var hasNotifiedArrival = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityTrackingBinding.inflate(layoutInflater)
        setContentView(binding.root)

        notificationHelper = NotificationHelper(this)
        orderId = intent.getStringExtra("ORDER_ID") ?: "order_1"

        val mapFragment = supportFragmentManager.findFragmentById(binding.map.id) as SupportMapFragment
        mapFragment.getMapAsync(this)

        MockDataStore.getOrder(orderId)?.let { updateUI(it) }
    }

    override fun onMapReady(googleMap: GoogleMap) {
        mMap = googleMap
        mMap?.uiSettings?.isZoomControlsEnabled = true
        MockDataStore.getOrder(orderId)?.let { updateUI(it) }
    }

    private fun updateUI(order: Order) {
        val providerPos = LatLng(order.providerLat, order.providerLng)
        val customerPos = LatLng(order.customerLat, order.customerLng)

        val providerName = MockDataStore.getUser(order.providerId)?.fullName?.ifBlank { null } ?: "مزود الخدمة"
        binding.tvProviderName.text = "مزود الخدمة: $providerName"
        binding.tvStatus.text = when (order.status) {
            OrderStatus.NEGOTIATING -> "جاري التفاوض"
            OrderStatus.IN_PROGRESS -> "الخدمة قيد التنفيذ"
            OrderStatus.COMPLETED -> "تم اكتمال الخدمة"
            else -> "تتبع الطلب"
        }

        mMap?.let { map ->
            if (providerMarker == null) {
                providerMarker = map.addMarker(
                    MarkerOptions()
                        .position(providerPos)
                        .title("مزود الخدمة")
                        .icon(BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_AZURE))
                )
            } else {
                providerMarker?.position = providerPos
            }

            if (customerMarker == null) {
                customerMarker = map.addMarker(
                    MarkerOptions()
                        .position(customerPos)
                        .title("موقعك")
                )
                map.moveCamera(CameraUpdateFactory.newLatLngZoom(customerPos, 14f))
            }

            val results = FloatArray(1)
            Location.distanceBetween(
                order.providerLat, order.providerLng,
                order.customerLat, order.customerLng,
                results
            )
            binding.tvDistance.text = String.format("المسافة: %.2f كم", results[0] / 1000)

            if (results[0] < 100 && !hasNotifiedArrival) {
                notificationHelper.showNotification("وصول المزود", "لقد وصل مقدم الخدمة إلى موقعك!")
                hasNotifiedArrival = true
            }

            if (order.status == OrderStatus.COMPLETED) {
                binding.btnCompleteOrder.visibility = View.VISIBLE
                binding.btnCompleteOrder.setOnClickListener {
                    ReviewDialogFragment.newInstance(order.id, order.providerId, order.customerId)
                        .show(supportFragmentManager, "review_dialog")
                }
            }
        }
    }
}
