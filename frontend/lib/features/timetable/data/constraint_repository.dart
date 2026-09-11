/// Constraint repository and model for the timetable solver.

class ConstraintModel {
  final String id;
  final String type;
  final String description;
  final bool isActive;

  ConstraintModel({
    required this.id,
    required this.type,
    required this.description,
    this.isActive = true,
  });

  factory ConstraintModel.fromJson(Map<String, dynamic> json) => ConstraintModel(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? '',
        description: json['description'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? true,
      );
}

class ConstraintRepository {
  Future<List<ConstraintModel>> fetchConstraints() async => [];
}
