abstract class AiService {
  /// Send a prompt and receive a text response.
  Future<String> complete(String prompt);
}

