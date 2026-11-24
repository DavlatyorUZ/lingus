/// A retry keeps the question active and cannot score twice.
class RecallRound {
  final int answer;
  final List<int> options;
  final Set<int> missed = {};
  bool solved = false;
  RecallRound(this.answer, List<int> choices)
    : options = List.unmodifiable(choices) {
    if (options.toSet().length != options.length || !options.contains(answer)) {
      throw ArgumentError('Unique options must contain the answer.');
    }
  }
  bool get perfect => missed.isEmpty;
  bool? choose(int id) {
    if (solved || !options.contains(id) || missed.contains(id)) return null;
    if (id == answer) {
      solved = true;
      return true;
    }
    missed.add(id);
    return false;
  }
}
