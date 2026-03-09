void main() {
  final m = {'a': 1};
  final m1 = Map.unmodifiable(m);
  m['a'] = 2;
  print(m1['a']);
}
