import 'package:flutter/material.dart';

import '../../model/transaction.dart';
import '../format.dart';
import 'icons.dart';
import 'tokens.dart';

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
      decoration: BoxDecoration(
        color: tone.fill,
        borderRadius: BorderRadius.circular(MalasRadius.xs),
      ),
      // widthFactor 1: the tag hugs its label instead of filling the row.
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: MalasText.labelTag.copyWith(color: tone.text),
        ),
      ),
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

/// A choice among several, e.g. a category or a closed day. Choices are
/// information, not actions, so they're flat (§2): no lip, a tick and the
/// brand outline when selected.
class SelectChip extends StatelessWidget {
  const SelectChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected
        ? MalasColors.textBrandDark
        : MalasColors.textPrimary;
    return Semantics(
      selected: isSelected,
      button: true,
      child: Material(
        color: isSelected ? MalasColors.bgSelected : MalasColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MalasRadius.chip),
          side: BorderSide(
            color: isSelected ? MalasColors.bgBrand : MalasColors.borderCard,
            width: MalasSize.cardStroke,
          ),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(MalasRadius.chip),
          child: Container(
            height: MalasSize.touch,
            padding: const EdgeInsets.symmetric(horizontal: MalasSpace.s16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected) ...[
                  Icon(MalasIcons.check, size: 16, color: foreground),
                  const SizedBox(width: MalasSpace.s4),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MalasText.labelChip.copyWith(color: foreground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One track with equal segments, the selected one raised as a white pill:
/// Masuk/Keluar, Piutang/Utang, Minggu/Bulan/Tahun. On the brand header the
/// track is the darker brand tone.
class SegmentedSelector extends StatelessWidget {
  const SegmentedSelector({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.values,
    this.isOnBrand = false,
  });

  final List<String> labels;

  /// A second line under each label, e.g. a total. Same length as [labels].
  final List<String>? values;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool isOnBrand;

  @override
  Widget build(BuildContext context) {
    final values = this.values;
    return Container(
      padding: const EdgeInsets.all(MalasSpace.s4),
      decoration: BoxDecoration(
        color: isOnBrand ? MalasColors.bgBrandPressed : MalasColors.bgSecondary,
        borderRadius: BorderRadius.circular(MalasRadius.md),
      ),
      child: Row(
        children: [
          for (final (index, label) in labels.indexed)
            Expanded(
              child: _Segment(
                label: label,
                value: values?[index],
                isSelected: index == selectedIndex,
                isOnBrand: isOnBrand,
                onTap: () => onSelected(index),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.value,
    required this.isSelected,
    required this.isOnBrand,
    required this.onTap,
  });

  final String label;
  final String? value;
  final bool isSelected;
  final bool isOnBrand;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    final foreground = isSelected
        ? (isOnBrand ? MalasColors.textOnBrandAction : MalasColors.textPrimary)
        : (isOnBrand ? MalasColors.textOnBrand : MalasColors.textSecondary);
    return Semantics(
      selected: isSelected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          constraints: const BoxConstraints(
            minHeight: MalasSize.touch - MalasSpace.s8,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: MalasSpace.s8,
            vertical: MalasSpace.s4,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? MalasColors.bgSurface : null,
            borderRadius: BorderRadius.circular(MalasRadius.md - MalasSpace.s4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MalasText.labelChip.copyWith(color: foreground),
              ),
              if (value != null)
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MalasText.labelTag.copyWith(
                    color: foreground,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
