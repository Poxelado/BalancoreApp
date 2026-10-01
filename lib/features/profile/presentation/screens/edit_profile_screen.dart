import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final UserProfile profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  late final TextEditingController _heightController;
  late String _sex;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.profile.displayName ?? '');
    _usernameController =
        TextEditingController(text: widget.profile.username ?? '');
    _bioController = TextEditingController(text: widget.profile.bio ?? '');
    _heightController = TextEditingController(
      text: widget.profile.height.toStringAsFixed(0),
    );
    _sex = widget.profile.sex;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final height = double.tryParse(_heightController.text) ?? widget.profile.height;

      final updated = widget.profile.copyWith(
        displayName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        username: _usernameController.text.trim().replaceAll('@', ''),
        bio: _bioController.text.trim(),
        sex: _sex,
        height: height,
        targetCalories: UserProfile.calculateTMB(
          sex: _sex,
          weight: widget.profile.currentWeight,
          height: height,
          age: widget.profile.age,
          activityLevel: widget.profile.activityLevel,
        ),
      );

      await ref.read(profileRepositoryProvider).saveProfile(updated);
      ref.invalidate(userProfileProvider);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar perfil'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Usuario',
              prefixText: '@',
              border: OutlineInputBorder(),
              helperText: 'Solo letras, números y guiones',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bioController,
            maxLines: 3,
            maxLength: 150,
            decoration: const InputDecoration(
              labelText: 'Biografía',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Sexo', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Masculino', label: Text('Masculino')),
              ButtonSegment(value: 'Femenino', label: Text('Femenino')),
            ],
            selected: {_sex},
            onSelectionChanged: (s) => setState(() => _sex = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _heightController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Altura (cm)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}