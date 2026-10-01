import 'package:flutter/material.dart';
import '../../domain/exercise.dart';

/// Pantalla simple de catálogo (si aún no tienes la biblioteca completa).
class ExerciseLibraryScreen extends StatelessWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final list = ExerciseCatalog.builtIn;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca de ejercicios'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, i) {
          final e = list[i];
          return Card(
            child: ListTile(
              title: Text(e.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${e.muscleGroup} · ${e.equipment}'),
            ),
          );
        },
      ),
    );
  }
}
