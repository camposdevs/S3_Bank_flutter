import 'package:flutter/material.dart';

/// Representa uma "caixinha" / objetivo de economia criado pelo usuário,
/// inspirado no "Guardar Dinheiro" do Itaú e nas "Caixinhas" do C6 Bank.
class SavingsGoal {
  final String id;
  final String name;
  final IconData icon;
  final double targetAmount;
  final double currentAmount;
  final DateTime createdAt;

  const SavingsGoal({
    required this.id,
    required this.name,
    required this.icon,
    required this.targetAmount,
    required this.currentAmount,
    required this.createdAt,
  });

  double get progress =>
      targetAmount <= 0 ? 0 : (currentAmount / targetAmount).clamp(0, 1);

  SavingsGoal copyWith({
    String? name,
    IconData? icon,
    double? targetAmount,
    double? currentAmount,
  }) {
    return SavingsGoal(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      createdAt: createdAt,
    );
  }
}
