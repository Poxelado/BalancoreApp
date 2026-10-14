import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'app.dart';
import 'core/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Si la inicialización falla (sin red, config corrupta, plugin caído),
  // mostramos un aviso en vez de dejar una pantalla en blanco / crash.
  try {
    await Firebase.initializeApp();
    await _initAppCheck();
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('Fallo al inicializar la app: $e');
    runApp(const _StartupErrorApp());
    return;
  }
  // Si más adelante usas FlutterFire CLI, cambia a:
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    const ProviderScope(
      child: BalancoreApp(),
    ),
  );
}

/// Activa Firebase App Check (best-effort).
///
/// En release usa Play Integrity en Android y App Attest en iOS; en debug un
/// proveedor de prueba, cuyo token hay que registrar en la consola de Firebase
/// para que las peticiones cuenten como válidas. Si falla, no rompe el arranque:
/// el exigir o no App Check se decide desde la consola de Firebase.
Future<void> _initAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider:
          kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
    );
  } catch (e) {
    debugPrint('App Check no disponible: $e');
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48),
                SizedBox(height: 16),
                Text(
                  'No se pudo iniciar Balancore',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Revisa tu conexión a internet e inténtalo de nuevo.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
