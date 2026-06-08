/// Parses a BITS Pilani email into structured user data.
/// Format: f{batch_year}{roll_number}@{subdomain}.bits-pilani.ac.in
/// Example: f20240175@hyderabad.bits-pilani.ac.in
class EmailParser {
  static const _bitsPattern =
      r'^f(\d{4})(\d{4})@([a-z]+)\.bits-pilani\.ac\.in$';

  static ParsedEmail? parse(String email) {
    final match = RegExp(_bitsPattern).firstMatch(email.toLowerCase().trim());
    if (match == null) return null;

    final batchYear    = int.parse(match.group(1)!);
    final rollNumber   = match.group(2)!;
    final subdomain    = match.group(3)!;
    final currentYear  = DateTime.now().year;
    final academicYear = (currentYear - batchYear + 1).clamp(1, 4);

    return ParsedEmail(
      batchYear:    batchYear,
      rollNumber:   rollNumber,
      subdomain:    subdomain,
      academicYear: academicYear,
    );
  }

  static bool isBitsEmail(String email) => parse(email) != null;
}

class ParsedEmail {
  final int batchYear;
  final String rollNumber;
  final String subdomain;   // 'hyderabad' → BPHC
  final int academicYear;   // 1–4

  const ParsedEmail({
    required this.batchYear,
    required this.rollNumber,
    required this.subdomain,
    required this.academicYear,
  });
}