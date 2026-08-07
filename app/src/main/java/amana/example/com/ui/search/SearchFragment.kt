package amana.example.com.ui.search

import android.content.Intent
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.core.os.bundleOf
import androidx.fragment.app.Fragment
import androidx.navigation.fragment.findNavController
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import amana.core.data.MockDataStore
import amana.core.models.Service
import amana.core.models.ServiceCategory
import amana.example.com.R
import amana.example.com.databinding.FragmentSearchBinding
import amana.example.com.databinding.ItemFeaturedServiceBinding
import amana.example.com.databinding.ItemServiceSearchBinding
import com.google.android.material.chip.Chip

class SearchFragment : Fragment() {

    private var _binding: FragmentSearchBinding? = null
    private val binding get() = _binding!!
    private var allServices = emptyList<Service>()
    private var selectedCategory: String? = null

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentSearchBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        allServices = MockDataStore.getServices()
        setupFeatured()
        setupFilterChips()
        binding.rvServices.layoutManager = LinearLayoutManager(requireContext())
        binding.tvViewAll.setOnClickListener { applyFilter() }
        binding.etSearch.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = applyFilter()
            override fun afterTextChanged(s: Editable?) = Unit
        })
        applyFilter()
    }

    private fun setupFeatured() {
        val categories = MockDataStore.getCategories()
        binding.rvFeatured.layoutManager =
            LinearLayoutManager(requireContext(), LinearLayoutManager.HORIZONTAL, false)
        binding.rvFeatured.adapter = FeaturedAdapter(categories) { category ->
            selectedCategory = category.name
            binding.etSearch.setText("")
            applyFilter()
        }
    }

    private class FeaturedAdapter(
        private val items: List<ServiceCategory>,
        private val onClick: (ServiceCategory) -> Unit
    ) : RecyclerView.Adapter<FeaturedAdapter.ViewHolder>() {

        inner class ViewHolder(private val binding: ItemFeaturedServiceBinding) :
            RecyclerView.ViewHolder(binding.root) {
            fun bind(item: ServiceCategory, isFirst: Boolean) {
                binding.tvEmoji.text = item.iconEmoji
                binding.tvTitle.text = item.name
                binding.tvSubtitle.text = "تصفح الخدمات المتاحة"
                binding.tvBadge.visibility = if (isFirst) View.VISIBLE else View.GONE
                binding.root.setOnClickListener { onClick(item) }
            }
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            val binding = ItemFeaturedServiceBinding.inflate(
                LayoutInflater.from(parent.context), parent, false
            )
            return ViewHolder(binding)
        }

        override fun onBindViewHolder(holder: ViewHolder, position: Int) =
            holder.bind(items[position], position == 0)
        override fun getItemCount(): Int = items.size
    }

    private fun setupFilterChips() {
        val chipAll = Chip(requireContext()).apply {
            text = "الكل"
            isCheckable = true
            isChecked = true
            setOnClickListener {
                selectedCategory = null
                applyFilter()
            }
        }
        binding.chipGroup.addView(chipAll)
        MockDataStore.getCategories().forEach { category ->
            val chip = Chip(requireContext()).apply {
                text = category.name
                isCheckable = true
                setOnClickListener {
                    selectedCategory = category.name
                    applyFilter()
                }
            }
            binding.chipGroup.addView(chip)
        }
    }

    private fun applyFilter() {
        val query = binding.etSearch.text?.toString()?.trim()?.lowercase().orEmpty()
        val filtered = allServices.filter { service ->
            val matchesQuery = query.isEmpty() ||
                service.serviceName.lowercase().contains(query) ||
                service.description.lowercase().contains(query)
            val matchesCategory = selectedCategory == null ||
                service.serviceName.contains(selectedCategory!!)
            matchesQuery && matchesCategory
        }
        binding.tvServicesEmpty.visibility = if (filtered.isEmpty()) View.VISIBLE else View.GONE
        binding.rvServices.adapter = ServiceSearchAdapter(filtered) { service ->
            findNavController().navigate(
                R.id.nav_service_detail,
                bundleOf("serviceId" to service.id)
            )
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }

    private class ServiceSearchAdapter(
        private val items: List<Service>,
        private val onClick: (Service) -> Unit
    ) : RecyclerView.Adapter<ServiceSearchAdapter.ViewHolder>() {

        inner class ViewHolder(private val binding: ItemServiceSearchBinding) :
            RecyclerView.ViewHolder(binding.root) {
            fun bind(service: Service) {
                binding.tvServiceName.text = service.serviceName
                binding.tvDescription.text = service.description
                binding.tvPrice.text = "${service.basePrice.toInt()} SDG"
                binding.root.setOnClickListener { onClick(service) }
            }
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            val binding = ItemServiceSearchBinding.inflate(LayoutInflater.from(parent.context), parent, false)
            return ViewHolder(binding)
        }

        override fun onBindViewHolder(holder: ViewHolder, position: Int) = holder.bind(items[position])
        override fun getItemCount(): Int = items.size
    }
}
