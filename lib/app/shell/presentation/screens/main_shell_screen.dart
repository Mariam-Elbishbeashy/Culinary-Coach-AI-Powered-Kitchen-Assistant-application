import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/features/community/presentation/screens/community_screen.dart';
import 'package:culinary_coach_app/features/history/presentation/screens/my_recipes_screen.dart';
import 'package:culinary_coach_app/features/home/presentation/screens/home_screen.dart';
import 'package:culinary_coach_app/features/filter/presentation/screens/filter_screen.dart';
import 'package:culinary_coach_app/features/shop/presentation/screens/shop_screen.dart';
import 'package:flutter/material.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({
    super.key,
    this.initialIndex = 0,
    this.openShopCartOnStart = false,
  });

  final int initialIndex;
  final bool openShopCartOnStart;

  @override
  State<MainShellScreen> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellScreen> {
  late int _currentIndex;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 4);
  }

  void _setDarkMode(bool value) {
    setState(() {
      _isDarkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor:
      _isDarkMode ? const Color(0xFF121212) : AppColors.background,

      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -70,
            child: _AmbientGlow(
              size: 260,
              color: AppColors.primary.withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            top: 140,
            left: -40,
            child: _AmbientGlow(
              size: 160,
              color: AppColors.accent.withValues(alpha: 0.28),
            ),
          ),

          IndexedStack(
            index: _currentIndex,
            children: [
              const HomeScreen(),

              MyRecipesScreen(
                isDarkMode: _isDarkMode,
                onDarkModeChanged: _setDarkMode,
              ),

              const CommunityScreen(),

              ShopScreen(
                showCartOnStart: widget.openShopCartOnStart,
              ),

              const FilterScreen(),
            ],
          ),
        ],
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: _currentIndex == 4 ? 70 : 66,
        width: _currentIndex == 4 ? 70 : 66,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: _currentIndex == 4
              ? Border.all(color: Colors.white, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE8A329)
                  .withValues(alpha: _currentIndex == 4 ? 0.45 : 0.22),
              blurRadius: _currentIndex == 4 ? 16 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          heroTag: null,
          elevation: 0,
          backgroundColor: _currentIndex == 4
              ? const Color(0xFFD9951F)
              : const Color(0xFFE8A329),
          foregroundColor: Colors.white,
          onPressed: () => setState(() => _currentIndex = 4),
          shape: const CircleBorder(),
          child: const Icon(Icons.add, size: 30),
        ),
      ),

      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 18,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius:
          const BorderRadius.vertical(top: Radius.circular(30)),
          child: BottomAppBar(
            height: 86,
            color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            elevation: 4,
            surfaceTintColor: Colors.transparent,
            shape: const CircularNotchedRectangle(),
            notchMargin: 10,
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: _NavBarItem(
                      icon: Icons.home_rounded,
                      label: 'Home',
                      isSelected: _currentIndex == 0,
                      isDarkMode: _isDarkMode,
                      onTap: () => setState(() => _currentIndex = 0),
                    ),
                  ),
                  Expanded(
                    child: _NavBarItem(
                      icon: Icons.favorite_border_rounded,
                      label: 'My Recipes',
                      isSelected: _currentIndex == 1,
                      isDarkMode: _isDarkMode,
                      onTap: () => setState(() => _currentIndex = 1),
                    ),
                  ),
                  const SizedBox(width: 66),
                  Expanded(
                    child: _NavBarItem(
                      icon: Icons.diversity_1,
                      label: 'Community',
                      isSelected: _currentIndex == 2,
                      isDarkMode: _isDarkMode,
                      onTap: () => setState(() => _currentIndex = 2),
                    ),
                  ),
                  Expanded(
                    child: _NavBarItem(
                      icon: Icons.storefront_outlined,
                      label: 'Shop',
                      isSelected: _currentIndex == 3,
                      isDarkMode: _isDarkMode,
                      onTap: () => setState(() => _currentIndex = 3),
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

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDarkMode,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDarkMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFFE8A329);
    final inactiveColor =
    isDarkMode ? Colors.white70 : const Color(0xFF8F8F8F);

    final color = isSelected ? activeColor : inactiveColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight:
                isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 11.5,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}