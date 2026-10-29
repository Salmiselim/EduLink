import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../providers/forum_provider.dart';
import '../utils/time_format.dart';
import '../widgets/answer_card.dart';
import '../widgets/forum_ui.dart';
import '../widgets/role_badge.dart';

class QuestionDetailScreen extends StatefulWidget {
  final String postId;

  const QuestionDetailScreen({super.key, required this.postId});

  @override
  State<QuestionDetailScreen> createState() => _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends State<QuestionDetailScreen> {
  static const int _answerMin = 3;
  static const int _answerMax = 1000;

  final TextEditingController _answerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _answerError;

  @override
  void dispose() {
    _answerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _submitAnswer() {
    final text = _answerController.text.trim();

    String? error;
    if (text.isEmpty) {
      error = "Écrivez votre réponse avant de l'envoyer";
    } else if (text.length < _answerMin) {
      error = 'Votre réponse est trop courte ($_answerMin caractères minimum)';
    }
    if (error != null) {
      setState(() => _answerError = error);
      return;
    }

    context.read<ForumProvider>().addAnswer(
          postId: widget.postId,
          body: text,
        );

    _answerController.clear();
    setState(() => _answerError = null);
    FocusScope.of(context).unfocus();

    // Fait défiler la liste jusqu'à la nouvelle réponse.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Votre réponse a été ajoutée !'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        tooltip: 'Retour',
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: ForumColors.text,
          size: 18,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const ForumPageTitle('Détail de la question'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ForumProvider>();
    final Post? post = provider.getPostById(widget.postId);

    if (post == null) {
      return Scaffold(
        backgroundColor: ForumColors.scaffold,
        appBar: _appBar(),
        body: const Center(
          child: ForumEmptyState(
            icon: Icons.help_outline_rounded,
            title: 'Question introuvable',
            subtitle: "Cette question n'existe plus ou a été supprimée.",
          ),
        ),
      );
    }

    final answers = provider.getAnswersForPost(post.id);

    return Scaffold(
      backgroundColor: ForumColors.scaffold,
      appBar: _appBar(),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                // Carte de la question
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: forumCardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ForumAvatar(
                            name: post.authorName,
                            isTeacher: post.isTeacher,
                            radius: 18,
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
                                        post.authorName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: ForumColors.text,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    RoleBadge(role: post.authorRole),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatTimeAgo(post.createdAt),
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: ForumColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: ForumPill(
                          label: post.courseName,
                          color: ForumColors.primary,
                          background: ForumColors.infoBg,
                          icon: Icons.sell_outlined,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        post.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: ForumColors.text,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        post.body,
                        style: const TextStyle(
                          fontSize: 14,
                          color: ForumColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // En-tête de section
                Text(
                  'Réponses (${answers.length})',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: ForumColors.text,
                  ),
                ),

                const SizedBox(height: 10),

                if (answers.isEmpty)
                  const ForumEmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Aucune réponse pour le moment',
                    subtitle: 'Soyez le premier à répondre !',
                  )
                else
                  ...answers.map((ans) => AnswerCard(answer: ans)),
              ],
            ),
          ),

          // Barre de réponse
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: ForumColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _answerController,
                        maxLength: _answerMax,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _submitAnswer(),
                        onChanged: (_) {
                          if (_answerError != null) {
                            setState(() => _answerError = null);
                          }
                        },
                        style: const TextStyle(
                          fontSize: 14,
                          color: ForumColors.textSecondary,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          errorText: _answerError,
                          hintText: 'Écrire une réponse...',
                          hintStyle: const TextStyle(
                            color: ForumColors.muted,
                            fontSize: 13.5,
                          ),
                          filled: true,
                          fillColor: ForumColors.neutralBg,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: IconButton.filled(
                        tooltip: 'Envoyer la réponse',
                        onPressed: _submitAnswer,
                        style: IconButton.styleFrom(
                          backgroundColor: ForumColors.primary,
                          foregroundColor: Colors.white,
                          fixedSize: const Size(48, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.send_rounded, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
