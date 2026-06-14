import 'package:flutter/material.dart';
import '../../features/complaints/presentation/screens/complaints_history_screen.dart';
import '../../features/complaints/presentation/screens/home_screen.dart';
import '../../features/complaints/presentation/screens/raise_complaint_screen.dart';
import '../../features/complaints/presentation/screens/settings_screen.dart';
import '../../features/complaints/presentation/screens/customer_orders_screen.dart';

import '../theme/page_transition.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // ✅ Screens List (NO const)
    final List<Widget> screens = [
      const HomeScreen(),
      const CustomerOrdersScreen(),
      const ComplaintHistoryScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      extendBody: true, // Allows content to show under the floating navigation bar
      body: screens[selectedIndex],

      // ✅ Modern Floating Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        padding: const EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: 24,
          top: 10,
        ),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Home
              _navItem(
                icon: Icons.home_rounded,
                label: "Home",
                index: 0,
              ),

              // Orders
              _navItem(
                icon: Icons.shopping_bag_rounded,
                label: "Orders",
                index: 1,
              ),

              // History
              _navItem(
                icon: Icons.history_rounded,
                label: "History",
                index: 2,
              ),

              // Settings
              _navItem(
                icon: Icons.settings_rounded,
                label: "Settings",
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Bottom Nav Item Widget with active indicator
  Widget _navItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final bool active = selectedIndex == index;
    const Color activeColor = Color(0xff0D47A1);
    final Color inactiveColor = Colors.grey.shade400;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            selectedIndex = index;
          });
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: active ? activeColor : inactiveColor,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                color: active ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: active ? 16 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}