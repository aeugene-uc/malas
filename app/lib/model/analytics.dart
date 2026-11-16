/// Analisis periods (§7.6). Profit shows only for a week or longer, so every
/// period here can show Untung.
enum AnalyticsPeriod {
  minggu('minggu', 'Minggu'),
  bulan('bulan', 'Bulan'),
  tahun('tahun', 'Tahun');

  const AnalyticsPeriod(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

/// One period on the calendar: a Monday-to-Sunday week, a month or a year.
/// Dates are calendar dates with no time zone, so they can't shift a day.
class PeriodRange {
  const PeriodRange._({
    required this.period,
    required this.from,
    required this.to,
  });

  /// The period of [period]'s kind that contains [date].
  factory PeriodRange.containing({
    required AnalyticsPeriod period,
    required DateTime date,
  }) {
    final day = DateTime.utc(date.year, date.month, date.day);
    return switch (period) {
      AnalyticsPeriod.minggu => PeriodRange._(
        period: period,
        from: day.subtract(Duration(days: day.weekday - DateTime.monday)),
        to: day.add(Duration(days: DateTime.sunday - day.weekday)),
      ),
      AnalyticsPeriod.bulan => PeriodRange._(
        period: period,
        from: DateTime.utc(day.year, day.month),
        to: DateTime.utc(day.year, day.month + 1, 0),
      ),
      AnalyticsPeriod.tahun => PeriodRange._(
        period: period,
        from: DateTime.utc(day.year),
        to: DateTime.utc(day.year, 12, 31),
      ),
    };
  }

  final AnalyticsPeriod period;
  final DateTime from;
  final DateTime to;

  PeriodRange get previous => PeriodRange.containing(
    period: period,
    date: from.subtract(const Duration(days: 1)),
  );

  PeriodRange get next => PeriodRange.containing(
    period: period,
    date: to.add(const Duration(days: 1)),
  );

  /// `"YYYY-MM-DD"`, as the API takes dates.
  String get fromWire => _formatWireDate(from);

  bool contains(DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    return !day.isBefore(from) && !day.isAfter(to);
  }
}

String _formatWireDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

/// `GET /analytics/summary`, computed by the server per §10.
class AnalyticsSummary {
  const AnalyticsSummary({
    required this.masuk,
    required this.keluar,
    required this.untung,
    required this.notCountedInProfit,
    required this.changes,
    required this.daysRecorded,
    required this.daysInPeriod,
    required this.piutangAtEnd,
    required this.utangAtEnd,
    required this.editedEntryCount,
  });

  factory AnalyticsSummary.fromJson(Map<String, Object?> json) {
    final changeJson = json['change'] as Map<String, Object?>;
    final notCountedJson = json['notCountedInProfit'] as Map<String, Object?>;
    return AnalyticsSummary(
      masuk: json['masuk'] as int,
      keluar: json['keluar'] as int,
      untung: json['untung'] as int?,
      notCountedInProfit: NotCountedInProfit.fromJson(notCountedJson),
      changes: SummaryChanges.fromJson(changeJson),
      daysRecorded: json['daysRecorded'] as int,
      daysInPeriod: json['daysInPeriod'] as int,
      piutangAtEnd: json['piutangAtEnd'] as int,
      utangAtEnd: json['utangAtEnd'] as int,
      editedEntryCount: json['editedEntryCount'] as int? ?? 0,
    );
  }

  final int masuk;
  final int keluar;

  /// Null for a single day (§7.6), which Analisis never asks for.
  final int? untung;
  final NotCountedInProfit notCountedInProfit;
  final SummaryChanges changes;
  final int daysRecorded;
  final int daysInPeriod;
  final int piutangAtEnd;
  final int utangAtEnd;

  /// Entries changed after they were saved. The PDF states it (§15), so a
  /// report someone else reads shows how much was corrected.
  final int editedEntryCount;
}

/// Money that moved but is not income or cost (§4.2, §7.6), each on its own
/// line so it never inflates Masuk or Keluar.
class NotCountedInProfit {
  const NotCountedInProfit({
    required this.modal,
    required this.ambilPribadi,
    required this.pinjaman,
    required this.titipan,
  });

  factory NotCountedInProfit.fromJson(Map<String, Object?> json) {
    return NotCountedInProfit(
      modal: json['modal'] as int,
      ambilPribadi: json['ambilPribadi'] as int,
      pinjaman: json['pinjaman'] as int,
      titipan: json['titipan'] as int,
    );
  }

  final int modal;
  final int ambilPribadi;
  final int pinjaman;
  final int titipan;

  bool get isEmpty =>
      modal == 0 && ambilPribadi == 0 && pinjaman == 0 && titipan == 0;
}

/// The change from the previous period as a fraction (`0.12` is +12%). Null
/// when the previous period was zero, never infinity.
class SummaryChanges {
  const SummaryChanges({
    required this.masuk,
    required this.keluar,
    required this.untung,
  });

  factory SummaryChanges.fromJson(Map<String, Object?> json) {
    return SummaryChanges(
      masuk: (json['masuk'] as num?)?.toDouble(),
      keluar: (json['keluar'] as num?)?.toDouble(),
      untung: (json['untung'] as num?)?.toDouble(),
    );
  }

  final double? masuk;
  final double? keluar;
  final double? untung;
}

/// One row of a ranked list: an item for money in, a category or expense
/// item for money out, with its share of the period's total.
class RankedRow {
  const RankedRow({
    required this.id,
    required this.name,
    required this.amount,
    required this.share,
    this.isItem = false,
  });

  factory RankedRow.fromJson(Map<String, Object?> json) {
    return RankedRow(
      id: json['id'] as String?,
      name: json['name'] as String,
      amount: json['amount'] as int,
      share: (json['share'] as num).toDouble(),
      isItem: json['kind'] == 'item',
    );
  }

  /// Null for "Tanpa kategori", which is no real category and can't be
  /// filtered on.
  final String? id;
  final String name;
  final int amount;

  /// A fraction of the period's total, `0.25` for a quarter.
  final double share;

  /// Money out lists categories and expense items together (§7.6), so each
  /// row says which it is: `kind: "item"`, otherwise a category.
  final bool isItem;
}
