import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final Color color;
  final IconData icon;

  const Category({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
  });
}

class Categories {
  static const Category personal = Category(
    id: 'personal',
    name: 'Pessoal',
    color: Color(0xFF26A69A),
    icon: Icons.person_outline,
  );

  static const Category work = Category(
    id: 'work',
    name: 'Trabalho',
    color: Color(0xFF1565C0),
    icon: Icons.work_outline,
  );

  static const Category study = Category(
    id: 'study',
    name: 'Estudos',
    color: Color(0xFF8E24AA),
    icon: Icons.school_outlined,
  );

  static const Category health = Category(
    id: 'health',
    name: 'Saúde',
    color: Color(0xFFD81B60),
    icon: Icons.favorite_outline,
  );

  static const Category home = Category(
    id: 'home',
    name: 'Casa',
    color: Color(0xFFFB8C00),
    icon: Icons.home_outlined,
  );

  static const List<Category> all = [
    personal,
    work,
    study,
    health,
    home,
  ];

  static Category defaultCategory() => personal;

  static Category? byId(String? id) {
    if (id == null) return null;
    for (final category in all) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }
}
