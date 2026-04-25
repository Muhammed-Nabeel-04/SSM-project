import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssm_app/widgets/common_widgets.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('StatusBadge shows readable review state', (tester) async {
    await tester.pumpWidget(wrap(const StatusBadge('mentor_review')));

    expect(find.text('Mentor Review'), findsOneWidget);
  });

  testWidgets('StarRating renders filled stars for earned rating', (tester) async {
    await tester.pumpWidget(wrap(const StarRating(stars: 3)));

    final filled = find.byIcon(Icons.star_rounded);
    final outline = find.byIcon(Icons.star_outline_rounded);

    expect(filled, findsNWidgets(3));
    expect(outline, findsNWidgets(2));
  });

  testWidgets('GrandTotalCard renders score and rating label', (tester) async {
    await tester.pumpWidget(wrap(const GrandTotalCard(total: 452, stars: 5)));

    expect(find.text('452 / 500'), findsOneWidget);
    expect(find.textContaining('Outstanding'), findsOneWidget);
  });
}
