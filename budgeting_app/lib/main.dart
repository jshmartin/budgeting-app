import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/transaction.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  Hive.registerAdapter(TransactionModelAdapter());

  await Hive.openBox<TransactionModel>('transactions');
  await Hive.openBox<double>('budget');

  runApp(MaterialApp(
    title: 'Budgeting App',
    theme: ThemeData(primarySwatch: Colors.blue),
    home: HomeScreen(),
  ));
}
