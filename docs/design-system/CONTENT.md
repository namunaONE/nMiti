# nMiti content law — bilingual UI writing rules

Wording is design. nMiti needs a written content law because every page
carries two scripts, two calendars, and two numeral systems. Drift here
is invisible in a single PR and fatal across a site.

## Scripts and numerals

- Nepali-language UI text is Devanagari; English-language UI text is
  Latin. The two scripts NEVER mix inside one value (no "कार्तिक 16").
- Devanagari digits ० १ २ ३ ४ ५ ६ ७ ८ ९ map to 0-9. Nepali UI renders
  dates in Devanagari digits; English UI in Latin digits.
- All numerals in tables and grids use `tabular-nums`.

## Date formats (canonical)

| Audience | Format | Example |
| -------- | ------ | ------- |
| Nepali UI | <महिना> <गते>, <वर्ष> वि.सं. | कार्तिक १६, २०८३ वि.सं. |
| English UI | <Month> <day>, <year> BS | Kartik 16, 2083 BS |
| Machine / data | <year>-<month>-<day> BS, zero-padded | 2083-07-16 BS |

Examples render from the canonical dataset — never hand-type a date
(architecture rule 6).

## Month and weekday names

`bsMonthNameEn` in the nepali_date SDK is the single source of truth for
romanized month names. The table below is the intent; if the SDK differs,
the SDK wins and this table gets fixed. Banned variants MUST NOT appear
in UI copy.

| BS # | Devanagari | Canonical Latin | Banned variants (seen in the wild) |
| ---- | ---------- | --------------- | ---------------------------------- |
| 1 | वैशाख | Baisakh | Baishakh, Baisak |
| 2 | जेठ | Jestha | Jeth |
| 3 | असार | Ashadh | Asar, Asaar |
| 4 | साउन | Shrawan | Srawan, Saun, Shravan |
| 5 | भदौ | Bhadra | Bhadau, Bhadaun |
| 6 | असोज | Ashwin | Asoj, Asooj, Aswin |
| 7 | कार्तिक | Kartik | Kartika, Kattik |
| 8 | मंसिर | Mangsir | Mansir, Marshir |
| 9 | पुष | Poush | Push, Pushya |
| 10 | माघ | Magh | Magh, Maghe |
| 11 | फागुन | Falgun | Fagun, Falguna |
| 12 | चैत | Chaitra | Chait, Chaitraa |

Weekdays (Devanagari, fixed): आइतबार, सोमबार, मंगलबार, बुधबार, बिहीबार,
शुक्रबार, शनिबार.

Festival names: Devanagari form is canonical; the first festival pages
MUST extend this table before shipping romanized festival names.

## Capitalization and voice

- Sentence-style capitalization for headings, titles, labels, buttons,
  and banners in English. Nepali has no case.
- Voice: concise, factual, zero hype. No exclamation marks in UI.
- Errors say what happened and what to do next. Never blame the user.

## Accessibility writing

- Color is never the only carrier of meaning — pair it with a text label.
- Alt text describes information, not decoration.
- Help appears in the same place on every page (WCAG 2.2 SC 3.2.6).

## Terminology quick rules

- पात्रो appears in English copy as "patro" — a lowercase loanword.
- "2083 BS" (space before BS); Nepali uses वि.सं.
- Bikram Sambat, not Vikram Samvat, in English copy.
- Projection years are labeled "projection" — never phrased as verified.
