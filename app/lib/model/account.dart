/// The signed-in owner and their store, from `GET /auth/me`, `POST /auth/login`
/// and `POST /auth/register`.
class Account {
  const Account({required this.user, required this.store});

  factory Account.fromJson(Map<String, Object?> json) {
    final storesJson = json['stores'] as List<Object?>;
    return Account(
      user: User.fromJson(json['user'] as Map<String, Object?>),
      // The MVP has one store per owner (§3).
      store: Store.fromJson(storesJson.first as Map<String, Object?>),
    );
  }

  final User user;
  final Store store;

  /// First run is done once the store has a name and a jenis usaha and the
  /// owner has agreed to the consent line (§7.1).
  bool get isSetUp =>
      store.name.isNotEmpty &&
      store.businessTypes.isNotEmpty &&
      user.hasConsented;
}

class User {
  const User({
    required this.id,
    required this.name,
    required this.phone,
    required this.consentAt,
  });

  factory User.fromJson(Map<String, Object?> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      consentAt: json['consentAt'] as String?,
    );
  }

  final String id;
  final String name;

  /// E.164, as the server stores it (`+62...`).
  final String phone;
  final String? consentAt;

  bool get hasConsented => consentAt != null;
}

class Store {
  const Store({
    required this.id,
    required this.name,
    required this.businessTypes,
    required this.plan,
    required this.trialEndsAt,
    this.closedDays = const {},
    this.dayChangeHour = 4,
    this.reminderTime,
    this.timezone = 'Asia/Jakarta',
    this.isAlertsOn = true,
  });

  factory Store.fromJson(Map<String, Object?> json) {
    final businessTypesJson = json['businessTypes'] as List<Object?>;
    final closedDaysJson = json['closedDays'] as List<Object?>? ?? const [];
    final trialEndsAt = json['trialEndsAt'] as String?;
    return Store(
      id: json['id'] as String,
      name: json['name'] as String,
      businessTypes: {
        for (final wireValue in businessTypesJson)
          BusinessType.fromWire(wireValue as String),
      },
      plan: Plan.fromWire(json['plan'] as String),
      trialEndsAt: trialEndsAt == null ? null : DateTime.parse(trialEndsAt),
      closedDays: {for (final weekday in closedDaysJson) weekday as int},
      dayChangeHour: json['dayChangeHour'] as int? ?? 4,
      reminderTime: json['reminderTime'] as String?,
      timezone: json['timezone'] as String? ?? 'Asia/Jakarta',
      isAlertsOn: json['alertsOn'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final Set<BusinessType> businessTypes;
  final Plan plan;
  final DateTime? trialEndsAt;

  /// ISO weekdays, as [DateTime.weekday] numbers them: 1 is Monday. A closed
  /// day is never "Belum dicatat" and gets no evening reminder (§7.5, §7.7).
  final Set<int> closedDays;

  /// The business day starts at this hour, so night sales stay on one date.
  final int dayChangeHour;

  /// `"HH:mm"` in the store's [timezone], or null for no evening reminder.
  final String? reminderTime;

  /// An IANA name such as `Asia/Jakarta`.
  final String timezone;
  final bool isAlertsOn;

  /// This store after Settings saved new values, which the server accepted
  /// as they were sent.
  Store withSettings({
    required Set<BusinessType> businessTypes,
    required Set<int> closedDays,
    required int dayChangeHour,
    required String? reminderTime,
    required bool isAlertsOn,
  }) {
    return Store(
      id: id,
      name: name,
      businessTypes: businessTypes,
      plan: plan,
      trialEndsAt: trialEndsAt,
      closedDays: closedDays,
      dayChangeHour: dayChangeHour,
      reminderTime: reminderTime,
      timezone: timezone,
      isAlertsOn: isAlertsOn,
    );
  }

  /// The trial sheet shows on the first open after day 14 (§8.11), and only
  /// to a store that has not chosen a paid plan.
  bool isTrialOverAt(DateTime now) {
    final trialEndsAt = this.trialEndsAt;
    return plan == Plan.gratis &&
        trialEndsAt != null &&
        now.isAfter(trialEndsAt);
  }
}

/// "Usaha kamu apa?" (§7.1), in the spec's order.
enum BusinessType {
  makananMinuman('MAKANAN_MINUMAN', 'Makanan & minuman'),
  jualanBarang('JUALAN_BARANG', 'Jualan barang'),
  bikinPesanan('BIKIN_PESANAN', 'Bikin & pesanan'),
  jasa('JASA', 'Jasa'),
  sewa('SEWA', 'Sewa'),
  antarOjek('ANTAR_OJEK', 'Antar & ojek'),
  taniTernakIkan('TANI_TERNAK_IKAN', 'Tani & ternak & ikan'),
  agen('AGEN', 'Agen');

  const BusinessType(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static BusinessType fromWire(String wireValue) {
    return values.firstWhere(
      (type) => type.wireValue == wireValue,
      orElse: () => throw FormatException('Unknown business type: $wireValue'),
    );
  }
}

/// The plans of §18, as the schema names them.
enum Plan {
  gratis('GRATIS'),
  pro('PRO'),
  proPlus('PRO_PLUS');

  const Plan(this.wireValue);

  final String wireValue;

  static Plan fromWire(String wireValue) {
    return values.firstWhere(
      (plan) => plan.wireValue == wireValue,
      orElse: () => throw FormatException('Unknown plan: $wireValue'),
    );
  }
}
