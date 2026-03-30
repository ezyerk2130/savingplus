# Design System Specification: Editorial Financial Excellence

## 1. Overview & Creative North Star: "The Modern Hearth"
This design system moves away from the cold, sterile aesthetic of traditional fintech. Our Creative North Star is **"The Modern Hearth"**—a digital environment that feels as secure as a bank vault but as warm and inviting as a sun-drenched courtyard in Dar es Salaam or Nairobi.

We break the "template" look by rejecting rigid borders in favor of **Organic Layering**. By using intentional asymmetry, generous 5.5rem (16) breathing room, and high-contrast typography scales, we create an editorial experience where financial data feels like a premium story rather than a spreadsheet. This is professional banking with a human soul.

---

## 2. Colors & Tonal Depth
Our palette is rooted in "SavingPlus Green" and deep earth tones, interpreted through a sophisticated Material Design lens to ensure functional depth.

### Core Palette
- **Primary (`#006d39`):** The "Confident Green." Used for high-level brand moments and key actions.
- **Primary Container (`#1DA75E`):** Lighter green for containers and gradients.
- **Secondary (`#904d00`):** The "Earth Tone." Used for accents that ground the green and provide warmth.
- **Surface (`#f9f9ff`):** A light, warm white that acts as our canvas.
- **On-Background (`#151c27`):** Deep navy for text. Never use pure black.

### The "No-Line" Rule
Boundaries must be defined solely through background color shifts, not 1px borders.
- Headers to body: transition from `surface` to `surface-container-low`
- Highlight: use `surface-container`
- Cards: use `surface-container-lowest` (`#ffffff`) for maximum lift

### Surface Hierarchy
1. **Base Layer:** `surface` (#f9f9ff)
2. **Section Layer:** `surface-container-low` (subtle containment)
3. **Card Layer:** `surface-container-lowest` (#ffffff) for lift
4. **Active Layer:** `surface-container-high` for hover/active

### Glass & Gradient
- Floating elements: surface at 80% opacity with 20px backdrop-blur
- Primary CTAs: gradient from `#006d39` to `#1DA75E`

---

## 3. Typography
| Level | Font | Size | Weight | Use |
|-------|------|------|--------|-----|
| Display-LG | Plus Jakarta Sans | 3.5rem | 600 | Hero goals |
| Headline-MD | Plus Jakarta Sans | 1.75rem | 600 | Section titles |
| Title-SM | Inter | 1rem | 500 | Card titles |
| Body-MD | Inter | 0.875rem | 400 | Descriptions |
| Label-MD | Inter | 0.75rem | 500 | Currency codes |
| Numbers | DM Mono | - | 500 | All amounts |

---

## 4. Elevation
- Tonal layering over drop shadows
- Ambient shadows for modals only: on-surface at 4% opacity, 32px blur, 8px Y
- Ghost borders for forms: outline-variant at 15% opacity

---

## 5. Components

### Buttons
- Primary: Gradient fill (primary → primary_container), white text, full roundedness
- Secondary: surface-container-high fill, primary text, no border
- Tertiary: Transparent, primary text, weight 600

### Input Fields
- surface-container-low background, 1.5px ghost border, primary on focus
- Labels: body-sm, on-surface-variant

### Cards
- 12px radius, no dividers, 3.5rem internal padding
- Separate sections via background color, not lines

### Currency Chips
- TZS/USD always visible, label-md in surface-container-highest chip

### Swahili Toggle
- Top-right, glassmorphic pill, active language with primary dot

---

## 6. Bottom Navigation
- 5 tabs: Home, Save, Circles, Wallet, Profile
- Active: filled icon with primary color
- Inactive: outlined icon, muted

---

## 7. Key Screens (from mockups)
- Splash: Logo centered, "Save smart. Grow together." tagline
- Onboarding: 3 slides with illustrations, dots indicator, "Get started" CTA
- Login: Logo, phone+password, fingerprint option, Google sign-in
- Register: Step 1/2, phone+email+password+confirm, progress bar
- OTP: 6-digit code entry, resend timer, "Verify" CTA
- Dashboard: Balance card (green gradient), quick actions, savings plans, transactions
- Savings: AutoSave, SafeLock, Goals, Circles quick actions
- AutoSave: Daily/Weekly/Monthly toggle, M-Pesa connection, projection
- Circles (Upatu): Group cards, cycle status, payout rotation, contribute
- Investments: Risk filter, product cards with return %, "Invest now"
- Goals: Category icons grid, name+target+date form, preview
- Deposit: Amount with presets, payment method cards, transaction summary
- Wallet: Flex balance card, FlexDollar promo, transactions
- KYC: Step indicator, NIDA upload, capture buttons
- Profile: Avatar, sections (Account, Security, Notifications, Preferences, Support)
- PIN Entry: Custom keypad, fingerprint option
- 2FA: 6-digit code with authenticator
