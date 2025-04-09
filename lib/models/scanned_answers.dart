class ScannedAnswers {
  final Map<int, String> answers;

  ScannedAnswers(this.answers);

  // Method to compare the scanned answers with the teacher's correct answers
  int compareWithCorrectAnswers(Map<int, String> correctAnswers) {
    int score = 0;

    for (var entry in answers.entries) {
      if (correctAnswers[entry.key] == entry.value) {
        score++; 
      }
    }

    return score;  
  }
}
