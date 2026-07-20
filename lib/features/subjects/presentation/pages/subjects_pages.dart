import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Skolar/core/theme/app_theme.dart';
import 'package:Skolar/features/subjects/presentation/providers/subjects_provider.dart';
import 'package:Skolar/features/subjects/presentation/widgets/subjects_widgets.dart';

class SubjectsPage extends StatelessWidget {
  const SubjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.onBackground,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'My Subjects',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.onBackground,
            letterSpacing: 0.3,
          ),
        ),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final asyncState = ref.watch(subjectsProvider);
              return asyncState.whenOrNull(
                    data: (s) => s.editMode
                        ? TextButton(
                            onPressed: () => ref
                                .read(subjectsProvider.notifier)
                                .commitDeletions(),
                            child: const Text(
                              'Done',
                              style: TextStyle(
                                color: AppTheme.wishlist,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          )
                        : TextButton(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => CreditTargetSheet(
                                  onConfirm: (value) {
                                    ref.read(subjectsProvider.notifier).setCreditTarget(value);
                                  },
                                ),
                              );
                            },
                            child: const Text(
                              'Edit credits',
                              style: TextStyle(
                                color: AppTheme.onBackground2,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                  ) ??
                  const SizedBox.shrink();
            }
          ),
        ],
      ),
      body: const SubjectsPageContent(),
    );
  }
}

class SubjectsPageContent extends ConsumerStatefulWidget {
  const SubjectsPageContent({super.key});

  @override
  ConsumerState<SubjectsPageContent> createState() => _SubjectsPageContentState();
}

class _SubjectsPageContentState extends ConsumerState<SubjectsPageContent> {
  bool _creditSheetShown = false;

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(subjectsProvider);

    asyncState.whenData((s) {
      if (!_creditSheetShown &&
          s.creditTargetLoaded &&
          s.creditTarget == null) {
        _creditSheetShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showCreditTargetSheet(context);
        });
      }
    });

    return asyncState.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.onBackground2),
      ),
      error: (e, _) => Center(
        child: Text(
          'Something went wrong.\n$e',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.onBackground2),
        ),
      ),
      data: (s) => SubjectsBody(
        state: s,
        onLongPress: (id) {
          HapticFeedback.mediumImpact();
          ref.read(subjectsProvider.notifier).enterEditMode();
          ref.read(subjectsProvider.notifier).togglePendingDelete(id);
        },
        onTap: (id) =>
            ref.read(subjectsProvider.notifier).togglePendingDelete(id),
        onAdd: () => _showAddSheet(context),
        onPickHandout: (userSubjectId) =>
            _pickHandout(context, userSubjectId),
        onUnstageHandout: (userSubjectId) =>
            ref.read(subjectsProvider.notifier).unstageHandout(userSubjectId),
        onSubmitStaged: () => _submitStaged(context),
      ),
    );
  }

  Future<void> _pickHandout(BuildContext context, String userSubjectId) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    ref
        .read(subjectsProvider.notifier)
        .stageHandout(
          userSubjectId: userSubjectId,
          fileBytes: file.bytes!,
          filename: file.name,
        );
  }

  Future<void> _submitStaged(BuildContext context) async {
    final error = await ref
        .read(subjectsProvider.notifier)
        .submitStagedHandouts();

    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Some uploads failed: $error'),
          backgroundColor: AppTheme.wishlist,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Handouts uploaded — study plans are being generated'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showCreditTargetSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreditTargetSheet(
        onConfirm: (value) {
          ref.read(subjectsProvider.notifier).setCreditTarget(value);
        },
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    final s = ref.read(subjectsProvider).valueOrNull;
    final remaining = s?.remainingCredits;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddSubjectSheet(
        remainingCredits: remaining,
        onConfirm: (name, courseCode, credits) => ref
            .read(subjectsProvider.notifier)
            .addCustomSubject(
              name: name,
              courseCode: courseCode,
              credits: credits,
            ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────

class SubjectsBody extends StatelessWidget {
  final SubjectsPageState state;
  final void Function(String id) onLongPress;
  final void Function(String id) onTap;
  final VoidCallback onAdd;
  final void Function(String userSubjectId) onPickHandout;
  final void Function(String userSubjectId) onUnstageHandout;
  final VoidCallback onSubmitStaged;

  const SubjectsBody({
    required this.state,
    required this.onLongPress,
    required this.onTap,
    required this.onAdd,
    required this.onPickHandout,
    required this.onUnstageHandout,
    required this.onSubmitStaged,
  });

  @override
  Widget build(BuildContext context) {
    final atCap =
        state.creditTarget != null && state.totalCredits >= state.creditTarget!;
    final hasStaged = state.stagedHandouts.isNotEmpty;

    return Column(
      children: [
        const SizedBox(height: AppTheme.lg),

        CreditRing(earned: state.totalCredits, target: state.creditTarget ?? 0),

        const SizedBox(height: AppTheme.sm),

        if (state.creditTarget != null)
          Text(
            atCap
                ? 'Credit limit reached'
                : '${state.remainingCredits} credits remaining',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: atCap
                  ? AppTheme.chartCompleted
                  : AppTheme.onBackground2.withValues(alpha: 0.7),
            ),
          ),

        const SizedBox(height: AppTheme.md),

        if (state.editMode)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.sm),
            child: Text(
              'Tap a subject to mark for removal',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.onBackground2.withValues(alpha: 0.6),
              ),
            ),
          ),

        Expanded(
          child: state.subjects.isEmpty
              ? const Center(
                  child: Text(
                    'No subjects yet.\nTap Add Subject below.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.onBackground2,
                      fontSize: 15,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.lg),
                  itemCount: state.subjects.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppTheme.sm),
                  itemBuilder: (_, i) {
                    final s = state.subjects[i];
                    final marked = state.pendingDelete.contains(
                      s.userSubjectId,
                    );
                    final uploading =
                        state.uploadingHandout[s.userSubjectId] == true;
                    final staged = state.stagedHandouts[s.userSubjectId];
                    return SubjectRow(
                      subject: s,
                      editMode: state.editMode,
                      marked: marked,
                      uploading: uploading,
                      stagedFilename: staged?.filename,
                      onTap: state.editMode
                          ? () => onTap(s.userSubjectId)
                          : null,
                      onLongPress: () => onLongPress(s.userSubjectId),
                      onPickHandout: state.editMode
                          ? null
                          : () => onPickHandout(s.userSubjectId),
                      onUnstageHandout: state.editMode
                          ? null
                          : () => onUnstageHandout(s.userSubjectId),
                    );
                  },
                ),
        ),

        if (hasStaged && !state.editMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.lg,
              0,
              AppTheme.lg,
              AppTheme.sm,
            ),
            child: GestureDetector(
              onTap: onSubmitStaged,
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.cloud_upload_rounded,
                      color: AppTheme.onPrimary,
                      size: 18,
                    ),
                    const SizedBox(width: AppTheme.xs),
                    Text(
                      'Generate plans for ${state.stagedHandouts.length} '
                      '${state.stagedHandouts.length == 1 ? 'subject' : 'subjects'}',
                      style: const TextStyle(
                        color: AppTheme.onPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.lg,
            AppTheme.md,
            AppTheme.lg,
            AppTheme.xl,
          ),
          child: IgnorePointer(
            ignoring: atCap,
            child: AnimatedOpacity(
              opacity: atCap ? 0.4 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                    border: Border.all(
                      color: AppTheme.onBackground2.withValues(alpha: 0.25),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        color: AppTheme.onBackground2,
                        size: 20,
                      ),
                      const SizedBox(width: AppTheme.xs),
                      Text(
                        atCap ? 'Credit limit reached' : 'Add Subject',
                        style: const TextStyle(
                          color: AppTheme.onBackground2,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
