import 'package:flutter/material.dart';
import '../theme/open_file_colors.dart';

extension ContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  OpenFileColors get appColors =>
      Theme.of(this).extension<OpenFileColors>() ?? OpenFileColors.dark;
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  Size get screenSize => MediaQuery.sizeOf(this);
}
