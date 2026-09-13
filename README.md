# OmniFile

A universal, high-performance, 100% offline file viewer and editor for Android.

Repository: https://github.com/My-Mation/omnifile

OmniFile is built on a straightforward premise: you should be able to open, inspect, and edit any file format on your mobile device instantly, privately, and reliably without internet access, third-party cloud dependencies, advertisements, or tracking.

---

## Core Principles

### Absolute Offline Privacy
- Zero Network Permissions: The Android application manifest contains no `android.permission.INTERNET`. Network sockets cannot be opened by the application runtime under any circumstance.
- Zero Telemetry: No analytics libraries, no crash reporting daemons, no device fingerprinting, and no background tracking services.
- On-Device Processing: All file parsing, syntax tokenization, media decoding, text recognition (OCR), and document serializations execute locally on the host CPU and GPU.

### The Golden Save Rule
OmniFile enforces a strict non-destructive editing paradigm. Original files are treated as immutable and read-only. Whenever you modify a document, edit an Excel sheet, trim a video, or alter an image, OmniFile saves the result into a clean sibling copy using the naming convention:
```
<filename> (edited).<extension>
```
If that name exists, OmniFile automatically increments the counter (for example, `<filename> (edited) (2).<extension>`), eliminating any risk of overwriting or corrupting source documents.

### Minimalist Monochrome Interface
OmniFile employs a purposeful black, white, and grayscale design language:
- Pure black (`#000000`) surfaces for OLED power efficiency and darkroom contrast.
- High-contrast typography in pure white (`#FFFFFF`) and calibrated gray tones.
- Flat 0.5px and 1px structural borders instead of drop shadows or elevation blur.
- Zero gradients, zero decorative animations, and zero color noise.

---

## Supported Formats and Viewer Matrix

| Category | Extensions | Key Features |
| :--- | :--- | :--- |
| **PDF Documents** | `.pdf` | Smooth vector rendering, pinch-to-zoom, page thumbnails, jump-to-page, document-wide search with Up/Down navigation, copy current page text, scanned book page OCR, and cover-and-replace text editing. |
| **Spreadsheets** | `.xlsx`, `.xls`, `.csv`, `.tsv` | Native OpenXML and CSV/TSV spreadsheet parser and serializer, interactive 2D grid navigation, in-place cell editing, formula bar, row/column insertion and deletion, multi-row append, and multi-sheet tab switching. |
| **Word Documents** | `.docx`, `.doc` | Native OpenXML document flow rendering, styled paragraph and table cell inspection/editing, paragraph insertion, document search with highlight cycling, and structural preservation. |
| **Presentations** | `.pptx`, `.ppt` | Slide deck slide-by-slide thumbnail navigation, formatted text frame extraction, slide title and bullet point editing, and slide search. |
| **Source Code & Scripts** | `.py`, `.js`, `.ts`, `.dart`, `.java`, `.kt`, `.c`, `.cpp`, `.cs`, `.go`, `.rs`, `.rb`, `.php`, `.sh`, `.sql`, `.json`, `.xml`, `.yaml`, `.yml`, `.toml`, `.ini`, `.css`, `.html`, `.log`, `.txt` | Over 180 syntax highlighting themes, 56dp line gutter with line numbering, active-line highlight, fast in-file search with match counters, Up/Down navigation, case-sensitive/case-insensitive search, word wrap toggle, pinch-to-zoom font scaling, copy whole file, and multi-encoding switcher (UTF-8, UTF-16, Latin-1, ASCII). |
| **Markdown & Readme** | `.md`, `.markdown`, `README` | Dual-mode viewer: seamless formatted Markdown rendering (headers, tables, code blocks, checklists) with a single-tap toggle to raw syntax-highlighted source code editing. |
| **Raster & Vector Images** | `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`, `.bmp`, `.heic`, `.svg`, `.ico` | Interactive canvas with 0.5x to 8.0x pinch-to-zoom, double-tap zoom cycles, 90-degree lossless rotation, animated GIF playback controls, automatic background OCR, in-image text search with Up/Down navigation, one-tap copy whole page, and complete EXIF metadata inspection. |
| **Video Playback** | `.mp4`, `.mkv`, `.avi`, `.mov`, `.webm`, `.ts`, `.3gp`, `.flv`, `.wmv` | Hardware-accelerated playback powered by libmpv (`media_kit`), scrubber seekbar, jump forward/backward (+/- 10s), variable speed controls (0.25x to 4.0x), automatic sibling subtitle discovery (`.srt`, `.vtt`, `.ass`), and double-tap gestures. |
| **Audio Playback** | `.mp3`, `.wav`, `.flac`, `.aac`, `.ogg`, `.m4a`, `.opus`, `.wma` | High-fidelity audio playback engine, dynamic scrubber, continuous playback, playback rate adjustments, track loop modes, ID3 tag metadata parsing, and embedded album art extraction. |
| **Compressed Archives** | `.zip`, `.tar`, `.gz`, `.tgz`, `.bz2`, `.xz`, `.7z`, `.rar` | Interactive breadcrumb folder explorer, inner archive file preview, isolate-based background extraction, and strict Zip-Slip directory traversal attack protection. |
| **Web Documents** | `.html`, `.htm` | Sandboxed offline WebView with strict Content-Security-Policy (`default-src 'none'`) blocking external network egress, JavaScript execution toggle, and raw source inspection. |
| **Binary & Hex Files** | `.dat`, `.bin`, `.exe`, `.dll`, `.so`, `.dylib`, `.class`, `.o`, `.obj`, `.iso`, `.img`, `.rom`, `.elf`, `.wasm`, `.dex`, `.hex`, or unknown formats | High-performance virtualized 3-column Hex Viewer (Offset, Hexadecimal, ASCII decoding) with 64KB chunk-based memory caching, search, and jump-to-offset navigation. |

---

## In-App Editing Capabilities

OmniFile goes beyond passive viewing by providing specialized, non-destructive editing workflows across multiple file formats:

### 1. Excel & CSV Spreadsheet Editor (.xlsx, .xls, .csv, .tsv)
- Live Cell Formula Bar: Displays the active cell coordinates (such as `[ B3 ]`), real-time content display, clear cell trigger, and an expanded multi-line cell entry dialog.
- Structural Grid Modification: Insert rows before or after the selection, delete rows, insert columns, delete columns, and append rows in single or multi-row batches.
- Native OpenXML and CSV/TSV Serialization: Direct parsing and serialization into ISO/IEC 29500-1 OpenXML format and comma/tab-separated values, maintaining complete compatibility with external spreadsheet tools while strictly preserving original files via the Golden Save Rule.

### 2. Word Document Paragraph & Table Editor (.docx)
- In-place editing of text paragraphs and table cells without breaking OpenXML `<w:tcPr>` properties or document formatting.
- Multi-occurrence text search across all paragraphs and tables with match counters and navigation buttons.

### 3. Source Code and Text Editor
- Full in-place editing for plain text, configuration files, and over 30 programming languages.
- Real-time Find and Replace engine with match counts, match navigation (Next/Prev), and Replace All capability.
- Line gutter numbering, custom tab sizes, dynamic word wrapping, and pinch-to-zoom font resizing.
- Encoding conversion between UTF-8, UTF-16, Latin-1, and US-ASCII.

### 4. PDF Non-Destructive Text Replacement
- PDF text editor operating on a cover-and-replace overlay paradigm.
- Tap any detected text block to overlay matching background containers with edited text rendered using best-match font estimation.
- Multi-page text indexing and search with instant page jumping and match previews.
- Copy current page text to clipboard with a single tap.

### 5. Image OCR, Interactive Text Editing & Studio
- Automatic OCR: Background on-device text recognition on load without requiring manual button clicks.
- On-Image Click-to-Edit: Tap any recognized text directly on the image to edit or replace it with matching font size and background cover.
- Tap-to-Add Text: Tap any empty spot on the image to insert a new text block with custom styling and size.
- Copy Whole Page: One-tap button to copy all recognized text on the image to the clipboard.
- Search on Image: Search for text occurrences on the image with match counter and Up/Down cycling.
- Transform & Crop Tools: Step rotation, horizontal/vertical flipping, and aspect ratio crop presets.

### 6. Video Trimmer
- Frame-accurate start time and end time trimming.
- Option to strip audio tracks for muted clip generation.
- Asynchronous local transcoding with progress feedback.

---

## On-Device Optical Character Recognition (OCR)

OmniFile includes a 100% offline text recognition suite:

- Automatic Image OCR: Powered by Google ML Kit on-device Latin text recognition models. Runs automatically on image load to identify all text blocks, lines, and bounding boxes.
- Scanned Book PDF OCR: Native Android PDF renderer with memory-safe dimension clamping (prevents Out-Of-Memory crashes on high-res book scans) that rasterizes scanned pages and feeds them to ML Kit OCR.
- PDF Vector Text Indexing: Pure Dart vector text extraction powered by Syncfusion PDF parsing, indexing all pages for rapid search and copy.
- OCR Result Viewer: A dedicated modal sheet displaying recognized text, word and character counts, real-time in-result text searching with query highlighting, one-tap clipboard copy, and export to a standalone `.txt` document.

---

## Performance and Architecture

OmniFile is designed for responsiveness on low-end and high-end devices alike:

### 4-Tier File Detection Engine
1. Magic Byte Identification: Inspects the initial 4 to 264 bytes against known binary signatures (such as `%PDF`, `PK\x03\x04`, `\xFF\xD8\xFF`, `\x89PNG`, `RIFF`, `\x1F\x8B`, `ustar`).
2. Extension Mapping: Fallback lookup across an extensive dictionary of file extensions.
3. Content Heuristic: Reads the initial 8KB chunk of extensionless files to evaluate printable ASCII and UTF-8 ratios.
4. Hexadecimal Fallback: Files that cannot be classified are routed to the virtualized 3-column Hex Viewer, ensuring no file ever hits an unrecoverable dead end.

### Zero Main-Thread Blocking
- Asynchronous Directory Scanning: Library discovery uses batched concurrent `FileStat` queries (chunks of 32 items) and in-memory path detection, preventing UI thread frame drops during folder indexation.
- Background Isolates: Heavy computation (ZIP extraction, archive traversal, image compression, large file hashing) executes inside dedicated Dart isolates.
- Virtualized Rendering: Hex and spreadsheet views load data chunks on demand (64KB blocks), enabling smooth scrolling through gigabyte-sized files without unbounded memory consumption.

---

## Project Structure

OmniFile follows Clean Architecture principles:

```
lib/
├── core/
│   ├── errors/             # Custom failure and exception types
│   ├── routes/             # App routing and screen navigation arguments
│   ├── services/           # OCR service, file detection service, storage helpers
│   ├── theme/              # Monochrome colors, typography, flat theme specifications
│   └── utils/              # File size formatters, path utilities, MIME helpers
├── data/
│   ├── datasources/        # Local storage, SharedPreferences, file system access
│   └── repositories/       # File, library, and recents repository implementations
├── domain/
│   ├── entities/           # FileItem, ViewerType, OcrResult, DocumentMetadata
│   ├── repositories/       # Abstract repository interfaces
│   └── usecases/           # Detection, recent files, and file search use cases
└── presentation/
    ├── providers/          # Riverpod state providers (library, search, settings, theme)
    ├── screens/
    │   ├── editor/         # Image editor, video trimmer screens
    │   ├── home/           # Library dashboard, recents list, search screen
    │   ├── settings/       # Settings, storage management, about screen
    │   ├── viewer/         # Universal viewer router and shell container
    │   └── viewers/        # Dedicated viewers (archive, audio, code, docx,
    │                       #   hex, html, image, markdown, office, pdf, video)
    └── widgets/            # Flat buttons, status badges, OCR result sheets, dialogs
```

---

## Building and Installation

### Prerequisites
- Flutter SDK (3.x or later, stable channel)
- Dart SDK (3.x or later)
- Android SDK (API Level 24 / Android 7.0 minimum, API Level 35 target)
- Java Development Kit (JDK 17)
- Android Debug Bridge (ADB) installed and accessible in your system `PATH`

### Setup Steps
1. Clone the repository:
   ```bash
   git clone https://github.com/My-Mation/omnifile.git
   cd omnifile
   ```

2. Retrieve project dependencies:
   ```bash
   flutter pub get
   ```

3. Run static code analysis:
   ```bash
   flutter analyze
   ```
   Expected output: `No issues found!`

4. Execute the unit and widget test suite:
   ```bash
   flutter test
   ```
   All 58 test cases should complete successfully.

5. Build a debug APK:
   ```bash
   flutter build apk --debug
   ```

6. Install onto a connected Android device or emulator:
   ```bash
   adb install -r build/app/outputs/flutter-apk/app-debug.apk
   ```

7. Build an optimized release APK:
   ```bash
   flutter build apk --release --split-per-abi
   ```

---

## Security Model

- Offline Confinement: The application does not declare `android.permission.INTERNET` in `android/app/src/main/AndroidManifest.xml`. The Android OS security sandbox strictly prevents any network communication.
- Path Traversal Protection: The archive extraction engine validates every entry destination against canonical root directories to prevent Zip-Slip vulnerabilities.
- Sandboxed Web Content: The embedded HTML viewer enforces a strict Content-Security-Policy meta header (`default-src 'none'`), neutralizing cross-site scripting and external resource loading.
- Read-Only Source Files: All editing flows preserve the original input file byte-for-byte.

---

## Contributing

Contributions from the open-source community are welcome. When submitting pull requests:
1. Ensure all code conforms to the project linter rules (`flutter analyze` reports zero issues).
2. Add unit or widget tests for any new viewer, editor feature, or file signature parser (`flutter test` passes all tests).
3. Do not add `android.permission.INTERNET` or introduce any telemetry libraries.
4. Adhere to the strict monochrome design language (no gradients, no drop shadows, black/white/gray surfaces).
5. Follow the Golden Save Rule for any editor modifications.

---

## License

OmniFile is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
