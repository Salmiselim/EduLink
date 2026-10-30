import 'package:flutter/material.dart';
import '../data/marketplace_mock_data.dart';
import '../models/marketplace_models.dart';
import '../widgets/review_dialog.dart';

/// Écran de messagerie et de suivi dédié à une commande ([MarketplaceRoutes.orderChat]).
/// Écoute les mises à jour de [MarketplaceController] via [ListenableBuilder], remet à zéro
/// le compteur de non-lus à l'ouverture, affiche en tête un bandeau d'actions contextuelles
/// (acceptation/refus/clôture/annulation, salle Jitsi Meet, téléchargement PDF privé, avis)
/// et fait défiler les messages automatiquement grâce à un [ScrollController].
class OrderChatScreen extends StatefulWidget {
  final String orderId;

  const OrderChatScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends State<OrderChatScreen> {
  final MarketplaceController _controller = MarketplaceController.instance;
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Planifie l'acquittement des messages non lus après le montage initial pour éviter une notification pendant `build`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.markConversationRead(widget.orderId);
    });
  }

  @override
  void dispose() {
    // Libération conjointe du contrôleur de texte et du ScrollController de la liste de messages.
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Enregistre un nouveau message (texte ou pièce jointe Cloudinary) dans le contrôleur,
  /// vide le champ de saisie puis anime le [ScrollController] jusqu'au bas de la conversation.
  void _sendMessage({String? attachmentLabel}) {
    final text = _msgController.text.trim();
    if (text.isEmpty && attachmentLabel == null) return;
    _controller.sendMessage(
      widget.orderId,
      text.isEmpty ? 'Pièce jointe envoyée : $attachmentLabel' : text,
      attachmentLabel: attachmentLabel,
    );
    _msgController.clear();
    // Défilement automatique vers le dernier message envoyé
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Abonnement réactif au contrôleur pour refléter en direct les nouveaux messages et changements de statut
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final order = _controller.allOrders.firstWhere(
          (o) => o.id == widget.orderId,
          orElse: () => _controller.allOrders.first,
        );
        final messages = _controller.getMessagesForOrder(order.id);
        final isSeller = order.sellerId == _controller.currentUserId;
        final peerName = isSeller ? order.buyerName : order.sellerName;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          // En-tête du Chat : Avatar de l'interlocuteur + indicateur Snapshot Firestore
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            titleSpacing: 0,
            title: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFDBEAFE),
                  child: Text(
                    peerName.isNotEmpty ? peerName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              peerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Snapshot Firestore',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Commande #${order.id.substring(order.id.length > 6 ? order.id.length - 6 : 0)} · ${isSeller ? "Vous êtes le vendeur" : "Vous êtes l'acheteur"}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              // 1. Bandeau supérieur : Rappel de l'offre, statut, lien Jitsi / PDF et boutons d'action
              _OrderSummaryHeader(
                order: order,
                isSeller: isSeller,
                onStatusChange: (status) {
                  _controller.updateOrderStatus(order.id, status);
                },
                onLeaveReview: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (_) => ReviewBottomSheet(
                      order: order,
                      onSubmit: (rating, comment) {
                        _controller.submitReview(
                          order: order,
                          rating: rating,
                          comment: comment,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Avis enregistré ! Note moyenne mise à jour et vérification des badges (L2).',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),

              // 2. Liste déroulante des messages temps réel (`conversations/{id}/messages`)
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    if (msg.isSystemMessage) {
                      return _SystemMessageBubble(message: msg);
                    }
                    final isMe = msg.senderId == _controller.currentUserId;
                    return _ChatBubble(message: msg, isMe: isMe);
                  },
                ),
              ),

              // 3. Barre inférieure de composition : bouton de pièce jointe, TextField étendu et envoi
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Joindre un fichier ou photo (MediaService L10)',
                        onPressed: () {
                          _sendMessage(
                            attachmentLabel: 'capture_exercice_edulink.pdf',
                          );
                        },
                        icon: const Icon(
                          Icons.attach_file_rounded,
                          color: Color(0xFF475569),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText:
                                'Écrire un message (lieu de remise, créneau, question)...',
                            hintStyle: TextStyle(
                              fontSize: 13.5,
                              color: Colors.grey.shade500,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _sendMessage,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(12),
                        ),
                        child: const Icon(Icons.send_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Bandeau supérieur fixe résumant l'état courant de la commande et exposant
/// les actions métier autorisées selon le rôle (`isSeller`) et le statut [OrderStatus].
class _OrderSummaryHeader extends StatelessWidget {
  final MarketplaceOrder order;
  final bool isSeller;
  final void Function(OrderStatus) onStatusChange;
  final VoidCallback onLeaveReview;

  const _OrderSummaryHeader({
    required this.order,
    required this.isSeller,
    required this.onStatusChange,
    required this.onLeaveReview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(order.offerType.icon, size: 18, color: order.offerType.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.offerTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: order.status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(order.status.icon, size: 13, color: order.status.color),
                    const SizedBox(width: 4),
                    Text(
                      order.status.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: order.status.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Text(
                order.amount <= 0
                    ? 'Montant : Gratuit (0 TND)'
                    : 'Montant : ${order.amount.toStringAsFixed(0)} TND (hors-app)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
              if (order.slotLabel != null)
                Text(
                  'Créneau : ${order.slotLabel}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              if (order.pickupAddress != null)
                Text(
                  'Lieu : ${order.pickupAddress}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475569),
                  ),
                ),
            ],
          ),

          // Bandeau Jitsi Meet affiché dès qu'un cours particulier en ligne est accepté
          if (order.meetingLink != null &&
              (order.status == OrderStatus.accepted ||
                  order.status == OrderStatus.completed)) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.video_call_rounded,
                    color: Color(0xFF4338CA),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Salle Jitsi Meet : ${order.meetingLink}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3730A3),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Ouverture de la visio Jitsi Meet : ${order.meetingLink}',
                          ),
                        ),
                      );
                    },
                    child: const Text('Rejoindre'),
                  ),
                ],
              ),
            ),
          ],

          // Bandeau de téléchargement du fichier privé (`GET /orders/:id/download`)
          if (order.offerType == OfferType.resourceDigital &&
              (order.status == OrderStatus.accepted ||
                  order.status == OrderStatus.completed)) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_download_rounded,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Fichier privé débloqué (GET /orders/:id/download)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Téléchargement du fichier PDF sécurisé depuis Cloudinary...',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Télécharger'),
                  ),
                ],
              ),
            ),
          ],

          // Boutons d'action de changement de statut (`PATCH /orders/:id/status`)
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isSeller && order.status == OrderStatus.requested) ...[
                FilledButton.icon(
                  onPressed: () => onStatusChange(OrderStatus.accepted),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Accepter la demande'),
                ),
                OutlinedButton.icon(
                  onPressed: () => onStatusChange(OrderStatus.rejected),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Refuser'),
                ),
              ],
              if (isSeller && order.status == OrderStatus.accepted)
                FilledButton.icon(
                  onPressed: () => onStatusChange(OrderStatus.completed),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.task_alt_rounded, size: 16),
                  label: const Text('Marquer comme terminée (après remise/séance)'),
                ),
              if (!isSeller && order.status == OrderStatus.requested)
                OutlinedButton.icon(
                  onPressed: () => onStatusChange(OrderStatus.cancelled),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Annuler ma demande'),
                ),
              if (!isSeller &&
                  order.status == OrderStatus.completed &&
                  !order.hasReview)
                FilledButton.icon(
                  onPressed: onLeaveReview,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.star_rounded, size: 16),
                  label: const Text('Laisser un avis (1–5 ★)'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bandeau centré signalant un événement automatique du cycle de commande
/// (verrouillage de créneau, création du lien Jitsi Meet, déblocage de fichier ou clôture).
class _SystemMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _SystemMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: Color(0xFF475569),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bulle de message alignée à droite pour l'émetteur courant et à gauche pour l'interlocuteur,
/// affichant l'éventuelle pièce jointe, l'horodatage `HH:mm` et la double coche de lecture (`readAt`).
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _ChatBubble({
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isMe ? null : Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              Text(
                message.senderName,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 3),
            ],
            Text(
              message.text,
              style: TextStyle(
                fontSize: 13.5,
                color: isMe ? Colors.white : const Color(0xFF0F172A),
                height: 1.35,
              ),
            ),
            if (message.attachmentLabel != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.16)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.insert_drive_file_outlined,
                      size: 15,
                      color: isMe ? Colors.white : const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        message.attachmentLabel!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isMe ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.75)
                        : Colors.grey.shade500,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.readAt != null
                        ? Icons.done_all_rounded
                        : Icons.check_rounded,
                    size: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
