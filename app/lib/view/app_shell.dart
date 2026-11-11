import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodel/app_shell_view_model.dart';
import 'analisis/analisis_view.dart';
import 'beranda/beranda_view.dart';
import 'catatan/catatan_view.dart';
import 'tanya/tanya_view.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AppShellViewModel>();
    return Scaffold(
      // IndexedStack keeps each tab's scroll position and state when the
      // owner switches away and back.
      body: IndexedStack(
        index: viewModel.selectedTab.index,
        children: const [
          BerandaView(),
          CatatanView(),
          AnalisisView(),
          TanyaView(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: viewModel.selectedTab.index,
        onDestinationSelected: (index) =>
            viewModel.selectTab(AppTab.values[index]),
        destinations: [
          for (final tab in AppTab.values)
            NavigationDestination(icon: Icon(_iconFor(tab)), label: tab.label),
        ],
      ),
    );
  }
}

IconData _iconFor(AppTab tab) {
  return switch (tab) {
    AppTab.beranda => Icons.home_outlined,
    AppTab.catatan => Icons.receipt_long_outlined,
    AppTab.analisis => Icons.insights_outlined,
    AppTab.tanya => Icons.chat_bubble_outline,
  };
}
