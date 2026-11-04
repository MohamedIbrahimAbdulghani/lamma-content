// Lamma Party Game - AI Generation Result Dialog Widget Tests
// Tests the 3 dialog states (success, partial, failure), auto-dismiss,
// and ensures no question/answer content is leaked in the UI.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamma_party_game_app/core/widgets/ai_generation_result_dialog.dart';

void main() {
  setUp(() {
    AiGenerationResultDialog.isShowing = false;
  });

  group('AiGenerationResultDialog Widget Tests', () {
    testWidgets('Success dialog renders animated checkmark, title, stats, and auto-dismisses', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showAiGenerationResultDialog(
                      context,
                      type: AiResultType.success,
                      title: 'تم التحديث بنجاح',
                      message: 'تمت إضافة 5 أسئلة جديدة',
                      details: 'تحدي الشلة: 5',
                    );
                  },
                  child: const Text('Open Success'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Success'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // Dialog fade/scale transition

      // Verify success dialog elements
      expect(find.text('تم التحديث بنجاح'), findsOneWidget);
      expect(find.text('تمت إضافة 5 أسئلة جديدة'), findsOneWidget);
      expect(find.text('تحدي الشلة: 5'), findsOneWidget);
      expect(find.textContaining('تمام'), findsOneWidget);

      // Verify no secret question content leaked
      expect(find.textContaining('سؤال سري'), findsNothing);

      // Pump through animated checkmark (600ms)
      await tester.pump(const Duration(milliseconds: 650));

      // Advance time past autoDismiss (2500ms)
      await tester.pump(const Duration(milliseconds: 2600));
      await tester.pumpAndSettle();

      // Dialog should be dismissed automatically
      expect(find.text('تم التحديث بنجاح'), findsNothing);
    });

    testWidgets('Partial success dialog renders warning icon and message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showAiGenerationResultDialog(
                      context,
                      type: AiResultType.partial,
                      title: 'تحديث جزئي',
                      message: 'أُضيف 3 من 5، والباقي لم يكتمل بسبب بطء الاتصال',
                    );
                  },
                  child: const Text('Open Partial'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Partial'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('تحديث جزئي'), findsOneWidget);
      expect(find.text('أُضيف 3 من 5، والباقي لم يكتمل بسبب بطء الاتصال'), findsOneWidget);
      expect(find.byIcon(Icons.priority_high_rounded), findsOneWidget);
      expect(find.textContaining('تمام'), findsOneWidget);

      // Tap 'تمام' dismisses immediately
      await tester.tap(find.textContaining('تمام'));
      await tester.pumpAndSettle();
      expect(find.text('تحديث جزئي'), findsNothing);
    });

    testWidgets('Failure dialog renders error icon, Arabic reason, retry and close buttons', (tester) async {
      bool retryPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showAiGenerationResultDialog(
                      context,
                      type: AiResultType.failure,
                      title: 'تعذّر التحديث',
                      message: 'تجاوز الحد المجاني فحاول لاحقاً',
                      onRetry: () {
                        retryPressed = true;
                      },
                    );
                  },
                  child: const Text('Open Failure'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Failure'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('تعذّر التحديث'), findsOneWidget);
      expect(find.text('تجاوز الحد المجاني فحاول لاحقاً'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsWidgets); // Close icon in error header
      expect(find.text('إعادة المحاولة'), findsOneWidget);
      expect(find.text('إغلاق'), findsOneWidget);

      // Tap Retry button
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();

      expect(retryPressed, isTrue);
      // Dialog should close after retry
      expect(find.text('تعذّر التحديث'), findsNothing);
    });
  });
}
