import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../services/courses_ai_service.dart';
import 'courses_ui.dart';

// Outils d'interface partagés du module Cours pour les fonctions assistées
// par IA : bouton uniforme « ✦ », exécution avec indicateur de chargement,
// affichage du résultat dans une feuille modale et application des
// corrections d'orthographe aux champs d'un formulaire.

/// Bouton secondaire uniforme pour toutes les actions assistées par IA
/// (violet, icône « étincelle ») : suggestion, correction, traduction, résumé.
class AiToolButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool compact;

  const AiToolButton(
    this.label, {
    super.key,
    this.onPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF7C3AED),
        backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.08),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 6 : 10,
        ),
        minimumSize: Size(0, compact ? 32 : 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: TextStyle(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w800,
        ),
      ),
      icon: const Icon(Icons.auto_awesome_rounded, size: 15),
      label: Text(
        label,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
    );
    if (compact) return button;
    return SizedBox(height: 40, child: button);
  }
}

/// Exécute [job] derrière une boîte de dialogue de chargement, puis renvoie
/// son résultat. Les erreurs [AiUnavailableException] sont converties en
/// `SnackBar` (message du service) et la méthode retourne `null`.
Future<T?> runWithAiLoader<T>(
  BuildContext context,
  String message,
  Future<T> Function() job,
) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: CourseColors.primary,
              strokeWidth: 3,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: CourseColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  try {
    return await job();
  } on AiUnavailableException catch (error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(duration: const Duration(seconds: 3), content: Text(error.message)),
    );
    return null;
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}

/// Correction proposée par l'IA pour un champ de formulaire ; [controller]
/// est mis à jour par [apply] lorsque l'utilisateur accepte la suggestion.
class AiFieldCorrection {
  final String label;
  final TextEditingController controller;
  final String corrected;
  bool applied = false;

  AiFieldCorrection({
    required this.label,
    required this.controller,
    required this.corrected,
  });

  /// Vrai si le texte proposé est identique à l'actuel (rien à corriger).
  bool get unchanged => corrected.trim() == controller.text.trim();

  void apply() {
    controller.text = corrected;
    applied = true;
  }
}

/// Feuille modale affichant, champ par champ, le texte original et la
/// proposition corrigée par l'IA, avec application au choix ou globale.
Future<void> showSpellingReviewSheet(
  BuildContext context,
  List<AiFieldCorrection> corrections,
) {
  final actionable = corrections.where((c) => !c.unchanged).toList();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: CourseColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          size: 18, color: Color(0xFF7C3AED)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Orthographe — propositions de l\'IA',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: CourseColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Comparez puis appliquez les corrections de votre choix.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: CourseColors.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final correction in corrections) ...[
                            Text(
                              correction.label,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: CourseColors.muted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: CourseColors.neutralBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                correction.unchanged
                                    ? '${correction.label} : rien à signaler.'
                                    : correction.corrected,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: CourseColors.text,
                                ),
                              ),
                            ),
                            if (!correction.unchanged) ...[
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.tonal(
                                  onPressed: correction.applied
                                      ? null
                                      : () => setSheetState(
                                            () => correction.apply(),
                                          ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: correction.applied
                                        ? CourseColors.successBg
                                        : CourseColors.primary,
                                    foregroundColor: correction.applied
                                        ? CourseColors.success
                                        : Colors.white,
                                    minimumSize: const Size(0, 34),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                  ),
                                  child: Text(
                                    correction.applied
                                        ? 'Appliqué'
                                        : 'Appliquer ce champ',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: CourseColors.textSecondary,
                            side: const BorderSide(color: CourseColors.border),
                            minimumSize: const Size(0, 44),
                          ),
                          child: const Text(
                            'Fermer',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: actionable.isEmpty
                              ? () => Navigator.pop(sheetContext)
                              : () {
                                  for (final correction in actionable) {
                                    if (!correction.applied) correction.apply();
                                  }
                                  setSheetState(() {});
                                  Navigator.pop(sheetContext);
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: CourseColors.primary,
                            minimumSize: const Size(0, 44),
                          ),
                          child: Text(
                            actionable.isEmpty
                                ? 'Aucune faute — fermer'
                                : 'Tout appliquer',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// Feuille modale générique affichant un texte produit par l'IA
/// (relecture de cours, résumé, traduction) avec copie rapide et,
/// éventuellement, un bouton d'action (ex. « Enregistrer la traduction »).
Future<void> showAiTextSheet(
  BuildContext context, {
  required String title,
  required String body,
  bool rtl = false,
  String? actionLabel,
  Future<void> Function()? onAction,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: CourseColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFF7C3AED),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: CourseColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CourseColors.neutralBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Directionality(
                          textDirection:
                              rtl ? TextDirection.rtl : TextDirection.ltr,
                          child: SelectableText(
                            body,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.6,
                              color: CourseColors.text,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: body));
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                duration: Duration(seconds: 2),
                                content: Text('Texte copié.'),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: CourseColors.textSecondary,
                            side: const BorderSide(color: CourseColors.border),
                            minimumSize: const Size(0, 44),
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 17),
                          label: const Text(
                            'Copier',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      if (actionLabel != null && onAction != null) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              setSheetState(() {});
                              await onAction();
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: CourseColors.primary,
                              minimumSize: const Size(0, 44),
                            ),
                            child: Text(
                              actionLabel,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            style: FilledButton.styleFrom(
                              backgroundColor: CourseColors.primary,
                              minimumSize: const Size(0, 44),
                            ),
                            child: const Text(
                              'Fermer',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
