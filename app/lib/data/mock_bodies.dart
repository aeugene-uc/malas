/// Canned response bodies for [MockApiAdapter], in the shapes of the API
/// contract (backend rev 3 for `/home`, the AI half in Multiplayr #59 for
/// `/ai/read`). Add a route here when a screen needs one before the backend
/// has it, and delete it once the real route works.
const Map<String, Object> mockBodiesByRoute = {
  'GET /auth/me': {
    'user': {
      'id': 'user-1',
      'name': 'Bu Sari',
      'phone': '081234567890',
      'consentAt': '2026-11-11T02:00:00.000Z',
    },
    'stores': [
      {
        'id': 'store-1',
        'name': 'Warung Bu Sari',
        'businessTypes': ['MAKANAN_MINUMAN'],
        'timezone': 'Asia/Jakarta',
        'dayChangeHour': 4,
        'plan': 'GRATIS',
        'trialEndsAt': '2026-11-25T00:00:00.000Z',
      },
    ],
  },
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
        'total': 205000,
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
            'quantity': null,
            'unit': null,
            'unitPrice': null,
            'lineTotal': 25000,
          },
        ],
        'payments': [
          {'date': '2026-11-11', 'amount': 205000, 'label': null},
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
      {'draft': 1, 'line': 0, 'code': 'NEW_ITEM', 'message': 'Baru'},
    ],
  },
  'POST /transactions': {
    'transaction': {
      'id': 'trx-new',
      'businessDate': '2026-11-11',
      'direction': 'IN',
      'total': 205000,
      'paid': 205000,
      'remaining': 0,
      'editCount': 0,
      'hasRetur': false,
      'person': null,
      'lines': <Object>[],
    },
    'warnings': <Object>[],
  },
};
