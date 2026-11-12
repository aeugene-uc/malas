import 'transaction.dart';

/// Everything Beranda shows, from one `GET /home` (backend contract rev 3).
class Home {
  const Home({
    required this.today,
    required this.comparisons,
    required this.cards,
    required this.entries,
  });

  factory Home.fromJson(Map<String, Object?> json) {
    final comparisonsJson = json['comparisons'] as List<Object?>;
    final entriesJson = json['entries'] as List<Object?>;
    return Home(
      today: DayTotals.fromJson(json['today'] as Map<String, Object?>),
      comparisons: [
        for (final comparisonJson in comparisonsJson)
          Comparison.fromJson(comparisonJson as Map<String, Object?>),
      ],
      cards: HomeCards.fromJson(json['cards'] as Map<String, Object?>),
      entries: [
        for (final entryJson in entriesJson)
          Transaction.fromJson(entryJson as Map<String, Object?>),
      ],
    );
  }

  final DayTotals today;
  final List<Comparison> comparisons;
  final HomeCards cards;
  final List<Transaction> entries;
}

class DayTotals {
  const DayTotals({
    required this.businessDate,
    required this.masuk,
    required this.keluar,
  });

  factory DayTotals.fromJson(Map<String, Object?> json) {
    return DayTotals(
      businessDate: json['date'] as String,
      masuk: json['masuk'] as int,
      keluar: json['keluar'] as int,
    );
  }

  final String businessDate;
  final int masuk;
  final int keluar;
}

/// "Kemarin Rp 1.020.000": the label is written by the server.
class Comparison {
  const Comparison({required this.label, required this.masuk});

  factory Comparison.fromJson(Map<String, Object?> json) {
    return Comparison(
      label: json['label'] as String,
      masuk: json['masuk'] as int,
    );
  }

  final String label;
  final int masuk;
}

/// The server leaves out a card that has nothing to show (spec §6), so each
/// one is null or empty when absent.
class HomeCards {
  const HomeCards({
    required this.alerts,
    required this.missedDays,
    required this.piutang,
    required this.utang,
    required this.dueToday,
    required this.queuedReads,
  });

  factory HomeCards.fromJson(Map<String, Object?> json) {
    final alertsJson = json['alerts'] as List<Object?>? ?? const [];
    final missedDaysJson = json['missedDays'] as List<Object?>? ?? const [];
    return HomeCards(
      alerts: [
        for (final alertJson in alertsJson)
          HomeAlert.fromJson(alertJson as Map<String, Object?>),
      ],
      missedDays: [for (final missedDay in missedDaysJson) missedDay as String],
      piutang: json['piutang'] as int?,
      utang: json['utang'] as int?,
      dueToday: json['dueToday'] as int?,
      queuedReads: json['queuedReads'] as int?,
    );
  }

  final List<HomeAlert> alerts;

  /// `YYYY-MM-DD` dates with no entry, closed days already left out.
  final List<String> missedDays;
  final int? piutang;
  final int? utang;
  final int? dueToday;
  final int? queuedReads;

  bool get hasOpenBalances => piutang != null || utang != null;
}

class HomeAlert {
  const HomeAlert({
    required this.id,
    required this.rule,
    required this.message,
  });

  factory HomeAlert.fromJson(Map<String, Object?> json) {
    return HomeAlert(
      id: json['id'] as String,
      rule: json['rule'] as String,
      message: json['message'] as String,
    );
  }

  final String id;
  final String rule;

  /// Filled from a fixed template by the server, already in Indonesian.
  final String message;
}
