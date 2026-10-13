import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';

/// Preferencias de apariencia: modo claro/oscuro/sistema y color de la app.
class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(themePreferencesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tema')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Apariencia',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: accentOf(context))),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_outlined),
                label: Text('Sistema'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('Claro'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('Oscuro'),
              ),
            ],
            selected: {prefs.themeMode},
            onSelectionChanged: (s) => ref
                .read(themePreferencesProvider.notifier)
                .setThemeMode(s.first),
          ),
          const SizedBox(height: 28),
          Text('Color de la app',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: accentOf(context))),
          const SizedBox(height: 4),
          Text(
            'Se usa como acento en botones, textos e íconos.',
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: AppColorTheme.values.map((colorTheme) {
              final selected = prefs.colorTheme == colorTheme;
              return Semantics(
                button: true,
                selected: selected,
                label: colorTheme.label,
                child: GestureDetector(
                  onTap: () => ref
                      .read(themePreferencesProvider.notifier)
                      .setColorTheme(colorTheme),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: colorTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: colorTheme.primary
                                        .withValues(alpha: 0.45),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: selected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 22)
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        colorTheme.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                          color: selected ? accentOf(context) : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
