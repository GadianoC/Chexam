String getFilledBubble(List<int> brightness) {
  const options = ['A', 'B', 'C', 'D'];
  
  // Find darkest and second darkest bubbles
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

  const fillThreshold = 200;  // Increased threshold to be more lenient
  const minDifference = 15;   // Reduced difference requirement

  // Calculate average brightness excluding the darkest bubble
  int sum = 0;
  int count = 0;
  for (int i = 0; i < brightness.length; i++) {
    if (i != minIndex) {
      sum += brightness[i];
      count++;
    }
  }
  int avgBrightness = sum ~/ count;

  // Check if the darkest bubble is significantly darker than others
  if (minVal > fillThreshold || (avgBrightness - minVal) < minDifference) {
    return '-'; // Indicate unanswered or unclear answer
  }

  return options[minIndex]; // Return the bubble with the lowest brightness
}
