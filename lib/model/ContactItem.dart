class ContactItem {
  final String name;
  final String phone;
  final String displayPhone;
  bool isRegistered;

  ContactItem({
    required this.name,
    required this.phone,
    required this.displayPhone,
    this.isRegistered = false,
  });

  // ✅ نسخة للكاش
  ContactItem copyWith({bool? isRegistered}) {
    return ContactItem(
      name: name,
      phone: phone,
      displayPhone: displayPhone,
      isRegistered: isRegistered ?? this.isRegistered,
    );
  }
}