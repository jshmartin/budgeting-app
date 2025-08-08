import 'package:hive/hive.dart';

part 'budget.g.dart';

@HiveType(typeId: 1)
class BudgetModel extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  double amount;

  @HiveField(2)
  DateTime startDate;

  @HiveField(3)
  DateTime endDate;

  BudgetModel({
    required this.title,
    required this.amount,
    required this.startDate,
    required this.endDate,
  });

  // Firebase serialization
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'amount': amount,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };
  }

  factory BudgetModel.fromFirestore(Map<String, dynamic> map) {
    return BudgetModel(
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
    );
  }
}
