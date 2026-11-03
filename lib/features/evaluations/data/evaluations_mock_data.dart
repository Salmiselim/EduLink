// Barrel de compatibilité du module Évaluations.
///
/// Tous les écrans importent historiquement `../data/evaluations_mock_data.dart`.
/// Ce fichier re-exporte le vrai [EvaluationsController] (couche HTTP + Hive)
/// pour qu'aucun écran n'ait besoin d'être modifié.
///
/// Le contrôleur mock original est conservé dans [evaluations_mock_legacy.dart]
/// et peut être utilisé en secours lors du développement hors-ligne via
/// `EvaluationsMockLegacy.instance` si besoin.
export '../controllers/evaluations_controller.dart';
