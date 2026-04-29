# AlignEye Mobile App Design System

This file is the source of truth for any human or AI model working on the app UI. Follow it before changing screens, components, icons, logos, animations, or navigation patterns.

## Product Direction

AlignEye is a production-level mobile app for posture correction, calibration, walking, breathing, therapy, training, tracking, and analytics. The visual style must feel modern, premium, calm, interactive, and health-focused.

The app should feel:

- Clean and modern
- Smoothly animated
- Touch-first and user interactive
- Consistent across every screen
- Production-ready, not prototype-like

## Core Design Rules

### 1. Global Button Background Rule

Every primary action button must use the same background treatment as the existing `Start Calibration` button.

Current `Start Calibration` button background:

```dart
LinearGradient(
  colors: [Color(0xFFA855F7), Color(0xFFEC4899)],
)
```

Design token:

```dart
primaryButtonGradient = LinearGradient(
  colors: [Color(0xFFA855F7), Color(0xFFEC4899)],
)
```

Apply this to:

- Filled buttons
- CTA buttons
- Start buttons
- Save buttons
- Continue buttons
- Mode selection buttons when selected
- Any button that performs the main action on a screen

Do not create random button colors for different pages. Secondary or text-only buttons may be transparent, but any button with a visible filled background must match this Start Calibration button background.

### 2. Calibration Background Rule

The calibration screen background is the dark app base:

```dart
calibrationBackground = Color(0xFF0D1A1D)
```

Use this color for dark immersive screens, calibration-like flows, device-focused states, and focused posture/training experiences.

### 3. Logo And Icon Consistency Rule

Use the same app icon/logo identity everywhere on the home page modules:

- Walking
- Breathe
- Therapy
- Training
- Tracking
- Analytics

Approved app assets:

```text
assets/appIcon.png
assets/logosvg.svg
assets/product.png
```

The logo/icon style must stay consistent across all feature cards and home modules. Do not mix unrelated icon packs, random gradients, or mismatched illustration styles for these modules.

If a feature needs a symbol, use one consistent icon language:

- Prefer the existing app logo mark where brand identity is needed.
- Use Material icons only when the symbol must explain the action quickly.
- Keep icon size, stroke weight, color treatment, and container shape consistent across all home feature entries.

## Home Page Feature Modules

The home page must present Walking, Breathe, Therapy, Training, Tracking, and Analytics as one unified feature family.

Each module should use the same structure:

- Same card radius
- Same padding
- Same icon/logo container size
- Same typography scale
- Same selected and pressed states
- Same animation behavior
- Same button/CTA background rule

Recommended feature card pattern:

```text
Container:
  radius: 20
  padding: 16-20
  background: subtle surface over app background
  border: low-opacity white or theme border

Icon/logo area:
  size: 44-56
  shape: rounded square or circle, used consistently
  asset/icon: same visual style everywhere

Title:
  16-18 px
  weight: 700

Subtitle/status:
  12-14 px
  opacity: 65-75%
```

## Color Tokens

Use named colors instead of ad hoc values.

```dart
appDarkBackground = Color(0xFF0D1A1D)
primaryButtonStart = Color(0xFFA855F7)
primaryButtonEnd = Color(0xFFEC4899)
brandTeal = Color(0xFF008090)
successTeal = Color(0xFF14B8A6)
dangerRed = Color(0xFFEF4444)
textOnDark = Colors.white
textOnDarkMuted = Colors.white.withOpacity(0.65)
surfaceOnDark = Colors.white.withOpacity(0.06)
borderOnDark = Colors.white.withOpacity(0.08)
```

Use gradients sparingly. The main repeated gradient is the Start Calibration button gradient.

## Motion And Interaction

Animations should feel smooth, useful, and responsive.

Use these defaults:

```dart
fastMotion = Duration(milliseconds: 180)
standardMotion = Duration(milliseconds: 300)
screenMotion = Duration(milliseconds: 400)
primaryCurve = Curves.easeOutCubic
exitCurve = Curves.easeInCubic
```

Recommended interactions:

- Buttons scale slightly on press.
- Cards lift or brighten subtly on tap.
- Screen transitions use fade plus a small slide.
- Progress states animate, never jump.
- Calibration, tracking, and training states may use pulse animation.
- Avoid excessive bouncing or decorative animation that distracts from posture feedback.

## Typography

Keep text readable and mobile-first.

Recommended type scale:

```text
Screen title: 26-30 px, weight 700
Section title: 18-22 px, weight 700
Card title: 16-18 px, weight 700
Body: 14-16 px, weight 400-500
Caption/status: 12-14 px, weight 500
Button: 16-17 px, weight 600
```

Rules:

- Do not use tiny text for important health or device states.
- Keep button text centered and single-purpose.
- Use muted text only for secondary descriptions.
- Do not let text overflow cards or buttons.

## Component Rules

### Primary Buttons

```text
height: 52-56
radius: 16
background: primaryButtonGradient
text: white, 16-17 px, weight 600
pressed state: slight scale down and lower opacity
disabled state: same shape, lower opacity, no new color
```

### Secondary Buttons

```text
background: transparent or subtle surface
text: white at 60-75% opacity
border: optional low-opacity border
```

### Cards

```text
radius: 16-20
padding: 16-20
background: subtle surface
border: low-opacity border
shadow: soft and minimal only where useful
```

### Icons And Logos

```text
home module icon size: 28-32
home module icon container: 44-56
logo asset: assets/logosvg.svg where SVG is appropriate
app icon asset: assets/appIcon.png for app identity and fallback logo use
```

Do not use different-looking icons for Walking, Breathe, Therapy, Training, Tracking, and Analytics. They must look like one family.

## Screen Guidance

### Calibration

- Keep the immersive dark background.
- Keep the Start Calibration button gradient as the global primary button style.
- Use calm, focused copy.
- Use pulse and progress animation to guide the user.

### Home

- Home should be the central interactive dashboard.
- Walking, Breathe, Therapy, Training, Tracking, and Analytics must share one visual system.
- Use consistent logo/icon styling for all feature modules.
- Avoid making one feature visually louder unless it is the current active mode.

### Analytics

- Use the same brand/icon identity as home.
- Charts should feel clean and medical-grade.
- Avoid overly colorful chart palettes that fight the main app colors.

### Therapy And Training

- Use motion to show progress, state changes, timers, and selected modes.
- Primary controls must follow the global button background rule.
- Keep device feedback clear and immediate.

## Implementation Notes For Flutter

Prefer centralizing these values in a theme or shared constants file instead of repeating raw colors.

Recommended future location:

```text
lib/theme/app_theme.dart
lib/theme/app_design_tokens.dart
```

When implementing:

- Replace duplicated raw button gradients with one shared token.
- Replace mismatched home module icons with consistent icon/logo treatment.
- Keep `assets/logosvg.svg` and `assets/appIcon.png` as the primary identity assets.
- Use `flutter_svg` for SVG logo rendering.
- Keep all production UI responsive for common Android and iOS screen sizes.

## Non-Negotiables

- Any filled button background must match the Start Calibration button background.
- Walking, Breathe, Therapy, Training, Tracking, and Analytics must use the same logo/icon style on the home page.
- Do not introduce unrelated button colors.
- Do not introduce unrelated icon styles.
- Do not ship static-feeling UI where user actions should animate.
- Do not allow text overflow or cramped mobile layouts.
