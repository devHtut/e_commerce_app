import 'package:flutter/material.dart';
import '../theme_config.dart';

class AppBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavigationBarItem> items;

  const AppBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final navBackground =
        Theme.of(context).bottomNavigationBarTheme.backgroundColor ??
        Theme.of(context).canvasColor;

    return Material(
      color: navBackground,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset + 12),
        child: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: Theme(
            data: Theme.of(context).copyWith(
              splashFactory: NoSplash.splashFactory,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: BottomNavigationBar(
              currentIndex: currentIndex,
              elevation: 0,
              selectedItemColor: AppColors.primaryGreen,
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              onTap: onTap,
              items: items,
            ),
          ),
        ),
      ),
    );
  }
}
