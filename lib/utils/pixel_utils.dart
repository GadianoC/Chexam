List<int> getRGBBrightness(int pixel, {bool toGray = true}) {
  final r = (pixel >> 16) & 0xFF;
  final g = (pixel >> 8) & 0xFF;
  final b = pixel & 0xFF;
  return toGray ? [(r + g + b) ~/ 3] : [r, g, b];
}

String getFilledBubble(List<int> brightness) {
  const options = ['A', 'B', 'C', 'D'];
  int minIndex = 0;
  int minVal = brightness[0];
  for (int i = 1; i < brightness.length; i++) {
    if (brightness[i] < minVal) {
      minVal = brightness[i];
      minIndex = i;
    }
  }
  return options[minIndex];
}
