import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'src/features/authentication/data/auth_repository.dart';
import 'src/features/authentication/presentation/auth_screen.dart';
import 'src/features/inventory/presentation/receive_product_screen.dart';
import 'src/features/inventory/presentation/inventory_screen.dart';
import 'src/features/analytics/presentation/analytics_screen.dart';
import 'src/features/due_management/presentation/due_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: VisionMartApp()));
}

class VisionMartApp extends ConsumerWidget {
  const VisionMartApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to the auth state (Login vs Logout)
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'A & R Vision Mart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: ThemeMode.system,
      // Intelligently switch screens based on auth state
      home: authState.when(
        data: (user) {
          if (user != null) {
            // User is Logged In -> Show Dashboard
            return const DashboardScreen();
          }
          // User is Logged Out -> Show Auth Screen
          return const AuthScreen();
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, trace) => Scaffold(
          body: Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}

// Temporary Dashboard to test Logout
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.read(authServiceProvider).currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          // LOGOUT BUTTON
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              // 1. Call the SignOut method
              ref.read(authServiceProvider).signOut();
              // 2. The StreamProvider in main.dart detects the change
              // and automatically switches back to AuthScreen.
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome Back!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              user?.email ?? 'User', // Show the logged-in email
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 30),
            const Text("Inventory & Sales modules coming next..."),
            // ... inside the Column children of DashboardScreen
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_box),
              label: const Text("Receive Product"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReceiveProductScreen())
                );
              },
            ),
            // ... inside the Column, below the "Receive Product" button
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.inventory),
              label: const Text("View Inventory"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InventoryScreen()) // Import the file!
                );
              },
            ),
            // ... inside the Column, below "View Inventory"
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.bar_chart),
              label: const Text("Business Report (Today)"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                backgroundColor: Colors.indigo.shade50, // Slight visual distinction
                foregroundColor: Colors.indigo,
              ),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnalyticsScreen())
                );
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.account_balance_wallet),
              label: const Text("Due List (Khata)"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DueScreen())
                );
              },
            ),
// ...
// ...

// ...
          ],
        ),
      ),
    );
  }
}