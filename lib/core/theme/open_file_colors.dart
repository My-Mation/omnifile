import 'package:flutter/material.dart';

@immutable
class OpenFileColors extends ThemeExtension<OpenFileColors> {
  // Surfaces
  final Color surfaceRoot;
  final Color surfaceApp;
  final Color surfaceCard;
  final Color surfaceCardHover;
  final Color surfaceElevated;
  final Color surfaceInput;
  final Color divider;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;

  // Accent
  final Color accentPrimary;
  final Color accentPrimaryDim;
  final Color accentOnAccent;

  // States
  final Color stateError;
  final Color stateErrorContainer;
  final Color stateWarning;
  final Color stateWarningContainer;
  final Color stateSuccess;

  // Overlays
  final Color overlayScrim;
  final Color overlayControls;
  final Color overlayFullscreen;

  // Semantic File-Type Colors
  final Color filePdf;
  final Color fileDocument;
  final Color fileSpreadsheet;
  final Color filePresentation;
  final Color fileCode;
  final Color fileText;
  final Color fileMarkdown;
  final Color fileArchive;
  final Color fileImage;
  final Color fileVideo;
  final Color fileAudio;
  final Color fileHtml;
  final Color fileUnknown;

  const OpenFileColors({
    required this.surfaceRoot,
    required this.surfaceApp,
    required this.surfaceCard,
    required this.surfaceCardHover,
    required this.surfaceElevated,
    required this.surfaceInput,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.accentPrimary,
    required this.accentPrimaryDim,
    required this.accentOnAccent,
    required this.stateError,
    required this.stateErrorContainer,
    required this.stateWarning,
    required this.stateWarningContainer,
    required this.stateSuccess,
    required this.overlayScrim,
    required this.overlayControls,
    required this.overlayFullscreen,
    required this.filePdf,
    required this.fileDocument,
    required this.fileSpreadsheet,
    required this.filePresentation,
    required this.fileCode,
    required this.fileText,
    required this.fileMarkdown,
    required this.fileArchive,
    required this.fileImage,
    required this.fileVideo,
    required this.fileAudio,
    required this.fileHtml,
    required this.fileUnknown,
  });

  static const OpenFileColors dark = OpenFileColors(
    surfaceRoot: Color(0xFF000000),
    surfaceApp: Color(0xFF0A0A0A),
    surfaceCard: Color(0xFF141414),
    surfaceCardHover: Color(0xFF1E1E1E),
    surfaceElevated: Color(0xFF242424),
    surfaceInput: Color(0xFF181818),
    divider: Color(0xFF2C2C2C),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF9E9E9E),
    textDisabled: Color(0xFF555555),
    accentPrimary: Color(0xFFFFFFFF),
    accentPrimaryDim: Color(0xFFCCCCCC),
    accentOnAccent: Color(0xFF000000),
    stateError: Color(0xFFDCDCDC),
    stateErrorContainer: Color(0xFF222222),
    stateWarning: Color(0xFFBDBDBD),
    stateWarningContainer: Color(0xFF222222),
    stateSuccess: Color(0xFFEEEEEE),
    overlayScrim: Color(0x99000000),
    overlayControls: Color(0x8C000000),
    overlayFullscreen: Color(0xD9000000),
    filePdf: Color(0xFFE0E0E0),
    fileDocument: Color(0xFFD4D4D4),
    fileSpreadsheet: Color(0xFFC8C8C8),
    filePresentation: Color(0xFFBCBCBC),
    fileCode: Color(0xFFFFFFFF),
    fileText: Color(0xFFE8E8E8),
    fileMarkdown: Color(0xFFDADADA),
    fileArchive: Color(0xFFB4B4B4),
    fileImage: Color(0xFFEAEAEA),
    fileVideo: Color(0xFFD0D0D0),
    fileAudio: Color(0xFFBEBEBE),
    fileHtml: Color(0xFFECECEC),
    fileUnknown: Color(0xFF888888),
  );

  static const OpenFileColors light = OpenFileColors(
    surfaceRoot: Color(0xFFFFFFFF),
    surfaceApp: Color(0xFFF7F7F7),
    surfaceCard: Color(0xFFFFFFFF),
    surfaceCardHover: Color(0xFFF0F0F0),
    surfaceElevated: Color(0xFFECECEC),
    surfaceInput: Color(0xFFF2F2F2),
    divider: Color(0xFFD8D8D8),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF555555),
    textDisabled: Color(0xFF9E9E9E),
    accentPrimary: Color(0xFF000000),
    accentPrimaryDim: Color(0xFF333333),
    accentOnAccent: Color(0xFFFFFFFF),
    stateError: Color(0xFF222222),
    stateErrorContainer: Color(0xFFE8E8E8),
    stateWarning: Color(0xFF444444),
    stateWarningContainer: Color(0xFFE8E8E8),
    stateSuccess: Color(0xFF111111),
    overlayScrim: Color(0x66000000),
    overlayControls: Color(0x8C000000),
    overlayFullscreen: Color(0xD9000000),
    filePdf: Color(0xFF1A1A1A),
    fileDocument: Color(0xFF2A2A2A),
    fileSpreadsheet: Color(0xFF333333),
    filePresentation: Color(0xFF3D3D3D),
    fileCode: Color(0xFF111111),
    fileText: Color(0xFF222222),
    fileMarkdown: Color(0xFF2E2E2E),
    fileArchive: Color(0xFF484848),
    fileImage: Color(0xFF181818),
    fileVideo: Color(0xFF252525),
    fileAudio: Color(0xFF353535),
    fileHtml: Color(0xFF1F1F1F),
    fileUnknown: Color(0xFF666666),
  );

  @override
  OpenFileColors copyWith({
    Color? surfaceRoot,
    Color? surfaceApp,
    Color? surfaceCard,
    Color? surfaceCardHover,
    Color? surfaceElevated,
    Color? surfaceInput,
    Color? divider,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? accentPrimary,
    Color? accentPrimaryDim,
    Color? accentOnAccent,
    Color? stateError,
    Color? stateErrorContainer,
    Color? stateWarning,
    Color? stateWarningContainer,
    Color? stateSuccess,
    Color? overlayScrim,
    Color? overlayControls,
    Color? overlayFullscreen,
    Color? filePdf,
    Color? fileDocument,
    Color? fileSpreadsheet,
    Color? filePresentation,
    Color? fileCode,
    Color? fileText,
    Color? fileMarkdown,
    Color? fileArchive,
    Color? fileImage,
    Color? fileVideo,
    Color? fileAudio,
    Color? fileHtml,
    Color? fileUnknown,
  }) {
    return OpenFileColors(
      surfaceRoot: surfaceRoot ?? this.surfaceRoot,
      surfaceApp: surfaceApp ?? this.surfaceApp,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceCardHover: surfaceCardHover ?? this.surfaceCardHover,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceInput: surfaceInput ?? this.surfaceInput,
      divider: divider ?? this.divider,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      accentPrimary: accentPrimary ?? this.accentPrimary,
      accentPrimaryDim: accentPrimaryDim ?? this.accentPrimaryDim,
      accentOnAccent: accentOnAccent ?? this.accentOnAccent,
      stateError: stateError ?? this.stateError,
      stateErrorContainer: stateErrorContainer ?? this.stateErrorContainer,
      stateWarning: stateWarning ?? this.stateWarning,
      stateWarningContainer: stateWarningContainer ?? this.stateWarningContainer,
      stateSuccess: stateSuccess ?? this.stateSuccess,
      overlayScrim: overlayScrim ?? this.overlayScrim,
      overlayControls: overlayControls ?? this.overlayControls,
      overlayFullscreen: overlayFullscreen ?? this.overlayFullscreen,
      filePdf: filePdf ?? this.filePdf,
      fileDocument: fileDocument ?? this.fileDocument,
      fileSpreadsheet: fileSpreadsheet ?? this.fileSpreadsheet,
      filePresentation: filePresentation ?? this.filePresentation,
      fileCode: fileCode ?? this.fileCode,
      fileText: fileText ?? this.fileText,
      fileMarkdown: fileMarkdown ?? this.fileMarkdown,
      fileArchive: fileArchive ?? this.fileArchive,
      fileImage: fileImage ?? this.fileImage,
      fileVideo: fileVideo ?? this.fileVideo,
      fileAudio: fileAudio ?? this.fileAudio,
      fileHtml: fileHtml ?? this.fileHtml,
      fileUnknown: fileUnknown ?? this.fileUnknown,
    );
  }

  @override
  OpenFileColors lerp(ThemeExtension<OpenFileColors>? other, double t) {
    if (other is! OpenFileColors) return this;
    return OpenFileColors(
      surfaceRoot: Color.lerp(surfaceRoot, other.surfaceRoot, t)!,
      surfaceApp: Color.lerp(surfaceApp, other.surfaceApp, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      surfaceCardHover: Color.lerp(surfaceCardHover, other.surfaceCardHover, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceInput: Color.lerp(surfaceInput, other.surfaceInput, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      accentPrimary: Color.lerp(accentPrimary, other.accentPrimary, t)!,
      accentPrimaryDim: Color.lerp(accentPrimaryDim, other.accentPrimaryDim, t)!,
      accentOnAccent: Color.lerp(accentOnAccent, other.accentOnAccent, t)!,
      stateError: Color.lerp(stateError, other.stateError, t)!,
      stateErrorContainer: Color.lerp(stateErrorContainer, other.stateErrorContainer, t)!,
      stateWarning: Color.lerp(stateWarning, other.stateWarning, t)!,
      stateWarningContainer: Color.lerp(stateWarningContainer, other.stateWarningContainer, t)!,
      stateSuccess: Color.lerp(stateSuccess, other.stateSuccess, t)!,
      overlayScrim: Color.lerp(overlayScrim, other.overlayScrim, t)!,
      overlayControls: Color.lerp(overlayControls, other.overlayControls, t)!,
      overlayFullscreen: Color.lerp(overlayFullscreen, other.overlayFullscreen, t)!,
      filePdf: Color.lerp(filePdf, other.filePdf, t)!,
      fileDocument: Color.lerp(fileDocument, other.fileDocument, t)!,
      fileSpreadsheet: Color.lerp(fileSpreadsheet, other.fileSpreadsheet, t)!,
      filePresentation: Color.lerp(filePresentation, other.filePresentation, t)!,
      fileCode: Color.lerp(fileCode, other.fileCode, t)!,
      fileText: Color.lerp(fileText, other.fileText, t)!,
      fileMarkdown: Color.lerp(fileMarkdown, other.fileMarkdown, t)!,
      fileArchive: Color.lerp(fileArchive, other.fileArchive, t)!,
      fileImage: Color.lerp(fileImage, other.fileImage, t)!,
      fileVideo: Color.lerp(fileVideo, other.fileVideo, t)!,
      fileAudio: Color.lerp(fileAudio, other.fileAudio, t)!,
      fileHtml: Color.lerp(fileHtml, other.fileHtml, t)!,
      fileUnknown: Color.lerp(fileUnknown, other.fileUnknown, t)!,
    );
  }
}

extension BuildContextThemeX on BuildContext {
  OpenFileColors get colors =>
      Theme.of(this).extension<OpenFileColors>() ?? OpenFileColors.dark;
}
