import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/forum_provider.dart';
import 'screens/forum_feed_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ForumProvider()),
      ],
      child: const EduLinkApp(),
    ),
  );
}

class EduLinkApp extends StatelessWidget {
  const EduLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduLink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5), // EduLink Indigo
          primary: const Color(0xFF4F46E5),
          secondary: const Color(0xFF0EA5E9),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FD),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          centerTitle: false,
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => MainNavigationScreenState();
}

class MainNavigationScreenState extends State<MainNavigationScreen> {
  // Default to Tab 2 (Forum - Member 3 Q&A)
  int _currentIndex = 2;

  void switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  final List<Widget> _screens = const [
    _PlaceholderTab(
      title: 'Offres & Soutien',
      member: 'Membre 5',
      icon: Icons.local_offer_outlined,
    ),
    _PlaceholderTab(
      title: 'Cours & Flashcards',
      member: 'Membre 2',
      icon: Icons.menu_book_rounded,
    ),
    ForumFeedScreen(), // Onglet M3 : Forum Q&A
    _PlaceholderTab(
      title: 'Séances & Messagerie',
      member: 'Membre 4',
      icon: Icons.video_call_outlined,
    ),
    _PlaceholderTab(
      title: 'Profil & Auth',
      member: 'Membre 1',
      icon: Icons.person_outline_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          backgroundColor: Colors.white,
          indicatorColor: Colors.indigo.shade100,
          elevation: 0,
          onDestinationSelected: switchTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.local_offer_outlined),
              selectedIcon: Icon(Icons.local_offer, color: Colors.indigo),
              label: 'Offres',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book, color: Colors.indigo),
              label: 'Cours',
            ),
            NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum, color: Colors.indigo),
              label: 'Forum (Q&A)',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today, color: Colors.indigo),
              label: 'Séances',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: Colors.indigo),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final String title;
  final String member;
  final IconData icon;

  const _PlaceholderTab({
    required this.title,
    required this.member,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Module géré par $member selon le plan EduLink.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.forum),
                label: const Text('Aller sur le Forum (Mon module M3)'),
                onPressed: () {
                  final state = context
                      .findAncestorStateOfType<MainNavigationScreenState>();
                  state?.switchTab(2);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
