import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Centro de ayuda. Por ahora con preguntas frecuentes locales; el centro de
/// soporte web se conectará aquí más adelante.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayuda y soporte')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(Icons.public, color: accentOf(context)),
              title: const Text('Centro de ayuda web'),
              subtitle: const Text('Próximamente'),
              trailing: const Icon(Icons.hourglass_empty),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Preguntas frecuentes',
            style: TextStyle(fontWeight: FontWeight.w700, color: accentOf(context)),
          ),
          const SizedBox(height: 8),
          _faq(
            context,
            '¿Cómo registro un entrenamiento?',
            'Ve a la pestaña Rutina, elige un día o crea una rutina, y toca Iniciar. '
                'Al terminar, tu sesión queda en el historial del Perfil.',
          ),
          _faq(
            context,
            '¿Cómo agrego comidas?',
            'En Nutrición puedes buscar alimentos, escanear/registrar por porción y '
                'guardar tus favoritos para reutilizarlos.',
          ),
          _faq(
            context,
            '¿Cómo cambio mi peso o mis datos?',
            'En Perfil toca tu foto o el lápiz, o entra a Ajustes · Cuenta · Perfil. '
                'Ahí ajustas peso, altura, objetivo y macros.',
          ),
          _faq(
            context,
            '¿Cómo elimino mi cuenta?',
            'Ajustes · Eliminar cuenta. Se borran tu perfil y todos tus registros de '
                'forma permanente.',
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(Icons.mail_outline, color: accentOf(context)),
              title: const Text('Escríbenos'),
              subtitle: const Text('soporte@balancore.app'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _faq(BuildContext context, String q, String a) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(q, style: const TextStyle(fontWeight: FontWeight.w600)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            a,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
