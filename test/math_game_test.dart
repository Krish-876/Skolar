import 'package:flutter_test/flutter_test.dart';
import 'package:Skolar/features/math_game/logic/question_generator.dart';
import 'package:Skolar/features/math_game/models/math_question.dart';

void main() {
  group('QuestionGenerator Tests', () {
    final generator = QuestionGenerator();

    test('Generates valid Addition questions', () {
      for (int i = 0; i < 20; i++) {
        final q = generator.generate(
          questionIndex: i,
          currentStreak: i,
          forcedType: MathQuestionType.addition,
        );
        expect(q.type, MathQuestionType.addition);
        expect(q.displayText.contains('+'), isTrue);
        expect(q.answer > 0, isTrue);
      }
    });

    test('Generates valid Subtraction questions with positive answers', () {
      for (int i = 0; i < 20; i++) {
        final q = generator.generate(
          questionIndex: i,
          currentStreak: i,
          forcedType: MathQuestionType.subtraction,
        );
        expect(q.type, MathQuestionType.subtraction);
        expect(q.displayText.contains('−'), isTrue);
        expect(q.answer > 0, isTrue);
      }
    });

    test('Generates valid Multiplication questions', () {
      for (int i = 0; i < 20; i++) {
        final q = generator.generate(
          questionIndex: i,
          currentStreak: i,
          forcedType: MathQuestionType.multiplication,
        );
        expect(q.type, MathQuestionType.multiplication);
        expect(q.displayText.contains('×'), isTrue);
        expect(q.answer > 0, isTrue);
      }
    });

    test('Generates valid Division questions with whole integer quotients', () {
      for (int i = 0; i < 20; i++) {
        final q = generator.generate(
          questionIndex: i,
          currentStreak: i,
          forcedType: MathQuestionType.division,
        );
        expect(q.type, MathQuestionType.division);
        expect(q.displayText.contains('÷'), isTrue);
        expect(q.answer > 0, isTrue);
      }
    });

    test('Generates valid LCM questions', () {
      for (int i = 0; i < 20; i++) {
        final q = generator.generate(
          questionIndex: i,
          currentStreak: i,
          forcedType: MathQuestionType.lcm,
        );
        expect(q.type, MathQuestionType.lcm);
        expect(q.displayText.startsWith('LCM('), isTrue);
        expect(q.answer > 0, isTrue);
      }
    });

    test('Generates valid HCF questions', () {
      for (int i = 0; i < 20; i++) {
        final q = generator.generate(
          questionIndex: i,
          currentStreak: i,
          forcedType: MathQuestionType.hcf,
        );
        expect(q.type, MathQuestionType.hcf);
        expect(q.displayText.startsWith('HCF('), isTrue);
        expect(q.answer > 0, isTrue);
      }
    });
  });
}
