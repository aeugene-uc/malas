import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:malas/data/api_client.dart';
import 'package:malas/data/mock_api_adapter.dart';
import 'package:malas/data/mock_bodies.dart';
import 'package:malas/data/tanya_repository.dart';
import 'package:malas/viewmodel/tanya_view_model.dart';

import '../support/recording_adapter.dart';
import '../support/status_adapter.dart';

void main() {
  TanyaViewModel buildViewModel(HttpClientAdapter adapter) {
    return TanyaViewModel(
      tanyaRepository: TanyaRepository(
        ApiClient(
          Dio(BaseOptions(baseUrl: 'http://mock'))..httpClientAdapter = adapter,
        ),
      ),
    );
  }

  test('addsTheAnswerUnderItsQuestion', () async {
    final viewModel = buildViewModel(
      MockApiAdapter(bodiesByRoute: mockBodiesByRoute),
    );

    await viewModel.ask('  Apa yang paling laku?  ');

    final exchange = viewModel.exchanges.single;
    expect(exchange.question, 'Apa yang paling laku?');
    expect(exchange.answer!.figures, hasLength(4));
    expect(viewModel.isAsking, isFalse);
  });

  test('sendsTheLastQuestionAsContextForAFollowUp', () async {
    final adapter = RecordingAdapter(bodiesByRoute: mockBodiesByRoute);
    final viewModel = buildViewModel(adapter);

    await viewModel.ask('pemasukan bln ini brp?');
    expect(adapter.lastRequest.data, {'question': 'pemasukan bln ini brp?'});

    await viewModel.ask('klo thn kmrn?');
    expect(adapter.lastRequest.data, {
      'question': 'klo thn kmrn?',
      'previousQuestion': 'pemasukan bln ini brp?',
    });
  });

  test('ignoresAnEmptyQuestion', () async {
    final viewModel = buildViewModel(
      MockApiAdapter(bodiesByRoute: mockBodiesByRoute),
    );

    await viewModel.ask('   ');

    expect(viewModel.exchanges, isEmpty);
  });

  test('showsTheMonthlyLimitMessageFromTheServer', () async {
    final viewModel = buildViewModel(
      StatusAdapter(
        429,
        code: 'QUOTA_EXCEEDED',
        message: 'Batas Tanya bulan ini habis',
      ),
    );

    await viewModel.ask('Untung bulan ini?');

    expect(
      viewModel.exchanges.single.errorMessage,
      'Batas Tanya bulan ini habis',
    );
    expect(viewModel.isPlanSheetDue, isFalse);
  });

  test('offersProWhenTheFreePlanAsks', () async {
    final viewModel = buildViewModel(
      StatusAdapter(
        403,
        code: TanyaViewModel.planRequiredCode,
        message: 'Tanya ada di paket Pro',
      ),
    );

    await viewModel.ask('Untung bulan ini?');

    expect(viewModel.isPlanSheetDue, isTrue);
    viewModel.planSheetShown();
    expect(viewModel.isPlanSheetDue, isFalse);
  });
}
