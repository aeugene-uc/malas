import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/auth_repository.dart';
import '../../data/store_repository.dart';
import '../../model/account.dart';
import '../../viewmodel/session_view_model.dart';
import '../../viewmodel/settings_view_model.dart';
import '../format.dart';
import 'items_view.dart';

/// Opened from the business name on Beranda (§6).
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  static Route<void> route(Account account) {
    return MaterialPageRoute(
      builder: (context) => ChangeNotifierProvider(
        create: (context) => SettingsViewModel(
          account: account,
          storeRepository: context.read<StoreRepository>(),
          authRepository: context.read<AuthRepository>(),
        ),
        child: const SettingsView(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SettingsViewModel>();
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionTitle('Jenis usaha'),
          _ChipWrap(
            children: [
              for (final type in BusinessType.values)
                FilterChip(
                  label: Text(type.label),
                  selected: viewModel.businessTypes.contains(type),
                  onSelected: (_) => viewModel.toggleBusinessType(type),
                ),
            ],
          ),
          const _SectionTitle('Hari tutup'),
          _ChipWrap(
            children: [
              for (
                var weekday = DateTime.monday;
                weekday <= DateTime.sunday;
                weekday++
              )
                FilterChip(
                  label: Text(formatIsoWeekdayShort(weekday)),
                  selected: viewModel.closedDays.contains(weekday),
                  onSelected: (_) => viewModel.toggleClosedDay(weekday),
                ),
            ],
          ),
          ListTile(
            title: const Text('Ganti hari'),
            trailing: DropdownButton<int>(
              value: viewModel.dayChangeHour,
              onChanged: (hour) {
                if (hour != null) viewModel.selectDayChangeHour(hour);
              },
              items: [
                for (final hour in SettingsViewModel.dayChangeHours)
                  DropdownMenuItem(value: hour, child: Text(_formatHour(hour))),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('Pengingat malam'),
            value: viewModel.isReminderOn,
            onChanged: viewModel.setReminderOn,
          ),
          if (viewModel.reminderTime case final reminderTime?)
            ListTile(
              title: const Text('Jam pengingat'),
              trailing: Text(reminderTime, style: textTheme.titleMedium),
              onTap: () => _pickReminderTime(context, reminderTime),
            ),
          SwitchListTile(
            title: const Text('Peringatan'),
            value: viewModel.isAlertsOn,
            onChanged: viewModel.setAlertsOn,
          ),
          const Divider(),
          ListTile(
            title: const Text('Barang dan satuan'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(ItemsView.route()),
          ),
          ListTile(
            title: const Text('Paket'),
            trailing: Text(_planLabel(viewModel.plan)),
          ),
          ListTile(
            title: Text(
              'Keluar',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _signOut(context),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (viewModel.errorMessage case final message?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
                onPressed: viewModel.hasChanges && !viewModel.isSaving
                    ? () => _save(context)
                    : null,
                child: const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickReminderTime(
    BuildContext context,
    String reminderTime,
  ) async {
    final viewModel = context.read<SettingsViewModel>();
    final [hour, minute] = reminderTime.split(':').map(int.parse).toList();
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
    );
    if (pickedTime == null) return;
    viewModel.selectReminderTime(
      '${_twoDigits(pickedTime.hour)}:${_twoDigits(pickedTime.minute)}',
    );
  }

  /// The navigator is taken before waiting, because Simpan's own context is
  /// rebuilt while it saves.
  Future<void> _save(BuildContext context) async {
    final navigator = Navigator.of(context);
    final session = context.read<SessionViewModel>();
    final account = await context.read<SettingsViewModel>().save();
    if (account == null) return;
    await session.enter(account);
    if (navigator.mounted) navigator.pop();
  }

  Future<void> _signOut(BuildContext context) async {
    final navigator = Navigator.of(context);
    await context.read<SessionViewModel>().signOut();
    navigator.popUntil((route) => route.isFirst);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(spacing: 8, runSpacing: 8, children: children),
    );
  }
}

String _formatHour(int hour) => '${_twoDigits(hour)}:00';

String _twoDigits(int number) => number.toString().padLeft(2, '0');

String _planLabel(Plan plan) {
  return switch (plan) {
    Plan.gratis => 'Gratis',
    Plan.pro => 'Pro',
    Plan.proPlus => 'Pro Plus',
  };
}
