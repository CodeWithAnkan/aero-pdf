# AeroPDF

> A lightweight, offline-first PDF reader for Android with on-device AI — zero cloud dependency, zero data collection.

---

## Overview

AeroPDF is a production-grade Flutter application built around a single guiding principle: **your documents never leave your device**. It combines high-fidelity PDF rendering, full-text search, annotation tools, and on-device AI summarization into a clean, Notion-inspired UI — all without ever touching a server.

---

## Screenshots & Features at a Glance

| Feature | Details |
|---|---|
| **PDF Rendering** | Syncfusion SfPdfViewer — native text selection, smooth scroll, pinch-zoom |
| **AI Insights** | Gemini Nano (AICore) on supported devices; TF-IDF extractive fallback everywhere else |
| **OCR** | Google ML Kit Text Recognition v2 — on-device, zero APK bloat |
| **Full-Text Search** | Isar FTS across all books simultaneously |
| **Annotations** | Highlight, underline, sticky notes — saved directly into the PDF file |
| **Progress Sync** | Per-book read position persisted across sessions |
| **Dark Mode & Typography** | 4 Google Font families, full light/dark theming via Riverpod |

---

## Architecture

AeroPDF follows a **feature-first layered architecture** with a clean separation between data, domain, and presentation concerns.

```
lib/
├── app/
│   └── router.dart              # GoRouter config + Android intent interception
├── core/
│   ├── db/
│   │   └── isar_service.dart    # Singleton Isar database handle
│   ├── models/                  # Isar collection schemas
│   │   ├── book.dart / book.g.dart
│   │   ├── annotation.dart / annotation.g.dart
│   │   ├── search_index.dart / search_index.g.dart
│   │   └── ocr_cache.dart / ocr_cache.g.dart
│   ├── pdf/
│   │   ├── pdf_service.dart     # Document open, title extraction, re-linking
│   │   ├── hash_service.dart    # SHA-256 file identity
│   │   ├── indexing_isolate.dart # Background FTS indexing (Dart Isolate)
│   │   └── ocr_detector.dart    # Scanned-page heuristic
│   ├── permissions/
│   │   └── permission_handler.dart # Android 13+ SAF-aware permission logic
│   └── theme/
│       ├── app_theme.dart       # Light/dark ColorScheme definitions
│       └── theme_provider.dart  # Riverpod Notifier + SharedPreferences
├── features/
│   ├── ai/
│   │   ├── ai_engine.dart       # AiEngine abstract interface + factory
│   │   ├── ai_provider.dart     # FutureProvider<AiEngine>, InsightsNotifier
│   │   ├── extractive_engine.dart # TF-IDF engine (runs in Dart Isolate)
│   │   └── insights_panel.dart  # DraggableScrollableSheet UI
│   ├── annotations/
│   │   ├── annotation_layer.dart # CustomPainter overlay (normalised coords)
│   │   └── annotation_provider.dart # StateNotifier CRUD
│   ├── library/
│   │   ├── library_screen.dart  # Workspace home, jump-back-in carousel
│   │   ├── library_provider.dart # Book CRUD, import pipeline, rename
│   │   ├── book_card.dart       # BookListTile, PdfThumbnail (JPEG cache)
│   │   ├── folder_screen.dart   # Per-folder document list
│   │   └── import_intent_screen.dart # Android share-sheet / file-intent handler
│   ├── navigation/
│   │   └── main_screen.dart     # IndexedStack bottom-nav shell
│   ├── ocr/
│   │   ├── ocr_service.dart     # ML Kit wrapper, normalised OcrBlock
│   │   └── ocr_controller.dart  # StateNotifier, cache-check → process → store
│   ├── reader/
│   │   ├── reader_screen.dart   # Main reading experience
│   │   ├── gesture_handler.dart # Tap / double-tap / long-press coordination
│   │   ├── ocr_selection_layer.dart # Transparent hit-test overlay for OCR blocks
│   │   ├── scroll_engine.dart   # ScrollController wrapper (page tracking)
│   │   └── texture_cache.dart   # Legacy placeholder
│   ├── search/
│   │   ├── search_provider.dart # Global FTS via Isar, grouped by book
│   │   └── search_screen.dart   # Search UI with book-grouped results
│   └── settings/
│       └── settings_screen.dart # Appearance, reading, storage, legal
└── main.dart                    # App entry point, Isar warm-up, ProviderScope
```

---

## Data Layer

### Isar Database (NoSQL, embedded)

AeroPDF uses **Isar 3** — a high-performance embedded database that runs natively without a JVM or SQLite bridge. All four collections are opened once and reused via a singleton.

| Collection | Key Fields | Purpose |
|---|---|---|
| `Book` | `fileHash (idx)`, `lastOpened (idx)` | Library metadata, read progress |
| `Annotation` | `bookId (idx)`, `pageNumber (idx)` | Highlights, underlines, notes |
| `SearchIndex` | `pageText (hash idx)` | FTS corpus, one row per page |
| `OcrCache` | `bookId (idx)`, `pageNumber (idx)` | Cached OCR blocks (JSON) |

**File identity** is based on a **SHA-256 hash** of the PDF bytes, not the file path. This means annotations and read progress survive file renames or moves — the `PdfService.relinkBook()` method finds the existing entry by hash and updates only the path.

### Storage Strategy

- PDFs are **copied** into `Documents/AeroPDF/` on first import (permanent path, not a temp cache).
- Thumbnail images are kept in a **`Map<int, MemoryImage>`** in-memory cache, keyed by `bookId`.
- Read position is **dual-persisted**: `SharedPreferences` (fast, survives cold start) and the Isar `Book` record (authoritative).

---

## AI Pipeline

The AI layer is built around a **strategy pattern** behind the `AiEngine` abstract interface, allowing the runtime to swap engines without any UI changes.

```
buildAiEngine()  →  AiCoreEngine (Gemini Nano)
                 └→  LocalExtractiveEngine (TF-IDF fallback)
```

### Engine 1 — Gemini Nano via AICore

- Uses the `gemini_nano_android` package to call the **Android AICore** system service.
- Available on select Android 14+ devices (Pixel 9+, Galaxy S25+, OnePlus 15).
- Context window is capped at ~2 000 chars (page) / ~3 000 chars (chapter) to fit Nano's constraints.
- On any failure, automatically falls back to the extractive engine.

### Engine 2 — LocalExtractiveEngine (TF-IDF)

A zero-dependency, pure-Dart extractive summarizer that runs inside a **Dart `Isolate`** to keep the UI thread free.

**Scoring pipeline per sentence:**

| Signal | Weight | Notes |
|---|---|---|
| TF-IDF | Variable | Term frequency × inverse document frequency across all pages |
| Positional | 0.0–0.40 | First sentence boosted, last sentence slight bonus |
| Cross-page recurrence | 0.0–0.35 | Terms appearing on ≥3 pages are concept terms |
| Length | −0.50–+0.10 | Penalises very short (<6 words) or very long (>50 words) sentences |
| Numeric bonus | +0.08 | Sentences with figures tend to be informative |
| Redundancy penalty | −0.40 | Jaccard overlap with already-selected sentences |

The IDF table and cross-page recurrence map are built **once at engine construction** from the full document corpus, then reused for every page/chapter query.

---

## Indexing Pipeline

Background indexing runs entirely in a **`Dart Isolate`** via `indexBookInBackground()`, keeping the main thread free during initial import.

```
File bytes
  └→ PdfDocument (Syncfusion)
       └→ PdfTextExtractor.extractTextLines()
            └→ word.text.join(' ')   ← fixes squished-word bug in absolute-positioned PDFs
                 └→ isPageTextScanned() heuristic (< 30 chars → likely scanned)
                      └→ SearchIndex rows (batch put)
                           └→ Book.isIndexed = true, Book.scannedPageCount updated
```

Scanned pages are flagged with `isOcr = true` in the `SearchIndex`. When the reader navigates to a flagged page, `OcrController` picks it up, renders the page at 2× resolution via `pdfx`, runs ML Kit OCR, and updates the index entry in-place.

---

## OCR System

```
Page render (pdfx, 2× resolution, JPEG)
  └→ OcrService.recognizeImage()
       └→ InputImage (BGRA8888 metadata)
            └→ ML Kit TextRecognizer (Latin script)
                 └→ OcrBlock[] with normalised Rect (0.0–1.0)
                      ├→ OcrCache.blocksJson (persisted)
                      └→ SearchIndex.pageText (updated for FTS)
```

All bounding boxes are stored **normalised to 0.0–1.0** relative to page dimensions. This makes them resolution-independent — the same coordinates render correctly at any zoom level or screen size.

---

## Annotation System

Annotations are stored in Isar with **normalised quad points** `[left, top, right, bottom]` in 0.0–1.0 space. At render time, `AnnotationLayer` (a `CustomPainter`) scales them to the actual page pixel size.

Supported types:

- **Highlight** — semi-transparent filled rect (default yellow, `opacity: 0.35`)
- **Underline** — 1.5px stroke along the bottom edge of the selection rect
- **Note** — 6px filled circle at the top-right corner of the selection, acts as a pin

Annotations can also be **baked into the PDF file** via `PdfViewerController.saveDocument()`, which overwrites the original file in `Documents/AeroPDF/`. This means annotations are portable — the annotated PDF can be shared to other readers.

---

## Navigation & Routing

**GoRouter** handles all navigation. A `redirect` guard inspects every incoming URI before routing:

```dart
redirect: (context, state) {
  final uri = state.uri.toString();
  if (uri.startsWith('content://') || uri.startsWith('file://')) {
    return '/import?uri=${Uri.encodeComponent(uri)}';
  }
  return null;
}
```

This intercepts Android file-share intents (from WhatsApp, Files app, email attachments, etc.) and routes them to `ImportIntentScreen` before GoRouter can crash on an unrecognised scheme. The `uri_to_file` package resolves the `content://` authority to a readable temp file, which is then passed through the normal `_addPdf()` pipeline.

**Route map:**

| Path | Screen |
|---|---|
| `/` | `MainScreen` (Library + Search + Settings shell) |
| `/folder` | `FolderScreen` |
| `/reader/:bookId?page=N` | `ReaderScreen` |
| `/search` | `SearchScreen` |
| `/search/:bookId` | `SearchScreen` (scoped to one book) |
| `/import?uri=...` | `ImportIntentScreen` |

---

## State Management

All state is managed with **Riverpod 2** (`flutter_riverpod: ^2.5.1`).

| Provider | Type | Scope |
|---|---|---|
| `libraryProvider` | `StateNotifierProvider<LibraryNotifier, LibraryState>` | Global |
| `annotationProvider` | `StateNotifierProvider.family<AnnotationNotifier, List<Annotation>, int>` | Per book |
| `globalSearchProvider` | `StateNotifierProvider<GlobalSearchNotifier, AsyncValue<List<SearchResult>>>` | Global |
| `aiEngineProvider` | `FutureProvider<AiEngine>` | Global singleton |
| `insightsProvider` | `StateNotifierProvider<InsightsNotifier, InsightsState>` | Global |
| `ocrControllerProvider` | `StateNotifierProvider<OcrController, AsyncValue<void>>` | Global |
| `themeProvider` | `NotifierProvider<ThemeNotifier, bool>` | Global |
| `typographyProvider` | `NotifierProvider<TypographyNotifier, String>` | Global |

---

## Reader Screen Architecture

The reader is built as a **`Stack`-based layout** rather than a simple `Scaffold`, enabling the animated show/hide of top and bottom bars without the PDF viewer reflowing or re-rendering.

```
Stack
├── SfPdfViewer (positioned, padded when UI visible)
├── GestureDetector (translucent tap overlay, middle strip only)
├── AnimatedPositioned (top bar — slides to top: -300 when hidden)
├── AnimatedPositioned (bottom bar — slides to bottom: -300 when hidden)
└── OCR indicator (Consumer, top-right corner)
```

Key interactions:

- **Single tap** — toggles UI visibility + system UI (`SystemUiMode.immersiveSticky`)
- **Text selection** — tapping while text is selected calls `_pdfController.clearSelection()` first
- **Progress scrubber** — `ValueNotifier<double>` drives both the slider and the page/percent labels, decoupled from `setState`
- **Exit progress** — saved to both `SharedPreferences` (fast) and Isar on `dispose()` and `onPageChanged`

---

## Permissions

| Permission | When | Why |
|---|---|---|
| `READ_EXTERNAL_STORAGE` | Android < 13 only | File picker access |
| None | Android 13+ | SAF (Storage Access Framework) handles file access via `FilePicker` internally |

The `requestStoragePermission()` helper checks `sdkInt` at runtime via `device_info_plus` and skips the manifest permission request on SDK 33+, keeping the permission dialog away from modern devices.

---

## Tech Stack

| Layer | Library | Version |
|---|---|---|
| UI Framework | Flutter | SDK ≥ 3.3.0 |
| PDF Rendering | `syncfusion_flutter_pdfviewer` | ^28.1.33 |
| PDF Parsing | `syncfusion_flutter_pdf` | ^28.1.33 |
| Thumbnail Rendering | `pdfx` | ^2.9.2 |
| Database | `isar` + `isar_flutter_libs` | ^3.1.0+1 |
| State Management | `flutter_riverpod` | ^2.5.1 |
| Navigation | `go_router` | ^14.2.7 |
| OCR | `google_mlkit_text_recognition` | ^0.13.1 |
| On-Device AI | `gemini_nano_android` | ^0.0.2 |
| File Picking | `file_picker` | ^8.1.2 |
| Hashing | `crypto` | ^3.0.3 |
| Fonts | `google_fonts` | ^8.1.0 |
| Permissions | `permission_handler` | ^11.3.1 |
| Device Info | `device_info_plus` | ^10.1.2 |
| Intent Handling | `uri_to_file` | ^1.0.0 |
| File Sharing | `share_plus` | ^12.0.2 |
| Wakelock | `wakelock_plus` | ^1.5.2 |
| Preferences | `shared_preferences` | ^2.5.5 |

---

## Build & Setup

### Prerequisites

- Flutter SDK ≥ 3.3.0
- Android SDK 21+ target (SDK 33+ recommended)
- Java 17

### Clone & Run

```bash
git clone https://github.com/CodeWithAnkan/aeropdf.git
cd aeropdf

# Install dependencies
flutter pub get

# Generate Isar schemas and Riverpod providers
dart run build_runner build --delete-conflicting-outputs

# Run on a connected device
flutter run --release
```

### Generate App Icon

```bash
dart run flutter_launcher_icons
```

Place your icon at `assets/icon/app_icon.png` (1024×1024px, no transparency for iOS).

---

## Privacy

AeroPDF is **100% offline**. It has no analytics, no telemetry, no crash reporting, and no network calls of any kind. All AI, OCR, and search processing happens on-device. See `PrivacyPolicyScreen` in `settings_screen.dart` for the full policy text shipped with the app.

---

## License

© 2026 Ankan Chatterjee. All rights reserved.

---

*Built with Flutter · Powered by on-device AI · Zero cloud dependency*