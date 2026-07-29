---
name: Nexus Human-Centric Interface
colors:
  surface: '#f9f9f7'
  surface-dim: '#dadad8'
  surface-bright: '#f9f9f7'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f4f4f1'
  surface-container: '#eeeeec'
  surface-container-high: '#e8e8e6'
  surface-container-highest: '#e2e3e0'
  on-surface: '#1a1c1b'
  on-surface-variant: '#3e4947'
  inverse-surface: '#2f3130'
  inverse-on-surface: '#f1f1ef'
  outline: '#6e7977'
  outline-variant: '#bec9c6'
  surface-tint: '#066a61'
  primary: '#004e47'
  on-primary: '#ffffff'
  primary-container: '#00685f'
  on-primary-container: '#93e4d8'
  inverse-primary: '#85d5c9'
  secondary: '#216963'
  on-secondary: '#ffffff'
  secondary-container: '#a8ece4'
  on-secondary-container: '#266d67'
  tertiary: '#742f13'
  on-tertiary: '#ffffff'
  tertiary-container: '#924628'
  on-tertiary-container: '#ffc9b6'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#a1f1e5'
  primary-fixed-dim: '#85d5c9'
  on-primary-fixed: '#00201d'
  on-primary-fixed-variant: '#005049'
  secondary-fixed: '#abefe7'
  secondary-fixed-dim: '#8fd3cb'
  on-secondary-fixed: '#00201d'
  on-secondary-fixed-variant: '#00504b'
  tertiary-fixed: '#ffdbcf'
  tertiary-fixed-dim: '#ffb59a'
  on-tertiary-fixed: '#380d00'
  on-tertiary-fixed-variant: '#773215'
  background: '#f9f9f7'
  on-background: '#1a1c1b'
  surface-variant: '#e2e3e0'
typography:
  display-lg:
    fontFamily: Manrope
    fontSize: 48px
    fontWeight: '800'
    lineHeight: 56px
    letterSpacing: -0.02em
  display-lg-mobile:
    fontFamily: Manrope
    fontSize: 36px
    fontWeight: '800'
    lineHeight: 44px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Manrope
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Manrope
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 14px
    letterSpacing: 0.02em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  2xl: 48px
  3xl: 64px
---

## Brand & Style
The design system is anchored in the concept of "Human Commerce"—a philosophy that prioritizes trust, clarity, and warmth in a peer-to-peer environment. It bridges the gap between digital efficiency and personal connection.

The visual style is **Modern Professional with a Soft Edge**. It utilizes generous whitespace, subtle depth, and a sophisticated color palette to evoke a sense of a premium boutique rather than a cluttered marketplace. The interface feels organic yet structured, utilizing high-quality typography and consistent 4px rhythm to establish reliability.

## Colors
This design system uses a "Trustworthy Teal" semantic ramp, now optimized for a **Light Mode first** experience. The palette is designed to be airy, clean, and professional.

- **Light Mode (Default):** Uses a warm off-white (`#fafaf7`) for the global background, paired with pure white surfaces to create clear containment for product imagery and UI elements.
- **Dark Mode:** Employs a deep, teal-tinted near-black for the global background, maintaining high contrast and brand continuity for reduced eye strain environments.
- **Action Colors:** Primary actions utilize core Teal (`#0d9488`) while secondary accents use a deeper Forest Teal (`#115e59`) to ensure clear hierarchy and professional grounding.

## Typography
The system employs a dual-font strategy. **Manrope** is used for headlines and display text to provide a modern, geometric character that feels approachable yet high-end. **Inter** is used for body copy and UI labels due to its exceptional legibility and systematic performance.

Hierarchy is strictly enforced through weight and scale. For mobile, display sizes are aggressively reduced to ensure primary messaging remains "above the fold" while maintaining its bold personality.

## Layout & Spacing
This design system follows a strict **4px grid system**. All margins, paddings, and component heights must be multiples of 4 to ensure visual mathematical harmony.

- **Mobile:** Uses a fluid 2-column or 1-column layout with 16px side margins and 12px gutters for product grids.
- **Desktop:** Transitions to a 12-column fixed-width grid (max 1280px) centered on the screen.
- **Vertical Rhythm:** A consistent 24px (lg) or 32px (xl) spacing is used between distinct content sections to maintain the "airy," high-end feel.

## Elevation & Depth
In light mode, depth is achieved through soft ambient shadows and subtle tonal shifts against the warm neutral base. The interface uses progressively lighter surface colors to indicate height and importance.

- **Level 0 (Base):** Global background (`background` / `#fafaf7`).
- **Level 1 (Card/Surface):** Pure white containers (`surface`) that sit atop the warm neutral base.
- **Level 2 (Floating/Interactive):** Surfaces with soft ambient shadows or subtle `outline-variant` borders to indicate interactivity.
- **Level 3 (Modals/Overlays):** Elevated surfaces with backdrop blurs and pronounced ambient shadows to isolate focus.

In dark mode, depth is primarily communicated through tonal layering and subtle teal-tinted inner glows rather than traditional shadows.

## Shapes
The shape language is defined by **Soft Geometricism**. 

Standard components (buttons, inputs) utilize a **0.5rem (8px)** radius. Larger containers such as product cards and modals utilize a **1rem (16px)** radius. This degree of roundedness removes "visual sharpness," making the C2C experience feel friendlier and less institutional. "Shoppable Pills" and tags always use a full pill radius (999px) to distinguish them as actionable metadata.

## Components

### Buttons & Actions
- **Primary:** Filled with `primary`. 8px radius. 16px horizontal padding. Bold Inter text.
- **Secondary:** Subtle forest teal background (`secondary-container`) with `on-secondary-container` text for a sophisticated alternative.
- **Bottom Tab Bar:** Clean white backdrop with 24px height icons. Use `on-surface-variant` for inactive states and `primary` for active states.

### Product Cards
- **Visuals:** Top-aligned photo or video with 16px top-radius. 1:1 or 4:5 aspect ratio.
- **Details:** 12px internal padding. Title in `headline-sm`, price in `label-md` with `primary` color.
- **Seller Chip:** Small avatar (24px) paired with `label-sm` text, positioned at the bottom of the card content.

### Inputs & Selection
- **Inputs:** 1px border (`outline`). On focus, the border thickens to 2px and changes to `primary` with a soft teal outer glow.
- **Chips:** `body-sm` text. Use `primary-container` for selected states and a light neutral background for unselected states.
- **Shoppable Pills:** Overlaid on product images. Semi-transparent surface with `on-surface` text and a small dot icon.

### Feedback
- **Success/Warning/Danger:** Use filled backgrounds with high-contrast text for critical alerts, or "Ghost" variants (colored text + subtle tinted background) for inline validation.