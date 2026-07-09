import 'package:flutter/material.dart';
import 'package:Skolar/features/exam_prediction_with_bank/questions_feature/exam_prediction_entity.dart';

// ---------------------------------------------------------------------------
// Stats widgets
// ---------------------------------------------------------------------------

class StatsCard extends StatelessWidget {
  final QuestionBankStats stats;
  const StatsCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question Bank',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatChip(
                  icon: Icons.quiz,
                  label: '${stats.totalQuestions}',
                  sublabel: 'Questions',
                ),
                _StatChip(
                  icon: Icons.calendar_today,
                  label: '${stats.paperYears.length}',
                  sublabel: 'Years',
                ),
                _StatChip(
                  icon: Icons.subject,
                  label: '${stats.subjects.length}',
                  sublabel: 'Subjects',
                ),
              ],
            ),
            if (stats.subjects.isNotEmpty) ...[
              const Divider(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: stats.subjects.entries
                    .map(
                      (e) => Chip(
                        label: Text('${e.key}: ${e.value}'),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  const _StatChip({
    required this.icon,
    required this.label,
    required this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.titleLarge),
        Text(sublabel, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class StatsLoadingCard extends StatelessWidget {
  const StatsLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generate widgets
// ---------------------------------------------------------------------------

class GeneratingCard extends StatelessWidget {
  const GeneratingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Running DICL pipeline…'),
          ],
        ),
      ),
    );
  }
}

class GeneratedQuestionCard extends StatelessWidget {
  final GeneratedQuestion question;
  const GeneratedQuestionCard({super.key, required this.question});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Generated Question',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Chip(
                  label: Text(question.subject),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const Divider(height: 20),
            Text(
              question.question,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Based on ${question.examplesUsed} past questions',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Upload widgets
// ---------------------------------------------------------------------------

class UploadingCard extends StatelessWidget {
  const UploadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Uploading and extracting questions…'),
          ],
        ),
      ),
    );
  }
}

class UploadResultCard extends StatelessWidget {
  final UploadResult result;
  const UploadResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle),
                const SizedBox(width: 8),
                Expanded(child: Text(result.message)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${result.added} added · ${result.total} total in bank',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (result.preview.isNotEmpty) ...[
              const Divider(height: 16),
              Text('Preview', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              ...result.preview.map(
                (q) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(
                        child: Text(
                          q,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Question Bank Card
// ---------------------------------------------------------------------------

class QuestionBankCard extends StatelessWidget {
  final QuestionItem question;
  const QuestionBankCard({super.key, required this.question});

  Color _typeColor(BuildContext context, String type) {
    return switch (type) {
      'mcq' => Colors.blue.shade100,
      'long_answer' => Colors.orange.shade100,
      'short_answer' => Colors.green.shade100,
      'numerical' => Colors.purple.shade100,
      _ => Theme.of(context).colorScheme.surfaceContainerHighest,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tags row
            Wrap(
              spacing: 6,
              children: [
                _Tag(label: question.subject, color: Colors.indigo.shade100),
                _Tag(
                  label: '${question.paperYear}',
                  color: Colors.grey.shade200,
                ),
                _Tag(label: question.examType, color: Colors.teal.shade100),
                _Tag(
                  label: question.questionType,
                  color: _typeColor(context, question.questionType),
                ),
                _Tag(label: '${question.marks}M', color: Colors.amber.shade100),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              question.questionText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared error widget
// ---------------------------------------------------------------------------

class ErrorCard extends StatelessWidget {
  final String message;
  const ErrorCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
