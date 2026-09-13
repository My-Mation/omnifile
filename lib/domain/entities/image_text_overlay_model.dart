import 'package:flutter/material.dart';

/// Represents an editable text block overlay positioned in original image coordinate space.
class ImageTextBlock {
  final String id;
  Rect rect;
  String text;
  double fontSize;
  Color textColor;
  Color backgroundColor;
  bool isCoverOriginal;
  bool isManual;

  ImageTextBlock({
    required this.id,
    required this.rect,
    required this.text,
    required this.fontSize,
    this.textColor = Colors.black,
    this.backgroundColor = Colors.white,
    this.isCoverOriginal = true,
    this.isManual = false,
  });

  ImageTextBlock copyWith({
    String? id,
    Rect? rect,
    String? text,
    double? fontSize,
    Color? textColor,
    Color? backgroundColor,
    bool? isCoverOriginal,
    bool? isManual,
  }) {
    return ImageTextBlock(
      id: id ?? this.id,
      rect: rect ?? this.rect,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      isCoverOriginal: isCoverOriginal ?? this.isCoverOriginal,
      isManual: isManual ?? this.isManual,
    );
  }
}
