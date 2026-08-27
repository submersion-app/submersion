import '../../../helpers/in_memory_media_object_store.dart';
import 'media_object_store_contract.dart';

void main() {
  runMediaObjectStoreContract(
    'InMemoryMediaObjectStore',
    () async => InMemoryMediaObjectStore(),
  );
}
