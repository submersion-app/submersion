import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/features/settings/presentation/widgets/s3_server_fields.dart';

void main() {
  test('a self-hosted endpoint turns path-style addressing on', () {
    final form = S3FormController();
    addTearDown(form.dispose);
    form.endpoint.text = 'https://minio.example.com';
    expect(form.pathStyle, isTrue);
    form.endpoint.text = 'https://s3.eu-west-1.amazonaws.com';
    expect(form.pathStyle, isFalse);
  });

  test('a manual path-style choice stops tracking the endpoint', () {
    final form = S3FormController();
    addTearDown(form.dispose);
    form.setPathStyle(true);
    form.endpoint.text = 'https://s3.eu-west-1.amazonaws.com';
    expect(form.pathStyle, isTrue);
  });

  test('build derives the region from the endpoint when left blank', () {
    final form = S3FormController();
    addTearDown(form.dispose);
    form.endpoint.text = 'https://s3.eu-west-1.amazonaws.com';
    form.bucket.text = 'b';
    form.accessKey.text = 'k';
    form.secretKey.text = 's';
    final config = form.build();
    expect(config.region, 'eu-west-1');
    expect(config.prefix, 'submersion-sync/');
  });

  test('load fills the fields and keeps the stored addressing', () {
    final form = S3FormController();
    addTearDown(form.dispose);
    form.load(
      S3Config(
        endpoint: 'https://minio.example.com',
        bucket: 'b',
        prefix: 'p/',
        pathStyle: false,
        accessKeyId: 'k',
        secretAccessKey: 's',
      ),
    );
    expect(form.bucket.text, 'b');
    expect(form.prefix.text, 'p/');
    expect(form.pathStyle, isFalse, reason: 'a stored choice never flips');
  });
}
