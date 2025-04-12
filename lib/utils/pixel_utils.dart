String getFilledBubble(List<int> brightness) {
  const options = ['A', 'B', 'C', 'D'];
  int minIndex = 0;
  int minVal = brightness[0];
  int secondMinVal = 255;

  for (int i = 1; i < brightness.length; i++) {
    if (brightness[i] < minVal) {
      secondMinVal = minVal;
      minVal = brightness[i];
      minIndex = i;
    } else if (brightness[i] < secondMinVal) {
      secondMinVal = brightness[i];
    }
  }

  const fillThreshold = 150;

  // Handle case where no bubble is filled or multiple bubbles are similarly filled
  if (minVal > fillThreshold || (secondMinVal - minVal) < 20) {
    return '-'; // Indicate unanswered or unclear answer
  }

  return options[minIndex]; // Return the bubble with the lowest brightness
}
