class TextInputValidator {
  static String? validate(String text) {
    if (text.trim().isEmpty) {
      return 'Enter some text to generate speech.';
    }

    return null;
  }
}