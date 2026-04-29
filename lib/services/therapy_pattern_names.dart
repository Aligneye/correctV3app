const List<String> kTherapyPatternNames = [
  'Wake-Up Pulse',
  'Cool-Down Glide',
  'Power Build',
  'Ocean Wave',
  'Deep Flow',
  'Smooth Rhythm',
  'Peak Release',
  'Dual Wave',
  'Refresh Break',
  'Pulse Lift',
  'Triple Boost',
  'Steady Hold',
  'Echo Waves',
  'Breathing Calm',
];

const List<String> _kFirmwarePatternNames = [
  'Muscle Act',
  'Rev Ramp',
  'Ramp',
  'Wave',
  'Slow Wave',
  'Sine Wave',
  'Triangle',
  'Dbl Wave',
  'Anti-Fatigue',
  'Pulse Ramp',
  'Triple Base',
  'Const Triple',
  'Exp Double',
  'Breath ExpSq',
];

const List<String> kTherapyPatternDescriptions = [
  'A gentle activation pattern that eases your muscles into the session.',
  'A gradually softening vibration designed to help you settle and relax.',
  'A steady build-up that brings stronger stimulation in a controlled way.',
  'A rolling wave sensation for a smooth, flowing therapy feel.',
  'A slow, deeper rhythm for longer, calming vibration cycles.',
  'A balanced rise-and-fall rhythm for comfortable continuous relief.',
  'A crisp peak-and-release pattern that alternates intensity clearly.',
  'Two layered waves that create a fuller massage-like vibration.',
  'Short recovery pulses intended to reduce fatigue during the session.',
  'A pulsing lift that ramps intensity in repeating waves.',
  'Three quick bursts followed by a reset for an energizing feel.',
  'A consistent triple pulse rhythm for stable, predictable stimulation.',
  'Expanding double waves that feel broader as the pattern progresses.',
  'A breathing-inspired rhythm for a calm, slow finish.',
];

String therapyPatternName(int patternIndex) {
  if (patternIndex >= 0 && patternIndex < kTherapyPatternNames.length) {
    return kTherapyPatternNames[patternIndex];
  }
  return 'Unknown';
}

String therapyPatternDescription(int patternIndex) {
  if (patternIndex >= 0 && patternIndex < kTherapyPatternDescriptions.length) {
    return kTherapyPatternDescriptions[patternIndex];
  }
  return 'Pattern details were not captured for this session.';
}

int? therapyPatternIndexFromName(String rawPattern) {
  final normalized = rawPattern.trim().toLowerCase();
  if (normalized.isEmpty) return null;

  for (var i = 0; i < kTherapyPatternNames.length; i++) {
    final name = kTherapyPatternNames[i].toLowerCase();
    final firmwareName = _kFirmwarePatternNames[i].toLowerCase();
    if (normalized == name ||
        normalized.startsWith('$name ') ||
        normalized == firmwareName ||
        normalized.startsWith('$firmwareName ')) {
      return i;
    }
  }

  return null;
}
