import 'package:flutter/material.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../training/domain/routine_generator.dart';
import '../../../training/presentation/widgets/routine_preview_widgets.dart';
import '../../../../core/notifications/notification_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/param_chips.dart';
import '../../../../core/utils/input_limits.dart';
part 'onboarding_identity_body.dart';
part 'onboarding_goal_reminders.dart';
part 'onboarding_routine.dart';

String _hhmm(int m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

/// Encabezado común de las páginas del onboarding: icono, título y bajada.
class OnboardingHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? step;

  const OnboardingHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.step,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accentOf(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accentOf(context), size: 26),
            ),
            if (step != null) ...[
              const Spacer(),
              Text(
                step!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 14,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
