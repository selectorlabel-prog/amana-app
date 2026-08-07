package amana.example.com.ui.onboarding

import android.os.Bundle
import android.text.InputType
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.TextView
import android.widget.Toast
import androidx.fragment.app.Fragment
import amana.core.data.MockDataStore
import amana.core.data.SessionManager
import amana.core.models.ProviderProfile
import amana.core.models.Service
import amana.core.models.UserRole
import amana.example.com.R
import amana.example.com.databinding.FragmentProviderOnboardingBinding
import com.google.android.material.chip.Chip

class ProviderOnboardingFragment : Fragment() {

    private var _binding: FragmentProviderOnboardingBinding? = null
    private val binding get() = _binding!!
    private val selectedSkills = linkedSetOf<String>()
    private val priceInputs = mutableMapOf<String, EditText>()
    private var currentStep = 1

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentProviderOnboardingBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        MockDataStore.getCategories().forEach { category ->
            val chip = Chip(requireContext()).apply {
                text = category.name
                isCheckable = true
                setOnCheckedChangeListener { _, isChecked ->
                    if (isChecked) selectedSkills.add(category.name)
                    else selectedSkills.remove(category.name)
                }
            }
            binding.chipSkills.addView(chip)
        }

        binding.btnContinue.setOnClickListener {
            when (currentStep) {
                1 -> {
                    if (selectedSkills.isEmpty()) {
                        Toast.makeText(context, "يرجى اختيار مهارة واحدة على الأقل", Toast.LENGTH_SHORT).show()
                        return@setOnClickListener
                    }
                    buildPriceInputs()
                    showStep(2)
                }
                2 -> {
                    if (binding.rgSpecialty.checkedRadioButtonId == -1) {
                        Toast.makeText(context, "يرجى اختيار التخصص", Toast.LENGTH_SHORT).show()
                        return@setOnClickListener
                    }
                    if (priceInputs.values.any { it.text.toString().toDoubleOrNull() == null }) {
                        Toast.makeText(context, "يرجى إدخال سعر صحيح لكل خدمة", Toast.LENGTH_SHORT).show()
                        return@setOnClickListener
                    }
                    showStep(3)
                }
                3 -> finishOnboarding()
            }
        }
    }

    private fun buildPriceInputs() {
        binding.llPrices.removeAllViews()
        priceInputs.clear()
        selectedSkills.forEach { skill ->
            val row = LinearLayout(requireContext()).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(0, 8, 0, 8)
            }
            val label = TextView(requireContext()).apply {
                text = skill
                textSize = 15f
                layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
            }
            val input = EditText(requireContext()).apply {
                hint = "السعر"
                inputType = InputType.TYPE_CLASS_NUMBER
                setText("15000")
                layoutParams = LinearLayout.LayoutParams(220, ViewGroup.LayoutParams.WRAP_CONTENT)
            }
            priceInputs[skill] = input
            row.addView(label)
            row.addView(input)
            binding.llPrices.addView(row)
        }
    }

    private fun finishOnboarding() {
        val userId = SessionManager.userId
        if (userId.isBlank()) {
            Toast.makeText(context, "يرجى تسجيل الدخول أولاً", Toast.LENGTH_SHORT).show()
            return
        }
        SessionManager.setRole(UserRole.PROVIDER)

        val specialtyBtn = binding.rgSpecialty
            .findViewById<RadioButton>(binding.rgSpecialty.checkedRadioButtonId)
        val specialty = specialtyBtn?.text?.toString().orEmpty()

        MockDataStore.saveProviderProfile(
            ProviderProfile(
                userId = userId,
                bio = specialty,
                skills = selectedSkills.toList(),
                isVerified = false
            ),
            specialty
        )

        selectedSkills.forEach { skill ->
            val price = priceInputs[skill]?.text.toString().toDoubleOrNull() ?: 0.0
            MockDataStore.addService(
                Service(
                    providerId = userId,
                    serviceName = skill,
                    basePrice = price,
                    description = specialty
                )
            )
        }

        Toast.makeText(
            context,
            "تم إنشاء ملفك كمزود خدمة. أصبحت خدماتك متاحة للعملاء.",
            Toast.LENGTH_LONG
        ).show()
        requireActivity().onBackPressedDispatcher.onBackPressed()
    }

    private fun showStep(step: Int) {
        currentStep = step
        binding.tvStepIndicator.text = "الخطوة $step من 3"
        binding.stepSkills.visibility = if (step == 1) View.VISIBLE else View.GONE
        binding.stepSpecialty.visibility = if (step == 2) View.VISIBLE else View.GONE
        binding.stepDocuments.visibility = if (step == 3) View.VISIBLE else View.GONE
        binding.btnContinue.text = if (step == 3) "إنهاء التسجيل" else "متابعة"
        updateProgress(step)
    }

    private fun updateProgress(step: Int) {
        binding.progressStep1.setBackgroundResource(
            if (step > 1) R.drawable.prov_bg_progress_done else R.drawable.prov_bg_progress_active
        )
        binding.progressStep2.setBackgroundResource(
            when {
                step > 2 -> R.drawable.prov_bg_progress_done
                step == 2 -> R.drawable.prov_bg_progress_active
                else -> R.drawable.prov_bg_progress_inactive
            }
        )
        binding.progressStep3.setBackgroundResource(
            if (step == 3) R.drawable.prov_bg_progress_active else R.drawable.prov_bg_progress_inactive
        )
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
