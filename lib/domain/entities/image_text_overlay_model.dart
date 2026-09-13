import 'package:flutter/material.dart';

/// Represents an editable text block overlay positioned in original image coordinate space.
class ImageTextBlock {
  final String id;
  Rect rect;
  String text;
  String originalText;
  double fontSize;
  Color textColor;
  Color backgroundColor;
  bool isCoverOriginal;
  bool isManual;
  String? fontFamily;
  FontWeight fontWeight;
  FontStyle fontStyle;

  ImageTextBlock({
    required this.id,
    required this.rect,
    required this.text,
    String? originalText,
    required this.fontSize,
    this.textColor = Colors.black,
    this.backgroundColor = Colors.transparent,
    this.isCoverOriginal = false,
    this.isManual = false,
    this.fontFamily,
    this.fontWeight = FontWeight.normal,
    this.fontStyle = FontStyle.normal,
  }) : originalText = originalText ?? text;

  bool get isModified => text != originalText;

  ImageTextBlock copyWith({
    String? id,
    Rect? rect,
    String? text,
    String? originalText,
    double? fontSize,
    Color? textColor,
    Color? backgroundColor,
    bool? isCoverOriginal,
    bool? isManual,
    String? fontFamily,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
  }) {
    return ImageTextBlock(
      id: id ?? this.id,
      rect: rect ?? this.rect,
      text: text ?? this.text,
      originalText: originalText ?? this.originalText,
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      isCoverOriginal: isCoverOriginal ?? this.isCoverOriginal,
      isManual: isManual ?? this.isManual,
      fontFamily: fontFamily ?? this.fontFamily,
      fontWeight: fontWeight ?? this.fontWeight,
      fontStyle: fontStyle ?? this.fontStyle,
    );
  }
}
