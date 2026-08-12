# Localization Contract

## Shipped languages

Ten languages, in the order their flags appear:

| Locale | Language | Locale | Language |
|---|---|---|---|
| `en` | English (fallback) | `fi` | Finnish |
| `cs` | Czech | `fr` | French |
| `sk` | Slovak | `nb` | Norwegian Bokmål |
| `de` | German | `pl` | Polish |
| `es` | Spanish | `sv` | Swedish |

A saved preference of `system` resolves to the device language when Numblop ships it, and to English
otherwise. Devices reporting `no` or `nn` are folded to `nb`.

## The two places a language lives

- `scripts/app/LanguageCatalog.gd` — one row per language: locale code, flag image, and name key.
  `SettingsManager` validates a saved preference against it, and both the opening screen and the
  settings screen build their flag buttons from it.
- `localization/strings.csv` — one column per language, header `keys,en,cs,sk,de,es,fi,fr,nb,pl,sv`.

**Adding a language is one row plus one column, and a flag PNG in `ui/buttons/`.** No scene edits.
The two lists must stay in step: a language in the catalog without a CSV column shows a flag that
switches the whole app to raw keys, which is why `tests/smoke/test_localization_catalog.gd` asserts
both directions and rejects orphan columns.

## Rules

- Put every user-facing string in `localization/strings.csv` using stable semantic keys. Never place
  user-facing prose directly in GDScript.
- Fill **every** language column in the same change. A blank cell is a test failure, because Godot
  falls back to the raw key and the screen reads `MAP_TITLE`.
- Keep `Numblop` untranslated as the public product name.
- Use whole-sentence keys and named placeholders such as `{count}`, `{table}`, and `{version}`. Every
  translation must carry exactly the placeholders the English text uses — a dropped `{count}` prints
  the sentence without its number and a renamed one prints the braces, and neither shows up until
  that language is actually played.
- Do not translate mathematical symbols or alter numeric formatting inside the learning core.
- Use UTF-8 and the bundled Baloo 2 font with its Noto Sans fallback. Verify the diacritics the
  shipped languages need, at minimum
  `á č ď é ě í ň ó ř š ť ú ů ý ž ä ö å ø æ ą ć ę ł ń ś ź ż ñ ü ß à è ê ô`.
- Check text expansion, wrapping, and touch sizes at 390 × 844. German and Finnish are the longest
  strings in practice and are the ones that overflow a button first.

## The Czech mastery bands

The four mastery bands carry deliberate Czech wording that describes the child's own experience
rather than a score, and it is pinned by test:

| Band | English | Czech |
|---|---|---|
| Building (0–59) | Learning | `Objevuji` |
| Practicing (60–79) | Practicing | `Procvičuji` |
| Mastered (80–89) | Mastered | `Upevňuji` |
| Automated (90–100) | Confident | `Mám jistotu` |

## Tests

`tests/smoke/test_localization_catalog.gd` covers the contract:

- the header matches the shipped language list exactly, in both directions;
- every key has non-empty text in every column;
- every translation keeps the English placeholders;
- the runtime catalog actually switches — one word is checked per language;
- the Czech band names are the agreed ones.

Responsive captures run in English and Czech only. Those two are the deepest-tested layouts; the
other eight are covered by the catalog tests and by reading the strings, not by screenshots.

Language choice is local device configuration, stored in `user://settings.cfg`, separately from
mastery. See [`SAVE_SYSTEM.md`](SAVE_SYSTEM.md).
