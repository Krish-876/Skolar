import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() {
  final outDir = Directory('assets/sounds');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  // 1. Focus Start: Crisp, glassy crystal chime (E6 + B6 + E7 chord with bell envelope)
  _generateGlassyChime(
    filePath: 'assets/sounds/focus_start.wav',
    durationSeconds: 1.4,
    notes: [
      _Note(freq: 1318.5, delay: 0.0, volume: 0.5, decay: 1.2), // E6
      _Note(freq: 1975.5, delay: 0.04, volume: 0.35, decay: 1.0), // B6
      _Note(freq: 2637.0, delay: 0.08, volume: 0.25, decay: 0.8), // E7
    ],
  );

  // 2. Break Start: Serene, warm glass bowl tone (A5 + C#6 + E6)
  _generateGlassyChime(
    filePath: 'assets/sounds/break_start.wav',
    durationSeconds: 2.0,
    notes: [
      _Note(freq: 880.0, delay: 0.0, volume: 0.45, decay: 1.8), // A5
      _Note(freq: 1108.7, delay: 0.05, volume: 0.4, decay: 1.6), // C#6
      _Note(freq: 1318.5, delay: 0.1, volume: 0.35, decay: 1.5), // E6
    ],
  );

  // 3. Break End: Crisp double upward glass ding (D6 -> A6)
  _generateGlassyChime(
    filePath: 'assets/sounds/break_end.wav',
    durationSeconds: 1.6,
    notes: [
      _Note(freq: 1174.6, delay: 0.0, volume: 0.45, decay: 1.0), // D6
      _Note(freq: 1760.0, delay: 0.14, volume: 0.5, decay: 1.3), // A6
    ],
  );

  // 4. Session Complete: Resonant, peaceful glass chime progression (C5 -> E5 -> G5 -> C6)
  _generateGlassyChime(
    filePath: 'assets/sounds/session_complete.wav',
    durationSeconds: 3.2,
    notes: [
      _Note(freq: 523.25, delay: 0.0, volume: 0.4, decay: 2.8), // C5
      _Note(freq: 659.25, delay: 0.18, volume: 0.4, decay: 2.6), // E5
      _Note(freq: 783.99, delay: 0.36, volume: 0.42, decay: 2.4), // G5
      _Note(freq: 1046.50, delay: 0.54, volume: 0.48, decay: 2.5), // C6
      _Note(
        freq: 1567.98,
        delay: 0.56,
        volume: 0.22,
        decay: 1.8,
      ), // G6 overtone
    ],
  );
}

class _Note {
  final double freq;
  final double delay;
  final double volume;
  final double decay;
  const _Note({
    required this.freq,
    required this.delay,
    required this.volume,
    required this.decay,
  });
}

void _generateGlassyChime({
  required String filePath,
  required double durationSeconds,
  required List<_Note> notes,
}) {
  const sampleRate = 44100;
  final numSamples = (sampleRate * durationSeconds).toInt();
  final audioData = Float32List(numSamples);

  for (final note in notes) {
    final startSample = (note.delay * sampleRate).toInt();
    for (int i = startSample; i < numSamples; i++) {
      final t = (i - startSample) / sampleRate;

      // Exponential decay envelope with instant 3ms attack
      final attack = (t / 0.003).clamp(0.0, 1.0);
      final envelope = attack * exp(-t * (3.5 / note.decay));

      // Fundamental sine wave + subtle glassy high harmonics
      final fundamental = sin(2 * pi * note.freq * t);
      final harmonic2 =
          0.25 *
          sin(
            2 * pi * (note.freq * 2.76) * t,
          ); // metallic/glass bell inharmonic
      final harmonic3 = 0.12 * sin(2 * pi * (note.freq * 5.4) * t);

      final sampleVal =
          (fundamental + harmonic2 + harmonic3) * envelope * note.volume;
      audioData[i] += sampleVal;
    }
  }

  // Normalize audio to avoid clipping
  double maxPeak = 0.0;
  for (int i = 0; i < numSamples; i++) {
    if (audioData[i].abs() > maxPeak) {
      maxPeak = audioData[i].abs();
    }
  }

  final gain = maxPeak > 0.0 ? (0.85 / maxPeak) : 1.0;

  // Build 16-bit PCM Stereo WAV Header + Data
  final bytesPerSample = 2; // 16-bit
  final numChannels = 2; // stereo
  final dataSize = numSamples * numChannels * bytesPerSample;
  final fileSize = 44 + dataSize;

  final byteData = ByteData(fileSize);

  // RIFF Chunk
  byteData.setUint8(0, 0x52); // 'R'
  byteData.setUint8(1, 0x49); // 'I'
  byteData.setUint8(2, 0x46); // 'F'
  byteData.setUint8(3, 0x46); // 'F'
  byteData.setUint32(4, fileSize - 8, Endian.little);
  byteData.setUint8(8, 0x57); // 'W'
  byteData.setUint8(9, 0x41); // 'A'
  byteData.setUint8(10, 0x56); // 'V'
  byteData.setUint8(11, 0x45); // 'E'

  // fmt Subchunk
  byteData.setUint8(12, 0x66); // 'f'
  byteData.setUint8(13, 0x6D); // 'm'
  byteData.setUint8(14, 0x74); // 't'
  byteData.setUint8(15, 0x20); // ' '
  byteData.setUint32(16, 16, Endian.little); // subchunk1 size
  byteData.setUint16(20, 1, Endian.little); // PCM = 1
  byteData.setUint16(22, numChannels, Endian.little);
  byteData.setUint32(24, sampleRate, Endian.little);
  byteData.setUint32(
    28,
    sampleRate * numChannels * bytesPerSample,
    Endian.little,
  ); // byte rate
  byteData.setUint16(
    32,
    numChannels * bytesPerSample,
    Endian.little,
  ); // block align
  byteData.setUint16(34, 16, Endian.little); // bits per sample

  // data Subchunk
  byteData.setUint8(36, 0x64); // 'd'
  byteData.setUint8(37, 0x61); // 'a'
  byteData.setUint8(38, 0x74); // 't'
  byteData.setUint8(39, 0x61); // 'a'
  byteData.setUint32(40, dataSize, Endian.little);

  // Write samples (Stereo 16-bit PCM)
  int offset = 44;
  for (int i = 0; i < numSamples; i++) {
    final sample = (audioData[i] * gain).clamp(-1.0, 1.0);
    final intSample = (sample * 32767.0).toInt().clamp(-32768, 32767);

    // Left channel
    byteData.setInt16(offset, intSample, Endian.little);
    offset += 2;
    // Right channel
    byteData.setInt16(offset, intSample, Endian.little);
    offset += 2;
  }

  File(filePath).writeAsBytesSync(byteData.buffer.asUint8List());
}
