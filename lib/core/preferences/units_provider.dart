import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kUnitsKey = 'balancore_units';

const double _kgPerLb = 0.45359237;
const double _cmPerIn = 2.54;

/// Sistema de unidades que el usuario elige para ver/ingresar peso y altura.
/// Internamente la app siempre guarda y calcula en kg y cm.
enum UnitSystem { metric, imperial }

extension UnitSystemX on UnitSystem {
  String get label =>
      this == UnitSystem.metric ? 'Métrico' : 'Imperial';

  /// Unidades que muestra, p. ej. "kg · cm".
  String get shortLabel =>
      this == UnitSystem.metric ? 'kg · cm' : 'lb · in';

  String get weightUnit => this == UnitSystem.metric ? 'kg' : 'lb';

  String get heightUnit => this == UnitSystem.metric ? 'cm' : 'in';

  /// kg → valor para mostrar.
  double weightToDisplay(double kg) =>
      this == UnitSystem.metric ? kg : kg / _kgPerLb;

  /// valor mostrado → kg.
  double weightToKg(double value) =>
      this == UnitSystem.metric ? value : value * _kgPerLb;

  /// cm → valor para mostrar.
  double heightToDisplay(double cm) =>
      this == UnitSystem.metric ? cm : cm / _cmPerIn;

  /// valor mostrado → cm.
  double heightToCm(double value) =>
      this == UnitSystem.metric ? value : value * _cmPerIn;

  /// "72.5 kg" (o "160 lb") ya en la unidad elegida.
  String formatWeight(double kg, {int decimals = 1}) =>
      '${weightToDisplay(kg).toStringAsFixed(decimals)} $weightUnit';

  /// "178 cm" (o "70 in").
  String formatHeight(double cm, {int decimals = 0}) =>
      '${heightToDisplay(cm).toStringAsFixed(decimals)} $heightUnit';
}

class UnitsNotifier extends StateNotifier<UnitSystem> {
  UnitsNotifier() : super(UnitSystem.metric) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_kUnitsKey) == 'imperial'
        ? UnitSystem.imperial
        : UnitSystem.metric;
  }

  Future<void> set(UnitSystem units) async {
    state = units;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUnitsKey, units.name);
  }
}

final unitsProvider =
    StateNotifierProvider<UnitsNotifier, UnitSystem>((ref) => UnitsNotifier());
