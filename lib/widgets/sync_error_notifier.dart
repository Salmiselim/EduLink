import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/forum_provider.dart';
import '../features/forum/widgets/forum_ui.dart';

/// Affiche un message en bas de l'écran quand une modification du Forum est
/// refusée par le serveur (règles de sécurité, réseau...), au lieu de la laisser
/// échouer en silence. À ajouter à l'état d'un écran du Forum :
/// `class _XState extends State<X> with ForumSyncErrorNotifier<X>`.
mixin ForumSyncErrorNotifier<T extends StatefulWidget> on State<T> {
  StreamSubscription<String>? _syncErrorSub;

  @override
  void initState() {
    super.initState();
    _syncErrorSub =
        context.read<ForumProvider>().syncErrors.listen(_showSyncError);
  }

  @override
  void dispose() {
    _syncErrorSub?.cancel();
    super.dispose();
  }

  void _showSyncError(String message) {
    if (!mounted) return;
    // Un seul écran (celui du dessus) affiche le message.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: ForumColors.danger,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
  }
}
