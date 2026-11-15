# AI Voice Expense Tracker – Software Specification & System Design

Version 1.0 · 14 Nov 2026 · Audience: product owner and AI coding agent

## 0. How to use this document

This is the single source of truth for building the app. A coding agent should work milestone by milestone (Section 17) and must not skip ahead. Every milestone has acceptance criteria. Keywords: MUST = required, SHOULD = strongly preferred, MAY = later or optional. Requirement IDs (FR-x, NFR-x) should be referenced in commits and tests.

## 1. Product overview

**Vision:** Record naturally (by voice, in Bengali or English), organize automatically, understand your spending, save intelligently.

**Primary user:** A smartphone user in Bangladesh who speaks Bangla (often mixed with English words like Samsung, lunch, bKash) and wants to log money in under 5 seconds without picking categories.

**Goals**

- Log a transaction in one tap plus one sentence.
- Work fully offline for recording, storage and reports.
- Never lose a recording or create a duplicate transaction.
- Keep financial data on the device by default.

**Non-goals (v1)**

- No server backend, no user accounts, no bank or SMS integration, no multi-device sync, no receipt OCR.

**Success metrics (measured on a local test set of at least 200 Bangla/English utterances)**

- Amount extracted correctly: at least 97%.
- Transaction type correct: at least 95%.
- Category correct without user edit: at least 85% (rules plus LLM).
- Voice tap to saved transaction: under 6 seconds median when STT works.
- Zero data loss across app kill, reboot, and airplane mode tests.

## 2. Review of the original idea: issues and decisions

These are the decisions that change or tighten your original document. Please confirm or overrule them.

| # | Issue in original plan | Decision |
| --- | --- | --- |
| D1 | `record` and `speech_to_text` both need the microphone. On Android they generally cannot capture simultaneously, so record-then-run-local-STT on the same audio is not possible with `speech_to_text`. | Use an `SttEngine` abstraction. Mode A (default): live `speech_to_text` session, no audio file kept. Mode B (fallback): record audio with `record`, queue it, transcribe later with Groq Whisper. Never run both at once. |
| D2 | Bangla support in `speech_to_text` is device and OS dependent and on Android often uses the network anyway. | Treat on-device STT as best effort. Check locale `bn_BD` availability at startup. If unavailable, go straight to Mode B. Always allow manual text entry (typed sentence goes through the same parser). |
| D3 | 'No hardcoded API keys' conflicts with 'no backend' once Groq is called from the phone. A key inside the app can be extracted. | Phase 2 MUST choose one: (a) BYOK: user pastes their own Groq key, stored in Keychain/Keystore (fastest, fine for personal use); or (b) a tiny stateless proxy (Cloudflare Worker or Supabase Edge Function) that holds the key and rate-limits. Default for a public release: (b). |
| D4 | Money type unspecified. Floating point causes rounding errors. | Store money as integer minor units (`amount_minor`, 1 BDT = 100 poisha) plus an ISO currency code. Never use `double` for money. |
| D5 | Transfer, loans and refunds need to know where money moves from and to, and who the counterparty is. | Add an `accounts` table (Cash, bKash, Nagad, Bank, Card) with a default Cash account, and a `counterparty` text field for loans. Accounts UI is minimal in MVP. |
| D6 | One utterance may contain several transactions ('ভাত ১২০, রিকশা ৪০'). | Parser MUST return a list of drafts. Preview screen shows each draft as a card. |
| D7 | LLMs can hallucinate numbers. | Amount guard: any amount returned by the LLM MUST appear in the transcript (after Bangla number normalisation) or the draft is flagged for mandatory manual review. |
| D8 | Calendar dates: 'আজ', 'গতকাল' depend on the device clock and timezone. | Store `occurred_at` as UTC ISO timestamp plus `local_date` (Asia/Dhaka derived from device timezone at entry). Reports group by `local_date`. |
| D9 | Groq model names change. | Model IDs live in a remote-config-free constants file (`ai_models.dart`) and MUST be verified against Groq docs before Phase 2. Current intent: Llama 3.1 8B Instant for extraction, GPT-OSS 120B for insights, Whisper large-v3 (or turbo) for STT. |
| D10 | iOS background execution is not guaranteed. | Pending queue MUST also drain on app foreground and on connectivity change. WorkManager/BGTaskScheduler are opportunistic only. |

## 3. Functional requirements

### 3.1 Capture

| ID | Requirement | Phase |
| --- | --- | --- |
| FR-1 | Home screen has a large microphone button. Press to start, tap again to stop (also support press-and-hold). | 1 |
| FR-2 | Live transcription shown while speaking when Mode A is active. | 1 |
| FR-3 | Typed-sentence entry box using the same pipeline. | 1 |
| FR-4 | Manual form entry: type, amount, date, category, account, note. | 1 |
| FR-5 | Mode B: save audio file, create a `pending_recordings` row, show it in a Pending list with status and retry. | 2 |
| FR-6 | After parsing, show a Preview card per draft with editable fields and a confidence badge. Nothing is saved before the user taps Confirm. | 1 |
| FR-7 | Undo toast for 5 seconds after save; edit or delete later from the list. | 1 |

### 3.2 Transactions

| ID | Requirement | Phase |
| --- | --- | --- |
| FR-10 | Types: expense, income, transfer, refund, loan\_given, loan\_received, loan\_repayment. | 1 |
| FR-11 | Spending nature tags (multi-select): recurring, one\_time, essential, discretionary, emergency. Not categories. | 1 |
| FR-12 | Edit, soft-delete, restore. Edits keep an audit row. | 1 |
| FR-13 | Duplicate prevention (Section 12.3). | 1 |
| FR-14 | Search and filter by date range, type, category, account, text. | 1 |

### 3.3 Categories

| ID | Requirement | Phase |
| --- | --- | --- |
| FR-20 | Three-level hierarchy: Category > Subcategory > optional Item (item is a free-text tag, not a table row). | 1 |
| FR-21 | Seeded default tree (Section 9). User may rename, add, merge, archive. | 1 / 2 |
| FR-22 | Rule-based mapping from keywords to category (editable keyword table). | 1 |
| FR-23 | LLM may propose a new category only after a similarity check against existing ones fails (Section 9.3). Proposals require user approval. | 2 |
| FR-24 | When the user corrects a category, store the keyword-to-category mapping so the same input is right next time (local learning). | 1 |

### 3.4 Reports and analytics

| ID | Requirement | Phase |
| --- | --- | --- |
| FR-30 | Daily, weekly, monthly, yearly reports: totals for income, expense, net. | 1 (daily/weekly/monthly), 3 (yearly) |
| FR-31 | Category breakdown (donut + list), top categories, daily trend line, month-over-month comparison. | 1 / 3 |
| FR-32 | Recurring expense list (manual flag in 1, detection in 4). | 3 |
| FR-33 | Budgets per category per month with progress and 80%/100% local notifications. | 3 |
| FR-34 | AI insights and weekly/monthly summary text (Section 11.4). | 3 |
| FR-35 | CSV export of transactions (UTF-8 with BOM so Excel shows Bangla correctly). | 1 |
| FR-36 | Encrypted backup file export and import. | 2 |

All numbers in reports come from SQL and Dart code. The LLM only explains already-computed numbers.

### 3.5 Settings

Language of UI (Bangla/English), digit style (Bangla ০-৯ or Latin 0-9), default currency, default account, STT mode preference, cloud AI toggle with consent text, API key entry (if BYOK), backup, export, app lock (biometric, Phase 2).

## 4. Non-functional requirements

| ID | Requirement |
| --- | --- |
| NFR-1 | Offline-first: all of Phase 1 works in airplane mode. |
| NFR-2 | Cold start under 2 s on a mid-range Android phone (about 4 GB RAM). |
| NFR-3 | Rule parser under 50 ms per sentence; DB write under 100 ms. |
| NFR-4 | Report queries under 300 ms for 50,000 transactions (indexes in Section 8). |
| NFR-5 | No continuous background services, no wake locks, no polling. Network calls batched. |
| NFR-6 | Minimum OS: Android 8.0 (API 26), iOS 15. Android is the primary target; iOS parity for core flow. |
| NFR-7 | Accessibility: tap targets at least 48 dp, Bangla fonts render correctly (Noto Sans Bengali), screen reader labels. |
| NFR-8 | Privacy: no analytics SDK in v1. No financial data leaves the device unless cloud AI is enabled and consented. |
| NFR-9 | Test coverage: parser and money logic at least 90% line coverage; repository layer at least 80%. |
| NFR-10 | Crash-safe: every write is in a DB transaction; pending items survive process death. |

## 5. System architecture

### 5.1 Style

Single Flutter app, feature-first layered architecture (presentation, application, domain, data). Riverpod for state and dependency injection. Drift over SQLite for persistence. No backend in Phase 1.

```text
+-----------------------------------------------------------------+
|                         PRESENTATION                            |
|  Home(mic) | Preview | Transactions | Reports | Categories | Settings |
|        Riverpod Notifiers / AsyncNotifiers (UI state)          |
+--------------------------------+--------------------------------+
                                 |
+--------------------------------v--------------------------------+
|                         APPLICATION                             |
|  CaptureOrchestrator  ParseOrchestrator  ReportService         |
|  CategoryService  BudgetService  ExportService  QueueProcessor |
+--------------------------------+--------------------------------+
                                 |
+--------------------------------v--------------------------------+
|                            DOMAIN                               |
|  Entities: Transaction, Draft, Category, Account, Budget        |
|  Value objects: Money, LocalDate, Confidence                    |
|  Interfaces: SttEngine, ExpenseExtractor, TransactionRepository |
+---------+---------------------+-----------------+---------------+
          |                     |                 |
+---------v-------+  +----------v------+  +-------v---------------+
| DATA: Drift DAOs|  | PARSING ENGINE  |  | INTEGRATIONS          |
| SQLite          |  | (pure Dart)     |  | speech_to_text,record |
| Secure storage  |  | Normalizer,     |  | GroqClient (Phase 2)  |
|                 |  | Number,Date,    |  | WorkManager/BGTask    |
|                 |  | Type,Category   |  | share_plus, local_notif|
+-----------------+  +-----------------+  +-----------------------+
```

### 5.2 Rules the coding agent MUST follow

1. Domain and parsing code is pure Dart with no Flutter imports, so it is unit-testable without a device.
2. UI never touches Drift or HTTP directly; it calls application services through providers.
3. All external capabilities (STT, LLM, clock, connectivity) sit behind interfaces so tests can fake them.
4. Money is always the `Money` value object (int minor units + currency).
5. Time comes from an injectable `Clock`; never call `DateTime.now()` directly in logic.
6. Every user-visible string goes through localisation (ARB files, `bn` and `en`).
7. No network call may block saving a transaction.

### 5.3 Packages

`flutter_riverpod` (with `riverpod_generator`), `drift` + `drift_flutter` + `sqlite3_flutter_libs` (use SQLCipher variant if app-level DB encryption is chosen), `speech_to_text`, `record`, `permission_handler`, `dio`, `flutter_secure_storage`, `workmanager`, `connectivity_plus`, `flutter_local_notifications`, `intl`, `fl_chart`, `csv`, `share_plus`, `path_provider`, `crypto`, `cryptography` (AES-GCM for backups), `freezed` + `json_serializable`, `go_router`, `mocktail`. The agent MUST pin versions and verify current APIs on pub.dev before use.

## 6. Voice-to-transaction pipeline

### 6.1 Overall flow

```text
Mic tap
  -> check mic permission
  -> choose engine (SttEngine.pick())
       Mode A available?  -> live speech_to_text (bn_BD or en_US)
       else                -> Mode B record audio file
  -> Mode A result text  -> ParseOrchestrator
  -> Mode B file saved   -> pending_recordings (status=queued)
                              -> QueueProcessor when online -> Groq Whisper -> text
  -> ParseOrchestrator:
       1. Normalizer
       2. RuleParser -> drafts + confidence
       3. if confidence < threshold or flags -> LLM extractor (if enabled and online)
       4. else keep rule result
  -> Preview screen (user edits)
  -> Confirm -> TransactionRepository.save (dedup check) -> DB
```

### 6.2 Capture state machine

States: `idle`, `requestingPermission`, `listening`, `processing`, `preview`, `queued`, `error`.

| From | Event | To |
| --- | --- | --- |
| idle | mic tapped, permission ok | listening |
| idle | mic tapped, no permission | requestingPermission |
| listening | stop / silence 3 s / 60 s max | processing (A) or queued (B) |
| processing | drafts ready | preview |
| processing | STT returns empty | error (offer retry and typed entry) |
| preview | confirm | idle (saved, undo toast) |
| preview | discard | idle |
| queued | online and processed | notification: ready to review |

Recording limit 60 seconds. Audio format for Mode B: AAC/M4A or 16 kHz mono WAV/FLAC to keep Whisper uploads small. Audio files are deleted after successful transcription and user confirmation of the resulting draft (or after 7 days, configurable).

### 6.3 Confidence and routing

The rule parser outputs a confidence score 0 to 1 per draft. Suggested scoring (tunable constants):

| Signal | Effect |
| --- | --- |
| Exactly one amount found | +0.35 |
| Transaction type from explicit verb (কিনেছি, খরচ, পেয়েছি, বেতন, ধার দিয়েছি) | +0.25 |
| Category matched by keyword | +0.20 |
| Date resolved from explicit word or default today | +0.10 |
| Description non-empty | +0.10 |
| Multiple conflicting amounts or no amount | set to 0 (force LLM or manual) |

Routing: at least 0.80 use rules; 0.50 to 0.79 use rules, and if cloud AI is enabled and online, ask LLM to refine category only; below 0.50 use LLM full extraction when available, otherwise show a partially filled preview with the amount field highlighted.

## 7. Parsing engine specification (offline, pure Dart)

### 7.1 Normalizer

1. Unicode NFC, trim, collapse whitespace.
2. Convert Bangla digits ০১২৩৪৫৬৭৮৯ to 0-9.
3. Normalise punctuation, remove the danda, convert Bangla comma/decimal forms.
4. Lowercase Latin text. Keep original text for display.
5. Common STT fixes via a small replacement map (for example ‘টাকা’ variants: টাকা, ট্যাকা, tk, taka, BDT, ৳).

### 7.2 Number parser

MUST handle all of the following and return a `Decimal`/int:

| Input | Value |
| --- | --- |
| ৬৫০০০, 65,000, 65000 | 65000 |
| ৬৫ হাজার, 65 hajar, 65k | 65000 |
| দেড় হাজার | 1500 |
| আড়াই হাজার | 2500 |
| সাড়ে তিন হাজার | 3500 |
| সাড়ে ১২০০ / সাড়ে বারোশো | 1250 |
| এক লাখ, ১.৫ লাখ, দেড় লাখ | 100000, 150000, 150000 |
| দুই কোটি | 20000000 |
| পাঁচশো, পাঁচ শ, ৫০০ | 500 |
| একশো বিশ | 120 |
| Bangla number words 0 to 99 (এক ... নিরানব্বই), including variants (চব্বিশ/চব্বিস) | exact |
| Mixed Bangla/English: 'five hundred taka', '2 lakh' | exact |
| Decimals: ১২০.৫০, 120.50 | 120.50 |

Word tables for 0 to 99 are explicit lookups (Bangla number words are irregular). Multipliers: শ/শো/শত=100, হাজার=1000, লাখ/লক্ষ=100000, কোটি=10^7. Fractions: দেড=1.5, আড়াই=2.5, সাড়ে X = X + 0.5 (applied to the following multiplier or number).

Quantity vs amount: numbers followed by units like কেজি, লিটার, টি, জন, ঘণ্টা, ডজন, পিস are quantities, not money. The money amount is the number adjacent to টাকা/tk/৳, or if absent, the largest remaining number not attached to a unit. If two money candidates remain, lower confidence and prefer the LLM.

### 7.3 Date parser

Resolve relative to `Clock.now()` in the device timezone. Support: আজ/today, গতকাল/কাল (past context)/yesterday, পরশু (past context)/day before yesterday, N দিন আগে, গত সপ্তাহ, গত সোমবার etc., explicit dates like ১২ নভেম্বর, 12/11, 12 Nov, Bangla month names, and time-of-day words (সকালে, দুপুরে, রাতে) that only set the time component. Default: today. Future dates for an expense are flagged and require confirmation.

### 7.4 Transaction type classifier

Keyword lists (editable constants, Bangla and English), checked in this priority order:

1. loan\_repayment: ধার শোধ, ঋণ পরিশোধ, ফেরত দিয়েছি (when a loan context exists), repaid.
2. loan\_given: ধার দিয়েছি, ঋণ দিয়েছি, lent.
3. loan\_received: ধার নিয়েছি, ঋণ নিয়েছি, borrowed.
4. refund: রিফান্ড, ফেরত পেয়েছি, refund.
5. transfer: ট্রান্সফার, পাঠিয়েছি নিজের, ক্যাশ আউট, cash out, cash in, বিকাশ থেকে ... এ.
6. income: বেতন, পেয়েছি, আয়, ইনকাম, পেলাম, salary, received, বোনাস, বিক্রি করে পেয়েছি.
7. expense: কিনেছি, কিনলাম, খরচ, দিয়েছি, পরিশোধ, bill, ভাড়া, খেয়েছি, লেগেছে, paid, bought. This is also the default when an amount exists with no other cue.

Extract counterparty (a name following ‘কে’, ‘থেকে’, ‘from’, ‘to’) for loan types and store in `counterparty`.

### 7.5 Description and category

Description = the transcript with amount, currency word, date words and type verbs removed, then title-cased for Latin parts and trimmed. Keep brand and product tokens (Samsung ফোন stays). Category matching: tokenise, lemmatise lightly (strip common Bangla suffixes ে, র, টা, গুলো, কে), look up in `category_keywords` (user-learned rows win over seeded rows), pick the highest-weight match; ties go to the most specific subcategory. If nothing matches, category is `Uncategorized` and confidence is reduced.

### 7.6 Multi-transaction splitting

Split the sentence on conjunctions and separators (এবং, আর, আর ... , comma, ‘and’, ‘।’) only when each fragment contains its own money amount. Otherwise treat as one transaction. Each draft stores the source fragment.

### 7.7 Parser output contract (internal)

A `DraftTransaction` has: type, amountMinor, currency, description, categoryId or suggestedCategoryPath, subcategory, itemTag, localDate, occurredAtUtc, accountId, counterparty, spendingNature list, confidence, sourceText, sourceFragment, flags list (for example amountNotInTranscript, futureDate, ambiguousAmount, uncategorized), and `source` (rules, llm, manual).

## 8. Data model (continued in Part 2 below)

The full schema, AI layer, security model, UI flows, project structure, testing and the milestone plan follow in the next sections.

### 8.1 Conventions

- IDs: UUID v7 strings (sortable, safe for future sync). Never auto-increment integers as business keys.
- Money: `amount_minor` INTEGER (poisha) + `currency` TEXT (ISO 4217, default BDT). Always positive; direction is derived from `type`.
- Time: `occurred_at` UTC epoch milliseconds; `local_date` TEXT `YYYY-MM-DD` computed at entry from device timezone. `created_at`, `updated_at` UTC epoch ms.
- Soft delete: `deleted_at` nullable. Hard delete only from a Purge action.
- All tables carry `created_at` and `updated_at`.

### 8.2 Tables

```sql
accounts(
  id TEXT PK, name TEXT NOT NULL, kind TEXT NOT NULL,        -- cash|bkash|nagad|bank|card|other
  currency TEXT NOT NULL DEFAULT 'BDT', opening_balance_minor INTEGER NOT NULL DEFAULT 0,
  is_default INTEGER NOT NULL DEFAULT 0, archived_at INTEGER, created_at, updated_at)

categories(
  id TEXT PK, parent_id TEXT NULL REFERENCES categories(id),
  name_bn TEXT, name_en TEXT NOT NULL, kind TEXT NOT NULL,   -- expense|income|both
  icon TEXT, color TEXT, is_system INTEGER NOT NULL DEFAULT 0,
  archived_at INTEGER, sort_order INTEGER DEFAULT 0, created_at, updated_at,
  UNIQUE(parent_id, name_en))

category_keywords(
  id TEXT PK, category_id TEXT NOT NULL REFERENCES categories(id),
  keyword TEXT NOT NULL,                                     -- normalized token
  weight REAL NOT NULL DEFAULT 1.0, source TEXT NOT NULL,    -- seed|user|llm
  hits INTEGER NOT NULL DEFAULT 0, created_at, updated_at,
  UNIQUE(keyword, category_id))

transactions(
  id TEXT PK, type TEXT NOT NULL,
  amount_minor INTEGER NOT NULL CHECK(amount_minor > 0), currency TEXT NOT NULL DEFAULT 'BDT',
  description TEXT NOT NULL DEFAULT '', item_tag TEXT,
  category_id TEXT REFERENCES categories(id),                -- leaf or parent; subcategory is a category row
  account_id TEXT NOT NULL REFERENCES accounts(id),
  to_account_id TEXT REFERENCES accounts(id),                -- transfers only
  counterparty TEXT,                                         -- loans
  occurred_at INTEGER NOT NULL, local_date TEXT NOT NULL,
  source TEXT NOT NULL,                                      -- voice|text|manual|import
  parse_method TEXT,                                         -- rules|llm|manual
  confidence REAL, source_text TEXT,
  dedup_hash TEXT NOT NULL,
  recording_id TEXT REFERENCES pending_recordings(id),
  deleted_at INTEGER, created_at, updated_at)

transaction_tags(                                            -- spending nature
  transaction_id TEXT REFERENCES transactions(id) ON DELETE CASCADE,
  tag TEXT NOT NULL,                                         -- recurring|one_time|essential|discretionary|emergency
  PRIMARY KEY(transaction_id, tag))

transaction_audit(
  id TEXT PK, transaction_id TEXT NOT NULL, action TEXT NOT NULL,   -- create|update|delete|restore
  before_json TEXT, after_json TEXT, at INTEGER NOT NULL)

pending_recordings(
  id TEXT PK, kind TEXT NOT NULL,                            -- audio|text
  file_path TEXT, duration_ms INTEGER, locale TEXT,
  status TEXT NOT NULL,                                      -- queued|uploading|transcribed|parsed|failed|done
  attempts INTEGER NOT NULL DEFAULT 0, next_attempt_at INTEGER,
  last_error TEXT, transcript TEXT, draft_json TEXT,
  created_at, updated_at)

budgets(
  id TEXT PK, category_id TEXT REFERENCES categories(id),    -- NULL = overall
  period TEXT NOT NULL DEFAULT 'monthly', amount_minor INTEGER NOT NULL,
  currency TEXT NOT NULL DEFAULT 'BDT', starts_on TEXT NOT NULL, ends_on TEXT,
  created_at, updated_at)

app_settings(key TEXT PK, value TEXT NOT NULL, updated_at)

ai_usage_log(                                                -- no financial content stored
  id TEXT PK, provider TEXT, model TEXT, purpose TEXT,       -- stt|extract|refine|insight
  tokens_in INTEGER, tokens_out INTEGER, latency_ms INTEGER, ok INTEGER, at INTEGER)
```

### 8.3 Indexes

- `transactions(local_date)` and `transactions(deleted_at, local_date)`
- `transactions(category_id, local_date)`
- `transactions(account_id, local_date)`
- `transactions(dedup_hash)` (non-unique; see Section 12.3)
- `category_keywords(keyword)`
- `pending_recordings(status, next_attempt_at)`
- Optional FTS5 virtual table over `transactions.description` for search.

### 8.4 Migrations and seeds

Drift schema versioning from day one with `schemaVersion` and migration tests (`drift_dev schema` export and verify). Seed data (default accounts, categories, keywords) is inserted by an idempotent `SeedService` keyed by `is_system` rows and a `seed_version` setting, so new seed versions can add rows without duplicating.

## 9. Category system

### 9.1 Hierarchy

Category (level 1) > Subcategory (level 2, a `categories` row with `parent_id`) > Item (level 3, free text in `item_tag`, for example Samsung). Hierarchy depth is capped at 2 in the table to keep reports simple. A transaction stores the most specific category row.

### 9.2 Seed tree (editable defaults)

| Category | Subcategories |
| --- | --- |
| Food & Dining (খাবার) | Breakfast, Lunch, Dinner, Groceries (বাজার), Snacks & Tea, Restaurants, Delivery |
| Transport (যাতায়াত) | Rickshaw, CNG/Auto, Bus, Ride-share, Fuel, Vehicle Maintenance, Train/Launch |
| Housing (বাসা) | Rent, Utilities (Electricity, Gas, Water), Internet, Maintenance |
| Mobile & Internet | Mobile Recharge, Data Pack |
| Shopping (কেনাকাটা) | Electronics (Mobile Phone, Laptop, Accessories), Clothing, Home Items, Cosmetics |
| Health (স্বাস্থ্য) | Medicine, Doctor, Tests, Insurance |
| Education (শিক্ষা) | Tuition, Books, Online Courses, Exam Fees |
| Family & Social | Gifts, Donations/Zakat, Events, Childcare |
| Entertainment | Movies, Subscriptions, Games, Travel & Holiday |
| Bills & Fees | Bank Charges, Government Fees, Mobile Banking Charges |
| Personal Care | Salon, Gym |
| Debt & Loans | Loan Given, Loan Received, Repayment (system, used by loan types) |
| Income (kind=income) | Salary, Business, Freelance, Gift, Interest, Other Income |
| Uncategorized | (system fallback, cannot be deleted) |

Seed keyword list (Bangla, Bangla-transliterated, English) of at least 300 entries MUST be generated as a data file (`assets/seed/category_keywords.json`) and reviewed by the product owner. Examples: ভাত, বিরিয়ানি, চা, lunch -> Food; রিকশা, সিএনজি, uber, pathao -> Transport; বিদ্যুৎ, গ্যাস, বাসা ভাড়া -> Housing; ফোন, Samsung, laptop -> Electronics; ওষুধ -> Medicine; বই, কোর্স -> Education; রিচার্জ -> Mobile Recharge.

### 9.3 Preventing duplicate categories (for AI proposals)

When the LLM proposes a category path not in the tree, the app MUST:

1. Normalise the proposed name (lowercase, strip spaces/punctuation, transliterate common Bangla to Latin where a map exists).
2. Compare against all non-archived category names (en and bn) using exact match, then Levenshtein ratio at least 0.85, then token-set overlap at least 0.6.
3. If any match: use the existing category and silently add the proposed name as a keyword.
4. If none: show 'New category suggested: X under Y' in Preview; the user can accept (creates row, source=llm keyword) or pick another.
5. Never auto-create categories without user acceptance.

The LLM is also given the current category tree (names only) in the prompt so it prefers existing ones.

## 10. Reports and analytics

### 10.1 Accounting rules (single source of truth)

| Type | Counts as expense in reports | Counts as income in reports | Account effect |
| --- | --- | --- | --- |
| expense | Yes | No | account balance decreases |
| income | No | Yes | account balance increases |
| refund | Reduces the original category's expense (net) | No | balance increases |
| transfer | No | No | from decreases, to increases |
| loan\_given | No (shown as Loans receivable) | No | balance decreases |
| loan\_received | No | No (shown as Loans payable) | balance increases |
| loan\_repayment | No (principal); interest is a separate expense | No | balance changes by direction of the loan |

Loan repayment direction is resolved by the counterparty's open loan: if you owe them, repayment decreases balance; if they owe you, it increases. If ambiguous, Preview asks the user.

### 10.2 Report definitions

- **Period:** day, ISO week (week starts Saturday by default for Bangladesh, configurable), calendar month, calendar year. All periods use `local_date`.
- **Totals:** income, expense (net of refunds), net = income - expense, transaction count, average daily expense.
- **Category breakdown:** sum by category, rolled up to parent, percentage of total expense.
- **Trend:** per-day totals for the period, 7-day moving average.
- **MoM comparison:** this month to date vs the same day-span of the previous month, per category, absolute and percent change; percentage is null when the previous value is zero.
- **Top N:** highest categories and highest single transactions.
- **Budget status:** spent / limit, remaining, projected month-end spend = spent / elapsed\_days \* days\_in\_month (labelled as an estimate).
- **Recurring analysis (Phase 3):** manually flagged recurring items now; auto-detection in Phase 4 (same normalised description, similar amount within 10%, roughly regular interval).

### 10.3 Example query (category breakdown for a month)

```sql
SELECT COALESCE(p.id, c.id) AS cat_id, COALESCE(p.name_en, c.name_en) AS cat_name,
       SUM(CASE WHEN t.type='expense' THEN t.amount_minor
                WHEN t.type='refund'  THEN -t.amount_minor ELSE 0 END) AS spent_minor
FROM transactions t
JOIN categories c ON c.id = t.category_id
LEFT JOIN categories p ON p.id = c.parent_id
WHERE t.deleted_at IS NULL AND t.local_date BETWEEN :from AND :to
  AND t.type IN ('expense','refund')
GROUP BY cat_id ORDER BY spent_minor DESC;
```

Report logic lives in `ReportRepository` with Drift queries; widget code only renders view models.

## 11. AI layer (Phase 2 and 3)

### 11.1 Interfaces

```dart
abstract class SttEngine { Future<SttResult> transcribe(AudioSource src); }       // live, file
abstract class ExpenseExtractor { Future<List<DraftTransaction>> extract(ExtractRequest r); }
abstract class InsightGenerator { Future<InsightBundle> generate(InsightInput i); }
```

Implementations: `DeviceSttEngine`, `GroqWhisperEngine`, `RuleExtractor`, `GroqLlmExtractor`, `GroqInsightGenerator`. A `FakeExtractor` is used in tests. Provider choice and base URL come from `AiConfig`; the proxy URL replaces the Groq URL when decision D3(b) is used.

### 11.2 Extraction prompt contract

System prompt rules: you extract financial transactions from a Bangla or English sentence; output JSON only; never invent amounts; amounts are plain numbers in BDT unless a currency is stated; choose category only from the provided list, otherwise return `new_category` with parent; dates are relative to the provided `today`; if unsure return null fields instead of guessing.

Input sent to the model (data minimisation): the transcript text, `today` (date only), timezone, and the list of category names. Never send account names, balances, history, device identifiers or other transactions.

Output JSON schema (array `transactions`, each item):

| Field | Type | Notes |
| --- | --- | --- |
| type | enum | one of the 7 types |
| amount | number or null | in major units; validated against transcript |
| currency | string | ISO code, default BDT |
| description | string | short, keep brand names |
| category | string or null | existing leaf name |
| subcategory | string or null |  |
| new\_category | object or null | name\_en, name\_bn, parent |
| date\_offset\_days | integer or null | 0 = today, -1 = yesterday; avoids model date arithmetic errors |
| counterparty | string or null |  |
| spending\_nature | array of enum | optional |
| confidence | number 0-1 |  |

Client MUST: use JSON mode or tool/schema-constrained output if the model supports it; parse defensively; reject non-conforming output; retry once with a repair prompt; then fall back to the rule result or manual form. Temperature 0 to 0.2. Max tokens about 600. Timeout 8 s (extraction) and 20 s (Whisper upload).

### 11.3 Guardrails

1. Amount guard (D7): after normalisation, the model's amount must equal a number found in the transcript (or a sum/product the rule number parser can reproduce). Otherwise set flag amountNotInTranscript and require manual confirmation.
2. Category must exist or be a user-approved proposal.
3. Date offset must be between -400 and +1; anything else is flagged.
4. Never auto-save an LLM result; Preview is always required (this is also true for rules in v1).
5. Log only metadata in `ai_usage_log`, not transcripts.

### 11.4 Insights (Phase 3)

Pipeline: (1) `InsightFacts` are computed in SQL/Dart (top categories, MoM deltas, budget status, largest transactions, recurring list, days over daily average). (2) A compact JSON of aggregated facts (no descriptions, no counterparty names) is sent to the advanced model. (3) The model returns short Bangla or English text: headline, 3 to 5 observations, 2 to 3 saving suggestions, each tied to a fact ID. (4) The client verifies that every number in the text matches a number in the facts; mismatching sentences are dropped. (5) Results are cached per period in a local table and regenerated at most once per day per period.

Tone rules: factual, non-judgemental; never label spending as waste without supporting data (for example 'Food delivery rose 42% over last month, 3 orders above 800 BDT'); suggestions must be realistic and reference the user's own numbers; no financial products or investment advice; include a footer that these are automated suggestions.

### 11.5 Cost and rate controls

Rule parser first (free). LLM extraction only for low confidence or when the user taps 'Improve with AI'. Whisper only for queued audio. Insights at most daily per period, and only on explicit open or weekly schedule. Client-side limits: at most 60 LLM calls per day and 30 Whisper calls per day (configurable). Handle HTTP 429 with exponential backoff and `Retry-After`.

## 12. Reliability

### 12.1 Pending queue

`QueueProcessor.drain()` runs on: app foreground, connectivity regained, after a new item is queued while online, and (opportunistically) via WorkManager/BGTaskScheduler. It processes items by `next_attempt_at`, one at a time, with these transitions: queued -> uploading -> transcribed -> parsed -> done, or failed after 5 attempts with exponential backoff (1 min, 5 min, 30 min, 2 h, 12 h). A transcribed item becomes a Review notification and appears in the Pending tab; transactions from queued audio are never auto-saved. A single in-process mutex prevents concurrent drains. Items survive app kill because state is in SQLite.

### 12.2 Failure handling

| Failure | Behaviour |
| --- | --- |
| Mic permission denied | Explain, deep link to settings, offer typed entry |
| STT returns empty/garbage | Show transcript for editing, offer retry or typed entry |
| Locale not available | Auto Mode B, tell the user once |
| Network timeout | Keep item queued, backoff, no user error unless they open it |
| LLM invalid JSON | One repair retry, then rules result or manual form |
| DB write fails | Keep Preview open, show error, do not discard draft |
| Disk full | Warn; block new audio recording |

### 12.3 Duplicate prevention

`dedup_hash = sha256(type | amount_minor | local_date | normalised description | account_id)`. On save, query for a non-deleted transaction with the same hash created within the last 10 minutes or the same `recording_id`. If found, show 'Looks like a duplicate' with Save anyway / Cancel. The same recording can never produce two saved transactions (unique `recording_id` + draft index). Imports from CSV use the same hash for skip-duplicates.

### 12.4 Backup and export

- CSV: columns date, type, amount, currency, category, subcategory, description, account, counterparty, tags, id. UTF-8 with BOM.
- Encrypted backup (Phase 2): JSON or SQLite snapshot, gzip, encrypted with AES-256-GCM; key derived from a user passphrase with Argon2id or PBKDF2-HMAC-SHA256 (at least 210,000 iterations if PBKDF2). File header holds version, salt, nonce. Restore validates version and authentication tag before replacing data, and offers merge or replace.

## 13. Security and privacy

1. **Data at rest:** SQLite in app-private storage. Phase 2 SHOULD move to SQLCipher with a random key stored in Keystore/Keychain. Exclude DB and audio from OS cloud backup unless the user opts in (Android `allowBackup=false` for the DB path; iOS `isExcludedFromBackup`).
2. **Secrets:** no keys in source or assets. BYOK keys in `flutter_secure_storage`. Proxy mode uses a short-lived signed token or an app attestation check (Play Integrity / App Attest) before the proxy forwards calls.
3. **Network:** HTTPS only, TLS validation default, optional certificate pinning for the proxy. No logging of request bodies.
4. **Consent:** first time cloud AI is enabled, a screen explains exactly what is sent (transcript text or audio, category names, today's date) and what is not (balances, accounts, history). Cloud features are off by default and can be revoked; revoking clears the queue's cloud steps.
5. **Data minimisation:** see 11.2 and 11.4. Redact long digit sequences (phone, account numbers) from transcripts before cloud calls.
6. **App lock (Phase 2):** optional biometric/PIN via `local_auth` on launch and resume after 60 s.
7. **Screens:** hide amounts in the app switcher snapshot (Android FLAG\_SECURE optional setting).
8. **Logging:** debug logs strip financial content; no analytics SDK.
9. **Audio retention:** delete after confirmed transcription (see 6.2).

## 14. UI screens and flows

Navigation: bottom bar with Home, Transactions, Reports, Settings. Pending items appear as a badge on Home.

| Screen | Contents |
| --- | --- |
| Home | Today's total, month-to-date summary card, last 5 transactions, big mic button, keyboard icon for typed entry, Pending badge |
| Capture overlay | Pulsing mic, live transcript, cancel, stop |
| Preview | One card per draft: type chips, amount (large, editable), description, category picker (search + recent), date, account, nature tags, confidence badge, flags in orange, Confirm all / Discard |
| Transactions | Grouped by day, filters, search, swipe to delete/edit, undo |
| Transaction detail/edit | All fields, original transcript, audit history |
| Reports | Segmented Day / Week / Month / Year, totals, donut, trend, top categories, MoM, budget bars |
| Insights (Phase 3) | Weekly and monthly AI summary cards with data citations |
| Categories | Tree view, add/rename/merge/archive, keywords per category |
| Accounts | List, add, set default, balances |
| Budgets (Phase 3) | Per category monthly limits |
| Pending | Queued/failed items, retry, delete, review ready |
| Settings | Language, digits, currency, week start, STT mode, cloud AI + consent, API key, backup/restore, CSV export, app lock, about |

UX rules: first launch onboarding in 3 screens (what you can say, mic permission, default account); example prompts shown on empty Home ('আজ ১২০ টাকা ভাত খেয়েছি'); Bangla is the default UI language when the device language is Bangla; every error has a recovery action; all long operations show progress.

## 15. Project structure

```text
lib/
  main.dart
  app/                    # router, theme, l10n, providers bootstrap
  core/
    money/                # Money value object
    time/                 # Clock, local date helpers
    result/               # Result/Failure types
    utils/
  domain/
    entities/             # Transaction, Draft, Category, Account, Budget
    repositories/         # abstract interfaces
    services/             # interfaces: SttEngine, ExpenseExtractor, InsightGenerator
  parsing/                # PURE DART
    normalizer.dart
    bangla_numbers.dart
    amount_parser.dart
    date_parser.dart
    type_classifier.dart
    category_matcher.dart
    splitter.dart
    rule_parser.dart
  data/
    db/                   # Drift tables, DAOs, migrations, seeds
    repositories/         # implementations
    secure/               # secure storage wrapper
  integrations/
    stt/                  # device_stt_engine, groq_whisper_engine, recorder
    ai/                   # groq_client, prompts, schemas, guardrails
    background/           # workmanager dispatcher, queue_processor
    notifications/
  features/
    capture/ preview/ transactions/ reports/ categories/
    accounts/ budgets/ insights/ pending/ settings/ onboarding/
      (each: presentation/ + application/)
test/
  parsing/ (golden files)  domain/  data/  integration/  widget/
assets/seed/              # categories.json, category_keywords.json, golden_utterances.json
docs/                     # this spec, ADRs, AGENTS.md
```

## 16. Testing strategy

| Layer | Approach |
| --- | --- |
| Parsing | Table-driven unit tests from `golden_utterances.json`: transcript -> expected drafts. Start with 150 cases for MVP, grow to 300+. Include STT-style noise, mixed Bangla/English, multi-transaction, fractions (সাড়ে, দেড়), dates. Parser changes MUST NOT lower the pass rate. |
| Money | Property tests: no rounding drift; parse -> format -> parse is stable. |
| Database | In-memory Drift; migration tests between all schema versions; report query tests with fixed datasets. |
| Repositories | Duplicate detection, soft delete, audit rows, account balance rules. |
| Orchestrators | Fake SttEngine, fake extractor, fake Clock, fake connectivity; test queue state machine and backoff. |
| AI layer | Recorded JSON fixtures; schema validation, amount guard, repair retry. No live API calls in CI. |
| Widgets | Golden screenshots for Home, Preview, Reports in Bangla and English. |
| Integration | `integration_test` for record -> preview -> save with a faked STT; airplane-mode flow; kill-app mid-queue. |
| Manual device matrix | Low-end Android 8/9, mid Android 13, Pixel latest, iPhone SE class; Bangla locale on/off; with and without Google speech services. |

CI: format, analyze (strict lints), unit and widget tests, coverage gate (NFR-9), build debug APK.

## 17. Milestone plan (build order for the coding agent)

Each milestone ends with a green build, passing tests, and the listed acceptance criteria.

### M0: Project foundation (1 to 2 days)

- Flutter project, folder structure, lints, Riverpod, go\_router, theme, l10n (bn/en), CI.
- `Money`, `Clock`, `Result`.
- AC: app launches to an empty shell in Bangla and English; `flutter analyze` clean; CI green.

### M1: Database and domain (3 to 4 days)

- Drift schema (Section 8), migrations, seeds, DAOs, repositories, audit and dedup logic.
- AC: repository tests pass; seed idempotent; 10,000-row report query under 300 ms in a benchmark test.

### M2: Parsing engine (5 to 7 days)

- Normalizer, Bangla number parser, date parser, type classifier, category matcher, splitter, confidence scoring.
- AC: at least 97% amount accuracy and 90% category accuracy on the golden set; every row in the 7.2 table passes; under 50 ms per sentence.

### M3: Manual entry, Transactions and Preview (4 to 5 days)

- Manual form, typed sentence entry through the parser, Preview screen, save with undo, edit/delete, list with filters.
- AC: a typed Bangla sentence yields correct Preview and saved row; duplicate warning works; fully offline.

### M4: Voice capture (3 to 4 days)

- Permissions, `DeviceSttEngine` (Mode A), capture state machine, live transcript, locale detection, graceful fallbacks to typed entry.
- AC: on a real Android device with Bangla enabled, spoken sentence reaches Preview; permission-denied and empty-result paths covered by tests.

### M5: Reports and CSV export (4 to 5 days)

- Daily/weekly/monthly reports, category breakdown, trend, accounting rules from 10.1, CSV export.
- AC: report totals match a SQL oracle on a seeded dataset; CSV opens correctly in Excel with Bangla text.

### M6 (end of Phase 1): Hardening (3 to 4 days)

- Onboarding, settings, accessibility, performance pass, device-matrix testing, bug fixes.
- AC: all NFR checks for Phase 1 pass; 24-hour manual dogfood with no data loss.

### Phase 2

- **M7:** Mode B recording, `pending_recordings`, QueueProcessor, background tasks, Pending screen.
- **M8:** Groq client (via BYOK or proxy per D3), Whisper engine, LLM extractor, guardrails, consent screen, usage limits.
- **M9:** Category management UI, AI category proposals with duplicate check, keyword learning, encrypted backup/restore, SQLCipher, app lock.

### Phase 3

- **M10:** Yearly reports, MoM, budgets and local notifications.
- **M11:** Insight facts engine, insight generation with number verification, summaries.
- **M12:** Multi-currency (stored per transaction with a manual rate table; no automatic FX in v1), optional Supabase sync design (separate ADR before any code).

### Phase 4

Subscription detection, asset register, advanced budgeting, multi-device. Each needs its own spec addendum.

## 18. Working rules for the coding agent (put in AGENTS.md)

1. Read this spec section for the current milestone before coding; list assumptions in the PR description.
2. Write tests first for parsing and money logic.
3. Do not add packages outside Section 5.3 without writing a short ADR in `docs/adr/`.
4. Verify package APIs and Groq model IDs against current documentation; do not rely on memory.
5. Keep functions small, no business logic in widgets, no `double` for money, no `DateTime.now()` outside `Clock`.
6. Any change to schema requires a migration plus migration test.
7. Never log transcripts or amounts in release builds.
8. If a requirement is ambiguous or conflicts with another, stop and ask instead of guessing.
9. Definition of done: analyzer clean, tests green, acceptance criteria met, docs updated.

## 19. Key risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Bangla STT quality and availability vary by device | High | Typed entry always available, Whisper fallback, editable Preview, STT noise cases in golden tests |
| Parser errors on informal speech | Medium | Confidence routing, LLM fallback, mandatory Preview, user-correction learning |
| API key abuse if shipped in app | High | Proxy or BYOK (D3) |
| iOS background limits | Medium | Foreground and connectivity triggers, no promises of background sync |
| Scope creep into AI features before the offline MVP is solid | High | Strict milestone gates; Phase 2 starts only after M6 acceptance |
| Loan and transfer semantics confuse users | Medium | Clear Preview wording, accounts default to Cash, ask when ambiguous |

## 20. Open questions for the product owner

1. App name, package ID and target stores (Play Store only, or iOS too)?
2. Is Android the primary target for the first release, with iOS as a later port?
3. For Phase 2: do you prefer BYOK (user enters own Groq key) or a small proxy you host?
4. Should the default UI language be Bangla, English, or follow the device?
5. Should week start on Saturday (Bangladesh convention) by default?
6. Do you need bKash/Nagad-style accounts in the MVP, or just a single Cash wallet?
7. Any monetisation plan (free, one-time, subscription)? This affects the proxy and privacy design.
8. Do you want a brand/visual direction (colors, tone) before the UI milestone?
