import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Date and Time Utilities
String formatMessageTime(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inDays == 0) {
    return DateFormat('HH:mm').format(dateTime);
  } else if (difference.inDays == 1) {
    return 'Yesterday';
  } else if (difference.inDays < 7) {
    return DateFormat('EEEE').format(dateTime);
  } else {
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }
}

String formatFullDate(DateTime dateTime) {
  return DateFormat('dd MMMM yyyy, HH:mm').format(dateTime);
}

String formatRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inSeconds < 60) {
    return 'Just now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m ago';
  } else if (difference.inHours < 24) {
    return '${difference.inHours}h ago';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  } else {
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }
}

// String Utilities
String capitalize(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1).toLowerCase();
}

String truncateText(String text, int maxLength) {
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength)}...';
}

bool isValidEmail(String email) {
  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  return emailRegex.hasMatch(email);
}

bool isValidPhoneNumber(String phone) {
  final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]+$');
  return phoneRegex.hasMatch(phone) && phone.length >= 10;
}

String generateChatId(String userId1, String userId2) {
  final ids = [userId1, userId2]..sort();
  return '${ids[0]}_${ids[1]}';
}

String generateMessageId() {
  return DateTime.now().millisecondsSinceEpoch.toString();
}

// Validation Utilities
String? validateEmail(String? email) {
  if (email == null || email.isEmpty) {
    return 'Email is required';
  }
  if (!isValidEmail(email)) {
    return 'Please enter a valid email';
  }
  return null;
}

String? validatePassword(String? password) {
  if (password == null || password.isEmpty) {
    return 'Password is required';
  }
  if (password.length < 6) {
    return 'Password must be at least 6 characters';
  }
  return null;
}

String? validateMessage(String? message) {
  if (message == null || message.trim().isEmpty) {
    return 'Message cannot be empty';
  }
  if (message.length > 1000) {
    return 'Message is too long';
  }
  return null;
}

// Other Utilities
bool isDarkMode(BuildContext context) {
  return MediaQuery.of(context).platformBrightness == Brightness.dark;
}

double getScreenWidth(BuildContext context) {
  return MediaQuery.of(context).size.width;
}

double getScreenHeight(BuildContext context) {
  return MediaQuery.of(context).size.height;
}

void showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

Future<void> delay(int milliseconds) async {
  await Future.delayed(Duration(milliseconds: milliseconds));
}
