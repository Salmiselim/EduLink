import 'package:flutter/material.dart';
import '../data/marketplace_mock_data.dart';
import '../models/marketplace_models.dart';

// ============================================================================
// ROUTE POUSSÉE : ASSISTANT DE CRÉATION / ÉDITION D'OFFRE EN 6 ÉTAPES (OfferWizardScreen)
// Page 8 — Métier 2 :
// « Assistant de création d'offre (route poussée, étudiant ou enseignant) :
//   1. Choix du type
//   2. Informations, photos ou fichier
//   3. Prix (en TND ou Gratuit)
//   4. Lieu ou mode et disponibilités
//   5. Cours lié (optionnel)
//   6. Aperçu -> Publication (ou Brouillon) »
//
// Répond au critère d'évaluation : « Contrôles de saisie et validations »
// via des clés [GlobalKey<FormState>] et des [TextFormField] sur chaque étape.
// ============================================================================

class OfferWizardScreen extends StatefulWidget {
  /// Si non nul, l'assistant s'ouvre en mode « Modification d'une offre existante » (`PATCH /offers/:id`)
  final Offer? existingOffer;

  const OfferWizardScreen({
    super.key,
    this.existingOffer,
  });

  @override
  State<OfferWizardScreen> createState() => _OfferWizardScreenState();
}

class _OfferWizardScreenState extends State<OfferWizardScreen> {
  final MarketplaceController _controller = MarketplaceController.instance;

  /// Clés de formulaire pour le contrôle de saisie étape par étape
  final GlobalKey<FormState> _step2FormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _step3FormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _step4FormKey = GlobalKey<FormState>();

  /// Index de l'étape active (0 à 5)
  int _currentStep = 0;

  // --- ÉTAPE 1 : Choix du type d'offre (`resource_digital`, `resource_physical`, `private_lesson`) ---
  OfferType _selectedType = OfferType.resourceDigital;

  // --- ÉTAPE 2 : Informations générales, photos et fichier PDF privé ---
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  String _selectedSubject = MarketplaceController.subjects.first;
  String _selectedLevel = 'L2';
  OfferCondition _selectedCondition = OfferCondition.bon;
  int _stockQuantity = 1;
  String? _uploadedFileName = 'support_revision_edulink.pdf';
  final List<String> _uploadedPhotos = ['photo_couverture_1.jpg'];
  String? _mediaValidationError;

  // --- ÉTAPE 3 : Prix en TND (0 = offre gratuite) ---
  bool _isFree = false;
  late final TextEditingController _priceController;

  // --- ÉTAPE 4 : Mode (En ligne Jitsi / Présentiel), Lieu OpenStreetMap & Créneaux (`availabilities`) ---
  DeliveryMode _selectedMode = DeliveryMode.online;
  String _selectedCity = 'Tunis';
  late final TextEditingController _addressController;
  final List<Map<String, String>> _draftSlots = [
    {'date': 'Mar 27 Oct 2026', 'start': '16:00', 'end': '17:00'},
    {'date': 'Jeu 29 Oct 2026', 'start': '18:00', 'end': '19:00'},
  ];
  String? _slotsValidationError;

  // --- ÉTAPE 5 : Cours rattaché optionnel (intégration avec le module Cours) ---
  String? _selectedCourseId = 'course_algo_1';

  /// Expression régulière validant le format horaire 24h `HH:mm` (ex: `09:30`, `14:00`)
  static final RegExp _timeRegex = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  /// Libellés des 6 étapes de l'assistant
  static const List<String> _stepTitles = [
    '1. Type d\'offre',
    '2. Infos & Médias',
    '3. Prix (TND)',
    '4. Mode, Lieu & Créneaux',
    '5. Cours lié (L6)',
    '6. Aperçu & Publication',
  ];

  bool get _isEditing => widget.existingOffer != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingOffer;
    if (existing != null) {
      _selectedType = existing.type;
      _titleController = TextEditingController(text: existing.title);
      _descController = TextEditingController(text: existing.description);
      _selectedSubject = existing.subject;
      _selectedLevel = existing.level;
      _selectedCondition = existing.condition ?? OfferCondition.bon;
      _stockQuantity = existing.quantity ?? 1;
      _isFree = existing.isFree;
      _priceController = TextEditingController(
        text: existing.isFree ? '0' : existing.price.toStringAsFixed(0),
      );
      _selectedMode = existing.mode ?? DeliveryMode.online;
      _selectedCity = existing.location?.city ?? 'Tunis';
      _addressController = TextEditingController(
        text: existing.location?.address ??
            'Campus Universitaire El Manar, devant la bibliothèque',
      );
      _selectedCourseId = existing.courseId;
      final existingSlots = _controller.getSlotsForOffer(existing.id);
      if (existingSlots.isNotEmpty) {
        _draftSlots
          ..clear()
          ..addAll(
            existingSlots.map(
              (s) => {
                'date': s.date,
                'start': s.startTime,
                'end': s.endTime,
              },
            ),
          );
      }
    } else {
      _titleController = TextEditingController();
      _descController = TextEditingController();
      _priceController = TextEditingController(text: '15');
      _addressController = TextEditingController(
        text: 'Campus Universitaire El Manar, devant la bibliothèque',
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// Vérifie la validité des contrôles de saisie de l'étape active avant d'autoriser le passage à la suivante
  bool _validateStep(int step) {
    if (step == 1) {
      final formValid = _step2FormKey.currentState?.validate() ?? false;
      if (_selectedType == OfferType.resourceDigital &&
          _uploadedFileName == null) {
        setState(() {
          _mediaValidationError =
              'Veuillez sélectionner un fichier PDF à téléverser.';
        });
        return false;
      }
      if (_selectedType == OfferType.resourcePhysical &&
          _uploadedPhotos.isEmpty) {
        setState(() {
          _mediaValidationError =
              'Veuillez ajouter au moins une photo de la ressource physique.';
        });
        return false;
      }
      setState(() => _mediaValidationError = null);
      if (!formValid) {
        _showValidationSnackBar(
          'Veuillez renseigner un titre (min. 5 caractères) et une description (min. 20 caractères).',
        );
      }
      return formValid;
    }

    if (step == 2) {
      if (_isFree) return true;
      final formValid = _step3FormKey.currentState?.validate() ?? false;
      if (!formValid) {
        _showValidationSnackBar(
          'Veuillez saisir un prix valide en TND (entre 1 et 500 TND) ou activer la gratuité.',
        );
      }
      return formValid;
    }

    if (step == 3) {
      if (_selectedType == OfferType.resourceDigital) return true;
      final needsAddress = _selectedType == OfferType.resourcePhysical ||
          (_selectedType == OfferType.privateLesson &&
              _selectedMode == DeliveryMode.onsite);
      bool addressValid = true;
      if (needsAddress) {
        addressValid = _step4FormKey.currentState?.validate() ?? false;
      }
      if (_selectedType == OfferType.privateLesson && _draftSlots.isEmpty) {
        setState(() {
          _slotsValidationError =
              'Au moins un créneau de disponibilité est obligatoire pour un cours particulier.';
        });
        _showValidationSnackBar(
          'Veuillez ajouter au moins un créneau horaire de disponibilité.',
        );
        return false;
      }
      setState(() => _slotsValidationError = null);
      if (!addressValid) {
        _showValidationSnackBar(
          'Veuillez saisir une adresse de rencontre valide (min. 6 caractères).',
        );
      }
      return addressValid;
    }

    return true;
  }

  void _showValidationSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFDC2626),
        content: Text(message),
      ),
    );
  }

  /// Passe à l'étape suivante uniquement si les contrôles de saisie de l'étape courante sont valides
  void _goToNextStep() {
    if (_validateStep(_currentStep)) {
      setState(() => _currentStep++);
    }
  }

  /// Ouvre une boîte de dialogue avec contrôles de saisie (`HH:mm` et `fin > début`) pour ajouter un créneau
  void _showAddDraftSlotDialog() {
    final slotFormKey = GlobalKey<FormState>();
    final dateCtrl = TextEditingController(text: 'Ven 30 Oct 2026');
    final startCtrl = TextEditingController(text: '14:00');
    final endCtrl = TextEditingController(text: '15:00');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Ajouter un créneau horaire',
          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
        ),
        content: Form(
          key: slotFormKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: dateCtrl,
                validator: (val) {
                  if (val == null || val.trim().length < 5) {
                    return 'Date obligatoire (ex: Ven 30 Oct 2026).';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'Date du créneau *',
                  hintText: 'Ex: Ven 30 Oct 2026',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: startCtrl,
                      validator: (val) {
                        final text = val?.trim() ?? '';
                        if (!_timeRegex.hasMatch(text)) {
                          return 'Format HH:mm';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Début (HH:mm) *',
                        hintText: '14:00',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: endCtrl,
                      validator: (val) {
                        final text = val?.trim() ?? '';
                        if (!_timeRegex.hasMatch(text)) {
                          return 'Format HH:mm';
                        }
                        final start = startCtrl.text.trim();
                        if (_timeRegex.hasMatch(start) &&
                            text.compareTo(start) <= 0) {
                          return 'Doit être > début';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Fin (HH:mm) *',
                        hintText: '15:00',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (slotFormKey.currentState!.validate()) {
                setState(() {
                  _draftSlots.add({
                    'date': dateCtrl.text.trim(),
                    'start': startCtrl.text.trim(),
                    'end': endCtrl.text.trim(),
                  });
                  _slotsValidationError = null;
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  /// Construit l'objet `Offer` et ses `AvailabilitySlot` puis les enregistre (`POST /offers` ou `PATCH /offers/:id`)
  void _submitOffer({required OfferStatus status}) {
    // Vérification finale de toutes les étapes avant publication
    for (int s = 1; s <= 3; s++) {
      if (!_validateStep(s)) {
        setState(() => _currentStep = s);
        return;
      }
    }

    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    final parsedPrice =
        _isFree ? 0.0 : (double.tryParse(_priceController.text.trim()) ?? 15.0);

    final linkedCourse = _selectedCourseId == null
        ? null
        : MarketplaceController.availableCoursesL6.firstWhere(
            (c) => c['id'] == _selectedCourseId,
            orElse: () => MarketplaceController.availableCoursesL6.first,
          );

    final offerId = widget.existingOffer?.id ??
        'offer_${DateTime.now().millisecondsSinceEpoch}';

    final needsLocation = _selectedType == OfferType.resourcePhysical ||
        (_selectedType == OfferType.privateLesson &&
            _selectedMode == DeliveryMode.onsite);

    final offerObj = Offer(
      id: offerId,
      sellerId: _controller.currentUserId,
      sellerName: _controller.currentUserName,
      sellerAvatar: _controller.currentUserRole == SellerRole.teacher
          ? 'KM'
          : 'YB',
      sellerSubtitle: _controller.currentUserRole == SellerRole.teacher
          ? 'Enseignant vérifié · INSAT Tunis'
          : 'L3 Génie Logiciel · FST Tunis',
      sellerBadges: _controller.currentUserRole == SellerRole.teacher
          ? const ['Enseignant vérifié', 'Mentor']
          : const ['Vendeur', 'Bien noté'],
      sellerRole: _controller.currentUserRole,
      type: _selectedType,
      title: title,
      subject: _selectedSubject,
      level: _selectedLevel,
      description: desc,
      images: _uploadedPhotos,
      price: parsedPrice,
      fileUrl: _selectedType == OfferType.resourceDigital
          ? 'https://res.cloudinary.com/edulink/private/${_uploadedFileName ?? "document.pdf"}'
          : null,
      fileSizeLabel: _selectedType == OfferType.resourceDigital
          ? 'PDF privé · ${_uploadedFileName ?? "document.pdf"}'
          : null,
      condition: _selectedType == OfferType.resourcePhysical
          ? _selectedCondition
          : null,
      quantity:
          _selectedType == OfferType.resourcePhysical ? _stockQuantity : null,
      mode: _selectedType == OfferType.privateLesson
          ? _selectedMode
          : (_selectedType == OfferType.resourcePhysical
              ? DeliveryMode.onsite
              : null),
      location: needsLocation
          ? OfferLocation(
              address: _addressController.text.trim(),
              city: _selectedCity,
              lat: 36.8325,
              lng: 10.1469,
            )
          : null,
      courseId: linkedCourse?['id'],
      courseTitle: linkedCourse?['title'],
      status: status,
      viewsCount: widget.existingOffer?.viewsCount ?? 0,
      salesCount: widget.existingOffer?.salesCount ?? 0,
      ratingAvg: widget.existingOffer?.ratingAvg ?? 0.0,
      ratingCount: widget.existingOffer?.ratingCount ?? 0,
      reportsCount: widget.existingOffer?.reportsCount ?? 0,
      createdAt: widget.existingOffer?.createdAt ?? DateTime.now(),
      isRecommendedByCourse: linkedCourse != null,
    );

    final slots = _selectedType == OfferType.privateLesson
        ? _draftSlots.asMap().entries.map((entry) {
            return AvailabilitySlot(
              id: 'slot_${offerId}_${entry.key}',
              offerId: offerId,
              sellerId: _controller.currentUserId,
              date: entry.value['date']!,
              startTime: entry.value['start']!,
              endTime: entry.value['end']!,
            );
          }).toList()
        : <AvailabilitySlot>[];

    if (_isEditing) {
      _controller.updateOffer(offerObj, slots: slots);
    } else {
      _controller.addOffer(offerObj, slots: slots);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEditing
              ? 'Offre modifiée avec succès (PATCH /offers/:id) !'
              : status == OfferStatus.published
                  ? 'Offre publiée avec succès sur la Marketplace !'
                  : 'Offre enregistrée en brouillon dans « Mes offres ».',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing
                  ? 'Modifier l\'offre'
                  : 'Assistant de création d\'offre',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            Text(
              'Publication en tant que : ${_controller.currentUserRole.badgeLabel}',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Barre de progression interactive des 6 étapes
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(_stepTitles.length, (i) {
                    final isDone = i < _currentStep;
                    final isActive = i == _currentStep;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          // Autorise toujours le retour en arrière ; valide les étapes intermédiaires si on avance
                          if (i < _currentStep) {
                            setState(() => _currentStep = i);
                          } else if (i > _currentStep &&
                              _validateStep(_currentStep)) {
                            setState(() => _currentStep = i);
                          }
                        },
                        child: Container(
                          height: 6,
                          margin: EdgeInsets.only(
                            right: i == _stepTitles.length - 1 ? 0 : 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDone || isActive
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      _stepTitles[_currentStep],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Étape ${_currentStep + 1} sur ${_stepTitles.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Contenu dynamique de l'étape active
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_currentStep == 0) _buildStep1Type(),
                if (_currentStep == 1) _buildStep2InfoAndMedia(),
                if (_currentStep == 2) _buildStep3Price(),
                if (_currentStep == 3) _buildStep4LocationAndSlots(),
                if (_currentStep == 4) _buildStep5LinkedCourse(),
                if (_currentStep == 5) _buildStep6Preview(),
              ],
            ),
          ),

          // Barre inférieure de navigation entre les étapes (Précédent / Suivant / Brouillon / Publier)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  if (_currentStep > 0)
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _currentStep--),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Précédent'),
                    ),
                  const Spacer(),
                  if (_currentStep < _stepTitles.length - 1)
                    FilledButton.icon(
                      onPressed: _goToNextStep,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Étape suivante'),
                    )
                  else ...[
                    OutlinedButton(
                      onPressed: () =>
                          _submitOffer(status: OfferStatus.draft),
                      child: const Text('Brouillon'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () =>
                          _submitOffer(status: OfferStatus.published),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                      label: Text(
                        _isEditing ? 'Enregistrer' : 'Publier l\'offre',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ÉTAPE 1 : Sélection du type d'offre parmi les 3 types définis en Page 7
  Widget _buildStep1Type() {
    final options = [
      (
        OfferType.resourceDigital,
        'Fiches de révision, annales corrigées (PDF)',
        'Fichier stocké en privé sur Cloudinary ; téléchargement débloqué après acceptation de la commande (ou immédiat si gratuit).',
      ),
      (
        OfferType.resourcePhysical,
        'Livre d\'occasion, polycopié, calculatrice',
        'Précisez l\'état (neuf, bon, usagé), la quantité en stock, les photos et le lieu de remise en main propre.',
      ),
      (
        OfferType.privateLesson,
        'Cours particulier individuel (1 h)',
        'Définissez votre tarif par heure, vos créneaux de disponibilité et le mode : en ligne (lien Jitsi Meet auto) ou en présentiel.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quel type d\'offre souhaitez-vous publier ?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Les enseignants et les étudiants peuvent vendre des ressources et donner des cours particuliers.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        ...options.map((item) {
          final type = item.$1;
          final isSelected = _selectedType == type;
          return GestureDetector(
            onTap: () => setState(() => _selectedType = type),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : Colors.grey.shade200,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: type.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(type.icon, color: type.color, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                type.label,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                type.code,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.$2,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.$3,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade700,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  /// ÉTAPE 2 : Saisie validée du titre, matière, niveau, description, fichier PDF ou état/stock
  Widget _buildStep2InfoAndMedia() {
    return Form(
      key: _step2FormKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informations générales & Fichiers (MediaService L10)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 14),

            // Contrôle de saisie sur le Titre (obligatoire, 5 à 80 caractères, non purement numérique)
            TextFormField(
              controller: _titleController,
              maxLength: 80,
              validator: (val) {
                final text = val?.trim() ?? '';
                if (text.isEmpty) {
                  return 'Le titre de l\'offre est obligatoire.';
                }
                if (text.length < 5) {
                  return 'Le titre doit contenir au moins 5 caractères (${text.length}/5).';
                }
                if (RegExp(r'^\d+$').hasMatch(text)) {
                  return 'Le titre ne peut pas contenir uniquement des chiffres.';
                }
                return null;
              },
              decoration: InputDecoration(
                labelText: 'Titre de l\'offre *',
                hintText: _selectedType == OfferType.privateLesson
                    ? 'Ex: Cours particulier d\'Algorithmique & Graphes (1 h)'
                    : 'Ex: Fiches Algo — Résumé + Annales Corrigées',
                helperText: 'Entre 5 et 80 caractères',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSubject,
                    decoration: InputDecoration(
                      labelText: 'Matière *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: MarketplaceController.subjects
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSubject = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedLevel,
                    decoration: InputDecoration(
                      labelText: 'Niveau *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: MarketplaceController.levels
                        .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedLevel = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Contrôle de saisie sur la Description (obligatoire, min 20 caractères)
            TextFormField(
              controller: _descController,
              maxLines: 4,
              maxLength: 600,
              validator: (val) {
                final text = val?.trim() ?? '';
                if (text.isEmpty) {
                  return 'La description détaillée est obligatoire.';
                }
                if (text.length < 20) {
                  return 'Veuillez détailler davantage votre offre (min. 20 caractères, actuel : ${text.length}).';
                }
                return null;
              },
              decoration: InputDecoration(
                labelText: 'Description détaillée *',
                hintText:
                    'Détaillez le contenu, les chapitres abordés, le nombre de pages ou le déroulé de la séance...',
                helperText: 'Minimum 20 caractères requis',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Champs spécifiques à une ressource numérique
            if (_selectedType == OfferType.resourceDigital) ...[
              const Text(
                'Fichier numérique privé (Cloudinary `fileUrl`) *',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _uploadedFileName ?? 'Aucun fichier sélectionné',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _uploadedFileName =
                              'fiches_${_selectedSubject.toLowerCase().replaceAll(' ', '_')}_$_selectedLevel.pdf';
                          _mediaValidationError = null;
                        });
                      },
                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                      label: const Text('Changer le PDF'),
                    ),
                  ],
                ),
              ),
            ],

            // Champs spécifiques à une ressource physique
            if (_selectedType == OfferType.resourcePhysical) ...[
              const Text(
                'État & Quantité en stock (`condition`, `quantity`) *',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: OfferCondition.values.map((cond) {
                  return ChoiceChip(
                    selected: _selectedCondition == cond,
                    onSelected: (_) =>
                        setState(() => _selectedCondition = cond),
                    label: Text(cond.label),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Quantité disponible en stock :',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton.outlined(
                    onPressed: _stockQuantity > 1
                        ? () => setState(() => _stockQuantity--)
                        : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      '$_stockQuantity',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton.outlined(
                    onPressed: () => setState(() => _stockQuantity++),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 14),
            const Text(
              'Photos d\'illustration (`images[]`)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._uploadedPhotos.map(
                  (p) => Chip(
                    avatar: const Icon(Icons.image_outlined, size: 16),
                    label: Text(p, style: const TextStyle(fontSize: 12)),
                    onDeleted: () => setState(() => _uploadedPhotos.remove(p)),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.add_a_photo_outlined, size: 16),
                  label: const Text('Ajouter une photo Cloudinary'),
                  onPressed: () {
                    setState(() {
                      _uploadedPhotos
                          .add('apercu_${_uploadedPhotos.length + 1}.jpg');
                      _mediaValidationError = null;
                    });
                  },
                ),
              ],
            ),
            if (_mediaValidationError != null) ...[
              const SizedBox(height: 8),
              Text(
                _mediaValidationError!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// ÉTAPE 3 : Définition validée du prix en TND ou activation de la gratuité (`0 TND`)
  Widget _buildStep3Price() {
    return Form(
      key: _step3FormKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tarification de l\'offre (en Dinars Tunisiens - TND)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Proposer cette offre gratuitement (0 TND)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              subtitle: const Text(
                'Pour une ressource numérique gratuite, le téléchargement est immédiat sans attendre l\'acceptation.',
                style: TextStyle(fontSize: 12),
              ),
              value: _isFree,
              onChanged: (val) => setState(() => _isFree = val),
            ),
            if (!_isFree) ...[
              const SizedBox(height: 12),
              // Contrôle de saisie numérique sur le prix en TND
              TextFormField(
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (_isFree) return null;
                  final text = val?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'Veuillez indiquer un prix en TND (ou activer l\'offre gratuite).';
                  }
                  final parsed = double.tryParse(text);
                  if (parsed == null) {
                    return 'Format numérique invalide (ex: 15 ou 25.5).';
                  }
                  if (parsed <= 0) {
                    return 'Le prix doit être strictement supérieur à 0 TND.';
                  }
                  if (parsed > 500) {
                    return 'Le tarif étudiant/enseignant ne peut pas dépasser 500 TND.';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: _selectedType == OfferType.privateLesson
                      ? 'Tarif par heure (TND / h) *'
                      : 'Prix de vente (TND) *',
                  suffixText: 'TND',
                  helperText: 'Valeur comprise entre 1 et 500 TND',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Rappel : Le paiement se fait hors application (en main propre ou convenu entre les parties via le chat de la commande).',
                      style:
                          TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ÉTAPE 4 : Mode (En ligne Jitsi / Présentiel), Adresse OpenStreetMap Nominatim et Créneaux horaires validés
  Widget _buildStep4LocationAndSlots() {
    if (_selectedType == OfferType.resourceDigital) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.cloud_done_rounded,
              size: 44,
              color: Color(0xFF2563EB),
            ),
            SizedBox(height: 10),
            Text(
              'Livraison 100 % numérique',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 6),
            Text(
              'Une ressource numérique ne nécessite ni lieu de remise physique ni créneaux horaires. Vous pouvez passer à l\'étape suivante.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
          ],
        ),
      );
    }

    return Form(
      key: _step4FormKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        children: [
          if (_selectedType == OfferType.privateLesson)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mode du cours particulier (`mode`)',
                    style:
                        TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<DeliveryMode>(
                    segments: const [
                      ButtonSegment(
                        value: DeliveryMode.online,
                        icon: Icon(Icons.videocam_outlined),
                        label: Text('En ligne (Jitsi Meet)'),
                      ),
                      ButtonSegment(
                        value: DeliveryMode.onsite,
                        icon: Icon(Icons.location_on_outlined),
                        label: Text('En présentiel'),
                      ),
                    ],
                    selected: {_selectedMode},
                    onSelectionChanged: (s) =>
                        setState(() => _selectedMode = s.first),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _selectedMode == DeliveryMode.online
                        ? 'API Jitsi Meet : une salle de visioconférence unique sera créée automatiquement dès l\'acceptation d\'une réservation.'
                        : 'Indiquez ci-dessous l\'adresse du cours en présentiel.',
                    style:
                        TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

          // Localisation OpenStreetMap Nominatim si ressource physique ou cours en présentiel
          if (_selectedType == OfferType.resourcePhysical ||
              (_selectedType == OfferType.privateLesson &&
                  _selectedMode == DeliveryMode.onsite))
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.map_rounded, color: Color(0xFF2563EB)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Localisation OpenStreetMap Nominatim *',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCity,
                    decoration: InputDecoration(
                      labelText: 'Ville / Gouvernorat *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: MarketplaceController.cities
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCity = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  // Contrôle de saisie sur l'adresse OpenStreetMap
                  TextFormField(
                    controller: _addressController,
                    validator: (val) {
                      final text = val?.trim() ?? '';
                      if (text.isEmpty) {
                        return 'L\'adresse ou le point de rencontre est obligatoire.';
                      }
                      if (text.length < 6) {
                        return 'Veuillez préciser l\'adresse (min. 6 caractères).';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: 'Adresse / Point de rencontre *',
                      helperText: 'Résolu via OpenStreetMap Nominatim',
                      suffixIcon: IconButton(
                        tooltip: 'Géocoder avec OpenStreetMap Nominatim',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Coordonnées Nominatim résolues : lat 36.8325, lng 10.1469',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.my_location_rounded),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Créneaux de disponibilité pour un cours particulier (`availabilities`)
          if (_selectedType == OfferType.privateLesson)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        color: Color(0xFF7C3AED),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Créneaux de disponibilité (`availabilities`) *',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showAddDraftSlotDialog,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Ajouter'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_draftSlots.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Aucun créneau défini. Ajoutez au moins un créneau horaire.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  ..._draftSlots.asMap().entries.map((entry) {
                    final i = entry.key;
                    final s = entry.value;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.access_time_filled_rounded,
                        color: Color(0xFF7C3AED),
                        size: 20,
                      ),
                      title: Text(
                        '${s['date']} · ${s['start']} - ${s['end']}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      trailing: IconButton(
                        onPressed: () =>
                            setState(() => _draftSlots.removeAt(i)),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    );
                  }),
                  if (_slotsValidationError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _slotsValidationError!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// ÉTAPE 5 : Rattachement optionnel de l'offre à un cours
  Widget _buildStep5LinkedCourse() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rattacher l\'offre à un cours (Optionnel)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Une offre rattachée à un cours (`offers.courseId`) apparaît directement sur la page de ce cours et dans les recommandations des étudiants inscrits.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          RadioGroup<String?>(
            groupValue: _selectedCourseId,
            onChanged: (val) => setState(() => _selectedCourseId = val),
            child: Column(
              children: [
                const RadioListTile<String?>(
                  value: null,
                  title: Text(
                    'Aucun cours lié (Offre générale)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                const Divider(),
                ...MarketplaceController.availableCoursesL6.map((course) {
                  return RadioListTile<String?>(
                    value: course['id'],
                    title: Text(
                      course['title']!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    subtitle: Text('Matière : ${course['subject']}'),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ÉTAPE 6 : Aperçu récapitulatif complet avant enregistrement en brouillon ou publication
  Widget _buildStep6Preview() {
    final parsedPrice =
        _isFree ? 0.0 : (double.tryParse(_priceController.text.trim()) ?? 15.0);
    final linkedCourse = _selectedCourseId == null
        ? null
        : MarketplaceController.availableCoursesL6.firstWhere(
            (c) => c['id'] == _selectedCourseId,
            orElse: () => MarketplaceController.availableCoursesL6.first,
          );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_outlined, color: Color(0xFF16A34A)),
              const SizedBox(width: 8),
              const Text(
                'Aperçu avant publication',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _controller.currentUserRole.badgeLabel,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _PreviewLine(
            'Type d\'offre',
            '${_selectedType.label} (${_selectedType.code})',
          ),
          _PreviewLine(
            'Titre',
            _titleController.text.trim().isEmpty
                ? '(Non renseigné — requis à l\'étape 2)'
                : _titleController.text.trim(),
          ),
          _PreviewLine(
            'Matière & Niveau',
            '$_selectedSubject · $_selectedLevel',
          ),
          _PreviewLine(
            'Prix',
            _isFree
                ? 'Gratuit (0 TND)'
                : '${parsedPrice.toStringAsFixed(0)} TND${_selectedType == OfferType.privateLesson ? " / h" : ""}',
          ),
          if (_selectedType == OfferType.resourceDigital)
            _PreviewLine(
              'Fichier PDF privé',
              _uploadedFileName ?? 'document.pdf',
            ),
          if (_selectedType == OfferType.resourcePhysical)
            _PreviewLine(
              'État & Stock',
              '${_selectedCondition.label} · $_stockQuantity en stock',
            ),
          if (_selectedType == OfferType.privateLesson)
            _PreviewLine(
              'Mode & Créneaux',
              '${_selectedMode.label} · ${_draftSlots.length} créneau(x)',
            ),
          _PreviewLine(
            'Cours lié (L6)',
            linkedCourse != null ? linkedCourse['title']! : 'Aucun',
          ),
        ],
      ),
    );
  }
}

/// Ligne de récapitulatif utilisée à l'étape 6 (Aperçu)
class _PreviewLine extends StatelessWidget {
  final String label;
  final String value;

  const _PreviewLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 135,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
