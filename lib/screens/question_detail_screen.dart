import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/forum/models/post.dart';
import '../models/reaction.dart';
import '../providers/forum_provider.dart';
import '../features/forum/routes/app_routes.dart';
import '../utils/content_filter.dart';
import '../features/forum/utils/time_format.dart';
import '../widgets/answer_card.dart';
import '../widgets/code_block.dart';
import '../widgets/code_editor.dart';
import '../features/forum/widgets/forum_ui.dart';
import '../widgets/rating_bar.dart';
import '../widgets/reaction_bar.dart';
import '../widgets/resource_suggestions_sheet.dart';
import '../widgets/role_badge.dart';
import '../widgets/sync_error_notifier.dart';

class QuestionDetailScreen extends StatefulWidget {
  final String postId;

  const QuestionDetailScreen({super.key, required this.postId});

  @override
  State<QuestionDetailScreen> createState() => _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends State<QuestionDetailScreen>
    with ForumSyncErrorNotifier<QuestionDetailScreen> {
  static const int _answerMin = 3;
  static const int _answerMax = 1000;

  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _answerError;
  bool _codeOpen = false;
  String _codeLanguage = 'python';

  @override
  void dispose() {
    _answerController.dispose();
    _codeController.dispose();
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
    } else {
      error = ContentFilter.validate(text);
    }
    if (error != null) {
      setState(() => _answerError = error);
      return;
    }

    final code = _codeController.text;
    context.read<ForumProvider>().addAnswer(
          postId: widget.postId,
          body: text,
          codeSnippet: _codeOpen && code.trim().isNotEmpty ? code : null,
          codeLanguage: _codeOpen ? _codeLanguage : null,
        );

    _answerController.clear();
    _codeController.clear();
    setState(() {
      _answerError = null;
      _codeOpen = false;
    });
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

  Future<void> _deletePost(Post post) async {
    final provider = context.read<ForumProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await confirmForumDelete(
      context,
      title: 'Supprimer la question ?',
      message:
          'La question, ses réponses et ses réactions seront supprimées définitivement.',
    );
    if (!confirmed) return;

    final ok = provider.deletePost(post.id);
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? 'Question supprimée' : 'Suppression impossible'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  PreferredSizeWidget _appBar({Post? post, ForumProvider? provider}) {
    final canModify =
        post != null && provider != null && provider.canModifyPost(post);

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
      actions: [
        if (canModify)
          PopupMenuButton<String>(
            tooltip: 'Options de la question',
            icon: const Icon(Icons.more_vert_rounded, color: ForumColors.text),
            onSelected: (value) {
              if (value == 'edit') {
                Navigator.pushNamed(
                  context,
                  ForumRoutes.forumAsk,
                  arguments: post.id,
                );
              }
              if (value == 'delete') _deletePost(post);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Modifier')),
              PopupMenuItem(value: 'delete', child: Text('Supprimer')),
            ],
          ),
      ],
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
      appBar: _appBar(post: post, provider: provider),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                _buildPostCard(post, provider),

                const SizedBox(height: 12),

                // Liaison L7 : ressources et tuteurs de la Marketplace
                OutlinedButton.icon(
                  onPressed: () => showResourceSuggestionsSheet(context, post),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ForumColors.primary,
                    minimumSize: const Size.fromHeight(46),
                    side: const BorderSide(color: ForumColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.storefront_outlined, size: 18),
                  label: const Text(
                    'Trouver une ressource ou un tuteur',
                    style: TextStyle(fontWeight: FontWeight.w800),
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
                  ...answers.map((ans) => AnswerCard(answer: ans, post: post)),
              ],
            ),
          ),

          _buildReplyBar(),
        ],
      ),
    );
  }

  Widget _buildPostCard(Post post, ForumProvider provider) {
    return Container(
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
                      post.isEdited
                          ? '${formatTimeAgo(post.createdAt)} · modifiée'
                          : formatTimeAgo(post.createdAt),
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

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ForumPill(
                label: post.courseName,
                color: ForumColors.primary,
                background: ForumColors.infoBg,
                icon: Icons.sell_outlined,
              ),
              if (post.isResolved)
                const ForumPill(
                  label: 'Résolue',
                  color: ForumColors.success,
                  background: ForumColors.successBg,
                  icon: Icons.check_circle_rounded,
                ),
            ],
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

          if (post.hasCode) ...[
            const SizedBox(height: 12),
            ForumCodeBlock(
              code: post.codeSnippet!,
              language: post.codeLanguage,
            ),
          ],

          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: post.tags
                  .map((tag) => ForumTag(
                        label: tag,
                        onTap: () {
                          // Filtre le fil sur ce tag puis revient à la liste.
                          provider.setTagFilter(tag);
                          Navigator.pop(context);
                        },
                      ))
                  .toList(),
            ),
          ],

          const SizedBox(height: 12),
          ReactionBar(target: ReactionTarget.post, targetId: post.id),
          const SizedBox(height: 6),
          RatingBar(target: ReactionTarget.post, targetId: post.id),
        ],
      ),
    );
  }

  Widget _buildReplyBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ForumColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.55,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_codeOpen) ...[
                  ForumCodeEditor(
                    controller: _codeController,
                    language: _codeLanguage,
                    onLanguageChanged: (value) =>
                        setState(() => _codeLanguage = value),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      tooltip: _codeOpen
                          ? "Retirer l'extrait de code"
                          : 'Ajouter un extrait de code',
                      onPressed: () => setState(() => _codeOpen = !_codeOpen),
                      icon: Icon(
                        Icons.code_rounded,
                        color: _codeOpen
                            ? ForumColors.primary
                            : ForumColors.muted,
                      ),
                    ),
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
                          errorMaxLines: 2,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
