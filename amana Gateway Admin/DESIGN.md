---
name: Modern Sudanese Marketplace
colors:
  surface: '#fcf9f8'
  surface-dim: '#dcd9d9'
  surface-bright: '#fcf9f8'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f6f3f2'
  surface-container: '#f0eded'
  surface-container-high: '#eae7e7'
  surface-container-highest: '#e5e2e1'
  on-surface: '#1b1c1c'
  on-surface-variant: '#42474f'
  inverse-surface: '#303030'
  inverse-on-surface: '#f3f0ef'
  outline: '#727780'
  outline-variant: '#c2c7d1'
  surface-tint: '#2d6197'
  primary: '#00355f'
  on-primary: '#ffffff'
  primary-container: '#0f4c81'
  on-primary-container: '#8ebdf9'
  inverse-primary: '#a0c9ff'
  secondary: '#8e4e14'
  on-secondary: '#ffffff'
  secondary-container: '#ffab69'
  on-secondary-container: '#783d01'
  tertiary: '#003b34'
  on-tertiary: '#ffffff'
  tertiary-container: '#00544b'
  on-tertiary-container: '#61cbbc'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d2e4ff'
  primary-fixed-dim: '#a0c9ff'
  on-primary-fixed: '#001c37'
  on-primary-fixed-variant: '#07497d'
  secondary-fixed: '#ffdcc4'
  secondary-fixed-dim: '#ffb780'
  on-secondary-fixed: '#2f1400'
  on-secondary-fixed-variant: '#6f3800'
  tertiary-fixed: '#8cf5e4'
  tertiary-fixed-dim: '#6fd8c8'
  on-tertiary-fixed: '#00201c'
  on-tertiary-fixed-variant: '#005048'
  background: '#fcf9f8'
  on-background: '#1b1c1c'
  surface-variant: '#e5e2e1'
  surface-white: '#FFFFFF'
  surface-gray-light: '#F8F9FA'
  nile-blue-deep: '#0A2E4D'
  sand-accent: '#F4A261'
  success-green: '#27A745'
  warning-amber: '#FFBF00'
  error-red: '#D93025'
typography:
  headline-lg:
    fontFamily: IBM Plex Sans
    fontSize: 30px
    fontWeight: '700'
    lineHeight: 38px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: IBM Plex Sans
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  headline-md:
    fontFamily: IBM Plex Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Noto Sans
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Noto Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-md:
    fontFamily: IBM Plex Sans
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: IBM Plex Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 4px
  xs: 8px
  sm: 12px
  md: 16px
  lg: 24px
  xl: 32px
  margin-mobile: 16px
  gutter-mobile: 12px
---

## Brand & Style

The design system is engineered for a professional service marketplace operating within the Khartoum context. It balances the reliability of established Sudanese institutions with the efficiency of modern mobile commerce. The aesthetic is **Corporate / Modern**, prioritizing high legibility and clear hit targets to accommodate outdoor use in high-glare environments.

The brand personality is dependable and accessible. It evokes a sense of "Amana" (trust) through structured layouts and "Assala" (authenticity) by incorporating colors that reflect both the modern cityscape and the natural landscape of Sudan. The UI utilizes generous white space to reduce cognitive load in a busy service-driven environment.

## Colors

The palette is anchored by **Deep Nile Blue**, signifying stability and professionalism. This is contrasted with **Sandy Orange** (extracted from the brand reference), which serves as a vibrant accent for calls-to-action and highlights, echoing the regional landscape.

- **Primary (#0F4C81):** Used for headers, primary actions, and brand-heavy components.
- **Secondary (#F4A261):** Used for interactive accents, ratings, and highlighting specific value propositions.
- **Neutral (#222222):** Used for high-contrast text to ensure readability under direct sunlight.
- **Semantic Colors:** Success, Warning, and Error colors are saturated to remain distinct even at low brightness settings.

## Typography

This design system uses a dual-font strategy to handle multi-script requirements seamlessly. 

1. **Primary Script Support:** For Arabic text, **Noto Sans** is the standard for body copy due to its exceptional legibility and balanced x-height across various dialects.
2. **Structural Script:** **IBM Plex Sans** is used for headlines and labels to provide a technical, modern edge.

**RTL Principles:**
- All type alignments must flip horizontally for Arabic localization.
- Ensure line heights for Arabic are roughly 20% larger than Latin counterparts to prevent descender clipping.
- Numbers should be rendered in the localized numeral system preferred by the user settings.

## Layout & Spacing

The design system employs a **Fluid Grid** model optimized for mobile-first consumption. The base unit is 4px, creating an 8pt rhythmic scale that ensures consistency across varied screen densities.

**Mobile (Default):**
- 4-column grid.
- 16px outer margins.
- 12px gutters.

**Layout Adaptation:**
- Content cards should span the full width of the grid on mobile.
- In RTL mode, the column order begins from the right, and the padding/margin logic is mirrored (e.g., `pl-4` becomes `pr-4`).
- Interactive elements (buttons, inputs) must maintain a minimum height of 48px to ensure accessibility for all users.

## Elevation & Depth

To maintain high contrast and clarity in outdoor environments, this design system uses **Tonal Layers** supplemented by **Low-Contrast Outlines** rather than heavy shadows.

- **Level 0 (Background):** Surface-white or light gray.
- **Level 1 (Cards):** 1px solid border (#E0E0E0) with a very soft, subtle 4% opacity shadow for a "lifted" feel.
- **Level 2 (Modals/Popovers):** Higher elevation with a 12% opacity shadow to clearly separate the action layer from the background.
- **Interaction:** Buttons utilize a slight inner-shadow when pressed to provide tactile feedback without relying solely on color change.

## Shapes

The shape language is **Rounded**, conveying a friendly yet professional tone. 

- **Standard Elements:** 0.5rem (8px) corner radius for most cards and input fields.
- **Interactive Elements:** Buttons and Chips use `rounded-lg` (16px) or full pill-shaping to distinguish them from static content containers.
- **Icons:** Use rounded stroke caps to match the soft corners of the UI.

## Components

### Service Cards
- **Structure:** Image (top/side), Title, Service Category Chip, Price, and Rating.
- **Provider View:** Includes "Availability" toggle and "Active Jobs" count.
- **Student View:** Focuses on "Price per Hour" and "Verification Badge" for trust.

### Chat Bubbles
- **Sent (User):** Deep Blue background with White text. Aligned to the trailing side (Right in LTR, Left in RTL).
- **Received:** Light Gray background with Dark text. Aligned to the leading side.
- **Metadata:** Timestamps tucked into the bottom corner of the bubble in a smaller, low-contrast font.

### Status Tracking Steps
- Horizontal step indicator for mobile. 
- Completed steps use `Success-Green`. 
- Active step uses `Primary-Blue` with a pulsing ring.
- Lines between steps thicken when completed to show progress clearly.

### Payment & Code Entry
- **OTP Fields:** High-contrast, individual bordered boxes (48x56px) with a heavy focus border color (#F4A261).
- **Payment:** Integrated icons for local payment providers (e.g., SyberPay, Fawry) using brand-approved logos.

### Role-Specific Navigation
- **Consumer:** Focus on "Search," "My Requests," and "Profile."
- **Provider:** Focus on "Dashboard," "Earnings," and "Leads."
- **Design:** Bottom navigation bar with 1px top border and active states highlighted in the Secondary Sandy Orange.