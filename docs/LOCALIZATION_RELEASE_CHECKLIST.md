# Welding Gas Wallet localization release checklist

Exact key parity is an engineering gate, not cultural approval. A language remains absent from Settings until every item below passes for its complete app catalog.

## Current release state

| Locale | Settings option | Full catalog | Cultural review | Release state |
|---|---|---:|---:|---|
| en | English | PASS | PASS | Enabled |
| es-419 | Español (Latinoamérica) | PASS | PASS | Enabled |
| pt, fr, de, it, nl, pl, tr, ro, cs, uk, ru, ar, zh-Hans, ja, ko, hi, ur, bn, vi, id, th, fil, ms, fi, sv, da, nb, el, he | Native autonym required | PENDING | PENDING | Blocked |

The 31-locale welding glossary is a terminology contract, not a full translation claim. It prevents incorrect geometric/engine meanings of “cylinder,” physical-height translations of “low,” and inconsistent refill, supplier, off-site and destructive-confirmation terms.

## Catalog and behavior

- [ ] A matching `.lproj/Localizable.strings` file has exact English key and format-placeholder parity.
- [ ] Every product screen, Settings row, sheet, empty/loading/error state, validation message, notification and accessibility label has been reviewed in context.
- [ ] No empty value, cross-key multiline leakage, English fallback prose, template copy or display of a persisted raw value remains.
- [ ] Language-region/script resolution is deliberate; the language appears in Settings under its native autonym.
- [ ] Numbers, decimal input, currency, dates and times use the selected locale.
- [ ] Counts use grammar-neutral localized labels and Apple’s locale-aware formatting; billing and reminder durations do not use English one/other branching.
- [ ] Search recognizes the localized words displayed to the customer.

## Cultural and domain review

- [ ] A fluent regional reviewer approves all strings in screen context; generated translation alone is never accepted.
- [ ] Welding-gas cylinder, low-gas, refill, exchange, supplier, rental/lease/deposit and off-site vocabulary matches regional trade usage and the checked-in glossary.
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

These checks require reviewed catalogs and an authorized device run; neither may be marked complete from source parity alone.
