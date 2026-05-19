/// Feature skeleton - Repository
abstract class ProfileRepository {
  Future<dynamic> getUserProfile(String userId);
  Future<dynamic> updateUserProfile(String userId, Map<String, dynamic> data);
}
