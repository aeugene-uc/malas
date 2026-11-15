/// Canned response bodies for [MockApiAdapter], in the shapes of the API
/// contract (backend rev 3 for `/home`, the AI half in Multiplayr #59 for
/// `/ai/read`). Add a route here when a screen needs one before the backend
/// has it, and delete it once the real route works.
const Map<String, Object> mockBodiesByRoute = {
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
  },
  'GET /analytics/by-item': {
    'rows': [
      {'id': 'item-1', 'name': 'Nasi goreng', 'amount': 4500000, 'share': 0.52},
      {'id': 'item-2', 'name': 'Es teh', 'amount': 1800000, 'share': 0.21},
      {'id': 'item-4', 'name': 'Mie goreng', 'amount': 1340000, 'share': 0.16},
    ],
  },
  'GET /analytics/by-category': {
    'rows': [
      {'id': 'cat-bahan', 'name': 'Bahan', 'amount': 3100000, 'share': 0.6},
      {'id': 'item-3', 'name': 'Gas', 'amount': 750000, 'share': 0.14},
      {'id': 'cat-sewa', 'name': 'Sewa', 'amount': 1000000, 'share': 0.19},
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
