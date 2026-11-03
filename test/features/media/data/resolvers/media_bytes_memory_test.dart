import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/resolvers/media_bytes_memory.dart';

/// What a browser keeps of the media it fetched (issue #4121): a bounded
/// amount, the least recently used going first.
void main() {
  Uint8List sized(int n) => Uint8List(n);

  test('keeps within its budget, dropping the least recently used', () {
    final memory = MediaBytesMemory(budgetBytes: 30);
    memory.put('a', sized(10));
    memory.put('b', sized(10));
    memory.put('c', sized(10));
    expect(memory.get('a'), isNotNull); // a is now the most recent

    memory.put('d', sized(10));

    expect(memory.get('b'), isNull);
    expect(memory.get('a'), isNotNull);
    expect(memory.get('c'), isNotNull);
    expect(memory.get('d'), isNotNull);
    expect(memory.sizeBytes, 30);
  });

  test('an entry larger than the whole budget is not kept', () {
    final memory = MediaBytesMemory(budgetBytes: 30);
    memory.put('a', sized(10));
    memory.put('huge', sized(31));

    expect(memory.get('huge'), isNull);
    expect(memory.get('a'), isNotNull);
  });

  test('putting a key again replaces it and its size', () {
    final memory = MediaBytesMemory(budgetBytes: 30);
    memory.put('a', sized(10));
    memory.put('a', sized(20));

    expect(memory.get('a'), hasLength(20));
    expect(memory.sizeBytes, 20);
  });
}
