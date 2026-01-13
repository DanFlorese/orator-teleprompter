import 'package:flutter/material.dart';

const Color redOrator = Color(0xFFFF0000); 
const Color whitePrimary = Color(0xFFFFFFFF);
const Color blackBackground = Color(0xFF0F0F0F); 
const Color graySurface = Color(0xFF272727); 

final ThemeData oratorTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: redOrator,
  scaffoldBackgroundColor: blackBackground,
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: redOrator,
      foregroundColor: whitePrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
);