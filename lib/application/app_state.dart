import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../domain/campus.dart';

class AppState {
  final bool demo, dark;
  final String category, query;
  final double simSpeed;
  const AppState({
    this.demo = true,
    this.dark = false,
    this.category = 'All',
    this.query = '',
    this.simSpeed = 1.0,
  });
  AppState copy({
    bool? demo,
    bool? dark,
    String? category,
    String? query,
    double? simSpeed,
  }) => AppState(
    demo: demo ?? this.demo,
    dark: dark ?? this.dark,
    category: category ?? this.category,
    query: query ?? this.query,
    simSpeed: simSpeed ?? this.simSpeed,
  );
}

class AppController extends Notifier<AppState> {
  @override
  AppState build() => const AppState();
  void update(AppState value) => state = value;
}

final appProvider = NotifierProvider<AppController, AppState>(
  AppController.new,
);
final demoSearchProvider = Provider<List<CampusPlace>>((ref) {
  final s = ref.watch(appProvider);
  return demoPlaces
      .where(
        (p) =>
            (s.category == 'All' || p.category == s.category) &&
            '${p.name} ${p.category} ${p.facilities.join(' ')}'
                .toLowerCase()
                .contains(s.query.toLowerCase()),
      )
      .toList();
});
const forest = Color(0xFF163F36);
const lime = Color(0xFFD5EF87);
const paper = Color(0xFFF6F7F2);
ThemeData campusTheme(bool dark) => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: forest,
    brightness: dark ? Brightness.dark : Brightness.light,
  ),
  scaffoldBackgroundColor: dark ? const Color(0xFF14231F) : paper,
  fontFamily: 'Roboto',
  appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: dark ? const Color(0xFF20352E) : Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: forest,
      foregroundColor: Colors.white,
      minimumSize: const Size(48, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: dark ? const Color(0xFF20352E) : Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  ),
);
