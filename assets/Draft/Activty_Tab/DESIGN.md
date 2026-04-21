---
name: Secure Operations Interface
colors:
  surface: '#faf8ff'
  surface-dim: '#d9d9e5'
  surface-bright: '#faf8ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f2fe'
  surface-container: '#ededf9'
  surface-container-high: '#e8e7f3'
  surface-container-highest: '#e2e1ed'
  on-surface: '#1a1b23'
  on-surface-variant: '#434655'
  inverse-surface: '#2e3039'
  inverse-on-surface: '#f0f0fb'
  outline: '#747686'
  outline-variant: '#c4c5d7'
  surface-tint: '#2151da'
  primary: '#0037b0'
  on-primary: '#ffffff'
  primary-container: '#1d4ed8'
  on-primary-container: '#cad3ff'
  inverse-primary: '#b7c4ff'
  secondary: '#565e74'
  on-secondary: '#ffffff'
  secondary-container: '#dae2fd'
  on-secondary-container: '#5c647a'
  tertiary: '#7f2500'
  on-tertiary: '#ffffff'
  tertiary-container: '#a73400'
  on-tertiary-container: '#ffc9b7'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dce1ff'
  primary-fixed-dim: '#b7c4ff'
  on-primary-fixed: '#001551'
  on-primary-fixed-variant: '#0039b5'
  secondary-fixed: '#dae2fd'
  secondary-fixed-dim: '#bec6e0'
  on-secondary-fixed: '#131b2e'
  on-secondary-fixed-variant: '#3f465c'
  tertiary-fixed: '#ffdbcf'
  tertiary-fixed-dim: '#ffb59c'
  on-tertiary-fixed: '#390c00'
  on-tertiary-fixed-variant: '#832700'
  background: '#faf8ff'
  on-background: '#1a1b23'
  surface-variant: '#e2e1ed'
typography:
  display-sm:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  body-base:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-caps:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
  numeric-data:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  gutter: 20px
  container_margin: 24px
---

## Brand & Style

The design system is engineered for high-stakes enterprise environments where security and data integrity are paramount. It targets IT administrators and security officers within the sports industry, balancing the high-energy nature of sports with the stoic reliability of cyber-security.

The aesthetic follows a **Corporate Modern** movement. It utilizes a refined, utilitarian structure that prioritizes information density without sacrificing clarity. The visual mood is one of "calm authority"—using crisp borders and a logic-driven layout to instill confidence in the user. Every element is designed to feel intentional and permanent, avoiding trendy flourishes in favor of a premium, lasting professional feel.

## Colors

The palette is anchored by "Deep Stadium Blue" and "Security Slate," providing a foundation of trust and athletic professionalism. The primary action color is a vivid, accessible blue, ensuring high visibility for interactive elements. 

The system employs a strict semantic coloring logic for status: 
- **Secure Green:** Indicates encrypted states, active health, and successful audits.
- **Warning Amber:** Used for non-critical anomalies or upcoming certificate expirations.
- **Critical Red:** Reserved for security breaches, failed encryptions, or unauthorized access attempts.

Backgrounds utilize cool-toned grays to reduce eye strain during long monitoring sessions, while surfaces use pure white to pop against the backdrop, creating a clear physical distinction between the canvas and the content containers.

## Typography

This design system relies exclusively on **Inter** to leverage its exceptional legibility and neutral, systematic character. The typographic hierarchy is built on high contrast between weights rather than size alone.

- **Headlines:** Use SemiBold and Bold weights with tighter letter-spacing to create a sense of urgency and importance.
- **Body Text:** Optimized for long-form audit logs and descriptions using the Regular weight at 16px for comfortable reading.
- **Data Display:** Numerical values utilize tabular lining figures (`tnum`) to ensure columns of data align perfectly in dashboard tables and inventory lists.
- **Labels:** Small-scale uppercase labels provide structural metadata without cluttering the primary visual field.

## Layout & Spacing

The system uses a **12-column fluid grid** for desktop views, transitioning to a single-column stack on mobile. The layout model is built on a 4px baseline grid to ensure mathematical harmony across all components.

Information is organized into "Content Blocks"—modular units that span varying column widths (e.g., 4 columns for small metrics, 8 columns for activity feeds). Gutters are kept tight at 20px to maintain high information density while horizontal padding within cards is generous (24px) to keep text from feeling cramped against borders. Priority is given to top-to-bottom scannability, with critical status indicators always positioned in the top-right or leading-left of their respective containers.

## Elevation & Depth

Depth in this design system is conveyed through a combination of **Tonal Layers** and **Subtle Shadows**. 

- **Level 0 (Background):** The base canvas uses the `neutral_background` hex.
- **Level 1 (Cards/Panels):** Pure white surfaces with a 1px solid `neutral_border`. This creates a crisp, architectural feel.
- **Level 2 (Interactive/Overlays):** Elements that require focus (like dropdowns or active modals) use an ambient, low-opacity shadow (Color: `secondary_color_hex`, Alpha: 8%, Blur: 12px, Y-Offset: 4px).

Avoid heavy dropshadows or floating effects. The goal is to make components feel like they are seated firmly on the interface, rather than hovering disconnectedly.

## Shapes

The design system employs a **Rounded** shape language to soften the industrial nature of the dashboard. This balance ensures the UI feels modern and premium rather than "legacy" or "brutalist."

- **Standard Radius:** 0.5rem (8px) for buttons, input fields, and small cards.
- **Large Radius:** 1rem (16px) for main dashboard containers and sections.
- **Pill Shapes:** Exclusively reserved for status badges and tags to distinguish them from interactive button elements.

## Components

### Buttons
Primary buttons use a solid blue fill with white text. Secondary buttons use a transparent background with a 1px slate border. Icons within buttons should be 20px and aligned to the leading edge to aid quick identification.

### Status Badges
Status badges must always include an icon + text pair. For example, a "Secure" badge uses a lock icon with the `status_success` color. Use a light 10% opacity background of the status color to ensure the text remains legible while clearly categorizing the alert level.

### Cards & Monitoring Panels
Every card should feature a 4px vertical "accent bar" on the top or left edge to denote category or status. This provides an immediate visual cue during a fast scroll.

### Input Fields
Fields use a 1px slate border that thickens to 2px and changes to the primary blue on focus. Labels must be positioned above the field, never as placeholder text, to maintain accessibility.

### Progress Bars
Used for data footprint and encryption progress. They feature a light gray track and a high-contrast blue or status-specific fill. Avoid gradients; use solid colors for a cleaner, more professional data visualization style.