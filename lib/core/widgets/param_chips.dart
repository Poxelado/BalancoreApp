import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Sección de parámetros con jerarquía visual común al onboarding y al
/// generador de rutinas: tarjeta suave, barra de acento, título y ayuda.
class ParamSection extends StatelessWidget {
  final String title;
  final String? helper;
  final Widget child;
  final Widget? trailing;
  final bool emphasized;
  final bool dense;

  const ParamSection({
    super.key,
    required this.title,
    required this.child,
    this.helper,
    this.trailing,
    this.emphasized = false,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = accentOf(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, dense ? 12 : 16, 16, dense ? 14 : 18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: emphasized ? 0.9 : 0.5),
          width: emphasized ? 1.2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: emphasized ? 18 : 15,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: emphasized ? 16 : 14.5,
                    letterSpacing: 0.1,
                    color: cs.onSurface,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (helper != null) ...[
            SizedBox(height: dense ? 3 : 5),
            Padding(
              padding: const EdgeInsets.only(left: 11),
              child: Text(
                helper!,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
          SizedBox(height: dense ? 10 : 12),
          child,
        ],
      ),
    );
  }
}

/// Chip de selección única. Conserva [ChoiceChip] para accesibilidad y tests.
class ParamChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;
  final bool showCheckmark;

  const ParamChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
    this.showCheckmark = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.03 : 1,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: showCheckmark,
        elevation: 0,
        pressElevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedColor: Theme.of(context).colorScheme.primary,
        side: chipSide(context, selected),
        shape: const StadiumBorder(),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 8 : 10,
        ),
        labelStyle: chipLabelStyle(context, selected, compact),
      ),
    );
  }
}

/// Chip de selección múltiple con check visible para dejar claro que se
/// pueden marcar varias opciones.
class ParamFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final bool compact;

  const ParamFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.03 : 1,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: onSelected,
        showCheckmark: true,
        checkmarkColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        pressElevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedColor: Theme.of(context).colorScheme.primary,
        side: chipSide(context, selected),
        shape: const StadiumBorder(),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 8 : 10,
        ),
        labelStyle: chipLabelStyle(context, selected, compact),
      ),
    );
  }
}

BorderSide chipSide(BuildContext context, bool selected) {
  final cs = Theme.of(context).colorScheme;
  return BorderSide(
    color: selected
        ? cs.primary
        : cs.outlineVariant.withValues(alpha: 0.7),
  );
}

TextStyle chipLabelStyle(BuildContext context, bool selected, bool compact) {
  final cs = Theme.of(context).colorScheme;
  return TextStyle(
    fontSize: compact ? 13 : 14,
    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
    color: selected ? cs.onPrimary : cs.onSurface,
  );
}

/// Etiqueta pequeña para señalar que un grupo admite varias selecciones.
class ParamMultiBadge extends StatelessWidget {
  const ParamMultiBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        'MULTI',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: accent,
        ),
      ),
    );
  }
}
