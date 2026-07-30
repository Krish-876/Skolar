import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileDetails {
  final String? endgame;
  final List<String> careerInterests;
  final String? prepStyle;

  const ProfileDetails({
    this.endgame,
    this.careerInterests = const [],
    this.prepStyle,
  });
}

final profileDetailsProvider = FutureProvider<ProfileDetails>((ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return const ProfileDetails();

  String? endgame;
  List<String> careerInterests = [];
  String? prepStyle;

  try {
    // 1. Fetch endgame flag
    final flags = await client
        .from('standing_flags')
        .select('instruction_text')
        .eq('user_id', user.id)
        .eq('source', 'onboarding')
        .order('confirmed_at', ascending: false)
        .limit(1);

    if (flags.isNotEmpty) {
      endgame = flags.first['instruction_text'] as String?;
    }
  } catch (_) {}

  try {
    // 2. Fetch career interests
    final units = await client
        .from('career_units')
        .select('name')
        .eq('user_id', user.id)
        .eq('source', 'onboarding');

    careerInterests = units
        .map((u) => u['name'] as String)
        .whereType<String>()
        .toList();
  } catch (_) {}

  try {
    // 3. Fetch prep style from nova_history
    final history = await client
        .from('nova_history')
        .select('content')
        .eq('user_id', user.id)
        .eq('source', 'onboarding')
        .order('confirmed_at', ascending: false)
        .limit(1);

    if (history.isNotEmpty) {
      prepStyle = history.first['content'] as String?;
    }
  } catch (_) {}

  return ProfileDetails(
    endgame: endgame,
    careerInterests: careerInterests,
    prepStyle: prepStyle,
  );
});
