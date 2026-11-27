import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/store_repository.dart';
import '../../model/account.dart';
import '../../viewmodel/session_view_model.dart';
import '../../viewmodel/settings_view_model.dart';
import '../format.dart';
import '../theme/brand_header.dart';
import '../theme/icons.dart';
import '../theme/lip.dart';
import '../theme/parts.dart';
import '../theme/tokens.dart';
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
        ),
        child: const SettingsView(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SettingsViewModel>();
    final reminderTime = viewModel.reminderTime;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // §5.4: a form keeps only the header hills; the action hides the
          // coins.
          BrandHeader(
            title: 'Pengaturan',
            height: _formHeaderHeight,
            actions: [
              IconButton(
                tooltip: 'Tutup',
                color: MalasColors.textOnBrand,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(MalasIcons.x),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MalasSpace.screen,
              MalasSpace.s8,
              MalasSpace.screen,
              MalasSpace.s24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(title: 'Jenis usaha'),
                _ChipWrap(
                  children: [
                    for (final type in BusinessType.values)
                      SelectChip(
                        label: type.label,
                        isSelected: viewModel.businessTypes.contains(type),
                        onPressed: () => viewModel.toggleBusinessType(type),
                      ),
                  ],
                ),
                const SizedBox(height: MalasSpace.s24),
                const SectionHeader(title: 'Hari tutup'),
                _ChipWrap(
                  children: [
                    for (
                      var weekday = DateTime.monday;
                      weekday <= DateTime.sunday;
                      weekday++
                    )
                      SelectChip(
                        label: formatIsoWeekdayShort(weekday),
                        isSelected: viewModel.closedDays.contains(weekday),
                        onPressed: () => viewModel.toggleClosedDay(weekday),
                      ),
                  ],
                ),
                const SizedBox(height: MalasSpace.s24),
                _SettingsCard(
                  rows: [
                    _SettingRow(
                      label: 'Ganti hari',
                      trailing: DropdownButton<int>(
                        value: viewModel.dayChangeHour,
                        underline: const SizedBox.shrink(),
                        style: MalasText.bodyStrong,
                        icon: const Icon(MalasIcons.caretDown, size: 20),
                        onChanged: (hour) {
                          if (hour != null) viewModel.selectDayChangeHour(hour);
                        },
                        items: [
                          for (final hour in SettingsViewModel.dayChangeHours)
                            DropdownMenuItem(
                              value: hour,
                              child: Text(_formatHour(hour)),
                            ),
                        ],
                      ),
                    ),
                    _SettingRow(
                      label: 'Pengingat malam',
                      onTap: () =>
                          viewModel.setReminderOn(!viewModel.isReminderOn),
                      trailing: Switch(
                        value: viewModel.isReminderOn,
                        onChanged: viewModel.setReminderOn,
                      ),
                    ),
                    if (reminderTime != null)
                      _SettingRow(
                        label: 'Jam pengingat',
                        value: reminderTime,
                        onTap: () => _pickReminderTime(context, reminderTime),
                      ),
                    _SettingRow(
                      label: 'Peringatan',
                      onTap: () => viewModel.setAlertsOn(!viewModel.isAlertsOn),
                      trailing: Switch(
                        value: viewModel.isAlertsOn,
                        onChanged: viewModel.setAlertsOn,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MalasSpace.s24),
                _SettingsCard(
                  rows: [
                    _SettingRow(
                      label: 'Barang dan satuan',
                      onTap: () =>
                          Navigator.of(context).push(ItemsView.route()),
                    ),
                    _SettingRow(
                      label: 'Paket',
                      value: _planLabel(viewModel.plan),
                    ),
                  ],
                ),
                const SizedBox(height: MalasSpace.s24),
                LipButton(
                  label: 'Keluar',
                  icon: MalasIcons.signOut,
                  variant: LipVariant.danger,
                  onPressed: () => _signOut(context),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            MalasSpace.screen,
            MalasSpace.s8,
            MalasSpace.screen,
            MalasSpace.s12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (viewModel.errorMessage case final message?)
                Padding(
                  padding: const EdgeInsets.only(bottom: MalasSpace.s8),
                  child: Text(
                    message,
                    style: MalasText.bodySecondary.copyWith(
                      color: MalasColors.textError,
                    ),
                  ),
                ),
              LipButton(
                label: 'Simpan',
                onPressed: viewModel.hasChanges && !viewModel.isSaving
                    ? () => _save(context)
                    : null,
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
    final session = context.read<SessionViewModel>();
    // §4.2: a sheet, primary for the action and a text button for Batal.
    final isConfirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            MalasSpace.screen,
            MalasSpace.s12,
            MalasSpace.screen,
            MalasSpace.s20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetHandle(),
              const SizedBox(height: MalasSpace.s20),
              Text('Keluar dari akun?', style: MalasText.titleScreen),
              const SizedBox(height: MalasSpace.s24),
              LipButton(
                label: 'Keluar',
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
              const SizedBox(height: MalasSpace.s8),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                child: const Text('Batal'),
              ),
            ],
          ),
        ),
      ),
    );
    if (isConfirmed != true) return;
    await session.signOut();
    navigator.popUntil((route) => route.isFirst);
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: MalasSpace.s8,
      runSpacing: MalasSpace.s4,
      children: children,
    );
  }
}

/// A flat §3 card of setting rows, 2px dividers between them.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (index, row) in rows.indexed) ...[
            if (index > 0) const Divider(indent: MalasSpace.s16),
            row,
          ],
        ],
      ),
    );
  }
}

/// Label on the left; a value, a control or a caret on the right. A row with
/// [onTap] is the tap target and shows the caret.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
  });

  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: MalasSize.row),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MalasSpace.s16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MalasText.titleItem,
                ),
              ),
              if (value != null) Text(value, style: MalasText.bodySecondary),
              ?trailing,
              if (onTap != null && trailing == null) ...[
                const SizedBox(width: MalasSpace.s8),
                const Icon(
                  MalasIcons.caretRight,
                  size: 20,
                  color: MalasColors.textMeta,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// §4.2 sheet handle, 40 × 5.
class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: _handleWidth,
        height: _handleHeight,
        decoration: BoxDecoration(
          color: MalasColors.borderCard,
          borderRadius: BorderRadius.circular(MalasRadius.xs),
        ),
      ),
    );
  }
}

const _formHeaderHeight = 150.0;
const _handleWidth = 40.0;
const _handleHeight = 5.0;

String _formatHour(int hour) => '${_twoDigits(hour)}:00';

String _twoDigits(int number) => number.toString().padLeft(2, '0');

String _planLabel(Plan plan) {
  return switch (plan) {
    Plan.gratis => 'Gratis',
    Plan.pro => 'Pro',
    Plan.proPlus => 'Pro Plus',
  };
}
