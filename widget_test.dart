import 'package:flutter_test/flutter_test.dart';
import 'package:product_hub/data/model/product.dart';

void main() {
  test('Product parses API JSON and survives a cache round trip', () {
    final p = Product.fromJson({
      'id': 1,
      'title': 'Phone',
      'description': 'A phone',
      'category': 'smartphones',
      'price': 100,
      'discountPercentage': 10,
    });
    expect(p.price, 100.0);
    expect(p.discountedPrice, 90.0);

    final copy = Product.fromJson(p.toJson());
    expect(copy.title, 'Phone');
    expect(copy.isLocal, false);
  });
}
