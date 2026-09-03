# Welding Gas Wallet localization release checklist

Exact key parity is an engineering gate, not cultural approval. At the product owner's direction, every target language is now selectable while native-speaker and on-device review remain explicit release-evidence tasks.

## Current release state

| Locale | Settings option | Full catalog | Cultural review | Release state |
|---|---|---:|---:|---|
| en | English | PASS | PASS | Enabled |
| es-419 | Español (Latinoamérica) | PASS | PASS | Enabled |
| pt, fr, de, it, nl, pl, tr, ro, cs, uk, ru, ar, zh-Hans, ja, ko, hi, ur, bn, vi, id, th, fil, ms, fi, sv, da, nb, el, he | PASS — native autonyms | PASS — 288/288 keys | PENDING — native/device review | Enabled by product decision |

The new catalogs combine automated full-catalog coverage, previously reviewed Welding Gas Wallet translations where the source meaning matches, the shared reviewed localization baseline, and the 31-locale welding glossary. The glossary is a terminology contract, not a claim that automated text has received native review. It prevents incorrect geometric/engine meanings of “cylinder,” fuel translations of welding gas, physical-height translations of “low,” and inconsistent refill, supplier, off-site, subscription-status and destructive-confirmation terms.

## Catalog and behavior

- [x] A matching `.lproj/Localizable.strings` file has exact English key and format-placeholder parity for every selectable locale.
- [ ] Every product screen, Settings row, sheet, empty/loading/error state, validation message, notification and accessibility label has been reviewed in context.
- [ ] No empty value, cross-key multiline leakage, English fallback prose, template copy or display of a persisted raw value remains.
- [x] Language-region/script resolution is deliberate; the language appears in Settings under its native autonym.
- [ ] Numbers, decimal input, currency, dates and times use the selected locale.
- [x] Counts use grammar-neutral localized labels and Apple’s locale-aware formatting; billing and reminder durations do not use English one/other branching.
- [ ] Search recognizes the localized words displayed to the customer.

## Cultural and domain review

- [ ] A fluent regional reviewer approves all strings in screen context; generated translation alone is never accepted.
- [x] Welding-gas cylinder, low-gas, refill, supplier, off-site and destructive-confirmation vocabulary matches the checked-in regional terminology contract.
- [ ] A fluent regional reviewer confirms the remaining exchange, rental/lease/deposit and surrounding trade copy in screen context.
- [ ] Commands, formality and destructive confirmation are natural locally; customers are never required to type an unexplained English word.
- [ ] Paywall copy describes job readiness, low-gas visibility and service history accurately. StoreKit remains the source of product name, localized price and billing period.
- [ ] Apple Account, restore, renewal, cancellation, grace period and billing-retry wording matches Apple’s customer model.
- [ ] Proper names, gas formulas and units remain unchanged only where that is the local convention.
- [ ] Copy avoids stereotypes, flags as language symbols, non-portable idioms and assumptions about one country.
- [ ] External legal links disclose their actual available document language honestly.

## Visual and accessible QA

- [ ] Inspect every screen at large Dynamic Type on compact iPhone and iPad layouts.
- [ ] Verify VoiceOver pronunciation, reading order, labels and state changes.
- [ ] For Arabic, Urdu and Hebrew, verify full RTL mirroring, mixed product names/numerals and directional icons after an in-app language change.
- [ ] Record reviewer, locale, app version and date in release evidence.

The source gate currently passes for all 31 locales and 288 keys. Native-speaker and device checks remain unclaimed because this update was explicitly code-only.
