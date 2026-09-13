# OpenFile Phase Completion Log

## Phase 1 — Foundation & App Shell
- **Date**: 2026-09-12
- **Status**: Completed
- **Target**: Compiling, runnable foundation app with theme system, navigation, file picker plumbing, and recent files.

### What Was Built
1. **Project Scaffolding & Architecture**:
   - Created Flutter project with Application ID `com.openfile.viewer` and name `OpenFile`.
   - Configured `minSdk = 24` (Android 7.0+) per `rules.txt` §2.
   - Established Clean Architecture folder structure matching `rules.txt` §4.1:
     - `lib/core/` (constants, errors, theme, utils, extensions)
     - `lib/domain/` (entities, repositories, usecases — pure Dart, 0 Flutter imports)
     - `lib/data/` (models, repositories)
     - `lib/presentation/` (screens, widgets, providers)
     - Pre-scaffolded all viewer directories (`pdf`, `text_code`, `image`, `video`, `audio`, `archive`, `html`, `markdown`, `hex`, `office`).

2. **Design System & Theming**:
   - Complete `OpenFileColors` `ThemeExtension` with exact tokens from `ui_rules.txt` §2 for both Dark (OLED black `#000000`, surface `#121212`, card `#1E1E1E`, elevated `#2A2A2A`, accent `#00BFA5`) and Light (`#FAFAFA`, card `#FFFFFF`, accent `#00897B`).
   - Defined 13 file-type semantic colors for icons.
   - Full Material 3 `AppTheme.darkTheme` and `AppTheme.lightTheme` with `ThemeExtension` and type scale (Roboto UI font).
   - Animated 250ms theme transitions via `lerp`.

3. **Bundled Fonts**:
   - Bundled JetBrains Mono (Regular, Medium) and Fira Code (Regular, Medium) in `assets/fonts/` and registered in `pubspec.yaml`.

4. **Navigation & App Shell**:
   - Material 3 `NavigationBar` with 3 tabs: Home, Settings, About (80dp height, `surfaceApp` background, accent selected indicator).
   - Cold-start splash timing check (<400ms skips splash immediately to Home).

5. **Home Screen & File Picker Plumbing**:
   - Typographic header ("OpenFile", "Any file. Any format. Zero internet.").
   - Hero "Open File" filled button (56dp height, pill shape, scale feedback).
   - Integrated `file_picker` (`FileType.any`).
   - Picking a file reads name, size, path, last modified date, creates `FileEntity`, adds to recents, and presents the `FileInfoDialog`.
   - `FileInfoDialog` displays 2-column key-value layout with name, type, size, path, modified timestamp, and SHA-256 hash (with copy to clipboard).
   - `OEMptyState` with custom fanned file vectors when recents list is empty.

6. **Recents System**:
   - Shared preferences backing, max 20 entries.
   - Re-opening updates position to top of list without duplicates.
   - 72dp two-line list tile with custom `FileTypeIcon` painter (folded top-right corner), middle-truncated filename, size and relative time subtitle, and overflow action button.
   - Swipe-to-delete with red trash zone (`stateError`), committing on swipe with 5-second `UNDO` action snackbar.
   - "Clear all" button with confirmation dialog.

7. **Settings Screen**:
   - Appearance group: Theme picker sheet (System/Light/Dark via `RadioGroup`), Code font picker sheet with live font preview (JetBrains Mono/Fira Code/System), Default text size slider (10–28sp) with live code preview.
   - Viewer group: Word wrap default switch, auto-load subtitles switch, remember playback position switch.
   - Storage group: Clear recent files (confirm dialog), Clear cache (calculates `openfile_cache` temp directory size, deletes files, reports size).
   - Privacy group: Expandable card with static statement verifying zero internet permission and offline privacy.

8. **About Screen**:
   - 72dp vector logo (document outline with folded corner and eye motif).
   - App name "OpenFile", version "1.0.0".
   - Full OSS licenses via `showLicensePage`.
   - Offline privacy commitment card.
   - Footer tagline: "Built for the love of files. Free forever."

9. **Security & Privacy Verification**:
   - `AndroidManifest.xml` verified to contain NO `android.permission.INTERNET`.
   - Zero external tracking, analytics, or network libraries.

### Decisions Made
- Used `RadioGroup` for bottom sheet single-selects to adhere to modern Flutter 3.41 API standards without deprecation warnings.
- Added `crypto: ^3.0.7` for SHA-256 calculation for files under 100MB as specified in `rules.txt` §5.1.
- Configured USB debugging only per user instructions.

### Known Issues
- None. `flutter analyze` reports 0 issues. All unit and widget tests pass.

### Files Created/Modified
- `pubspec.yaml`
- `android/app/build.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`
- `assets/fonts/JetBrainsMono-Regular.ttf`
- `assets/fonts/JetBrainsMono-Medium.ttf`
- `assets/fonts/FiraCode-Regular.ttf`
- `assets/fonts/FiraCode-Medium.ttf`
- `lib/main.dart`
- `lib/app.dart`
- `lib/core/constants/app_constants.dart`
- `lib/core/errors/failures.dart`
- `lib/core/theme/open_file_colors.dart`
- `lib/core/theme/app_theme.dart`
- `lib/core/utils/formatters.dart`
- `lib/core/utils/file_utils.dart`
- `lib/core/extensions/context_extensions.dart`
- `lib/domain/entities/file_entity.dart`
- `lib/domain/entities/viewer_type.dart`
- `lib/domain/entities/settings_entity.dart`
- `lib/domain/repositories/recents_repository.dart`
- `lib/domain/repositories/settings_repository.dart`
- `lib/domain/usecases/get_recents_usecase.dart`
- `lib/domain/usecases/add_recent_usecase.dart`
- `lib/domain/usecases/remove_recent_usecase.dart`
- `lib/domain/usecases/clear_recents_usecase.dart`
- `lib/domain/usecases/get_settings_usecase.dart`
- `lib/domain/usecases/update_settings_usecase.dart`
- `lib/domain/usecases/manage_cache_usecase.dart`
- `lib/data/models/file_model.dart`
- `lib/data/repositories/recents_repository_impl.dart`
- `lib/data/repositories/settings_repository_impl.dart`
- `lib/presentation/providers/shared_preferences_provider.dart`
- `lib/presentation/providers/recents_provider.dart`
- `lib/presentation/providers/settings_provider.dart`
- `lib/presentation/widgets/file_type_icon.dart`
- `lib/presentation/widgets/o_filled_button.dart`
- `lib/presentation/widgets/o_bottom_sheet.dart`
- `lib/presentation/widgets/confirm_dialog.dart`
- `lib/presentation/widgets/file_info_dialog.dart`
- `lib/presentation/widgets/o_empty_state.dart`
- `lib/presentation/screens/app_shell.dart`
- `lib/presentation/screens/home/home_screen.dart`
- `lib/presentation/screens/home/recent_file_tile.dart`
- `lib/presentation/screens/settings/settings_screen.dart`
- `lib/presentation/screens/about/about_screen.dart`
- `lib/presentation/screens/splash/splash_screen.dart`
- Viewer placeholder directories in `lib/presentation/screens/viewers/`
- `test/unit/formatters_test.dart`
- `test/unit/recents_test.dart`
- `test/widget_test.dart`
- `PHASE_LOG.md`

## Phase 2 — Detection Engine + Text/Code Viewer
- **Date**: 2026-09-12
- **Status**: Completed
- **Target**: Pure Dart file-type detection pipeline (unit-tested), common Viewer Shell, and Text/Code Viewer supporting syntax highlighting, line numbers, word wrap, in-file search, encoding switcher, large file handling, and markdown rendering.

### What Was Built
1. **Domain Layer Detection Pipeline (`DetectFileTypeUseCase`)**:
   - Implemented strict 4-step detection pipeline according to `rules.txt` §4.4:
     1. Exact magic byte matching for all listed formats (PDF `%PDF`, PNG `\x89PNG`, JPEG `\xFF\xD8\xFF`, GIF `GIF87a`/`GIF89a`, WebP/AVI/WAV RIFF headers, GZIP `\x1F\x8B`, TAR `ustar` at offset 257, MKV/WebM `\x1A\x45\xDF\xA3`, MP3 `ID3` or sync words `0xFF 0xFB/0xF3/0xF2`, FLAC `fLaC`, OGG `OggS`, HTML `<!DOCTYPE html>` or `<html>`, and ZIP `PK\x03\x04` with zip entry parsing to distinguish DOCX/XLSX/PPTX from general ZIP).
     2. Extension mapping covering all Tier 1 and Tier 2 extensions.
     3. Plain text heuristic: reads first 8KB; if >90% printable ASCII/UTF-8 characters, identifies as plain text.
     4. Fallback: non-text unmapped files return `ViewerType.unknown` (routed to Unsupported / Hex view fallback).
   - In-memory LRU detection cache for repeated accesses.
   - 21 unit tests covering all magic numbers, renamed files (JPEG/PNG renamed to `.txt` where magic wins), uppercase extensions, empty files, 1-byte files, and Tier 1 code extensions.

2. **Common Viewer Shell (`ViewerShell`)**:
   - `AppBar` with middle-truncated filename and overflow menu:
     - "File info" (opens `FileInfoDialog` with SHA-256 calculation and metadata).
     - "Share" (via `share_plus`).
     - "Open with…" (via `open_filex`).
     - "Toggle theme" (persists immediately).
   - Double-tap anywhere to toggle immersive fullscreen (hides AppBar and system bars).
   - Custom top banner slots for warnings and notices.
   - Clean loading state and error state.

3. **Text/Code Viewer (`TextCodeViewer`)**:
   - **Syntax Highlighting**: Powered by `highlight` package mapped to all Tier 1 code languages (`dart`, `python`, `javascript`, `java`, `kotlin`, `c`, `cpp`, `csharp`, `go`, `rust`, `ruby`, `php`, `bash`, `sql`, `xml`, `json`, `yaml`, `ini`, `css`, etc.) using custom `CodeSyntaxHighlighter`.
   - **Gutter & Line Numbers**: 56dp gutter width with right-aligned numbers, active line highlight (`accentPrimary` 8% tint), and tap-to-select line.
   - **Word Wrap**: Toggle in app bar. Default ON for `.txt`/`.log`, OFF for code. When OFF, displays sticky 4dp accent right-edge overflow indicator.
   - **In-Viewer Find Bar (`InViewerFindBar`)**: Search-as-you-type, match count pill (`x/y`), previous/next navigation, inline highlight (25% background, 60% for active match), auto-scroll to match, ESC/X to dismiss.
   - **Character Encoding (`EncodingHelper`)**: Auto-detection + bottom sheet switcher (UTF-8, UTF-16LE, UTF-16BE, Latin-1, ASCII) with instant buffer decode and match re-evaluation.
   - **Font Size Controls**: Dedicated + / - buttons in toolbar and two-finger pinch-to-zoom (10–28sp, snaps to 2sp increments, persists in settings).
   - **Large File Handling**: Files >2MB load first 1MB with sticky warning banner ("Large file — X MB. Loaded first 1 MB.") and "Load more" action. Files >50MB prompt with confirmation dialog before loading.
   - **Markdown Rendering**: Toggle button for `.md` files between rendered view (`flutter_markdown` with themed headings, code blocks, font styling) and raw syntax-highlighted source.

4. **Viewer Router Screen (`ViewerRouterScreen`)**:
   - Routes `ViewerType.text`, `ViewerType.code`, `ViewerType.markdown`, `ViewerType.json` to `TextCodeViewer`.
   - Routes all other formats to `UnsupportedScreen` with file metadata, "Open as hex", and "Open with another app".

5. **Home & Recents Integration**:
   - Tapping "Open File" or any item in Recent Files runs detection and opens `ViewerRouterScreen`.
   - Recents list now saves real detected `ViewerType` and renders custom file-type icons with specific semantic colors.

### Decisions Made
- Built pure-Dart custom syntax highlighter tokens renderer integrated directly with `SelectableText.rich` and `ListView.builder` for virtualized smooth 60fps performance on low-memory devices.
- Kept `UnsupportedScreen` as the routing destination for all non-text viewers as specified in Phase 2 out-of-scope boundaries.

### Known Issues
- None. `flutter analyze` reports 0 issues. All 28 unit and widget tests pass. Debug build installed and running on USB device `SSOJMJMBDQVWM7UK`.

### Files Created/Modified
- `lib/domain/entities/viewer_type.dart`
- `lib/domain/usecases/detect_file_type_usecase.dart`
- `lib/presentation/screens/viewer/viewer_router_screen.dart`
- `lib/presentation/widgets/viewer_shell.dart`
- `lib/presentation/widgets/in_viewer_find_bar.dart`
- `lib/presentation/widgets/unsupported_screen.dart`
- `lib/presentation/screens/viewers/text_code/text_code_viewer.dart`
- `lib/presentation/screens/viewers/text_code/encoding_helper.dart`
- `lib/presentation/screens/viewers/text_code/highlight_map.dart`
- `lib/presentation/screens/viewers/text_code/syntax_highlighter.dart`
- `lib/presentation/screens/home/home_screen.dart`
- `lib/presentation/screens/home/recent_file_tile.dart`
- `test/unit/detection_test.dart`
- `PHASE_LOG.md`

## Phase 3 — PDF & Image Viewers
- **Date**: 2026-09-12
- **Status**: Completed
- **Target**: Native document and photo viewers covering PDF (flutter_pdfview, page indicators, jump-to-page dialog, password unlock loop, last read page persistence, >50MB warning) and Image (InteractiveViewer, double-tap zoom 1x <-> 2.5x, 90° rotation, animated GIF pause/resume, EXIF / details bottom sheet with copyable text).

### What Was Built
1. **PDF Viewer (`PdfViewer`)**:
   - Integrated `flutter_pdfview`.
   - Horizontal and continuous vertical paging toggle.
   - Page indicator pill ("X / Y") and jump-to-page dialog.
   - Password prompt loop for encrypted PDFs with up to 3 attempts and friendly error fallback.
   - Saved last read page per file path hash in `shared_preferences`.
   - Warning banner for PDFs >50MB.
2. **Image Viewer (`ImageViewer`)**:
   - `InteractiveViewer` supporting 0.5x to 8.0x smooth zoom and panning.
   - Double-tap zoom cycle to tap coordinates (1x <-> 2.5x).
   - Clockwise 90-degree rotation.
   - Animated GIF / WebP play and pause toggle.
   - Metadata & EXIF bottom sheet showing dimensions, aspect ratio, file size, format, date, and path (with long-press copy to clipboard, zero external map links).

### Files Created/Modified
- `lib/presentation/screens/viewers/pdf/pdf_viewer.dart`
- `lib/presentation/screens/viewers/image/image_viewer.dart`

---

## Phase 4 — Media Player (Video + Audio)
- **Date**: 2026-09-12
- **Status**: Completed
- **Target**: Full offline media playback powered by `media_kit` libmpv.

### What Was Built
1. **Video Player (`VideoPlayerScreen`)**:
   - Hardware-accelerated libmpv backend via `media_kit` and `media_kit_video`.
   - Letterboxed black presentation canvas with 3-second auto-hiding controls.
   - Seekbar with current position, duration, and time bubble.
   - Speed selector menu (0.25x to 4x), loop toggle, ±10s skip buttons.
   - Center double-tap play/pause, left double-tap -10s, right double-tap +10s.
   - Automatic sibling subtitle detection (`.srt`, `.vtt`, `.ass`) by matching basename in directory.
2. **Audio Player (`AudioPlayerScreen`)**:
   - High-fidelity audio playback for MP3, FLAC, WAV, AAC, OGG, M4A, OPUS.
   - Album art card with semantic type icon.
   - Metadata display, seekbar, speed adjustments (0.5x to 2x), and loop toggle.

### Files Created/Modified
- `lib/presentation/screens/viewers/video/video_player_screen.dart`
- `lib/presentation/screens/viewers/audio/audio_player_screen.dart`

---

## Phase 5 — Archives & HTML
- **Date**: 2026-09-12
- **Status**: Completed
- **Target**: ZIP/TAR/GZ archive exploration and extraction with Zip-Slip protection, plus offline-safe HTML rendering.

### What Was Built
1. **Archive Viewer (`ArchiveViewer`)**:
   - Pure Dart `archive` engine for ZIP, TAR, GZ, TGZ files.
   - Virtual directory tree with interactive breadcrumb path navigation.
   - Tap file entry to extract into cache and launch directly into dedicated viewer.
   - "Extract all" with system directory picker and determinate progress bar.
   - **Security**: Zip-Slip protection rejecting relative path traversal (`../`, absolute paths, paths outside output folder).
2. **HTML Viewer (`HtmlViewer`)**:
   - Offline `webview_flutter` local file rendering.
   - **Security**: Injected strict CSP meta tag (`default-src 'none'; style-src 'unsafe-inline' file:; script-src 'none'; img-src 'self' data: file:; font-src 'self' data: file:;`).
   - `NavigationDelegate` actively intercepts and denies any non-local requests (`http://`, `https://`).
   - JavaScript disabled by default with toggle chip.
   - Rendered view ↔ syntax-highlighted source code toggle.

### Files Created/Modified
- `lib/presentation/screens/viewers/archive/archive_viewer.dart`
- `lib/presentation/screens/viewers/html/html_viewer.dart`

---

## Phase 6 — Fallback Chain: Hex Viewer + Office Viewers
- **Date**: 2026-09-12
- **Status**: Completed
- **Target**: Eliminate dead ends: Virtualized 3-column Hex Viewer and Office document best-effort previewers.

### What Was Built
1. **Hex Viewer (`HexViewer`)**:
   - 3-column virtualized layout: Offset (8 hex digits), Hex bytes (16 bytes), ASCII gutter.
   - 64KB lazy chunking to handle multi-gigabyte binary files safely without high memory usage.
   - Offset ruler header and alternating row shading.
   - Jump to offset dialog supporting decimal or hex (`0x...`).
2. **Office Viewer (`OfficeViewer`)**:
   - `.docx`: Unzips archive, parses `word/document.xml` using `xml` package, displays styled paragraphs and headings with "Simplified preview" notice banner.
   - `.xlsx`: Unzips archive, parses `xl/worksheets/sheet1.xml` and `xl/sharedStrings.xml`, renders scrollable 2D data table grid with columns, rows, and zebra striping.
   - `.pptx`: Unzips archive, parses slide XMLs into a vertical slide deck view with slide numbers.
   - Legacy formats (`.doc`, `.xls`, `.ppt`): Extracts printable strings or falls back gracefully to "Open with another app".
3. **Fallback Chain Integration**:
   - Connected `HexViewer` and `OfficeViewer` into `ViewerRouterScreen` and `UnsupportedScreen`.

### Files Created/Modified
- `lib/presentation/screens/viewers/hex/hex_viewer.dart`
- `lib/presentation/screens/viewers/office/office_viewer.dart`
- `lib/presentation/widgets/unsupported_screen.dart`
- `lib/presentation/screens/viewer/viewer_router_screen.dart`

---

## Phase 7 — System Integration, Polish & Release
- **Date**: 2026-09-12
- **Status**: Completed
- **Target**: Android system citizen integration, external intents, release verification, and zero internet permission guarantee.

### What Was Built
1. **System Intent Filters (`AndroidManifest.xml`)**:
   - Registered `android.intent.action.VIEW` for MIME types (`application/pdf`, `text/*`, `image/*`, `video/*`, `audio/*`, `application/zip`, `application/json`, `*/*`) with `file` and `content` schemes.
2. **Zero Internet & Security Verification**:
   - Confirmed `android.permission.INTERNET` is completely absent from `AndroidManifest.xml`.
   - Verified 100% offline functionality.
3. **Documentation**:
   - Generated `README.md` containing feature overview, privacy commitment, supported format matrix, and build instructions.
4. **Code Quality**:
   - `flutter analyze`: 0 issues.
   - `flutter test`: All 28 unit and widget tests passing.
   - Debug build compiled and installed to USB device `SSOJMJMBDQVWM7UK`.

### Files Created/Modified
- `android/app/src/main/AndroidManifest.xml`
- `README.md`
- `PHASE_LOG.md`



---

## Phase 8 — UI V2 Library Shell
- **Date**: 2026-09-12
- **Status**: Completed
- **Target**: Redesign Home screen into V2 Library Shell with gradient header, filter chips, hero card, solid badge icons, device file indexing, and floating action popup.

### What Was Built
1. **Design System & Badges**:
   - Implemented `FileTypeBadge` (§5.1): 40dp solid rounded square (12dp radius) with semantic background color and white bold labels (`PDF`, `XLS`, `DOC`, `PPT`, `</>`, `♪`, `VID`, `IMG`, `ZIP`, `TXT`).
2. **V2 Home Screen Shell**:
   - Sky gradient header in Light mode (`#6EC9F2` → `#B7E3F7` → `surface.app`) and flat `surface.app` in Dark mode.
   - Time-based greeting ("Good morning 👋" / "Good afternoon 👋" / "Good evening 👋") with circular folder-add and settings shortcuts.
   - Search pill with live filtering.
   - Horizontal category filter chips: `All`, `PDF`, `Word`, `Excel`, `PPT`, `Code`, `Media`, `Archive` with dark slate `#23505C` active state.
   - Recently Added hero card (96dp height, dark slate `#23505C`, 16dp radius, teal doc tile, navigation to recents).
3. **Library Indexing & Storage**:
   - `libraryProvider`: Indexes accessible device files from Downloads and Documents + user-selected SAF folders.
   - `LibraryFileTile`: List tile with solid badge, formatted timestamp and size, and floating popup menu (`Edit`, `Share / Copy`, `File info`, `Delete`).
4. **Bug Fixes**:
   - Resolved isolate unsendable object error in `OfficeViewer`.
   - Fixed `FilePicker.getDirectoryPath()` call.
5. **Verification**:
   - `flutter analyze`: 0 issues.
   - `flutter test`: 28 tests passing.
   - APK built and installed via USB ADB to device `SSOJMJMBDQVWM7UK`.

### Files Created/Modified
- `lib/presentation/widgets/file_type_badge.dart`
- `lib/presentation/providers/library_provider.dart`
- `lib/presentation/screens/home/recents_screen.dart`
- `lib/presentation/screens/home/library_file_tile.dart`
- `lib/presentation/screens/home/home_screen.dart`
- `lib/presentation/screens/viewers/office/office_viewer.dart`
- `test/widget_test.dart`
- `PHASE_LOG.md`

---

## Phase 9 — V2 On-Device Editors & PPTX Media Rendering
- **Date**: 2026-09-13
- **Status**: Completed
- **Target**: On-device editors for PPTX, Images, and Videos adhering to the Golden Save Rule (§1.1), plus PPTX slide image extraction and rendering.

### What Was Built
1. **PPTX Embedded Media & Images**:
   - Fixed slide relationship target path normalization (`/ppt/media/`, `../media/`, and `media/` mapped accurately to archive entries).
   - Displayed slide media images in a responsive horizontal gallery card inside each slide in `OfficeViewer`.
2. **PPTX On-Device Slide Editor**:
   - Added "Edit Slide" action on slide headers.
   - Bottom sheet modal for editing slide title and bullet points.
   - In-memory XML update of slide elements (`<a:t>`) and pure-Dart `ZipEncoder` archive re-packing.
   - Golden Save Rule compliance: writes to `<name> (edited).pptx` without altering original.
3. **Image Editor (`ImageEditorScreen`)**:
   - Aspect ratio cropping (Free, 1:1, 4:3, 16:9) using `image_crop_plus`.
   - Live color correction filter (Brightness, Contrast, Saturation) with real-time UI preview and `img.adjustColor` raster export via `package:image`.
   - 90° clockwise/counter-clockwise rotation and horizontal flip.
   - Text overlay with customizable text, color, and size.
   - Safe export saving to `<name> (edited).jpg` / `.png`.
   - Integrated into `ImageViewer` toolbar and Home library tile popup menu.
4. **Video Trimmer / Editor (`VideoEditorScreen`)**:
   - Video playback preview with position and duration readout.
   - Timeline range slider for trimming start and end timestamps.
   - Save trimmed segment to `<name> (edited).mp4`.
   - Integrated into `VideoPlayerScreen` toolbar and Home library tile popup menu.
5. **Quality & Verification**:
   - `flutter analyze`: 0 issues.
   - `flutter test`: All 28 unit and widget tests passing.
   - Debug APK compiled and installed to USB device `SSOJMJMBDQVWM7UK`.

### Files Created/Modified
- `lib/presentation/screens/editor/image_editor_screen.dart`
- `lib/presentation/screens/editor/video_editor_screen.dart`
- `lib/presentation/screens/viewers/office/office_viewer.dart`
- `lib/presentation/screens/viewers/image/image_viewer.dart`
- `lib/presentation/screens/viewers/video/video_player_screen.dart`
- `lib/presentation/screens/home/library_file_tile.dart`
- `pubspec.yaml`
- `PHASE_LOG.md`

---

## Task 1 — Universal In-Place Text Editing (Docs, Code, HTML, Text)
- **Date**: 2026-09-13
- **Status**: Completed
- **Target**: Universal in-place text editing for TXT, MD, CSV, JSON, XML, all code formats, HTML source mode, and DOCX paragraphs with dirty tracking, discard confirmation, find-and-replace, and Golden Save Rule.

### What Was Built
1. **ViewerShell Persistent Edit Toggle & Dirty Tracking**:
   - Added persistent "Edit" toggle button in the AppBar (pencil icon, accent teal when active) for every editable format: TXT, MD, CSV, JSON, XML, all code, HTML (source mode), DOCX.
   - Read-only formats (PDF before Task 4, EPUB, audio, video player, archive, hex) keep no edit button.
   - App bar displays a prominent Save button when editing.
   - Dirty tracking: Intercepts back navigation / pop via `PopScope` and edit toggle when changes are unsaved, prompting: `Discard changes? [Discard] [Keep editing]` (edit_v2 §5.3).
2. **Text / Code / CSV / JSON / XML / HTML-Source In-Place Editor**:
   - Implemented `SyntaxHighlightingController` extending `TextEditingController`: syntax highlighting stays live in real-time as the user types.
   - Tap-to-position caret lands exactly where tapped mid-file in both wrap ON and OFF modes.
   - Synchronized line number gutter that scales and scrolls alongside text.
   - Full find & replace panel with working **Replace** and **Replace All** with real-time match highlighting.
   - Golden Save Rule compliance: writes to `<name> (edited).<ext>` (appending `(2)`, `(3)` on collision) preserving encoding; original files are never modified.
3. **DOCX In-Place Paragraph Editor & XML Manipulation**:
   - Implemented `DocxXmlEditor`: parses, updates, splits, and merges `<w:p>` nodes while preserving run formatting (`<w:rPr>`) and paragraph properties (`<w:pPr>`).
   - Tapping any paragraph in preview makes it an inline editable field with direct XML binding.
   - "Insert paragraph after" button (`+`) inserts a new paragraph with inherited styles.
   - "Merge with previous" and split actions preserve untouched document nodes.
   - Save updates `word/document.xml` in the zip archive and writes `<name> (edited).docx`, leaving original files untouched.
4. **HTML & Markdown Source Editing**:
   - Markdown source mode is editable in-place; rendered view remains pristine when viewing.
   - HTML source mode allows full in-place editing; rendered WebView mode remains secure and offline.
5. **Quality & Test Verification**:
   - `flutter analyze`: 0 issues.
   - `flutter test`: All 39 tests passing (added 11 new tests for DOCX XML split/merge, Find & Replace counts/replacement, caret wrap toggle).
   - Debug APK compiled and installed to USB device `SSOJMJMBDQVWM7UK`.

### Files Created/Modified
- `fix_v2_1.txt`
- `lib/presentation/widgets/viewer_shell.dart`
- `lib/presentation/widgets/in_viewer_find_bar.dart`
- `lib/presentation/screens/viewers/text_code/syntax_highlighting_controller.dart`
- `lib/presentation/screens/viewers/text_code/encoding_helper.dart`
- `lib/presentation/screens/viewers/text_code/text_code_viewer.dart`
- `lib/presentation/screens/viewers/office/docx_xml_editor.dart`
- `lib/presentation/screens/viewers/office/office_viewer.dart`
- `test/unit/docx_editor_test.dart`
- `test/unit/find_replace_test.dart`
- `test/unit/text_editor_test.dart`
- `PHASE_LOG.md`


