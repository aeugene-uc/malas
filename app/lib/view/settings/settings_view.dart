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

/// Opened from Pengaturan on Beranda (§6).
class SettingsView extends StatelessWidget {
  const SettingsView({super.key, this.storeName});

  final String? storeName;

  static Route<void> route(Account account) {
    return MaterialPageRoute(
      builder: (context) => ChangeNotifierProvider(
        create: (context) => SettingsViewModel(
          account: account,
          storeRepository: context.read<StoreRepository>(),
        ),
        child: SettingsView(storeName: account.store.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SettingsViewModel>();
    final reminderTime = viewModel.reminderTime;
    final resolvedStoreName =
        storeName ??
        context.watch<SessionViewModel?>()?.account?.store.name ??
        '';
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
              MalasSpace.s16,
              MalasSpace.screen,
              MalasSpace.s24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(title: 'Usaha'),
                _SettingsCard(
                  rows: [
                    _SettingRow(label: 'Nama usaha', value: resolvedStoreName),
                    _SettingRow(
                      label: 'Jenis usaha',
                      value: _formatBusinessTypes(viewModel.businessTypes),
                      onTap: () => _pickBusinessTypes(context),
                    ),
                    _SettingRow(
                      label: 'Hari tutup',
                      value: _formatClosedDays(viewModel.closedDays),
                      onTap: () => _pickClosedDays(context),
                    ),
                  ],
                ),
                const SizedBox(height: MalasSpace.s24),
                const SectionHeader(title: 'Pengingat'),
                _SettingsCard(
                  rows: [
                    _SettingRow(
                      label: 'Ganti hari',
                      value: _formatHour(viewModel.dayChangeHour),
                      onTap: () => _pickDayChangeHour(context),
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
                const SectionHeader(title: 'Lainnya'),
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
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: MalasColors.textError,
                  ),
                  onPressed: () => _signOut(context),
                  child: const Text('Keluar'),
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

  Future<void> _pickBusinessTypes(BuildContext context) async {
    final viewModel = context.read<SettingsViewModel>();
    final picked = await showModalBottomSheet<Set<BusinessType>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MultiSelectSheet<BusinessType>(
        title: 'Jenis usaha',
        options: BusinessType.values,
        labelOf: (type) => type.label,
        initial: viewModel.businessTypes,
      ),
    );
    if (picked == null) return;
    for (final type in BusinessType.values) {
      if (picked.contains(type) != viewModel.businessTypes.contains(type)) {
        viewModel.toggleBusinessType(type);
      }
    }
  }

  Future<void> _pickClosedDays(BuildContext context) async {
    final viewModel = context.read<SettingsViewModel>();
    final weekdays = [
      for (var day = DateTime.monday; day <= DateTime.sunday; day++) day,
    ];
    final picked = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MultiSelectSheet<int>(
        title: 'Hari tutup',
        options: weekdays,
        labelOf: formatIsoWeekdayShort,
        initial: viewModel.closedDays,
      ),
    );
    if (picked == null) return;
    for (final day in weekdays) {
      if (picked.contains(day) != viewModel.closedDays.contains(day)) {
        viewModel.toggleClosedDay(day);
      }
    }
  }

  Future<void> _pickDayChangeHour(BuildContext context) async {
    final viewModel = context.read<SettingsViewModel>();
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SingleSelectSheet<int>(
        title: 'Ganti hari',
        options: SettingsViewModel.dayChangeHours,
        labelOf: _formatHour,
        initial: viewModel.dayChangeHour,
      ),
    );
    if (picked != null) viewModel.selectDayChangeHour(picked);
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

/// §4.2 bottom sheet with flat SelectChips and a primary Pakai button.
class _MultiSelectSheet<T> extends StatefulWidget {
  const _MultiSelectSheet({
    required this.title,
    required this.options,
    required this.labelOf,
    required this.initial,
  });

  final String title;
  final List<T> options;
  final String Function(T) labelOf;
  final Set<T> initial;

  @override
  State<_MultiSelectSheet<T>> createState() => _MultiSelectSheetState<T>();
}

class _MultiSelectSheetState<T> extends State<_MultiSelectSheet<T>> {
  late final Set<T> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
            Text(widget.title, style: MalasText.titleScreen),
            const SizedBox(height: MalasSpace.s16),
            Wrap(
              spacing: MalasSpace.s8,
              runSpacing: MalasSpace.s8,
              children: [
                for (final option in widget.options)
                  SelectChip(
                    label: widget.labelOf(option),
                    isSelected: _selected.contains(option),
                    onPressed: () => setState(() {
                      if (!_selected.remove(option)) _selected.add(option);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: MalasSpace.s24),
            LipButton(
              label: 'Pakai',
              onPressed: () => Navigator.of(context).pop({..._selected}),
            ),
            const SizedBox(height: MalasSpace.s8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SingleSelectSheet<T> extends StatefulWidget {
  const _SingleSelectSheet({
    required this.title,
    required this.options,
    required this.labelOf,
    required this.initial,
  });

  final String title;
  final List<T> options;
  final String Function(T) labelOf;
  final T initial;

  @override
  State<_SingleSelectSheet<T>> createState() => _SingleSelectSheetState<T>();
}

class _SingleSelectSheetState<T> extends State<_SingleSelectSheet<T>> {
  late T _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
            Text(widget.title, style: MalasText.titleScreen),
            const SizedBox(height: MalasSpace.s16),
            Wrap(
              spacing: MalasSpace.s8,
              runSpacing: MalasSpace.s8,
              children: [
                for (final option in widget.options)
                  SelectChip(
                    label: widget.labelOf(option),
                    isSelected: _selected == option,
                    onPressed: () => setState(() => _selected = option),
                  ),
              ],
            ),
            const SizedBox(height: MalasSpace.s24),
            LipButton(
              label: 'Pakai',
              onPressed: () => Navigator.of(context).pop(_selected),
            ),
            const SizedBox(height: MalasSpace.s8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
          ],
        ),
      ),
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
/// [onTap] and no custom [trailing] shows the caret.
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
        constraints: const BoxConstraints(minHeight: MalasSpace.s56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MalasSpace.s16,
            vertical: MalasSpace.s12,
          ),
          child: Row(
            children: [
              if (value == null)
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MalasText.titleItem,
                  ),
                )
              else ...[
                Text(label, style: MalasText.titleItem),
                const SizedBox(width: MalasSpace.s12),
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: MalasText.bodySecondary,
                  ),
                ),
              ],
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

String _formatBusinessTypes(Set<BusinessType> types) {
  if (types.isEmpty) return 'Belum dipilih';
  return [
    for (final type in BusinessType.values)
      if (types.contains(type)) type.label,
  ].join(', ');
}

String _formatClosedDays(Set<int> weekdays) {
  if (weekdays.isEmpty) return 'Tidak ada';
  return [
    for (var day = DateTime.monday; day <= DateTime.sunday; day++)
      if (weekdays.contains(day)) formatIsoWeekdayShort(day),
  ].join(', ');
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
