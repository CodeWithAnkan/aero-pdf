<p align="center">
  <img src="assets/icon/app_icon2.png" alt="AeroPDF Logo" width="100%"/>
</p>

# AeroPDF

> A lightweight, offline-first PDF reader for Android with on-device AI — zero cloud dependency, zero data collection.

---

## Overview

AeroPDF is a production-grade Flutter application built around a single guiding principle:

> **Your documents never leave your device.**

It combines high-fidelity PDF rendering, full-text search, annotation tools, and on-device AI summarization into a clean, modern reading experience — all without relying on external servers or cloud infrastructure.

---

# Screenshots & Features at a Glance

| Feature | Details |
|---|---|
| **PDF Rendering** | Syncfusion SfPdfViewer — native text selection, smooth scroll, pinch-zoom |
| **AI Insights** | Gemini Nano (AICore) on supported devices |
| **OCR** | Google ML Kit Text Recognition v2 — fully on-device |
| **Full-Text Search** | Real-time global search across all imported PDFs |
| **Annotations** | Highlight, underline, sticky notes — saved directly into the PDF |
| **Progress Tracking** | Per-book read position persisted across sessions |
| **Dark Mode & Typography** | Full light/dark theming with customizable typography |

---

# Architecture

AeroPDF follows a **feature-first layered architecture** with clear separation between:

- Data
- Domain
- Presentation

```plaintext
lib/
├── app/
├── core/
├── features/
├── services/
├── widgets/
└── main.dart
```

The application is designed around scalability, maintainability, and minimal runtime overhead.

---

# Data Layer

## Isar Database

AeroPDF uses **Isar 3**, a high-performance embedded NoSQL database optimized for Flutter applications.

### Collections

| Collection | Purpose |
|---|---|
| `Book` | Library metadata & reading progress |
| `Annotation` | Highlights, underlines, notes |
| `SearchIndex` | Full-text searchable document content |
| `OcrCache` | Cached OCR results |

---

## File Identity System

PDFs are identified using a **SHA-256 hash** of the file bytes instead of file paths.

This ensures:

- Read progress survives file renames
- Annotations remain linked correctly
- Files can be relocated without breaking references

---

# AI Pipeline

The AI system is designed around an interchangeable engine architecture.

```plaintext
buildAiEngine()
    └── AiCoreEngine (Gemini Nano)
```

## Gemini Nano Integration

On supported Android devices, AeroPDF uses:

- Gemini Nano
- Android AICore
- Fully on-device execution

This enables:

- AI-generated summaries
- Contextual document insights
- Offline processing
- Zero cloud dependency

The AI pipeline is optimized to work within strict mobile hardware and token constraints while maintaining responsiveness and low memory overhead.

---

# Indexing Pipeline

Background indexing runs inside a **Dart Isolate**, ensuring the UI remains smooth during heavy processing.

```plaintext
PDF Import
   └── Text Extraction
        └── OCR Detection
             └── Search Index Generation
                  └── AI Processing
```

The indexing system powers:

- Real-time global search
- AI summaries
- Fast document discovery

---

# OCR System

AeroPDF uses **Google ML Kit OCR** for scanned and image-based PDFs.

## OCR Workflow

```plaintext
PDF Page Render
   └── ML Kit Text Recognition
        └── OCR Blocks
             └── Search Index Update
```

Everything runs locally on-device.

No uploaded files.
No server processing.

---

# Annotation System

Annotations are stored using normalized coordinates, making them resolution-independent and scalable across zoom levels.

Supported annotation types:

- Highlight
- Underline
- Sticky Notes

Annotations can also be permanently embedded into the PDF file for portability.

---

# Navigation & Routing

Navigation is handled using **GoRouter** with Android intent interception support.

Supported flows include:

- File manager imports
- Share-sheet imports
- Deep-link handling
- Reader state restoration

---

# State Management

AeroPDF uses **Riverpod 2** for scalable and reactive state management.

Core systems managed through Riverpod include:

- Library management
- OCR processing
- Search indexing
- AI insights
- Theme management
- Annotation state

---

# Reader Architecture

The reader is built using a layered `Stack`-based layout to allow:

- Immersive fullscreen reading
- Animated controls
- Persistent overlays
- Smooth UI transitions

Core interactions include:

- Tap-to-toggle immersive mode
- Text selection handling
- Reading progress persistence
- Dynamic page tracking

---

# Privacy

AeroPDF follows a strict **Zero-Cloud Architecture** philosophy.

The app contains:

- No analytics
- No telemetry
- No trackers
- No background data collection
- No cloud uploads

All processing happens locally on the device.

Your documents remain yours.

---

# Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter |
| Language | Dart |
| Database | Isar |
| State Management | Riverpod |
| Navigation | GoRouter |
| OCR | Google ML Kit |
| PDF Rendering | Syncfusion PDF Viewer |
| AI | Gemini Nano (AICore) |
| Security | flutter_secure_storage |

---

# Build & Setup

## Prerequisites

- Flutter SDK ≥ 3.3.0
- Android SDK 21+
- Java 17

---

## Clone the Repository

```bash
git clone https://github.com/CodeWithAnkan/aeropdf.git
cd aeropdf
```

---

## Install Dependencies

```bash
flutter pub get
```

---

## Generate Build Files

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Run the Application

```bash
flutter run --release
```

---

# Roadmap

Planned improvements include:

- Semantic document search
- Multi-document AI context understanding
- Better annotation workflows
- Desktop support
- Advanced reading analytics (fully local)

---

# Contributing

Contributions are welcome.

Please read:

- [CONTRIBUTING.md](CONTRIBUTING.md)

before submitting pull requests or feature proposals.

---

# License

© 2026 Ankan Chatterjee. All rights reserved.

---

<p align="center">
  Built with Flutter • Powered by On-Device AI • Zero Cloud Dependency
</p>
