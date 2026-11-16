/// Canned response bodies for [MockApiAdapter], in the shapes of the API
/// contract (backend rev 3 for `/home`, the AI half in Multiplayr #59 for
/// `/ai/read`). Add a route here when a screen needs one before the backend
/// has it, and delete it once the real route works.
final Map<String, Object> mockBodiesByRoute = {
  'GET /auth/me': _setUpAccount,
  'POST /auth/login': {'token': 'mock-token', ..._setUpAccount},
  // A new owner: no store name, no jenis usaha and no consent yet, so the
  // app opens first-run setup.
  'POST /auth/register': {
    'token': 'mock-token',
    'user': {
      'id': 'user-2',
      'name': 'Pak Budi',
      'phone': '+6281298765432',
      'consentAt': null,
    },
    'stores': [
      {
        'id': 'store-2',
        'name': '',
        'businessTypes': <Object>[],
        'timezone': 'Asia/Jakarta',
        'dayChangeHour': 4,
        'plan': 'GRATIS',
        'trialEndsAt': '2026-11-29T00:00:00.000Z',
      },
    ],
  },
  'GET /items': {
    'items': [
      {
        'id': 'item-1',
        'name': 'Nasi goreng',
        'kind': 'SOLD',
        'unit': 'porsi',
        'savedPrice': 15000,
      },
      {
        'id': 'item-2',
        'name': 'Es teh',
        'kind': 'SOLD',
        'unit': null,
        'savedPrice': 3000,
      },
      {
        'id': 'item-3',
        'name': 'Gas',
        'kind': 'BOUGHT',
        'unit': null,
        'savedPrice': null,
      },
    ],
  },
  'PATCH /items/:id': {'item': <String, Object>{}},
  'GET /analytics/summary': {
    'masuk': 8640000,
    'keluar': 5210000,
    'untung': 3430000,
    'notCountedInProfit': {
      'modal': 0,
      'ambilPribadi': 600000,
      'pinjaman': 0,
      'titipan': 0,
    },
    'change': {'masuk': 0.12, 'keluar': -0.05, 'untung': null},
    'daysRecorded': 10,
    'daysInPeriod': 15,
    'piutangAtEnd': 240000,
    'utangAtEnd': 1200000,
    'editedEntryCount': 2,
  },
  'GET /analytics/by-item': {
    'rows': [
      {
        'id': 'item-1',
        'name': 'Nasi goreng',
        'kind': 'item',
        'amount': 4500000,
        'share': 0.52,
      },
      {
        'id': 'item-2',
        'name': 'Es teh',
        'kind': 'item',
        'amount': 1800000,
        'share': 0.21,
      },
      {
        'id': 'item-4',
        'name': 'Mie goreng',
        'kind': 'item',
        'amount': 1340000,
        'share': 0.16,
      },
    ],
  },
  'GET /analytics/by-category': {
    'rows': [
      {
        'id': 'cat-bahan',
        'name': 'Bahan',
        'kind': 'category',
        'amount': 3100000,
        'share': 0.6,
      },
      {
        'id': 'item-3',
        'name': 'Gas',
        'kind': 'item',
        'amount': 750000,
        'share': 0.14,
      },
      {
        'id': 'cat-sewa',
        'name': 'Sewa',
        'kind': 'category',
        'amount': 1000000,
        'share': 0.19,
      },
    ],
  },
  'GET /alerts': {
    'alerts': [
      {
        'id': 'alert-1',
        'rule': 'PRICE_RISE',
        'message': 'Gas naik 12% dari pembelian terakhir',
      },
    ],
  },
  // Felicia's #59 shape. Code fills each {fN} from figures.
  'POST /ai/ask': {
    'answer': 'Paling laku minggu ini: {f0} ({f1}) dan {f2} ({f3}).',
    'figures': [
      {'key': 'f0', 'label': 'Kopi susu', 'value': 42, 'unit': 'porsi'},
      {'key': 'f1', 'label': 'Kopi susu', 'value': 630000, 'unit': 'IDR'},
      {'key': 'f2', 'label': 'Es teh', 'value': 30, 'unit': 'gelas'},
      {'key': 'f3', 'label': 'Es teh', 'value': 90000, 'unit': 'IDR'},
    ],
    'daysRecorded': 5,
    'period': {'from': '2026-11-09', 'to': '2026-11-15'},
    'function': 'byItem',
  },
  'GET /transactions': {'transactions': sampleTransactions, 'nextCursor': null},
  'DELETE /transactions/:id': <String, Object>{},
  'POST /transactions/:id/restore': <String, Object>{},
  'POST /transactions/:id/payments': {
    'payment': {'id': 'pay-new', 'date': '2026-11-15', 'amount': 10000},
  },
  'GET /receivables': {
    'rows': [_budiBon],
  },
  'GET /payables': {
    'rows': [_supplierTempo, _overpaidOrder],
  },
  'POST /auth/consent': {'consentAt': '2026-11-15T09:00:00.000Z'},
  'PATCH /stores/:id': {'store': <String, Object>{}},
  'GET /home': {
    'today': {'date': '2026-11-11', 'masuk': 420000, 'keluar': 150000},
    'comparisons': [
      {'label': 'Kemarin', 'masuk': 1020000},
      {'label': 'Selasa lalu', 'masuk': 790000},
    ],
    'cards': {
      'alerts': [
        {
          'id': 'alert-1',
          'rule': 'PRICE_RISE',
          'message': 'Gas naik 12% dari pembelian terakhir',
        },
      ],
      'missedDays': ['2026-11-09'],
      'piutang': 240000,
      'utang': 1200000,
      'dueToday': 2,
      'queuedReads': 3,
    },
    'entries': [
      {
        'id': 'trx-1',
        'businessDate': '2026-11-11',
        'direction': 'IN',
        'total': 42000,
        'paid': 42000,
        'remaining': 0,
        'editCount': 0,
        'hasRetur': false,
        'person': null,
        'lines': [
          {
            'id': 'line-1',
            'item': {'id': 'item-1', 'name': 'Nasi goreng'},
            'category': {'id': 'cat-1', 'name': 'Penjualan'},
            'quantity': '2',
            'unit': 'porsi',
            'unitPrice': 15000,
            'lineTotal': 30000,
            'discount': 0,
          },
          {
            'id': 'line-2',
            'item': {'id': 'item-2', 'name': 'Es teh'},
            'category': {'id': 'cat-1', 'name': 'Penjualan'},
            'quantity': '4',
            'unit': 'gelas',
            'unitPrice': 3000,
            'lineTotal': 12000,
            'discount': 0,
          },
        ],
      },
    ],
  },
  // "jual nasi goreng 12, es teh selawe, beli gas 25 ribu, bon Pak Budi 30 ribu"
  'POST /ai/read': {
    'inputId': 'input-1',
    'drafts': [
      {
        'direction': 'IN',
        'total': 180000,
        'personId': null,
        'personName': null,
        'dueDate': null,
        'source': 'VOICE',
        'inputId': 'input-1',
        'note': null,
        'lines': [
          {
            'itemId': 'item-1',
            'itemName': 'Nasi goreng',
            'categoryId': 'cat-1',
            'quantity': '12',
            'unit': 'porsi',
            'unitPrice': 15000,
            'lineTotal': 180000,
          },
          {
            'itemId': 'item-2',
            'itemName': 'Es teh',
            'categoryId': 'cat-1',
            // "es teh selawe": selawe is a quantity (spec 7.3), and with
            // no saved price yet the line has no total.
            'quantity': '25',
            'unit': null,
            'unitPrice': null,
            'lineTotal': null,
          },
        ],
        'payments': [
          {'date': '2026-11-11', 'amount': 180000, 'label': null},
        ],
      },
      {
        'direction': 'OUT',
        'total': 25000,
        'personId': null,
        'personName': null,
        'dueDate': null,
        'source': 'VOICE',
        'inputId': 'input-1',
        'note': null,
        'lines': [
          {
            'itemId': null,
            'itemName': 'Gas',
            'categoryId': 'cat-ops',
            'quantity': null,
            'unit': null,
            'unitPrice': null,
            'lineTotal': 25000,
          },
        ],
        'payments': [
          {'date': '2026-11-11', 'amount': 25000, 'label': null},
        ],
      },
      {
        'direction': 'IN',
        'total': 30000,
        'personId': 'person-1',
        'personName': 'Pak Budi',
        'dueDate': null,
        'source': 'VOICE',
        'inputId': 'input-1',
        'note': null,
        'lines': [
          {
            'itemId': null,
            'itemName': null,
            'categoryId': 'cat-1',
            'quantity': null,
            'unit': null,
            'unitPrice': null,
            'lineTotal': 30000,
          },
        ],
        'payments': <Object>[],
      },
    ],
    'warnings': [
      {
        'code': 'UNCLEAR_READ',
        'message': 'Kurang jelas, cek lagi',
        'draftIndex': 0,
        'lineIndex': 1,
      },
    ],
  },
  'POST /transactions': {
    'transaction': {
      'id': 'trx-new',
      'businessDate': '2026-11-11',
      'direction': 'IN',
      'total': 180000,
      'paid': 180000,
      'remaining': 0,
      'editCount': 0,
      'hasRetur': false,
      'person': null,
      'lines': <Object>[],
    },
    'warnings': <Object>[],
  },
};

const Map<String, Object> _setUpAccount = {
  'user': {
    'id': 'user-1',
    'name': 'Bu Sari',
    'phone': '+6281234567890',
    'consentAt': '2026-11-11T02:00:00.000Z',
  },
  'stores': [
    {
      'id': 'store-1',
      'name': 'Warung Bu Sari',
      'businessTypes': ['MAKANAN_MINUMAN'],
      'closedDays': [7],
      'timezone': 'Asia/Jakarta',
      'dayChangeHour': 4,
      'reminderTime': '20:00',
      'alertsOn': true,
      'plan': 'GRATIS',
      'trialEndsAt': '2026-11-25T00:00:00.000Z',
    },
  ],
};

/// Newest first, as `GET /transactions` returns them.
final List<Map<String, Object>> sampleTransactions = [
  _nasiGorengSale,
  _gasPurchase,
  _budiBon,
  _supplierTempo,
  _overpaidOrder,
];

Map<String, Object> _transaction({
  required String id,
  required String businessDate,
  required String direction,
  required int total,
  required int paid,
  required List<Map<String, Object?>> lines,
  Map<String, Object>? person,
  String? dueDate,
  int editCount = 0,
  bool hasRetur = false,
}) {
  return {
    'id': id,
    'businessDate': businessDate,
    'direction': direction,
    'total': total,
    'paid': paid,
    'remaining': total - paid,
    'editCount': editCount,
    'hasRetur': hasRetur,
    'person': ?person,
    'dueDate': ?dueDate,
    'lines': lines,
  };
}

Map<String, Object?> _line({
  required String id,
  required String? itemName,
  required int lineTotal,
  String? itemId,
  Map<String, Object>? category,
  String? quantity,
  String? unit,
}) {
  return {
    'id': id,
    'item': itemName == null
        ? null
        : {'id': itemId ?? 'item-$id', 'name': itemName},
    'category': category,
    'quantity': quantity,
    'unit': unit,
    'unitPrice': null,
    'lineTotal': lineTotal,
    'discount': 0,
  };
}

final Map<String, Object> _nasiGorengSale = _transaction(
  id: 'trx-1',
  businessDate: '2026-11-15',
  direction: 'IN',
  total: 42000,
  paid: 42000,
  editCount: 2,
  lines: [
    _line(
      id: 'l1',
      itemId: 'item-1',
      itemName: 'Nasi goreng',
      quantity: '2',
      unit: 'porsi',
      lineTotal: 30000,
    ),
    _line(
      id: 'l2',
      itemId: 'item-2',
      itemName: 'Es teh',
      quantity: '4',
      unit: 'gelas',
      lineTotal: 12000,
    ),
  ],
);

final Map<String, Object> _gasPurchase = _transaction(
  id: 'trx-2',
  businessDate: '2026-11-15',
  direction: 'OUT',
  total: 25000,
  paid: 25000,
  lines: [_line(id: 'l3', itemId: 'item-3', itemName: 'Gas', lineTotal: 25000)],
);

final Map<String, Object> _budiBon = _transaction(
  id: 'trx-3',
  businessDate: '2026-11-14',
  direction: 'IN',
  total: 30000,
  paid: 0,
  person: {'id': 'person-1', 'name': 'Pak Budi'},
  dueDate: '2026-11-20',
  lines: [_line(id: 'l4', itemName: null, lineTotal: 30000)],
);

final Map<String, Object> _supplierTempo = _transaction(
  id: 'trx-4',
  businessDate: '2026-11-13',
  direction: 'OUT',
  total: 1200000,
  paid: 0,
  person: {'id': 'person-2', 'name': 'Toko Sumber Rejeki'},
  dueDate: '2026-11-27',
  hasRetur: true,
  lines: [
    _line(
      id: 'l5',
      itemName: 'Beras',
      category: {'id': 'cat-bahan', 'name': 'Bahan'},
      quantity: '50',
      unit: 'kg',
      lineTotal: 1200000,
    ),
  ],
);

final Map<String, Object> _overpaidOrder = _transaction(
  id: 'trx-5',
  businessDate: '2026-11-12',
  direction: 'IN',
  total: 150000,
  paid: 200000,
  person: {'id': 'person-3', 'name': 'Bu Ani'},
  lines: [
    _line(
      id: 'l6',
      itemName: 'Nasi kotak',
      quantity: '10',
      unit: 'paket',
      lineTotal: 150000,
    ),
  ],
);
