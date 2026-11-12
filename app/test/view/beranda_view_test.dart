import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/mock_api_adapter.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/model/transaction.dart';
import 'package:malas/view/beranda/beranda_view.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('showsTodayComparisonsCardsAndEntries', (tester) async {
    await _pumpBeranda(tester, mockBodiesByRoute);

    expect(find.text('Rp 420.000'), findsOneWidget);
    expect(find.text('Rp 150.000'), findsOneWidget);
    expect(
      find.text('Kemarin Rp 1.020.000 · Selasa lalu Rp 790.000'),
      findsOneWidget,
    );
    expect(find.text('Gas naik 12% dari pembelian terakhir'), findsOneWidget);
    expect(find.text('Belum dicatat: Sen'), findsOneWidget);
    expect(
      find.text('Piutang Rp 240.000 · Utang Rp 1.200.000'),
      findsOneWidget,
    );
    expect(find.text('Jatuh tempo hari ini: 2'), findsOneWidget);
    expect(find.text('3 menunggu dibaca'), findsOneWidget);
    expect(find.text('Nasi goreng 2 porsi, Es teh 4 gelas'), findsOneWidget);
    expect(find.text('+Rp 42.000'), findsOneWidget);
    for (final label in ['Bicara', 'Foto', 'Ketik']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('leavesOutCardsTheServerLeftOut', (tester) async {
    await _pumpBeranda(tester, const {
      'GET /home': {
        'today': {'date': '2026-11-11', 'masuk': 0, 'keluar': 0},
        'comparisons': <Object>[],
        'cards': {'utang': 50000},
        'entries': <Object>[],
      },
    });

    expect(find.text('Utang Rp 50.000'), findsOneWidget);
    expect(find.textContaining('Piutang'), findsNothing);
    expect(find.textContaining('Belum dicatat'), findsNothing);
    expect(find.textContaining('Jatuh tempo'), findsNothing);
    expect(find.textContaining('menunggu dibaca'), findsNothing);
    expect(find.text('Catatan hari ini'), findsNothing);
  });

  testWidgets('offersCobaLagiWhenTheFirstLoadFails', (tester) async {
    await _pumpBeranda(tester, const {});

    expect(find.text('Mock belum ada: GET /home'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
  });

  test('describeEntryPutsThePersonFirstAndNamesABareAmountByCategory', () {
    const entry = Transaction(
      id: 'trx-2',
      businessDate: '2026-11-11',
      direction: Direction.masuk,
      total: 30000,
      paid: 0,
      remaining: 30000,
      editCount: 0,
      hasRetur: false,
      person: NamedRef(id: 'person-1', name: 'Pak Budi'),
      lines: [
        TransactionLine(
          id: 'line-9',
          item: null,
          category: NamedRef(id: 'cat-1', name: 'Penjualan'),
          quantity: null,
          unit: null,
          unitPrice: null,
          lineTotal: 30000,
          discount: 0,
        ),
      ],
    );

    expect(describeEntry(entry), 'Pak Budi · Penjualan');
  });
}

Future<void> _pumpBeranda(
  WidgetTester tester,
  Map<String, Object> bodiesByRoute,
) async {
  final dio = Dio(BaseOptions(baseUrl: 'http://mock'))
    ..httpClientAdapter = MockApiAdapter(bodiesByRoute: bodiesByRoute);
  await tester.pumpWidget(
    Provider<ApiClient>.value(
      value: ApiClient(dio),
      child: const MaterialApp(home: BerandaView()),
    ),
  );
  await tester.pumpAndSettle();
}
