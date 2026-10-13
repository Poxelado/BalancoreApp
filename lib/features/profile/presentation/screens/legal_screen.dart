import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

enum LegalDoc { privacy, terms }

/// Pantalla de texto legal (Política de privacidad / Términos y condiciones).
class LegalScreen extends StatelessWidget {
  final LegalDoc doc;

  const LegalScreen({super.key, required this.doc});

  String get _title =>
      doc == LegalDoc.privacy ? 'Política de privacidad' : 'Términos y condiciones';

  @override
  Widget build(BuildContext context) {
    const updated = 'Última actualización: octubre 2026';
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            updated,
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
          ),
          const SizedBox(height: 20),
          ...(doc == LegalDoc.privacy ? _privacy(context) : _terms(context)),
        ],
      ),
    );
  }

  List<Widget> _privacy(BuildContext context) => [
        _h(context, 'Qué datos guardamos'),
        _p(context,
            'Balancore guarda tu perfil (nombre, sexo, edad, peso, altura y objetivo), '
            'tus rutinas, tus registros de entrenamiento, tus registros de peso y tus '
            'registros diarios de comidas. Todo se asocia a tu cuenta.'),
        _h(context, 'Dónde se guardan'),
        _p(context,
            'La información se almacena en Firebase (Google) asociada a tu usuario. '
            'El acceso está restringido a tu propia cuenta mediante reglas de seguridad.'),
        _h(context, 'Qué no hacemos'),
        _p(context,
            'No vendemos ni cedemos tu información a terceros. No mostramos publicidad '
            'personalizada. No compartimos tus datos con otros usuarios.'),
        _h(context, 'Correo y contraseña'),
        _p(context,
            'Tu correo se usa para iniciar sesión y para enviarte verificaciones y '
            'restablecimientos de contraseña. La contraseña la administra Firebase; '
            'Balancore nunca la almacena en texto plano.'),
        _h(context, 'Asistente con IA'),
        _p(context,
            'Si usas el generador de rutinas con IA, algunos datos de tu perfil '
            '(objetivo, nivel, días disponibles) se envían al proveedor del modelo para '
            'generar la sugerencia. No se envían datos identificatorios.'),
        _h(context, 'Tus derechos'),
        _p(context,
            'Puedes editar o eliminar tus datos en cualquier momento. Desde Ajustes '
            'puedes cerrar sesión o eliminar tu cuenta por completo, lo que borra tu '
            'perfil y registros de forma permanente.'),
      ];

  List<Widget> _terms(BuildContext context) => [
        _h(context, 'Aceptación'),
        _p(context,
            'Al crear una cuenta y usar Balancore aceptas estos términos. Si no estás '
            'de acuerdo, no uses la aplicación.'),
        _h(context, 'Uso de la app'),
        _p(context,
            'Balancore es una herramienta de apoyo para registrar entrenamiento y '
            'alimentación. No reemplaza la opinión de un profesional de la salud, '
            'nutricionista o entrenador certificado.'),
        _h(context, 'Tu cuenta'),
        _p(context,
            'Eres responsable de mantener la confidencialidad de tu contraseña y de la '
            'actividad de tu cuenta. No compartas tu acceso con terceros.'),
        _h(context, 'Contenido y sugerencias'),
        _p(context,
            'Las rutinas, estimaciones de calorías, macros y sugerencias son referenciales '
            'y pueden no ajustarse a tu situación particular. Consulta a un profesional '
            'antes de iniciar un programa de entrenamiento o alimentación.'),
        _h(context, 'Limitación de responsabilidad'),
        _p(context,
            'Balancore se entrega "tal cual". No nos hacemos responsables de lesiones, '
            'problemas de salud o decisiones tomadas a partir de la información mostrada '
            'en la app.'),
        _h(context, 'Cambios'),
        _p(context,
            'Podemos actualizar estos términos. Te avisaremos dentro de la app cuando '
            'haya cambios importantes.'),
      ];

  Widget _h(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: accentOf(context),
          ),
        ),
      );

  Widget _p(BuildContext context, String text) => Text(
        text,
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
}
