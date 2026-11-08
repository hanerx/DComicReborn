/// A scanlation group's upstream identity, independent of its display name.
class ScanlationGroup {
  final String id;
  final String name;

  const ScanlationGroup(this.id, this.name);

  factory ScanlationGroup.fromJson(Map<String, dynamic> json) =>
      ScanlationGroup(json['id'] as String, json['name'] as String);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
