const List<String> kTherapyPatternNames = [
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

String therapyPatternName(int patternIndex) {
  if (patternIndex >= 0 && patternIndex < kTherapyPatternNames.length) {
    return kTherapyPatternNames[patternIndex];
  }
  return 'Unknown';
}

int? therapyPatternIndexFromName(String rawPattern) {
  final normalized = rawPattern.trim().toLowerCase();
  if (normalized.isEmpty) return null;

  for (var i = 0; i < kTherapyPatternNames.length; i++) {
    final name = kTherapyPatternNames[i].toLowerCase();
    if (normalized == name || normalized.startsWith('$name ')) {
      return i;
    }
  }

  return null;
}
