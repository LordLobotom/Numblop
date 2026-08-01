# Localization Contract

## Supported locales

- `en` — English fallback.
- `cs` — Czech.
- `system` — saved preference that resolves to Czech for a Czech device and English otherwise.

## Rules

- Put every user-facing string in `localization/strings.csv` using stable semantic keys.
- Add English and Czech in the same change; blank fallback text is a test failure.
- Keep `Numblop` untranslated as the public product name.
- Use whole-sentence keys and named placeholders such as `{count}` and `{table}`.
- Do not translate mathematical symbols or alter numeric formatting inside the learning core.
- Use UTF-8 and the bundled Fredoka font, verifying Czech characters:
  `á č ď é ě í ň ó ř š ť ú ů ý ž`.
- Check text expansion, wrapping, and touch sizes in both locales at 390 × 844.

Language choice is local device configuration and is stored separately from mastery.
