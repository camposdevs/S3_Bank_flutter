import 'package:flutter/material.dart';
import '../models/savings_goal.dart';
import '../models/user_tier.dart';

/// Arredonda para centavos (evita 0.1 + 0.2 = 0.30000000000000004).
double _round2(double value) => (value * 100).round() / 100;

/// Gerencia as caixinhas/objetivos de "Guardar Dinheiro" e calcula o
/// rendimento simulado com base no nível (tier) atual do usuário.
/// TODO(integração-backend): substituir cálculo de rendimento local por
/// valor vindo do backend (ex: GET /savings/yield), que deve considerar
/// a taxa CDI real do dia (hoje mockada como constante).
class SavingsProvider extends ChangeNotifier {
  final List<SavingsGoal> _goals;

  /// Taxa CDI anual mockada (12,15% a.a. — valor de referência de mercado).
  /// TODO(integração-backend): buscar taxa CDI atual via API financeira.
  static const double mockAnnualCdiRate = 0.1215;

  SavingsProvider() : _goals = _seedGoals();

  List<SavingsGoal> get goals => List.unmodifiable(_goals);

  double get totalSaved =>
      _round2(_goals.fold(0.0, (sum, goal) => sum + goal.currentAmount));

  /// Rendimento estimado do mês corrente, com base no total guardado
  /// e no percentual do CDI do nível do usuário.
  double monthlyYieldEstimate(UserTier tier) {
    final monthlyRate = (mockAnnualCdiRate * tier.cdiPercentage) / 12;
    return totalSaved * monthlyRate;
  }

  Map<String, dynamic> toJson() => {
        'goals': _goals.map((g) => g.toJson()).toList(),
      };

  void restore(Map<String, dynamic> json) {
    final list = (json['goals'] as List?) ?? const [];
    _goals
      ..clear()
      ..addAll(list.map((e) => SavingsGoal.fromJson(Map<String, dynamic>.from(e as Map))));
    notifyListeners();
  }

  /// Dados de exemplo da conta de demonstração.
  void loadDemoData() {
    _goals
      ..clear()
      ..addAll(_seedGoals());
    notifyListeners();
  }

  /// Remove as caixinhas de exemplo para um cadastro novo.
  void resetForNewAccount() {
    _goals.clear();
    notifyListeners();
  }

  void createGoal({
    required String name,
    required IconData icon,
    required double targetAmount,
  }) {
    _goals.add(
      SavingsGoal(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        icon: icon,
        targetAmount: targetAmount,
        currentAmount: 0,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void deposit(String goalId, double amount) {
    final value = _round2(amount);
    if (value <= 0) return;
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index == -1) return;
    final goal = _goals[index];
    _goals[index] = goal.copyWith(currentAmount: _round2(goal.currentAmount + value));
    notifyListeners();
  }

  /// Retorna o valor efetivamente resgatado (limitado ao saldo da caixinha).
  double withdraw(String goalId, double amount) {
    final value = _round2(amount);
    if (value <= 0) return 0;
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index == -1) return 0;
    final goal = _goals[index];
    final actual = value > goal.currentAmount ? goal.currentAmount : value;
    _goals[index] = goal.copyWith(currentAmount: _round2(goal.currentAmount - actual));
    notifyListeners();
    return actual;
  }

  static List<SavingsGoal> _seedGoals() {
    final now = DateTime.now();
    return [
      SavingsGoal(
        id: 'g1',
        name: 'Reserva de Emergência',
        icon: Icons.shield_outlined,
        targetAmount: 5000,
        currentAmount: 1820,
        createdAt: now.subtract(const Duration(days: 60)),
      ),
      SavingsGoal(
        id: 'g2',
        name: 'Viagem',
        icon: Icons.flight_takeoff,
        targetAmount: 2500,
        currentAmount: 640,
        createdAt: now.subtract(const Duration(days: 20)),
      ),
    ];
  }
}
