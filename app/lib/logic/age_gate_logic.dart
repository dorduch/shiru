int calculateAge(DateTime birthDate, DateTime now) {
  var age = now.year - birthDate.year;
  final birthdayReached =
      now.month > birthDate.month ||
      (now.month == birthDate.month && now.day >= birthDate.day);
  if (!birthdayReached) {
    age -= 1;
  }
  return age;
}

String? validateAdultBirthDate(DateTime? birthDate, DateTime now) {
  if (birthDate == null) {
    return 'Choose your birth date to continue.';
  }

  if (calculateAge(birthDate, now) < 18) {
    return 'This area is only available to adults.';
  }

  return null;
}
