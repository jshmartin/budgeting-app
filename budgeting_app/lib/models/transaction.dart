import 'package:hive/hive.dart';

part 'transaction.g.dart';

@HiveType(typeId: 0)
class TransactionModel extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  double amount;

  @HiveField(2)
  DateTime date;

  TransactionModel({
    required this.title,
    required this.amount,
    required this.date,
  });

  // --- Firebase serialization ---
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
    };
  }

  factory TransactionModel.fromFirestore(Map<String, dynamic> map) {
    return TransactionModel(
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      date: DateTime.parse(map['date']),
    );
  }
}
