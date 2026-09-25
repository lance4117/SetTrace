import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/database/app_database.dart';
import 'features/plans/plan_repository.dart';
import 'features/workout/workout_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await AppDatabase.open();
  final preferences = await SharedPreferences.getInstance();
  runApp(SetTraceApp(plans: PlanRepository(database.db),
    workouts: WorkoutRepository(database.db), preferences: preferences));
}
