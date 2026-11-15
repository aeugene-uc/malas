import 'package:flutter/material.dart';

import '../../model/account.dart';
import '../format.dart';

/// The one sheet on the first open after day 14 (§8.11, §18), also shown
/// when a free owner asks Tanya. It returns the plan the owner picked. No
/// record is ever locked, whatever they pick.
Future<Plan> showTrialSheet(
  BuildContext context, {
  String title = 'Masa coba selesai',
}) async {
  final chosenPlan = await showModalBottomSheet<Plan>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    // Three plans and two buttons are taller than the default half-screen
    // sheet on small phones, which would push the buttons off screen.
    isScrollControlled: true,
    builder: (context) => _TrialSheet(title: title),
  );
  return chosenPlan ?? Plan.gratis;
}

class _TrialSheet extends StatelessWidget {
  const _TrialSheet({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: textTheme.titleLarge),
            const SizedBox(height: 16),
            for (final (name, monthlyPrice, aiReads) in const [
              ('Gratis', 0, '5 baca AI sebulan'),
              ('Pro', 25000, '300 baca AI sebulan, Tanya'),
              ('Pro Plus', 50000, '1.000 baca AI sebulan, Tanya'),
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(name),
                subtitle: Text(aiReads),
                trailing: Text(
                  monthlyPrice == 0
                      ? formatRupiah(0)
                      : '${formatRupiah(monthlyPrice)}/bulan',
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
              onPressed: () => Navigator.of(context).pop(Plan.pro),
              child: const Text('Pilih Pro'),
            ),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(0, 56)),
              onPressed: () => Navigator.of(context).pop(Plan.gratis),
              child: const Text('Lanjut Gratis'),
            ),
          ],
        ),
      ),
    );
  }
}
