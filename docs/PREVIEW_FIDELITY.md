# Browser preview fidelity contract

The approved interactive browser preview is the product source of truth. Native implementations preserve its information hierarchy, industrial blue/steel palette, spacing rhythm, status semantics, permanent free-banner slot, three-cylinder gate, searchable/filterable inventory, activity summaries, suppliers, forms, backup, delete/undo, and responsive phone/tablet behavior.

Expected native differences are limited to platform-owned rendering:

- SwiftUI navigation, sheets, controls, SF Symbols, keyboards, safe areas, Dynamic Type and VoiceOver.
- Jetpack Compose Material 3 navigation, sheets, controls, Material Symbols, keyboards, insets, font scaling and TalkBack.
- App Store/Play localized prices, system consent dialogs, system file pickers and notification permission prompts.
- Small text-metric and anti-aliasing differences between SF Pro and Roboto.

Currency is displayed with the locale-appropriate sign. ISO currency codes remain internal to persisted records for normalization. Historical currencies are neither converted nor combined.

## Required visual QA before packaging

1. Capture the same three-cylinder Home state on a current iPhone simulator and Android emulator.
2. Capture the tablet two-column state on iPad and an 800 dp Android tablet.
3. Compare each capture beside the browser reference at the same logical viewport.
4. Verify banner reservation, touch targets, Dynamic Type/font scaling, RTL, empty state, expanded status row, forms and paywall.
5. Package only after visible mismatches are fixed.

Native simulator/device capture is intentionally separate from a code-only upload because hosted APK, iOS and TestFlight workflows require explicit cost authorization.
