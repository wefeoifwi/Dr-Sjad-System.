import 'package:flutter/material.dart';
import '../../core/responsive_layout.dart';
import '../../core/theme.dart';

class LayoutShell extends StatefulWidget {
  final Widget child; // The screen content to display
  final int selectedIndex;
  final Function(int) onIndexChanged;
  final List<NavigationDestination> destinations;

  const LayoutShell({
    super.key,
    required this.child,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.destinations,
  });

  @override
  State<LayoutShell> createState() => _LayoutShellState();
}

class _LayoutShellState extends State<LayoutShell> {
  // Uses widget.destinations now

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      // Mobile: Bottom Navigation Bar
      mobile: Scaffold(
        body: widget.child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: widget.selectedIndex,
          onDestinationSelected: widget.onIndexChanged,
          destinations: widget.destinations,
          backgroundColor: AppTheme.surface,
          elevation: 10,
        ),
      ),
      
      // Tablet: Navigation Rail (Slim side bar)
      tablet: Scaffold(
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: AppTheme.surface,
              selectedIndex: widget.selectedIndex,
              onDestinationSelected: widget.onIndexChanged,
              labelType: NavigationRailLabelType.selected,
              destinations: widget.destinations.map((d) {
                return NavigationRailDestination(
                  icon: d.icon,
                  selectedIcon: d.selectedIcon,
                  label: Text(d.label),
                );
              }).toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: widget.child),
          ],
        ),
      ),
      
      // Desktop: Full Drawer / Sidebar
      desktop: Scaffold(
        body: Row(
          children: [
            // Custom Drawer for Desktop
            Container(
              width: 250,
              color: AppTheme.surface,
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  // Logo Area
                  const Icon(Icons.spa, size: 48, color: AppTheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'CarePoint',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Menu Items
                  Expanded(
                    child: ListView.builder(
                      itemCount: widget.destinations.length,
                      itemBuilder: (context, index) {
                        final isSelected = widget.selectedIndex == index;
                        return ListTile(
                          leading: Icon(
                            isSelected 
                              ? (widget.destinations[index].selectedIcon as Icon).icon 
                              : (widget.destinations[index].icon as Icon).icon,
                            color: isSelected ? AppTheme.primary : Colors.white70,
                          ),
                          title: Text(
                            widget.destinations[index].label,
                            style: TextStyle(
                              color: isSelected ? AppTheme.primary : Colors.white70,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          onTap: () => widget.onIndexChanged(index),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(thickness: 1, width: 1, color: Colors.white10),
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }
}
