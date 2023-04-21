import 'package:flutter/material.dart';

ThemeData dark = ThemeData(
  fontFamily: 'Roboto',
  primaryColor: Color(0xFFffbd5c),
  secondaryHeaderColor: Color(0xFF009f67),
  disabledColor: Color(0xFF6f7275),
  brightness: Brightness.dark,
  hintColor: Color(0xFFbebebe),
  cardColor: Colors.black,
  textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Color(0xFFffbd5c))), colorScheme: ColorScheme.dark(primary: Color(0xFFffbd5c), secondary: Color(0xFFffbd5c)).copyWith(error: Color(0xFFdd3135)),
);
