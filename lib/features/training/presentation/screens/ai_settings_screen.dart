import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ai/ai_key_store.dart';

/// Configuración de la IA: el usuario trae su propia clave de Gemini.
///
/// La clave se guarda solo en este dispositivo y no se sincroniza. La app
/// funciona igual sin ella (usa el generador de reglas).
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final _ctrl = TextEditingController();
  bool _hasKey = false;
  bool _loaded = false;
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final key = await AiKeyStore.read();
    if (!mounted) return;
    setState(() {
      _hasKey = key != null;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _ctrl.text.trim();
    if (key.isEmpty) {
      await AiKeyStore.clear();
    } else {
      await AiKeyStore.save(key);
    }
    if (!mounted) return;
    setState(() => _hasKey = key.isNotEmpty);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          key.isEmpty ? 'Clave eliminada' : 'Clave guardada en este dispositivo',
        ),
      ),
    );
  }

  Future<void> _remove() async {
    await AiKeyStore.clear();
    _ctrl.clear();
    if (!mounted) return;
    setState(() => _hasKey = false);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('IA · Ajustes')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cómo funciona',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'La app genera rutinas con un motor de reglas que funciona '
                    'sin internet. Si añades una clave de Gemini, además se '
                    'consulta al modelo para proponer la rutina.\n\n'
                    'La clave se guarda solo en este dispositivo y no se sube '
                    'a la nube.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Clave de API de Gemini',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _loaded && _hasKey
                  ? 'Ya hay una clave guardada en este dispositivo.'
                  : 'Opcional. Consíguela gratis en Google AI Studio.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ctrl,
              obscureText: _obscured,
              enableSuggestions: false,
              autocorrect: false,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_\-]')),
              ],
              decoration: InputDecoration(
                labelText: 'Clave (AIza…)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _obscured ? 'Ver clave' : 'Ocultar clave',
                  icon: Icon(
                    _obscured
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscured = !_obscured),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _save, child: const Text('Guardar')),
            if (_hasKey) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _remove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Eliminar clave'),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Aviso: al generar con IA se envía tu objetivo, nivel, días por '
              'semana, equipamiento, peso, edad y sexo al servicio de Google '
              'para que el modelo pueda proponer la rutina.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}