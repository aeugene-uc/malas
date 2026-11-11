# MALAS

Spec: `malas-spec.txt` in Multiplayr DEPD/App/App. Code that implements the spec uses its words (Masuk, Keluar, Piutang, Utang, Simpan) and matches it exactly.

## Layout

```
app/       Flutter, MVVM
  lib/model/       plain data classes, fromJson/toJson
  lib/data/        ApiClient (dio) and repositories, the only code that talks HTTP
  lib/viewmodel/   one ViewModel per screen, holds screen state, calls repositories
  lib/view/        widgets only, read state from their ViewModel, no HTTP, no business logic
backend/   Express + TypeScript + Prisma on MariaDB
  src/routes/      URL to controller, nothing else
  src/controllers/ read and validate the request, call a service, send the response
  src/services/    business rules and §10 calculations, no req/res
  src/ai/          model calls (Gemma 4 on NVIDIA, DeepSeek fallback)
  prisma/          schema.prisma and migrations
  test/
```

## Time

- The database and every API timestamp are UTC.
- A business date is computed in `backend/src/services` from the store's `timezone` (default `Asia/Jakarta`) and `dayChangeHour` (default 4). Never from the server clock or from `NOW()` / `CURDATE()` in SQL.
- Dates travel as `"YYYY-MM-DD"`. Money is integer rupiah. Quantities travel as strings (`"0.5"`).

## Coding standard

- Shortest working version. No interface with one implementation, no factory for one product, no config for a value that never changes. Standard library and installed packages before a new dependency.
- One function or module does one job.
- Names say what a thing is. A named intermediate that explains a step beats a dense one-liner.
- Type every function signature. TypeScript `"strict": true`. Dart with `strict-casts` and `strict-raw-types`.
- Collections are plural, booleans start with `is` or `has`, maps are named `xByY`. camelCase in TypeScript and Dart.
- Related constants are an enum or a string union, never bare numbers. A lone constant is `const`.
- Three or more parameters, or two that could be swapped: one options object in TypeScript, named parameters in Dart.
- Function names are verb + object (`computeLineTotal`) or a question (`isFullyPaid`). A file reads top-down: the main flow first, helpers after their caller.
- A class bundles data with the behaviour that changes it. Functions that own no data stay module functions.
- Call another module's functions through its name (`transactionService.save(...)`).
- Let errors surface. Catch only where the code can retry, fall back or tell the user. Never swallow an error.
- Validate at trust boundaries: request bodies, AI output, network calls.
- Comments say why, never what.
- A test must fail when the code is wrong. Break the code once and check that the test catches it. Test names state the behaviour (`savesSpokenTotalAndRecordsDiscount`).
- UI carries labels and data only. No subtitle, hint or footer text explaining a feature.

## Git

- One branch per issue (`s5-save-path`, `f3-draft-screen`). No pull requests.
- Commits are small and sequential: each one builds, and each one does one step.
- When the issue is done: rebase the branch onto `main`, merge it into `main`, push. The last commit message says `Closes #N`.
- Announce each merge in Multiplayr DEPD/App/App with the issue number and which spec §8 flow Obie should test. All team communication goes through Multiplayr.
- `.env` is never committed. Copy `backend/.env.example`.
- Commit as yourself.
