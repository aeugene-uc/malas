import '../../model/tanya_answer.dart';
import '../format.dart';

final RegExp _placeholder = RegExp(r'\{(\w+)\}');

/// The answer with each `{fN}` replaced by its figure. A placeholder with no
/// figure shows "—", so a number the code did not supply is never invented.
String fillAnswer(TanyaAnswer answer) {
  final figuresByKey = {
    for (final figure in answer.figures) figure.key: figure,
  };
  return answer.answer.replaceAllMapped(_placeholder, (match) {
    final figure = figuresByKey[match.group(1)];
    return figure == null ? '—' : formatFigure(figure);
  });
}

/// `Rp 630.000` for money, `42 porsi` or `0,5 kg` for a quantity.
String formatFigure(TanyaFigure figure) {
  if (figure.isMoney) return formatRupiah(figure.value.round());
  return '${_formatQuantity(figure.value)} ${figure.unit}';
}

String _formatQuantity(num value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toString().replaceAll('.', ',');
}
