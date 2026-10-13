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
          if (doc == LegalDoc.terms) ...[
            _callout(
              context,
              'Balancore es una herramienta de apoyo para mejorar tus hábitos. '
              'No es un servicio médico ni nutricional y no nos hacemos '
              'responsables por decisiones, indicaciones o resultados de terceros '
              'o agentes externos a la app.',
            ),
            const SizedBox(height: 8),
          ],
          ...(doc == LegalDoc.privacy ? _privacy(context) : _terms(context)),
        ],
      ),
    );
  }

  Widget _callout(BuildContext context, String text) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accentOf(context).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentOf(context).withValues(alpha: 0.4)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      );

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
        _h(context, '1. Aceptación'),
        _p(context,
            'Al crear una cuenta, iniciar sesión o usar Balancore aceptas estos '
            'Términos y Condiciones y la Política de privacidad. Si no estás de acuerdo, '
            'no uses la aplicación. Si la usas en nombre de otra persona, declaras contar '
            'con su autorización para aceptar estos términos.'),
        _h(context, '2. Qué ofrece Balancore'),
        _p(context,
            'Balancore es una herramienta de apoyo para registrar y organizar tu '
            'entrenamiento, tu alimentación y tus hábitos (peso, agua y sueño). Su '
            'propósito es ayudarte a construir y mantener mejores hábitos de vida. Todas '
            'las estimaciones (calorías, macronutrientes, agua y progreso) son '
            'referenciales y se calculan con fórmulas generales a partir de los datos '
            'que tú ingresas.'),
        _h(context, '3. No es un servicio de salud'),
        _p(context,
            'Balancore NO es un servicio médico, nutricional ni de entrenamiento '
            'profesional, y no sustituye la evaluación, diagnóstico, tratamiento o '
            'consejo de un profesional calificado (médico, nutricionista, kinesiólogo, '
            'entrenador u otro). No diseñes, inicies ni modifiques un plan de '
            'alimentación, suplementación o entrenamiento basándote únicamente en lo que '
            'muestra la app. Consulta a un profesional, sobre todo si tienes una '
            'condición médica, estás embarazada o amamantando, eres menor de edad, o '
            'tomas medicamentos.'),
        _h(context, '4. Tu responsabilidad'),
        _p(context,
            'Solo tú decides qué información ingresas y cómo actúas a partir de ella. '
            'Eres responsable de: (a) la veracidad de los datos que registras; (b) '
            'interpretar la información con criterio y responsabilidad; (c) detener '
            'cualquier actividad si sientes dolor, mareo o malestar; (d) mantener la '
            'confidencialidad de tu contraseña y la actividad de tu cuenta; y (e) usar '
            'la app conforme a la ley y a estos términos.'),
        _h(context, '5. Sin garantía de resultados'),
        _p(context,
            'Balancore entrega estimaciones y sugerencias automatizadas. No garantizamos '
            'resultados específicos (pérdida o aumento de peso, composición corporal, '
            'marcas deportivas, mejoras de salud ni ningún otro). Los resultados dependen '
            'de factores ajenos a la app y fuera de nuestro control, como tu genética, tu '
            'constancia, tu estado de salud, tus decisiones y tus circunstancias '
            'personales.'),
        _h(context, '6. Limitación de responsabilidad: terceros y agentes externos'),
        _p(context,
            'En la máxima medida permitida por la ley, Balancore y sus autores, '
            'desarrolladores y colaboradores no seremos responsables de daños directos, '
            'indirectos, incidentales, especiales o consecuentes derivados del uso o de '
            'la imposibilidad de usar la app.\n\n'
            'En particular, NO asumimos responsabilidad alguna por hechos, decisiones o '
            'resultados producidos por terceros o por agentes externos que desconocemos o '
            'no controlamos, incluyendo, sin limitarse a: (a) consejos, indicaciones o '
            'tratamientos de profesionales, entrenadores, nutricionistas, gimnasios, '
            'coaches o cualquier tercero; (b) planes, dietas, suplementos o productos '
            'adquiridos o seguidos por fuera de la app; (c) lesiones, problemas de salud '
            'o resultados derivados de rutinas, cargas o indicaciones que tú o un tercero '
            'interpreten u obtengan a partir de la app; (d) información errónea, '
            'incompleta o desactualizada ingresada por el usuario; y (e) interrupciones, '
            'errores o pérdidas causadas por servicios de terceros (por ejemplo, '
            'Firebase/Google, el sistema operativo, tu dispositivo o tu conexión a '
            'internet).\n\n'
            'En resumen: te entregamos la herramienta y te acompañamos en la construcción '
            'de mejores hábitos, pero las decisiones y sus consecuencias son tuyas y no '
            'de Balancore.'),
        _h(context, '7. Uso adecuado'),
        _p(context,
            'Te comprometes a no usar la app con fines ilícitos, a no intentar vulnerar '
            'su seguridad o la de otros usuarios, a no publicar contenido ofensivo ni de '
            'terceros sin autorización, y a no reproducir, copiar ni explotar '
            'comercialmente la app sin permiso. Podemos suspender o cerrar las cuentas '
            'que incumplan estos términos.'),
        _h(context, '8. Contenido del usuario'),
        _p(context,
            'El contenido que creas (rutinas, recetas, registros y notas) es tuyo. Nos '
            'otorgas una autorización limitada para almacenarlo y mostrártelo dentro de '
            'la app. Eres responsable de que ese contenido no infrinja derechos de '
            'terceros.'),
        _h(context, '9. Propiedad intelectual'),
        _p(context,
            'Balancore, su nombre, logo, diseño, código y contenidos propios pertenecen a '
            'sus autores y están protegidos por la ley. Estos términos no te ceden '
            'derechos sobre ellos.'),
        _h(context, '10. Disponibilidad y cambios'),
        _p(context,
            'La app se ofrece «tal cual» y «según disponibilidad». Podemos modificarla, '
            'suspenderla o discontinuarla, total o parcialmente, sin garantizar un '
            'funcionamiento ininterrumpido o libre de errores. Podemos actualizar estos '
            'términos; ante cambios importantes te avisaremos dentro de la app y el uso '
            'continuado implicará su aceptación.'),
        _h(context, '11. Terminación'),
        _p(context,
            'Puedes dejar de usar la app y eliminar tu cuenta en cualquier momento desde '
            'Ajustes. Al eliminar la cuenta, tus datos se borran de forma permanente, '
            'salvo aquello que debamos conservar por obligación legal.'),
        _h(context, '12. Ley aplicable y contacto'),
        _p(context,
            'Estos términos se rigen por las leyes de la República de Chile. Cualquier '
            'duda sobre ellos puedes escribirnos a soporte@balancore.app.'),
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
