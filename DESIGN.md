# Design System Strategy: The Luminous Productivity Framework

## 1. Overview & Creative North Star
This design system is built upon the North Star of **"The Ethereal Organizer."** Moving away from the rigid, boxy constraints of traditional productivity tools, this system prioritizes breathability, soft depth, and high-end editorial flair. 

The goal is to transform the complex logistics of trip and event planning into a serene, guided experience. We achieve this by breaking the standard mobile grid through intentional asymmetry—using large, bold display typography offset by airy white space and floating "glass" containers. The interface should feel less like a database and more like a high-end travel journal.

---

## 2. Colors & Surface Philosophy
The palette leverages a sophisticated interplay between deep energetic gradients and soft, layered neutrals.

### Palette Highlights
- **Primary Gradient:** A transition from `primary (#3642e9)` to `primary_container (#8f97ff)`. This is reserved for "Moments of Action" (Hero CTAs, Active States).
- **Secondary/Tertiary Accents:** `secondary (#7335cc)` and `tertiary (#95377a)` are used for categorization (e.g., distinguishing "Trips" from "Events").
- **Neutral Foundation:** `background (#f5f6f7)` serves as the canvas, while `surface_container_lowest (#ffffff)` provides the crisp lift for interactive cards.

### The Rules of Engagement
- **The "No-Line" Rule:** 1px solid borders are strictly prohibited for sectioning. Definition must be achieved through background shifts. For example, a `surface_container_low` group should sit directly on a `surface` background to define its boundary.
- **Surface Hierarchy & Nesting:** Treat the UI as physical layers of fine paper. 
    - **Base Layer:** `surface`
    - **Secondary Content Areas:** `surface_container_low`
    - **Interactive Floating Cards:** `surface_container_lowest`
- **The "Glass & Gradient" Rule:** Floating action elements (like the bottom nav or FABs) must utilize Glassmorphism. Use `surface_container_lowest` with a 80% opacity and a 20px backdrop-blur to allow the background context to bleed through softly.
- **Signature Textures:** Use the Primary-to-Secondary gradient as a subtle background fill for "Mission" or "Hero" cards to provide visual soul.

---

## 3. Typography
The typography uses a dual-font strategy to balance authoritative editorial style with functional legibility.

- **Display & Headlines (Plus Jakarta Sans):** Used for large-scale headers (`display-lg` to `headline-sm`). These should be set with tight letter-spacing (-2%) to create a "compact-premium" look.
- **Body & Labels (Inter):** Used for all functional data. Inter's tall x-height ensures clarity in dense trip itineraries.
- **Hierarchy Strategy:** Establish a 3:1 ratio between headline and body size. For example, a `headline-lg` title should be supported by `body-sm` metadata to create a dynamic, editorial contrast.

---

## 4. Elevation & Depth
Depth in this design system is achieved through **Tonal Layering** rather than heavy drop shadows.

- **The Layering Principle:** Place a `surface_container_lowest` card atop a `surface_container` background. The slight shift in hex value provides a sophisticated "lift" that feels more modern than a shadow.
- **Ambient Shadows:** For high-priority floating elements (e.g., the Trip Card), use a "Signature Glow" shadow:
    - **Color:** `on_surface` at 6% opacity.
    - **Blur:** 32px to 48px.
    - **Y-Offset:** 8px.
- **The "Ghost Border" Fallback:** If a divider is required for accessibility, use the `outline_variant` token at **10% opacity**. It should be felt, not seen.
- **Corner Radii:** Consistent use of `md (1.5rem)` for primary cards and `lg (2rem)` for main container wrappers to maintain a friendly, approachable hand-feel.

---

## 5. Components

### Buttons
- **Primary:** Full gradient fill (`primary` to `primary_dim`) with `on_primary` text. `xl (3rem)` rounding.
- **Secondary:** `surface_container_high` background with `primary` text. No border.
- **Tertiary:** Text-only using `primary` color, bold weight, with a `label-md` scale.

### Cards (The Core Planning Unit)
- **Style:** Forbid the use of divider lines inside cards. Use `spacing-4 (1.4rem)` of vertical whitespace to separate header text from itinerary details.
- **Nesting:** Small "sub-cards" or "chips" inside a main card should use `surface_container_low` to create a sunken, tactile effect.

### Input Fields
- **Container:** Use `surface_container` with no border. On focus, transition the background to `surface_container_lowest` and add a `primary` "Ghost Border" at 20% opacity.
- **Typography:** Placeholder text uses `on_surface_variant` in `body-md`.

### Bottom Navigation
- **Style:** A floating "pill" container using the Glassmorphism rule.
- **Active State:** A `surface_container_high` circular backdrop behind the icon, utilizing `primary` color for the icon itself.

---

## 6. Do's and Don'ts

### Do
- **DO** use white space as a structural element. If a screen feels cluttered, increase the spacing between cards using the `20 (7rem)` or `24 (8.5rem)` tokens.
- **DO** overlap elements slightly (e.g., a profile icon overlapping a card edge) to break the "grid" feel and add a custom, designed touch.
- **DO** use the `tertiary` (purple/pink) accents for rewards, streaks, or "XP" to differentiate productivity logic from travel logic.

### Don't
- **DON'T** use 100% black (#000000) for text. Always use `on_surface (#2c2f30)` for a softer, more premium reading experience.
- **DON'T** use hard-edged rectangles. Every container must adhere to the `md` or `lg` rounding scale to maintain the "Soft Minimalism" vibe.
- **DON'T** use standard grey shadows. Shadows should always be diffused and low-contrast to avoid a "dirty" UI look.