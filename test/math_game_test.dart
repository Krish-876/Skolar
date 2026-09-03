import 'package:flutter_test/flutter_test.dart';
import 'package:Skolar/features/math_game/logic/question_generator.dart';
import 'package:Skolar/features/math_game/models/math_question.dart';

void main() {
  group('QuestionGenerator Tests', () {
    final generator = QuestionGenerator();

    test(
      'Follows progressive difficulty order (Addition -> Subtraction -> Multiplication -> Division -> LCM -> HCF)',
      () {
        expect(generator.determineType(0), MathQuestionType.addition);
        expect(generator.determineType(3), MathQuestionType.addition);
        expect(generator.determineType(4), MathQuestionType.subtraction);
        expect(generator.determineType(7), MathQuestionType.subtraction);
        expect(generator.determineType(8), MathQuestionType.multiplication);
        expect(generator.determineType(12), MathQuestionType.multiplication);
        expect(generator.determineType(13), MathQuestionType.division);
        expect(generator.determineType(17), MathQuestionType.division);
        expect(generator.determineType(18), MathQuestionType.lcm);
        expect(generator.determineType(23), MathQuestionType.lcm);
        expect(generator.determineType(24), MathQuestionType.hcf);
      },
    );

    test('Points increase with difficulty and question type', () {
      final qAdd = generator.generate(questionIndex: 0);
      final qSub = generator.generate(questionIndex: 4);
      final qMul = generator.generate(questionIndex: 8);
      final qDiv = generator.generate(questionIndex: 13);
      final qLcm = generator.generate(questionIndex: 18);
      final qHcf = generator.generate(questionIndex: 24);

      expect(qAdd.type, MathQuestionType.addition);
      expect(qSub.type, MathQuestionType.subtraction);
      expect(qMul.type, MathQuestionType.multiplication);
      expect(qDiv.type, MathQuestionType.division);
      expect(qLcm.type, MathQuestionType.lcm);
      expect(qHcf.type, MathQuestionType.hcf);

      expect(qAdd.basePoints < qSub.basePoints, isTrue);
      expect(qSub.basePoints < qMul.basePoints, isTrue);
      expect(qMul.basePoints < qDiv.basePoints, isTrue);
      expect(qDiv.basePoints < qLcm.basePoints, isTrue);
      expect(qLcm.basePoints < qHcf.basePoints, isTrue);
    });

    test('Generates valid positive subtraction questions', () {
      for (int i = 4; i < 8; i++) {
        final q = generator.generate(questionIndex: i);
        expect(q.type, MathQuestionType.subtraction);
        expect(q.answer > 0, isTrue);
      }
    });

    test('Generates valid whole-number division questions', () {
      for (int i = 13; i < 18; i++) {
        final q = generator.generate(questionIndex: i);
        expect(q.type, MathQuestionType.division);
        expect(q.answer > 0, isTrue);
      }
    });
  });
}
