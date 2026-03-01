part of 'app_state.dart';
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

// ─── Poll System ────────────────────────────────────────────────────────────

extension PollsExtension on PigioAppState {
  // ── Queries ──────────────────────────────────────────────────────────────

  List<GroupPoll> getPollsForGroup(String groupId) =>
      _polls.where((p) => p.groupId == groupId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<GroupPoll> getActivePollsForGroup(String groupId) =>
      _polls.where((p) => p.groupId == groupId && p.isActive).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // ── CRUD ─────────────────────────────────────────────────────────────────

  void createPoll({
    required String groupId,
    required String question,
    required List<String> options,
  }) {
    if (options.length < 2 || options.length > 4) return;
    _polls.add(GroupPoll(
      id: _newId(),
      groupId: groupId,
      question: question,
      options: options,
      createdBy: 'self',
    ));
    notifyListeners();
    _saveData();
    logActivity('Sondage créé : $question', '📊');
  }

  void voteOnPoll(String pollId, int optionIndex, {String voterId = 'self'}) {
    final idx = _polls.indexWhere((p) => p.id == pollId);
    if (idx < 0) return;
    final poll = _polls[idx];
    if (!poll.isActive) return;

    final newVotes = Map<int, List<String>>.from(
      poll.votes.map((k, v) => MapEntry(k, List<String>.from(v))),
    );
    for (final entry in newVotes.values) {
      entry.remove(voterId);
    }
    newVotes.putIfAbsent(optionIndex, () => []);
    newVotes[optionIndex]!.add(voterId);

    _polls[idx] = GroupPoll(
      id: poll.id,
      groupId: poll.groupId,
      question: poll.question,
      options: poll.options,
      votes: newVotes,
      createdAt: poll.createdAt,
      createdBy: poll.createdBy,
      isActive: poll.isActive,
    );
    notifyListeners();
    _saveData();
  }

  void unvoteOnPoll(String pollId, {String voterId = 'self'}) {
    final idx = _polls.indexWhere((p) => p.id == pollId);
    if (idx < 0) return;
    final poll = _polls[idx];
    if (!poll.isActive) return;

    final newVotes = Map<int, List<String>>.from(
      poll.votes.map((k, v) => MapEntry(k, List<String>.from(v))),
    );
    for (final entry in newVotes.values) {
      entry.remove(voterId);
    }

    _polls[idx] = GroupPoll(
      id: poll.id,
      groupId: poll.groupId,
      question: poll.question,
      options: poll.options,
      votes: newVotes,
      createdAt: poll.createdAt,
      createdBy: poll.createdBy,
      isActive: poll.isActive,
    );
    notifyListeners();
    _saveData();
  }

  void closePoll(String pollId) {
    final idx = _polls.indexWhere((p) => p.id == pollId);
    if (idx < 0) return;
    final poll = _polls[idx];
    _polls[idx] = GroupPoll(
      id: poll.id,
      groupId: poll.groupId,
      question: poll.question,
      options: poll.options,
      votes: poll.votes,
      createdAt: poll.createdAt,
      createdBy: poll.createdBy,
      isActive: false,
    );
    notifyListeners();
    _saveData();
    logActivity('Sondage fermé : ${poll.question}', '📊');
  }

  void deletePoll(String pollId) {
    _polls.removeWhere((p) => p.id == pollId);
    notifyListeners();
    _saveData();
  }
}
