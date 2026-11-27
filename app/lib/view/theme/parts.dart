import 'package:flutter/material.dart';

import '../../model/transaction.dart';
import '../format.dart';
import 'tokens.dart';
import 'icons.dart';

/// §1.2: money is a prefix and a number on one baseline, 4 apart. Masuk is
/// green `+Rp`, Keluar `−Rp` (U+2212), anything else plain `Rp`.
enum MoneySign { masuk, keluar, neutral }

enum MoneySize { hero, large, row }

class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount, {
    super.key,
    this.sign = MoneySign.neutral,
    this.size = MoneySize.row,
    this.color,
  });

  /// From an entry's effect on the owner's money: a Retur turns the sign.
  factory MoneyText.forEntry(
    Transaction entry, {
    MoneySize size = MoneySize.row,
  }) {
    final effect = entry.direction == Direction.masuk
        ? entry.total
        : -entry.total;
    return MoneyText(
      effect.abs(),
      sign: effect < 0 ? MoneySign.keluar : MoneySign.masuk,
      size: size,
    );
  }

  final int amount;
  final MoneySign sign;
  final MoneySize size;

  /// Overrides the sign's colour, e.g. white on brand.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final (numberStyle, prefixStyle) = switch (size) {
      MoneySize.hero => (MalasText.moneyHero, MalasText.rpHero),
      MoneySize.large => (MalasText.moneyLarge, MalasText.rpLarge),
      MoneySize.row => (MalasText.moneyRow, MalasText.rpRow),
    };
    final prefix = switch (sign) {
      MoneySign.masuk => '+Rp',
      MoneySign.keluar => '−Rp',
      MoneySign.neutral => 'Rp',
    };
    final textColor =
        color ??
        (sign == MoneySign.masuk
            ? MalasColors.textMasuk
            : MalasColors.textPrimary);
    return Semantics(
      container: true,
      label: '$prefix ${groupThousands(amount)}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(prefix, style: prefixStyle.copyWith(color: textColor)),
          const SizedBox(width: MalasSpace.s4),
          Text(
            groupThousands(amount),
            style: numberStyle.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}

/// The tone and icon a row shows for an entry. Categories are named by the
/// owner, so this matches on common words and falls back on direction.
(CategoryTone, IconData) toneFor(Transaction entry) {
  final name = [
    for (final line in entry.lines) ...[?line.category?.name, ?line.item?.name],
  ].join(' ').toLowerCase();
  bool has(List<String> words) => words.any(name.contains);
  if (has(['minum', 'teh', 'kopi', 'jus', 'es '])) {
    return (CategoryTone.minuman, MalasIcons.coffeeFill);
  }
  if (has(['gas', 'listrik', 'bensin', 'air'])) {
    return (CategoryTone.merah, MalasIcons.fireFill);
  }
  if (has(['bahan', 'beras', 'gula', 'minyak', 'telur', 'sayur'])) {
    return (CategoryTone.bahan, MalasIcons.basketFill);
  }
  if (has(['makan', 'nasi', 'goreng', 'mie', 'ayam'])) {
    return (CategoryTone.makanan, MalasIcons.bowlFoodFill);
  }
  if (entry.direction == Direction.masuk) {
    return (CategoryTone.penjualan, MalasIcons.storefrontFill);
  }
  return (CategoryTone.lainnya, MalasIcons.receiptFill);
}

/// §2: category tiles are information, so flat (no lip).
class CategoryTile extends StatelessWidget {
  const CategoryTile({super.key, required this.tone, required this.icon});

  final CategoryTone tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MalasSize.categoryTile,
      height: MalasSize.categoryTile,
      decoration: BoxDecoration(
        color: tone.base,
        borderRadius: BorderRadius.circular(MalasRadius.sm),
      ),
      child: Icon(icon, size: 20, color: MalasColors.iconOnInk),
    );
  }
}

/// §3 tag variants.
enum TagTone {
  netral(MalasColors.bgSecondary, MalasColors.textPrimary),
  piutang(MalasColors.bgSelected, MalasColors.textBrandDark),
  lunas(MalasColors.bgMasukSoft, MalasColors.textMasuk),
  lewat(MalasColors.bgErrorSoft, MalasColors.textError),
  perhatian(MalasColors.bgHighlight, MalasColors.textPrimary);

  const TagTone(this.fill, this.text);

  final Color fill;
  final Color text;
}

class TagChip extends StatelessWidget {
  const TagChip(this.label, {super.key, this.tone = TagTone.netral});

  final String label;
  final TagTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: MalasSpace.s8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.fill,
        borderRadius: BorderRadius.circular(MalasRadius.xs),
      ),
      child: Text(label, style: MalasText.labelTag.copyWith(color: tone.text)),
    );
  }
}

/// §3 Entry Row: tile, title and meta, money on the right. The whole row is
/// the tap target.
class EntryRow extends StatelessWidget {
  const EntryRow({
    super.key,
    required this.title,
    required this.money,
    required this.tone,
    required this.icon,
    this.meta,
    this.tags = const [],
    this.onTap,
  });

  final String title;
  final String? meta;
  final Widget money;
  final CategoryTone tone;
  final IconData icon;
  final List<Widget> tags;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final meta = this.meta;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: MalasSize.row),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: MalasSpace.s16,
          ),
          child: Row(
            children: [
              CategoryTile(tone: tone, icon: icon),
              const SizedBox(width: MalasSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MalasText.titleItem,
                    ),
                    if (meta != null)
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MalasText.bodySecondary,
                      ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: MalasSpace.s4),
                      Wrap(
                        spacing: MalasSpace.s4,
                        runSpacing: MalasSpace.s4,
                        children: tags,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: MalasSpace.s12),
              money,
            ],
          ),
        ),
      ),
    );
  }
}

/// §3: one flat card holding rows, 2px dividers inset to the text column and
/// none after the last row.
class RowsCard extends StatelessWidget {
  const RowsCard({super.key, required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (index, row) in rows.indexed) ...[
            if (index > 0)
              const Divider(
                indent:
                    MalasSpace.s16 + MalasSize.categoryTile + MalasSpace.s12,
              ),
            row,
          ],
        ],
      ),
    );
  }
}

/// §3 section header: title left, total right.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return Padding(
      padding: const EdgeInsets.only(bottom: MalasSpace.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MalasText.titleSection,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// One entry as a §3 row: the item name as title, quantity and person as
/// meta, money by its effect.
class EntryRowFor extends StatelessWidget {
  const EntryRowFor({super.key, required this.entry, this.onTap});

  final Transaction entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (tone, icon) = toneFor(entry);
    final lines = entry.lines;
    final names = [
      for (final line in lines) line.item?.name ?? line.category?.name ?? '',
    ].where((name) => name.isNotEmpty);
    final person = entry.person?.name;
    final firstLine = lines.length == 1 ? lines.single : null;
    final quantity = firstLine?.quantity;
    final meta = [
      if (quantity != null) [quantity, ?firstLine?.unit].join(' '),
      if (lines.length > 1) '${lines.length} barang',
      if (names.isNotEmpty) ?person,
    ].join(' · ');
    return EntryRow(
      title: names.isEmpty ? (person ?? '') : names.join(', '),
      meta: meta.isEmpty ? null : meta,
      money: MoneyText.forEntry(entry),
      tone: tone,
      icon: icon,
      onTap: onTap,
      tags: [
        if (!entry.isFullyPaid)
          TagChip(
            'Sisa ${formatRupiah(entry.remaining)}',
            tone: TagTone.piutang,
          ),
        if (entry.editCount > 0) TagChip('Diubah ${entry.editCount}x'),
        if (entry.hasRetur) const TagChip('Ada retur'),
      ],
    );
  }
}
