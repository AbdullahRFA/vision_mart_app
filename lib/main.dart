import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'firebase_options.dart';
import 'src/features/authentication/data/auth_repository.dart';
import 'src/features/authentication/presentation/auth_screen.dart';
import 'src/features/inventory/presentation/receive_product_screen.dart';
import 'src/features/inventory/presentation/inventory_screen.dart';
import 'src/features/analytics/presentation/analytics_screen.dart';
import 'src/features/analytics/data/analytics_repository.dart';
import 'src/features/due_management/presentation/due_screen.dart';
import 'src/features/expenses/presentation/expense_screen.dart';

// ... [ThemeModeNotifier, themeModeProvider, main, and VisionMartApp remain unchanged] ...

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return ThemeMode.system;
  }
  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

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
    final authState = ref.watch(authStateProvider);
    final themeMode = ref.watch(themeModeProvider);
    const primarySeed = Color(0xFF2563EB);

    return MaterialApp(
      title: 'A & R Vision Mart',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: primarySeed),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Colors.black87),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primarySeed,
          brightness: Brightness.dark,
          surface: const Color(0xFF0F172A),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        scaffoldBackgroundColor: const Color(0xFF020617),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      home: authState.when(
        data: (user) => user != null ? const DashboardScreen() : const AuthScreen(),
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, trace) => Scaffold(body: Center(child: Text('Error: $e'))),
      ),
    );
  }
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _selectedFilter = 'This Month';
  DateTimeRange? _customRange;

  final List<String> _filterOptions = [
    'Today', 'This Week', 'This Month', 'This Year', 'All Time', 'Custom'
  ];

  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    DateTime start, end;

    switch (_selectedFilter) {
      case 'Today':
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'This Week':
        start = now.subtract(Duration(days: now.weekday % 7));
        start = DateTime(start.year, start.month, start.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'This Month':
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case 'This Year':
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
      case 'All Time':
        start = DateTime(2020);
        end = DateTime.now();
        break;
      case 'Custom':
        return _customRange ?? DateTimeRange(start: now, end: now);
      default:
        start = DateTime(now.year, now.month, 1);
        end = DateTime.now();
    }
    return DateTimeRange(start: start, end: end);
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      currentDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _selectedFilter = 'Custom';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.read(authServiceProvider).currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final range = _getDateRange();
    final salesStream = ref.watch(analyticsRepositoryProvider).getSalesForRange(range.start, range.end);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: isDark ? "Switch to Light Mode" : "Switch to Dark Mode",
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? Colors.yellow : Colors.grey[800],
            ),
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggle();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(authServiceProvider).signOut(),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- WELCOME HEADER ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E40AF), const Color(0xFF1E3A8A)]
                      : [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Welcome Back,", style: TextStyle(color: Colors.white70, fontSize: 14)),
                        Text(
                          user?.email?.split('@')[0] ?? 'Admin',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- BUSINESS OVERVIEW SECTION ---
            // Locate this section inside your DashboardScreen > build > Column
// under "// --- BUSINESS OVERVIEW SECTION ---"

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Business Overview", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

                // Filter Dropdown
                PopupMenuButton<String>(
                  initialValue: _selectedFilter,
                  onSelected: (value) {
                    if (value == 'Custom') {
                      _pickCustomDateRange();
                    } else {
                      setState(() => _selectedFilter = value);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _selectedFilter,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            // Changed to Yellow as requested
                            // Note: Yellow is hard to read on White (Light Mode), so we typically keep it dark in light mode.
                            // If you want yellow ALWAYS, just use 'Colors.yellow'.
                            // Below logic: Yellow in Dark Mode, Dark Blue in Light Mode.
                            color: isDark ? Colors.yellow : Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 18,
                          // Icon matches the text color
                          color: isDark ? Colors.yellow : Theme.of(context).primaryColor,
                        ),
                      ],
                    ),
                  ),
                  itemBuilder: (context) => _filterOptions.map((filter) => PopupMenuItem(
                    value: filter,
                    child: Text(filter),
                  )).toList(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // --- METRIC CARDS ---
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: salesStream,
              builder: (context, snapshot) {
                double totalRevenue = 0;
                double totalProfit = 0;

                if (snapshot.hasData) {
                  for (var sale in snapshot.data!) {
                    totalRevenue += (sale['totalAmount'] ?? 0).toDouble();
                    totalProfit += (sale['profit'] ?? 0).toDouble();
                  }
                }

                final totalInvestment = totalRevenue - totalProfit;
                final bool isProfitNegative = totalProfit < 0;

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: LinearProgressIndicator());
                }

                return Column(
                  children: [
                    // Row 1: Investment & Revenue
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: "Investment",
                            subtitle: "(COGS)",
                            value: "৳${totalInvestment.toStringAsFixed(0)}",
                            icon: Icons.inventory_2_outlined,
                            color: Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            title: "Revenue",
                            subtitle: "(Sales)",
                            value: "৳${totalRevenue.toStringAsFixed(0)}",
                            icon: Icons.attach_money,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Row 2: Profit (Full Width) with Conditional Background
                    _StatCard(
                      title: "Net Profit",
                      subtitle: "(Earnings)",
                      value: "৳${totalProfit.toStringAsFixed(0)}",
                      icon: isProfitNegative ? Icons.trending_down : Icons.trending_up,
                      // Pass Red/Green background color logic here
                      backgroundColor: isProfitNegative ? Colors.red.shade700 : Colors.green.shade700,
                      color: Colors.white, // This is ignored if backgroundColor is set, but kept for safety
                      isFullWidth: true,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 30),

            // --- QUICK ACTIONS ---
            const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: [
                _DashboardCard(
                  title: "Receive Stock",
                  icon: Icons.add_box_rounded,
                  color: Colors.blue,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceiveProductScreen())),
                ),
                _DashboardCard(
                  title: "Inventory",
                  icon: Icons.inventory_2_rounded,
                  color: Colors.purple,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen())),
                ),
                _DashboardCard(
                  title: "Sales Report",
                  icon: Icons.bar_chart_rounded,
                  color: Colors.orange,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen())),
                ),
                _DashboardCard(
                  title: "Due List",
                  icon: Icons.account_balance_wallet_rounded,
                  color: Colors.red,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DueScreen())),
                ),
                _DashboardCard(
                  title: "Expenses",
                  icon: Icons.money_off_csred_rounded,
                  color: Colors.redAccent,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseScreen())),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Updated Statistic Card Widget
class _StatCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final IconData icon;
  final Color color;
  final bool isFullWidth;
  final Color? backgroundColor; // Added to support solid background

  const _StatCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.color,
    this.isFullWidth = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Logic: If backgroundColor is provided (Profit card), use it.
    // Otherwise use default Theme colors.
    final finalBgColor = backgroundColor ?? (isDark ? const Color(0xFF1E293B) : Colors.white);

    // Logic: If we have a custom background (Red/Green), text MUST be White for contrast.
    // If standard card, use standard colors (White/Grey for Dark Mode, Black/Grey for Light Mode).
    final hasCustomBg = backgroundColor != null;
    final mainTextColor = hasCustomBg ? Colors.white : (isDark ? Colors.white : Colors.black87);
    final subTextColor = hasCustomBg ? Colors.white70 : (isDark ? Colors.white70 : Colors.grey[600]);
    final iconTintColor = hasCustomBg ? Colors.white : color;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: finalBgColor,
        borderRadius: BorderRadius.circular(16),
        border: hasCustomBg ? null : Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: hasCustomBg ? backgroundColor!.withOpacity(0.3) : color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasCustomBg ? Colors.white.withOpacity(0.2) : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: iconTintColor),
              ),
              if (isFullWidth)
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: subTextColor),
                )
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 12, color: subTextColor, fontWeight: FontWeight.bold)),
          if (!isFullWidth)
            Text(subtitle, style: TextStyle(fontSize: 10, color: subTextColor)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: mainTextColor,
            ),
          ),
        ],
      ),
    );
  }
}
// _DashboardCard remains unchanged
class _DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardCard({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}