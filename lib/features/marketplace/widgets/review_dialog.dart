import 'package:flutter/material.dart';
import '../models/marketplace_models.dart';

// ============================================================================
// FEUILLE MODALE : DÉPÔT D'UN AVIS (ReviewBottomSheet)
// Appelée depuis « Mes commandes » ou depuis le Chat d'une commande lorsque
// le statut de la commande est passé à `completed` (Étape 4 du parcours, Page 8).
// Règle 5 (Page 2) : Un seul avis par commande terminée (id du document = orderId).
// ============================================================================

class ReviewBottomSheet extends StatefulWidget {
  final MarketplaceOrder order;
  final void Function(int rating, String comment) onSubmit;

  const ReviewBottomSheet({
    super.key,
    required this.order,
    required this.onSubmit,
  });

  @override
  State<ReviewBottomSheet> createState() => _ReviewBottomSheetState();
}

class _ReviewBottomSheetState extends State<ReviewBottomSheet> {
  /// Note sélectionnée par l'acheteur (1 à 5 étoiles ★, par défaut 5)
  int _selectedRating = 5;

  /// Contrôleur du champ de commentaire textuel
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de la feuille modale
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Évaluer cette commande',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Vendeur : ${widget.order.sellerName} (1 seul avis par commande)',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Rappel de l'offre évaluée
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Icon(
                  widget.order.offerType.icon,
                  size: 18,
                  color: widget.order.offerType.color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.order.offerTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Sélecteur interactif de 1 à 5 étoiles ★
          const Center(
            child: Text(
              'Quelle note attribuez-vous sur 5 ?',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              final isSelected = starValue <= _selectedRating;
              return IconButton(
                onPressed: () => setState(() => _selectedRating = starValue),
                iconSize: 38,
                icon: Icon(
                  isSelected ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isSelected
                      ? const Color(0xFFF59E0B)
                      : Colors.grey.shade400,
                ),
              );
            }),
          ),
          const SizedBox(height: 12),

          // Champ de commentaire
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Votre commentaire sur la ressource ou la séance',
              hintText:
                  'Ex: Support très clair, explications pédagogiques et ponctuel...',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Bouton d'envoi (`POST /reviews`)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () {
                final text = _commentController.text.trim().isEmpty
                    ? 'Très bonne expérience, je recommande !'
                    : _commentController.text.trim();
                widget.onSubmit(_selectedRating, text);
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text(
                'Publier mon avis (met à jour la note & les badges L2)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
