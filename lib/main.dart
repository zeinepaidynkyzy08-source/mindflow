import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:just_audio/just_audio.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  var firebaseReady = false;
  Object? firebaseError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (error) {
    firebaseError = error;
  }

  const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  if (webClientId.isEmpty) {
    await GoogleSignIn.instance.initialize();
  } else {
    await GoogleSignIn.instance.initialize(serverClientId: webClientId);
  }

  runApp(
    MindFlowApp(firebaseReady: firebaseReady, firebaseError: firebaseError),
  );
}

class MindColors {
  static const sky = Color(0xFF65C7F7);
  static const skyDark = Color(0xFF1695D1);
  static const sand = Color(0xFFF4E7CE);
  static const green = Color(0xFF41A66A);
  static const mint = Color(0xFFA9E5BB);
  static const coral = Color(0xFFFF8A7A);
  static const meditationBlue = Color(0xFFD8F1FF);
  static const meditationPurple = Color(0xFFE8DFFF);
  static const lavender = Color(0xFFC7B6F3);
  static const lavenderDeep = Color(0xFF8068C8);
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1B2A3A);
  static const muted = Color(0xFF6C7A87);
  static const danger = Color(0xFFE35D5B);
}

class MindFlowApp extends StatefulWidget {
  final bool firebaseReady;
  final Object? firebaseError;

  const MindFlowApp({
    super.key,
    this.firebaseReady = false,
    this.firebaseError,
  });

  @override
  State<MindFlowApp> createState() => _MindFlowAppState();
}

class _MindFlowAppState extends State<MindFlowApp> {
  var _themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindFlow',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: widget.firebaseReady
          ? AuthGate(
              themeMode: _themeMode,
              onThemeChanged: (value) => setState(() => _themeMode = value),
            )
          : FirebaseSetupScreen(error: widget.firebaseError),
    );
  }

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: MindColors.skyDark,
      brightness: brightness,
      primary: MindColors.skyDark,
      secondary: dark ? MindColors.mint : MindColors.green,
      tertiary: MindColors.lavenderDeep,
      error: MindColors.danger,
    );

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF101820) : MindColors.sand,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: dark ? MindColors.white : MindColors.ink,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: dark ? const Color(0xFF182532) : MindColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF213140) : MindColors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const AuthGate({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }
        final user = snapshot.data;
        if (user == null) return const AuthScreen();
        return UserBootstrap(
          user: user,
          themeMode: themeMode,
          onThemeChanged: onThemeChanged,
        );
      },
    );
  }
}

class UserBootstrap extends StatelessWidget {
  final User user;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const UserBootstrap({
    super.key,
    required this.user,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.instance.userDoc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LoadingScreen();
        final data = snapshot.data!.data() ?? {};
        final subjects = List<String>.from(data['subjects'] as List? ?? []);
        final savedTheme = data['themeMode'] as String?;
        final savedThemeMode = savedTheme == 'dark'
            ? ThemeMode.dark
            : ThemeMode.light;
        if (savedTheme != null && savedThemeMode != themeMode) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onThemeChanged(savedThemeMode);
          });
        }
        if (subjects.isEmpty) return SubjectSetupScreen(user: user);
        return MainShell(
          user: user,
          subjects: subjects,
          themeMode: themeMode,
          onThemeChanged: onThemeChanged,
        );
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _register = false;
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _emailAuth() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.length < 6 || (_register && name.isEmpty)) {
      _toast(
        _register
            ? 'Enter name, email, and a password with at least 6 characters.'
            : 'Enter email and password.',
      );
      return;
    }

    await _runAuth(() async {
      UserCredential credential;
      if (_register) {
        credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        await credential.user!.updateDisplayName(name);
      } else {
        credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      await FirestoreService.instance.upsertUser(
        credential.user!,
        displayName: _register ? name : null,
      );
    });
  }

  Future<void> _googleAuth() async {
    await _runAuth(() async {
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      await FirestoreService.instance.upsertUser(userCredential.user!);
    });
  }

  Future<void> _runAuth(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on FirebaseAuthException catch (error) {
      _toast(error.message ?? error.code);
    } on GoogleSignInException catch (error) {
      _toast(error.description ?? error.code.name);
    } catch (error) {
      _toast(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BrandHeader(),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(value: false, label: Text('Login')),
                              ButtonSegment(
                                value: true,
                                label: Text('Register'),
                              ),
                            ],
                            selected: {_register},
                            onSelectionChanged: (value) {
                              setState(() => _register = value.first);
                            },
                          ),
                          const SizedBox(height: 16),
                          if (_register) ...[
                            TextField(
                              controller: _name,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _password,
                            obscureText: true,
                            onSubmitted: (_) => _busy ? null : _emailAuth(),
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _busy ? null : _emailAuth,
                            icon: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _register
                                        ? Icons.person_add_alt
                                        : Icons.login,
                                  ),
                            label: Text(_register ? 'Create account' : 'Login'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _googleAuth,
                            icon: const Icon(Icons.g_mobiledata, size: 28),
                            label: const Text('Continue with Google'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SubjectSetupScreen extends StatefulWidget {
  final User user;

  const SubjectSetupScreen({super.key, required this.user});

  @override
  State<SubjectSetupScreen> createState() => _SubjectSetupScreenState();
}

class _SubjectSetupScreenState extends State<SubjectSetupScreen> {
  final _subjects = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _subjects.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final subjects = _subjects.text
        .split(',')
        .map((subject) => subject.trim())
        .where((subject) => subject.isNotEmpty)
        .toSet()
        .toList();
    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write at least one subject name.')),
      );
      return;
    }
    setState(() => _busy = true);
    await FirestoreService.instance.saveSubjects(widget.user.uid, subjects);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const BrandHeader(),
                      const SizedBox(height: 18),
                      Text(
                        'Write the name of subjects',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Example: Mathematics, Biology, History. MindFlow will use them for lesson preparation.',
                        style: TextStyle(color: MindColors.muted, height: 1.35),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _subjects,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Subjects',
                          prefixIcon: Icon(Icons.menu_book_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _busy ? null : _save,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Start'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final User user;
  final List<String> subjects;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const MainShell({
    super.key,
    required this.user,
    required this.subjects,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(user: widget.user, subjects: widget.subjects),
      LessonsPage(user: widget.user, subjects: widget.subjects),
      MeditationPage(user: widget.user),
      ChatPage(user: widget.user),
      SettingsPage(
        user: widget.user,
        subjects: widget.subjects,
        themeMode: widget.themeMode,
        onThemeChanged: widget.onThemeChanged,
      ),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Lessons',
          ),
          NavigationDestination(
            icon: Icon(Icons.spa_outlined),
            selectedIcon: Icon(Icons.spa),
            label: 'Meditate',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'AI Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  final User user;
  final List<String> subjects;

  const DashboardPage({super.key, required this.user, required this.subjects});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService.instance;

    return AppScaffold(
      title: 'MindFlow',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.tasks(user.uid).orderBy('dueDate').snapshots(),
        builder: (context, taskSnapshot) {
          final tasks =
              taskSnapshot.data?.docs.map(MindTask.fromDoc).toList() ?? [];
          final open = tasks.where((task) => !task.completed).toList();
          final completed = tasks.where((task) => task.completed).length;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: service
                .moods(user.uid)
                .orderBy('createdAt', descending: true)
                .limit(7)
                .snapshots(),
            builder: (context, moodSnapshot) {
              final moods =
                  moodSnapshot.data?.docs.map(MoodEntry.fromDoc).toList() ?? [];
              final stress = moods.isEmpty
                  ? 0
                  : (moods.map((mood) => mood.stress).reduce((a, b) => a + b) /
                            moods.length)
                        .round();

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  WelcomeCard(
                    user: user,
                    openTasks: open.length,
                    stress: stress,
                  ),
                  const SizedBox(height: 14),
                  SectionTitle(
                    title: 'Skills achieved',
                    action: '$completed done',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SkillChip(
                        icon: Icons.timer_outlined,
                        label: '${open.length + completed} planned',
                      ),
                      SkillChip(
                        icon: Icons.check_circle_outline,
                        label: '$completed completed',
                      ),
                      SkillChip(
                        icon: Icons.psychology_outlined,
                        label: '${moods.length} check-ins',
                      ),
                      SkillChip(
                        icon: Icons.menu_book_outlined,
                        label: '${subjects.length} subjects',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (stress >= 70)
                    const InsightCard(
                      icon: Icons.favorite_outline,
                      title: 'High stress before examination',
                      body:
                          'Try one breathing session, then choose one small lesson task. If you feel unsafe or very depressed, contact a trusted adult or emergency support.',
                      color: MindColors.danger,
                    )
                  else
                    const InsightCard(
                      icon: Icons.eco_outlined,
                      title: 'Calm preparation mode',
                      body:
                          'Use Lessons for homework planning, Meditation for stress, and AI Chat when focus feels hard.',
                      color: MindColors.green,
                    ),
                  const SizedBox(height: 18),
                  SectionTitle(
                    title: 'Lessons to prepare',
                    action: open.isEmpty ? null : '${open.length} open',
                  ),
                  const SizedBox(height: 8),
                  if (open.isEmpty)
                    const EmptyState(
                      message:
                          'No lesson tasks yet. Add preparation work on the Lessons page.',
                    )
                  else
                    ...open
                        .take(5)
                        .map((task) => TaskTile(task: task, compact: true)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class LessonsPage extends StatelessWidget {
  final User user;
  final List<String> subjects;

  const LessonsPage({super.key, required this.user, required this.subjects});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService.instance;

    return AppScaffold(
      title: 'Lesson Preparation',
      actions: [
        IconButton(
          tooltip: 'Add lesson',
          onPressed: () => showTaskSheet(context, user.uid, subjects: subjects),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTaskSheet(context, user.uid, subjects: subjects),
        icon: const Icon(Icons.add),
        label: const Text('Lesson'),
      ),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.tasks(user.uid).orderBy('dueDate').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorState(message: snapshot.error.toString());
          }
          if (!snapshot.hasData) return const LoadingScreen(inline: true);
          final tasks = snapshot.data!.docs.map(MindTask.fromDoc).toList();
          if (tasks.isEmpty) {
            return const EmptyState(
              message:
                  'Add homework, exam topics, or reading tasks that you need to prepare.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 92),
            itemBuilder: (context, index) => TaskTile(
              task: tasks[index],
              onToggle: () => service.updateTask(user.uid, tasks[index].id, {
                'completed': !tasks[index].completed,
              }),
              onEdit: () => showTaskSheet(
                context,
                user.uid,
                subjects: subjects,
                task: tasks[index],
              ),
              onDelete: () => service.deleteTask(user.uid, tasks[index].id),
            ),
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemCount: tasks.length,
          );
        },
      ),
    );
  }
}

class MeditationPage extends StatefulWidget {
  final User user;

  const MeditationPage({super.key, required this.user});

  @override
  State<MeditationPage> createState() => _MeditationPageState();
}

class _MeditationPageState extends State<MeditationPage> {
  final _note = TextEditingController();
  final _audioPlayer = AudioPlayer();
  Timer? _draftTimer;
  var _mood = 'Anxious';
  var _stress = 45.0;
  String? _playingSound;
  var _draftLoaded = false;
  final _answers = <int, double>{};

  static const _natureSounds = [
    MeditationSound(
      title: 'Rain sound',
      subtitle: 'Soft rain for anxiety before exams',
      icon: Icons.water_drop_outlined,
      color: MindColors.skyDark,
      assetPath: 'assets/audio/soundsforyou-soft-rain-ambient-111154.mp3',
      fallbackAssetPath: 'assets/audio/rain_sound.wav',
    ),
    MeditationSound(
      title: 'Ocean waves',
      subtitle: 'Slow waves for breathing rhythm',
      icon: Icons.waves_outlined,
      color: MindColors.lavenderDeep,
      assetPath: 'assets/audio/soundsforyou-ocean-sea-soft-waves-121349.mp3',
      fallbackAssetPath: 'assets/audio/ocean_waves.wav',
    ),
    MeditationSound(
      title: 'Forest morning',
      subtitle: 'Light nature ambience for calm focus',
      icon: Icons.park_outlined,
      color: MindColors.green,
      assetPath:
          'assets/audio/soundsforyou-forest-ambience-with-cuckoo-birds-chirping-123046.mp3',
      fallbackAssetPath: 'assets/audio/forest_morning.wav',
    ),
    MeditationSound(
      title: 'Night wind',
      subtitle: 'Gentle background for sleep reset',
      icon: Icons.air_outlined,
      color: MindColors.coral,
      assetPath: 'assets/audio/u_2osti9u7b5-night-cricket-and-wind-235066.mp3',
      fallbackAssetPath: 'assets/audio/night_wind.wav',
    ),
    MeditationSound(
      title: 'Thunder rain',
      subtitle: 'Deep storm ambience for blocking noise',
      icon: Icons.thunderstorm_outlined,
      color: MindColors.skyDark,
      assetPath:
          'assets/audio/white_records-rain-sounds-relaxing-noise-and-sound-of-summer-rain-143334.mp3',
      fallbackAssetPath: 'assets/audio/thunder_rain.wav',
    ),
    MeditationSound(
      title: 'River stream',
      subtitle: 'Moving water for steady concentration',
      icon: Icons.water_outlined,
      color: MindColors.green,
      assetPath:
          'assets/audio/white_records-singing-of-birds-and-the-sound-of-the-stream-sounds-of-nature-144996.mp3',
      fallbackAssetPath: 'assets/audio/river_stream.wav',
    ),
    MeditationSound(
      title: 'Bird morning',
      subtitle: 'Fresh nature sound before lessons',
      icon: Icons.wb_sunny_outlined,
      color: MindColors.coral,
      assetPath:
          'assets/audio/soundreality-birds-singing-in-the-spring-forest-356883.mp3',
      fallbackAssetPath: 'assets/audio/bird_morning.wav',
    ),
    MeditationSound(
      title: 'Campfire calm',
      subtitle: 'Warm crackle for slow breathing',
      icon: Icons.local_fire_department_outlined,
      color: MindColors.coral,
      assetPath:
          'assets/audio/soundreality-ambient-forest-campfire-meditation-452486.mp3',
      fallbackAssetPath: 'assets/audio/campfire_calm.wav',
    ),
    MeditationSound(
      title: 'Snow silence',
      subtitle: 'Quiet ambience for tired evenings',
      icon: Icons.ac_unit_outlined,
      color: MindColors.skyDark,
      assetPath:
          'assets/audio/sspsurvival-movement-on-snow-snow-footsteps-on-snow-creaking-snow-winter-steps-15923.mp3',
      fallbackAssetPath: 'assets/audio/snow_silence.wav',
    ),
    MeditationSound(
      title: 'Garden rain',
      subtitle: 'Gentle rain with soft outdoor air',
      icon: Icons.yard_outlined,
      color: MindColors.lavenderDeep,
      assetPath:
          'assets/audio/freesound_community-garden-pond-hydrophone-23899.mp3',
      fallbackAssetPath: 'assets/audio/garden_rain.wav',
    ),
  ];

  static const _hertzSounds = [
    MeditationSound(
      title: '174 Hz',
      subtitle: 'Gentle body relaxation tone',
      icon: Icons.graphic_eq,
      color: MindColors.skyDark,
      assetPath:
          'assets/audio/freesound_community-solfeggio-combination-174-741-and-417-hz-19442.mp3',
      fallbackAssetPath: 'assets/audio/174_hz.wav',
    ),
    MeditationSound(
      title: '285 Hz',
      subtitle: 'Slow reset after study pressure',
      icon: Icons.graphic_eq,
      color: MindColors.green,
      assetPath:
          'assets/audio/dominique_garnier-bamboo-forest-285hz-314677.mp3',
      fallbackAssetPath: 'assets/audio/285_hz.wav',
    ),
    MeditationSound(
      title: '396 Hz',
      subtitle: 'Release fear and study stress',
      icon: Icons.graphic_eq,
      color: MindColors.lavenderDeep,
      assetPath:
          'assets/audio/nonenothingnowhere-396-hz-root-chakra-156263.mp3',
      fallbackAssetPath: 'assets/audio/396_hz.wav',
    ),
    MeditationSound(
      title: '432 Hz',
      subtitle: 'Calm background for reading',
      icon: Icons.graphic_eq,
      color: MindColors.skyDark,
      assetPath:
          'assets/audio/nonenothingnowhere-432-hz-tune-in-with-nature-156265.mp3',
      fallbackAssetPath: 'assets/audio/432_hz.wav',
    ),
    MeditationSound(
      title: '528 Hz',
      subtitle: 'Positive reset before homework',
      icon: Icons.graphic_eq,
      color: MindColors.green,
      assetPath:
          'assets/audio/nonenothingnowhere-528-hz-solar-plexus-156266.mp3',
      fallbackAssetPath: 'assets/audio/528_hz.wav',
    ),
    MeditationSound(
      title: '639 Hz',
      subtitle: 'Calm connection and self-kindness',
      icon: Icons.graphic_eq,
      color: MindColors.lavenderDeep,
      assetPath:
          'assets/audio/nonenothingnowhere-639-hz-heart-chakra-156267.mp3',
      fallbackAssetPath: 'assets/audio/639_hz.wav',
    ),
    MeditationSound(
      title: '741 Hz',
      subtitle: 'Clear thoughts for problem solving',
      icon: Icons.graphic_eq,
      color: MindColors.skyDark,
      assetPath:
          'assets/audio/nonenothingnowhere-741hz-throat-chakra-balancing-fostering-honest-expressions-157686.mp3',
      fallbackAssetPath: 'assets/audio/741_hz.wav',
    ),
    MeditationSound(
      title: '852 Hz',
      subtitle: 'Clear mind before examination',
      icon: Icons.graphic_eq,
      color: MindColors.coral,
      assetPath:
          'assets/audio/nonenothingnowhere-852hz-third-eye-awakening-unleashing-intuition-clairvoyance-157687.mp3',
      fallbackAssetPath: 'assets/audio/852_hz.wav',
    ),
    MeditationSound(
      title: '963 Hz',
      subtitle: 'Quiet reflection before sleep',
      icon: Icons.graphic_eq,
      color: MindColors.lavenderDeep,
      assetPath:
          'assets/audio/nonenothingnowhere-963hz-crown-chakra-healing-vibrational-harmonics-for-awakening-157688.mp3',
      fallbackAssetPath: 'assets/audio/963_hz.wav',
    ),
    MeditationSound(
      title: '40 Hz',
      subtitle: 'Low focus tone for study blocks',
      icon: Icons.graphic_eq,
      color: MindColors.green,
      assetPath:
          'assets/audio/purebinaural-purebinaural-40-hz-gamma-binaural-beats-with-brown-noise-526498.mp3',
      fallbackAssetPath: 'assets/audio/40_hz.wav',
    ),
    MeditationSound(
      title: '10 Hz',
      subtitle: 'Alpha relaxation for meditation',
      icon: Icons.graphic_eq,
      color: MindColors.skyDark,
      assetPath:
          'assets/audio/lucistar-10-hertz-binaural-beat-frequency-tone-sound-wav-379129.mp3',
      fallbackAssetPath: 'assets/audio/10_hz.wav',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _setupAudioSession();
    unawaited(_audioPlayer.setLoopMode(LoopMode.one));
    unawaited(_audioPlayer.setVolume(1));
    _note.addListener(_scheduleDraftSave);
    unawaited(_loadDraft());
  }

  Future<void> _setupAudioSession() async {
    try {
      await _audioPlayer
          .setAudioSource(
            AudioSource.uri(Uri.parse('asset:///assets/audio/rain_sound.wav')),
          )
          .catchError((_) => null); // Don't fail on setup
    } catch (e) {
      // Audio session setup complete
    }
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    unawaited(_saveDraft());
    _note.dispose();
    unawaited(_audioPlayer.dispose());
    super.dispose();
  }

  Future<void> _loadDraft() async {
    final doc = await FirestoreService.instance.userDoc(widget.user.uid).get();
    final draft = doc.data()?['meditationDraft'] as Map<String, dynamic>?;
    if (draft == null || !mounted) {
      _draftLoaded = true;
      return;
    }
    final answers = draft['answers'] as Map<String, dynamic>? ?? {};
    setState(() {
      _mood = draft['mood'] as String? ?? _mood;
      _stress = (draft['stress'] as num?)?.toDouble() ?? _stress;
      _playingSound = null;
      _answers
        ..clear()
        ..addAll(
          answers.map(
            (key, value) => MapEntry(int.parse(key), (value as num).toDouble()),
          ),
        );
      _note.text = draft['note'] as String? ?? '';
      _draftLoaded = true;
    });
  }

  void _scheduleDraftSave() {
    if (!_draftLoaded) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 600), () {
      unawaited(_saveDraft());
    });
  }

  Future<void> _saveDraft() {
    return FirestoreService.instance.saveMeditationDraft(
      widget.user.uid,
      mood: _mood,
      stress: _stress,
      selectedSound: _playingSound,
      answers: _answers,
      note: _note.text.trim(),
    );
  }

  int get _depressionScore =>
      _answers.values.fold(0, (total, value) => total + value.round());

  String get _scaleLabel {
    if (_depressionScore <= 4) return 'Low';
    if (_depressionScore <= 9) return 'Mild';
    if (_depressionScore <= 14) return 'Moderate';
    return 'High';
  }

  Future<void> _saveMood() async {
    await FirestoreService.instance.addMood(
      widget.user.uid,
      mood: _mood,
      stress: _stress.round(),
      depressionScore: _depressionScore,
      note: _note.text.trim(),
    );
    _note.clear();
    await _saveDraft();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Check-in saved.')));
    }
  }

  Future<void> _toggleSound(MeditationSound sound) async {
    HapticFeedback.selectionClick();
    if (_playingSound == sound.title) {
      await _audioPlayer.stop();
      if (mounted) setState(() => _playingSound = null);
      await _saveDraft();
      return;
    }

    if (mounted) setState(() => _playingSound = sound.title);
    await FirestoreService.instance.saveSelectedSound(
      widget.user.uid,
      sound.title,
    );
    try {
      await _audioPlayer.setAsset(sound.assetPath);
      await _audioPlayer.play();
    } catch (error) {
      try {
        await _audioPlayer.setAsset(sound.fallbackAssetPath);
        await _audioPlayer.play();
      } catch (fallbackError) {
        if (!mounted) return;
        setState(() => _playingSound = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not play ${sound.title}: $fallbackError'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = [
      'Low energy',
      'Sad mood',
      'Hard to focus',
      'Poor sleep',
      'Hopeless thoughts',
    ];

    return AppScaffold(
      title: 'Meditation',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const MeditationHero(),
          const SizedBox(height: 14),
          SoundSection(
            title: 'Nature music',
            sounds: _natureSounds,
            playingSound: _playingSound,
            onToggle: _toggleSound,
          ),
          const SizedBox(height: 14),
          SoundSection(
            title: 'Hz sounds',
            sounds: _hertzSounds,
            playingSound: _playingSound,
            onToggle: _toggleSound,
          ),
          const SizedBox(height: 14),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirestoreService.instance
                .userDoc(widget.user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              final premium =
                  snapshot.data?.data()?['premium'] as bool? ?? false;
              return PremiumUpgradeCard(
                uid: widget.user.uid,
                isPremium: premium,
                title: premium ? 'Other sounds unlocked' : 'Other sounds',
                subtitle: premium
                    ? 'Premium sound packs and weekly AI mood support are saved on your profile.'
                    : 'Unlock extra rain mixes, deep sleep tones, study ambience, and weekly AI mood support.',
                price: '\$3.99',
              );
            },
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle(title: 'Mood and depression scale'),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    selected: {_mood},
                    onSelectionChanged: (value) {
                      setState(() => _mood = value.first);
                      unawaited(_saveDraft());
                    },
                    segments: const [
                      ButtonSegment(
                        value: 'Calm',
                        label: Text('Calm'),
                        icon: Icon(Icons.spa),
                      ),
                      ButtonSegment(
                        value: 'Tired',
                        label: Text('Tired'),
                        icon: Icon(Icons.bedtime),
                      ),
                      ButtonSegment(
                        value: 'Anxious',
                        label: Text('Anxious'),
                        icon: Icon(Icons.flash_on),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Stress: ${_stress.round()}%'),
                  Slider(
                    value: _stress,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    onChanged: (value) => setState(() => _stress = value),
                    onChangeEnd: (value) => unawaited(_saveDraft()),
                  ),
                  const SizedBox(height: 6),
                  ...List.generate(questions.length, (index) {
                    final value = _answers[index] ?? 0;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${questions[index]}: ${value.round()}'),
                        Slider(
                          value: value,
                          min: 0,
                          max: 4,
                          divisions: 4,
                          onChanged: (next) =>
                              setState(() => _answers[index] = next),
                          onChangeEnd: (next) => unawaited(_saveDraft()),
                        ),
                      ],
                    );
                  }),
                  Text('Depression scale: $_depressionScore ($_scaleLabel)'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _note,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'What happened this week?',
                      prefixIcon: Icon(Icons.edit_note),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _saveMood,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Save check-in'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const SectionTitle(title: 'Recent weekly mood'),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirestoreService.instance
                .moods(widget.user.uid)
                .orderBy('createdAt', descending: true)
                .limit(8)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LoadingScreen(inline: true);
              final moods = snapshot.data!.docs.map(MoodEntry.fromDoc).toList();
              if (moods.isEmpty) {
                return const EmptyState(
                  message: 'Mood history will appear here.',
                );
              }
              return Column(
                children: moods.map((mood) => MoodTile(mood: mood)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  final User user;

  const ChatPage({super.key, required this.user});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const _messageLimit = 1000;
  static const _welcomeMessage = ChatMessage(
    fromUser: false,
    text:
        'Ask me about lessons, homework, exam stress, meditation, nature sounds, Hz sounds, or when it is better to listen.',
  );

  final _message = TextEditingController();
  final _messages = <ChatMessage>[_welcomeMessage];
  var _chatLoaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadChat());
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _loadChat() async {
    final doc = await FirestoreService.instance.userDoc(widget.user.uid).get();
    final data = doc.data() ?? {};
    final stored = data['chatMessages'] as List? ?? [];
    final messages = stored
        .whereType<Map>()
        .map(
          (message) => ChatMessage.fromMap(Map<String, dynamic>.from(message)),
        )
        .toList();
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(messages.isEmpty ? [_welcomeMessage] : messages);
      _chatLoaded = true;
    });
  }

  Future<void> _saveChat() {
    return FirestoreService.instance.saveChatState(
      widget.user.uid,
      messages: _messages,
      usedCount: _messages.where((message) => message.fromUser).length,
    );
  }

  void _send() {
    final text = _message.text.trim();
    if (text.isEmpty) return;
    final sentMessages = _messages.where((message) => message.fromUser).length;
    if (sentMessages >= _messageLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You reached the 1000 AI chat message limit.'),
        ),
      );
      return;
    }
    setState(() {
      _messages.add(ChatMessage(fromUser: true, text: text));
      _messages.add(ChatMessage(fromUser: false, text: _replyFor(text)));
      _message.clear();
    });
    unawaited(_saveChat());
  }

  String _replyFor(String text) {
    final lower = text.toLowerCase();

    if (_hasAny(lower, [
      'rain',
      'ocean',
      'forest',
      'river',
      'bird',
      'nature',
    ])) {
      return 'Nature sounds are best when your body feels tense or distracted. Try rain for anxiety, ocean waves for breathing, forest or birds for morning study, and river stream for steady focus. Keep volume low so it supports your lesson instead of taking attention.';
    }
    if (_hasAny(lower, [
      'hz',
      'hertz',
      'frequency',
      '432',
      '528',
      '396',
      '852',
    ])) {
      return 'Hz sounds in this app are meditation tones. Use 432 Hz for calm reading, 528 Hz for a positive reset, 396 Hz when fear or exam stress feels strong, and 852 Hz when you want a clearer mind before revision. Listen softly for 5-15 minutes; they are relaxation tools, not medical treatment.';
    }
    if (_hasAny(lower, ['when', 'better', 'time', 'listen'])) {
      return 'Best timing: before studying, listen 3-5 minutes to calm down; during homework, use rain, river, or 432 Hz at low volume; before sleep, use night wind, snow silence, or 963 Hz; before an exam, use ocean waves or 852 Hz with slow breathing.';
    }
    if (_hasAny(lower, ['homework', 'assignment', 'task'])) {
      return 'For homework, choose one small part first. Set a 10 minute timer, write the exact question you need to solve, and keep only one subject open. After 10 minutes, continue with a 25 minute focus block or add the task on the Lessons page.';
    }
    if (_hasAny(lower, [
      'focus',
      'concentrate',
      'lesson',
      'study',
      'prepare',
    ])) {
      return 'To focus on a lesson, start with recall: write what you already remember, then study only the weak part. Use 25 minutes study plus 5 minutes rest. If your mind is noisy, play rain, river stream, or 432 Hz quietly.';
    }
    if (_hasAny(lower, ['exam', 'test', 'before examination'])) {
      return 'Before an exam, make three groups: know well, unsure, and urgent. Study urgent first, then test yourself with short questions. Use ocean waves or 852 Hz for 5 minutes, breathe out slowly, then revise one topic.';
    }
    if (_hasAny(lower, ['stress', 'anxious', 'panic', 'worried'])) {
      return 'For stress, open Meditation and try: breathe in 4, hold 4, breathe out 6. Then listen to rain, ocean waves, or 396 Hz for a few minutes. After that, pick one tiny lesson action so your brain sees progress.';
    }
    if (_hasAny(lower, ['depress', 'sad', 'hopeless', 'cannot', 'cry'])) {
      return 'I am glad you wrote this. First, do one caring action: drink water, breathe slowly, and message a trusted person. Use the depression scale in Meditation to track how heavy it feels. If you might hurt yourself or feel unsafe, contact emergency help or a trusted adult immediately.';
    }
    if (_hasAny(lower, ['app', 'mindflow', 'what can you do', 'help'])) {
      return 'I can help with this app: choosing nature sounds, explaining Hz sounds, deciding when to listen, planning lessons, handling homework, preparing for exams, and checking mood or stress.';
    }
    return 'I can answer questions about MindFlow: lessons, homework, exam stress, meditation, nature sounds, Hz sounds, and when to listen. Tell me which subject or feeling you want help with.';
  }

  bool _hasAny(String text, List<String> words) {
    return words.any(text.contains);
  }

  void _askQuickQuestion(String question) {
    _message.text = question;
    _send();
  }

  @override
  Widget build(BuildContext context) {
    final sentMessages = _messages.where((message) => message.fromUser).length;
    final remainingMessages = _messageLimit - sentMessages;

    return AppScaffold(
      title: 'AI Chat',
      child: Column(
        children: [
          if (!_chatLoaded) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: ChatLimitCard(
              used: sentMessages,
              limit: _messageLimit,
              remaining: remainingMessages,
            ),
          ),
          QuickQuestionBar(onQuestionSelected: _askQuickQuestion),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) =>
                  ChatBubble(message: _messages[index]),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _message,
                      minLines: 1,
                      maxLines: 3,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'I cannot focus on my lesson...',
                        prefixIcon: Icon(Icons.psychology_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: remainingMessages <= 0 ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  final User user;
  final List<String> subjects;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const SettingsPage({
    super.key,
    required this.user,
    required this.subjects,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _name = TextEditingController();
  final _avatar = TextEditingController();
  final _subjects = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _avatar.dispose();
    _subjects.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    await FirestoreService.instance.upsertUser(
      widget.user,
      displayName: _name.text.trim(),
      avatar: _avatar.text.trim(),
    );
    await widget.user.updateDisplayName(_name.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile saved.')));
    }
  }

  Future<void> _saveSubjects() async {
    final subjects = _subjects.text
        .split(',')
        .map((subject) => subject.trim())
        .where((subject) => subject.isNotEmpty)
        .toSet()
        .toList();
    if (subjects.isEmpty) return;
    await FirestoreService.instance.saveSubjects(widget.user.uid, subjects);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Subjects updated.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Settings',
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.instance.userDoc(widget.user.uid).snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? {};
          _name.text = data['name'] as String? ?? widget.user.displayName ?? '';
          _avatar.text = data['avatar'] as String? ?? '';
          final subjects = List<String>.from(
            data['subjects'] as List? ?? widget.subjects,
          );
          _subjects.text = subjects.join(', ');

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: MindColors.lavender,
                        backgroundImage: _avatar.text.isEmpty
                            ? null
                            : NetworkImage(_avatar.text),
                        child: _avatar.text.isEmpty
                            ? const Icon(
                                Icons.person,
                                size: 42,
                                color: MindColors.white,
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _avatar,
                        decoration: const InputDecoration(
                          labelText: 'Avatar URL',
                          prefixIcon: Icon(Icons.image_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _subjects,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Subjects',
                          prefixIcon: Icon(Icons.menu_book_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InfoRow(
                        label: 'Email',
                        value: widget.user.email ?? 'No email',
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _saveProfile,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save profile'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _saveSubjects,
                        icon: const Icon(Icons.school_outlined),
                        label: const Text('Save subjects'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: SwitchListTile(
                  value: widget.themeMode == ThemeMode.dark,
                  onChanged: (value) {
                    final mode = value ? ThemeMode.dark : ThemeMode.light;
                    widget.onThemeChanged(mode);
                    unawaited(
                      FirestoreService.instance.saveThemeMode(
                        widget.user.uid,
                        mode,
                      ),
                    );
                  },
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Dark mode'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await GoogleSignIn.instance.signOut();
                  await FirebaseAuth.instance.signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class FirestoreService {
  FirestoreService._();

  static final instance = FirestoreService._();
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> userDoc(String uid) {
    return _db.collection('users').doc(uid);
  }

  CollectionReference<Map<String, dynamic>> tasks(String uid) {
    return userDoc(uid).collection('tasks');
  }

  CollectionReference<Map<String, dynamic>> moods(String uid) {
    return userDoc(uid).collection('moods');
  }

  Future<void> upsertUser(User user, {String? displayName, String? avatar}) {
    return userDoc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'name': displayName?.isNotEmpty == true ? displayName : user.displayName,
      'avatar': avatar?.isNotEmpty == true ? avatar : user.photoURL,
      'lastLoginAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveSubjects(String uid, List<String> subjects) {
    return userDoc(uid).set({
      'subjects': subjects,
      'subjectsUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveThemeMode(String uid, ThemeMode mode) {
    return userDoc(uid).set({
      'themeMode': mode == ThemeMode.dark ? 'dark' : 'light',
      'themeUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> savePremium(String uid, bool premium) {
    return userDoc(uid).set({
      'premium': premium,
      'premiumUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveSelectedSound(String uid, String? selectedSound) {
    return userDoc(uid).set({
      'meditationDraft': {
        'selectedSound': selectedSound,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
  }

  Future<void> saveMeditationDraft(
    String uid, {
    required String mood,
    required double stress,
    required String? selectedSound,
    required Map<int, double> answers,
    required String note,
  }) {
    return userDoc(uid).set({
      'meditationDraft': {
        'mood': mood,
        'stress': stress,
        'selectedSound': selectedSound,
        'answers': answers.map((key, value) => MapEntry(key.toString(), value)),
        'note': note,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
  }

  Future<void> saveChatState(
    String uid, {
    required List<ChatMessage> messages,
    required int usedCount,
  }) {
    return userDoc(uid).set({
      'chatMessages': messages.map((message) => message.toMap()).toList(),
      'chatMessageCount': usedCount,
      'chatUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> addMood(
    String uid, {
    required String mood,
    required int stress,
    required int depressionScore,
    required String note,
  }) {
    return moods(uid).add({
      'mood': mood,
      'stress': stress,
      'depressionScore': depressionScore,
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveTask(String uid, MindTaskDraft draft, {String? id}) {
    final data = {
      'title': draft.title,
      'subject': draft.subject,
      'dueDate': Timestamp.fromDate(draft.dueDate),
      'completed': draft.completed,
      'updatedAt': FieldValue.serverTimestamp(),
      if (id == null) 'createdAt': FieldValue.serverTimestamp(),
    };
    if (id == null) return tasks(uid).add(data);
    return tasks(uid).doc(id).set(data, SetOptions(merge: true));
  }

  Future<void> updateTask(String uid, String id, Map<String, Object?> data) {
    return tasks(
      uid,
    ).doc(id).update({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> deleteTask(String uid, String id) {
    return tasks(uid).doc(id).delete();
  }
}

class MindTask {
  final String id;
  final String title;
  final String subject;
  final DateTime dueDate;
  final bool completed;

  const MindTask({
    required this.id,
    required this.title,
    required this.subject,
    required this.dueDate,
    required this.completed,
  });

  factory MindTask.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return MindTask(
      id: doc.id,
      title: data['title'] as String? ?? 'Untitled lesson',
      subject: data['subject'] as String? ?? 'General',
      dueDate: (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completed: data['completed'] as bool? ?? false,
    );
  }

  int get daysLeft {
    final today = DateTime.now();
    return DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
  }
}

class MindTaskDraft {
  final String title;
  final String subject;
  final DateTime dueDate;
  final bool completed;

  const MindTaskDraft({
    required this.title,
    required this.subject,
    required this.dueDate,
    required this.completed,
  });
}

class MoodEntry {
  final String mood;
  final int stress;
  final int depressionScore;
  final String note;

  const MoodEntry({
    required this.mood,
    required this.stress,
    required this.depressionScore,
    required this.note,
  });

  factory MoodEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return MoodEntry(
      mood: data['mood'] as String? ?? 'Calm',
      stress: data['stress'] as int? ?? 0,
      depressionScore: data['depressionScore'] as int? ?? 0,
      note: data['note'] as String? ?? '',
    );
  }
}

class ChatMessage {
  final bool fromUser;
  final String text;

  const ChatMessage({required this.fromUser, required this.text});

  factory ChatMessage.fromMap(Map<String, dynamic> data) {
    return ChatMessage(
      fromUser: data['fromUser'] as bool? ?? false,
      text: data['text'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'fromUser': fromUser, 'text': text};
  }
}

class MeditationSound {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String assetPath;
  final String fallbackAssetPath;

  const MeditationSound({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.assetPath,
    required this.fallbackAssetPath,
  });
}

Future<void> showTaskSheet(
  BuildContext context,
  String uid, {
  required List<String> subjects,
  MindTask? task,
}) async {
  final title = TextEditingController(text: task?.title ?? '');
  var subject =
      task?.subject ?? (subjects.isEmpty ? 'General' : subjects.first);
  var dueDate = task?.dueDate ?? DateTime.now().add(const Duration(days: 3));
  var completed = task?.completed ?? false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 18,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionTitle(
                    title: task == null
                        ? 'Add lesson task'
                        : 'Update lesson task',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: title,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'What must you prepare?',
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: subject,
                    items: [
                      for (final item in subjects)
                        DropdownMenuItem(value: item, child: Text(item)),
                      if (!subjects.contains('General'))
                        const DropdownMenuItem(
                          value: 'General',
                          child: Text('General'),
                        ),
                    ],
                    onChanged: (value) =>
                        setSheetState(() => subject = value ?? subject),
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      prefixIcon: Icon(Icons.school_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text(
                      'Due ${MaterialLocalizations.of(context).formatMediumDate(dueDate)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dueDate,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 1),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setSheetState(() => dueDate = picked);
                    },
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: completed,
                    title: const Text('Skill achieved'),
                    onChanged: (value) =>
                        setSheetState(() => completed = value ?? false),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () async {
                      if (title.text.trim().isEmpty) return;
                      await FirestoreService.instance.saveTask(
                        uid,
                        MindTaskDraft(
                          title: title.text.trim(),
                          subject: subject,
                          dueDate: dueDate,
                          completed: completed,
                        ),
                        id: task?.id,
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: Icon(task == null ? Icons.add : Icons.save_outlined),
                    label: Text(task == null ? 'Create' : 'Save changes'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  title.dispose();
}

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      floatingActionButton: floatingActionButton,
      body: child,
    );
  }
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [MindColors.sky, MindColors.lavender],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.spa, size: 48, color: MindColors.white),
        ),
        const SizedBox(height: 12),
        const Text(
          'MindFlow',
          style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
        ),
        const Text(
          'Student lessons, stress, mood, and support',
          textAlign: TextAlign.center,
          style: TextStyle(color: MindColors.muted),
        ),
      ],
    );
  }
}

class MeditationHero extends StatelessWidget {
  const MeditationHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MindColors.meditationBlue, MindColors.meditationPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: MindColors.white,
            foregroundColor: MindColors.lavenderDeep,
            child: Icon(Icons.self_improvement),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exam stress reset',
                  style: TextStyle(
                    color: MindColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Breathe in for 4, hold for 4, breathe out for 6. Repeat before opening the lesson task.',
                  style: TextStyle(color: MindColors.muted, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SoundSection extends StatelessWidget {
  final String title;
  final List<MeditationSound> sounds;
  final String? playingSound;
  final ValueChanged<MeditationSound> onToggle;

  const SoundSection({
    super.key,
    required this.title,
    required this.sounds,
    required this.playingSound,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(title: title),
            const SizedBox(height: 10),
            ...sounds.map(
              (sound) => SoundTile(
                sound: sound,
                selected: playingSound == sound.title,
                onTap: () => onToggle(sound),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SoundTile extends StatelessWidget {
  final MeditationSound sound;
  final bool selected;
  final VoidCallback onTap;

  const SoundTile({
    super.key,
    required this.sound,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? sound.color.withValues(alpha: 0.14)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: sound.color.withValues(alpha: 0.16),
                  foregroundColor: sound.color,
                  child: Icon(sound.icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sound.title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sound.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MindColors.muted,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: selected ? 'Stop' : 'Play',
                  onPressed: onTap,
                  icon: Icon(selected ? Icons.pause : Icons.play_arrow),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PremiumUpgradeCard extends StatelessWidget {
  final String uid;
  final bool isPremium;
  final String title;
  final String subtitle;
  final String price;

  const PremiumUpgradeCard({
    super.key,
    required this.uid,
    required this.isPremium,
    required this.title,
    required this.subtitle,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MindColors.meditationPurple, MindColors.meditationBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            backgroundColor: MindColors.white,
            foregroundColor: MindColors.lavenderDeep,
            child: Icon(Icons.workspace_premium_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: MindColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: MindColors.muted, height: 1.35),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: isPremium
                      ? null
                      : () => _showPremiumSheet(context, uid, price),
                  icon: Icon(
                    isPremium
                        ? Icons.verified_outlined
                        : Icons.lock_open_outlined,
                  ),
                  label: Text(
                    isPremium ? 'Premium active' : 'Unlock for $price',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPremiumSheet(BuildContext context, String uid, String price) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionTitle(title: 'Premium sounds'),
              const SizedBox(height: 10),
              Text(
                '$price unlocks other sound packs and premium AI chat support. Real App Store or Google Play payment can be connected next.',
                style: const TextStyle(color: MindColors.muted, height: 1.35),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () async {
                  await FirestoreService.instance.savePremium(uid, true);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.payment_outlined),
                label: Text('Continue with $price'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ChatLimitCard extends StatelessWidget {
  final int used;
  final int limit;
  final int remaining;

  const ChatLimitCard({
    super.key,
    required this.used,
    required this.limit,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    final progress = limit == 0 ? 0.0 : used / limit;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.smart_toy_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$remaining AI messages left',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text('$used/$limit'),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
          ],
        ),
      ),
    );
  }
}

class QuickQuestionBar extends StatelessWidget {
  final ValueChanged<String> onQuestionSelected;

  const QuickQuestionBar({super.key, required this.onQuestionSelected});

  static const _questions = [
    'Which Hz sound is better for focus?',
    'When should I listen to rain sound?',
    'How can I prepare my lesson?',
    'What should I do before an exam?',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final question = _questions[index];
          return ActionChip(
            avatar: const Icon(Icons.auto_awesome_outlined, size: 18),
            label: Text(question),
            onPressed: () => onQuestionSelected(question),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemCount: _questions.length,
      ),
    );
  }
}

class WelcomeCard extends StatelessWidget {
  final User user;
  final int openTasks;
  final int stress;

  const WelcomeCard({
    super.key,
    required this.user,
    required this.openTasks,
    required this.stress,
  });

  @override
  Widget build(BuildContext context) {
    final name = user.displayName?.isNotEmpty == true
        ? user.displayName!
        : user.email?.split('@').first ?? 'student';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MindColors.sky, MindColors.lavender],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hi, $name',
            style: const TextStyle(
              color: MindColors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Prepare lessons calmly and check your mood before examination stress grows.',
            style: TextStyle(color: MindColors.white, height: 1.4),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              StatPill(label: 'Open lessons', value: '$openTasks'),
              StatPill(label: 'Avg stress', value: '$stress%'),
            ],
          ),
        ],
      ),
    );
  }
}

class StatPill extends StatelessWidget {
  final String label;
  final String value;

  const StatPill({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: MindColors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$value $label',
        style: const TextStyle(
          color: MindColors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class SkillChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const SkillChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      side: BorderSide.none,
    );
  }
}

class InsightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  const InsightCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.14),
              foregroundColor: color,
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(
                      color: MindColors.muted,
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
  }
}

class TaskTile extends StatelessWidget {
  final MindTask task;
  final bool compact;
  final VoidCallback? onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TaskTile({
    super.key,
    required this.task,
    this.compact = false,
    this.onToggle,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dueColor = task.daysLeft <= 2 ? MindColors.danger : MindColors.green;

    return Card(
      child: ListTile(
        leading: Checkbox(
          value: task.completed,
          onChanged: onToggle == null ? null : (_) => onToggle!(),
        ),
        title: Text(
          task.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            decoration: task.completed ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text('${task.subject} · ${_dueLabel(task.daysLeft)}'),
        trailing: compact
            ? Icon(Icons.circle, color: dueColor, size: 12)
            : PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit?.call();
                  if (value == 'delete') onDelete?.call();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Update')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
      ),
    );
  }

  String _dueLabel(int days) {
    if (days < 0) return 'overdue';
    if (days == 0) return 'due today';
    if (days == 1) return 'due tomorrow';
    return 'due in $days days';
  }
}

class MoodTile extends StatelessWidget {
  final MoodEntry mood;

  const MoodTile({super.key, required this.mood});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: MindColors.green.withValues(alpha: 0.14),
          foregroundColor: MindColors.green,
          child: const Icon(Icons.spa),
        ),
        title: Text('${mood.mood} · ${mood.stress}% stress'),
        subtitle: Text(
          'Depression scale ${mood.depressionScore}. ${mood.note.isEmpty ? 'No note' : mood.note}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final color = message.fromUser
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final textColor = message.fromUser
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Align(
      alignment: message.fromUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          message.text,
          style: TextStyle(color: textColor, height: 1.35),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;

  const SectionTitle({super.key, required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        if (action != null)
          Text(action!, style: const TextStyle(color: MindColors.muted)),
      ],
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const InfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: MindColors.muted)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;

  const EmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: MindColors.muted, height: 1.4),
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;

  const ErrorState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return EmptyState(message: 'Something needs attention: $message');
  }
}

class LoadingScreen extends StatelessWidget {
  final bool inline;

  const LoadingScreen({super.key, this.inline = false});

  @override
  Widget build(BuildContext context) {
    final loader = const Center(child: CircularProgressIndicator());
    return inline ? loader : Scaffold(body: loader);
  }
}

class FirebaseSetupScreen extends StatelessWidget {
  final Object? error;

  const FirebaseSetupScreen({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const BrandHeader(),
                      const SizedBox(height: 20),
                      const InsightCard(
                        icon: Icons.cloud_off_outlined,
                        title: 'Firebase is not configured on this build',
                        body:
                            'Add this app to Firebase, download config files, then run flutterfire configure. The app shows this screen instead of crashing.',
                        color: MindColors.skyDark,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        SelectableText(
                          error.toString(),
                          style: const TextStyle(color: MindColors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
