import 'package:flutter/material.dart';

class AppColors {
  // Primary Brand
  static const primary = Color(0xFF1A3C6E);
  static const primaryLight = Color(0xFF2A5298);
  static const accent = Color(0xFF00BFA5);
  static const accentLight = Color(0xFF4DD0C4);

  // Role Colors
  static const studentColor = Color(0xFF1A3C6E);
  static const mentorColor = Color(0xFF2E7D32);
  static const hodColor = Color(0xFF6A1B9A);
  static const adminColor = Color(0xFFB71C1C);

  // Category Colors
  static const academic = Color(0xFF1565C0);
  static const development = Color(0xFF2E7D32);
  static const skill = Color(0xFFE65100);
  static const discipline = Color(0xFF6A1B9A);
  static const leadership = Color(0xFFC62828);

  // Status Colors
  static const draft = Color(0xFF757575);
  static const submitted = Color(0xFF1976D2);
  static const mentorReview = Color(0xFFF57C00);
  static const hodReview = Color(0xFF7B1FA2);
  static const approved = Color(0xFF388E3C);
  static const rejected = Color(0xFFD32F2F);

  // Star Colors
  static const starGold = Color(0xFFFFC107);

  // Backgrounds
  static const background = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const cardBg = Color(0xFFFFFFFF);

  // Text
  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF6B7280);
  static const textLight = Color(0xFF9CA3AF);

  // Utility
  static const divider = Color(0xFFE5E7EB);
  static const error = Color(0xFFDC2626);
  static const success = Color(0xFF16A34A);
}

class AppStrings {
  static const appName = 'SSM System';
  static String academicYear = '2025-2026'; // updated on app start from backend

  // Categories
  static const cat1 = 'Academic Performance';
  static const cat2 = 'Student Development';
  static const cat3 = 'Skill & Professional';
  static const cat4 = 'Discipline & Contribution';
  static const cat5 = 'Leadership & Initiatives';
}

class AppConfig {
  // Change this to your FastAPI server IP when testing on device
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const tokenKey = 'ssm_access_token';
  static const userRoleKey = 'ssm_user_role';
  static const userIdKey = 'ssm_user_id';
  static const userNameKey = 'ssm_user_name';
  static const deptIdKey = 'ssm_dept_id';
}
