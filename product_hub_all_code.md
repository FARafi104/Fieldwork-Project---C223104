## pubspec.yaml

```yaml
name: product_hub
description: Flutter app consuming the DummyJSON REST API with CRUD, Hive cache, pagination and search.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  dio: ^5.4.3
  provider: ^6.1.2
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  cached_network_image: ^3.4.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true

```

## analysis_options.yaml

```yaml
include: package:flutter_lints/flutter.yaml

```

## lib/core/app_exception.dart

```dart
import 'dart:io';

import 'package:dio/dio.dart';

/// Friendly error shown in the UI.
class AppException implements Exception {
  AppException(this.message);
  final String message;

  factory AppException.fromDio(DioException e) {
    const offline =
        'No internet connection. Please check your network and try again.';
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppException(offline);
      case DioExceptionType.badResponse:
        return AppException(
            'Server error (${e.response?.statusCode}). Please try again later.');
      default:
        if (e.error is SocketException) return AppException(offline);
        return AppException('Something went wrong. Please try again.');
    }
  }

  @override
  String toString() => message;
}

```

## lib/core/constants.dart

```dart
class AppConstants {
  static const appName = 'Product Hub';
  static const baseUrl = 'https://dummyjson.com';
  static const pageSize = 20;
}

```

## lib/core/theme.dart

```dart
import 'package:flutter/material.dart';

class AppTheme {
  static const _seed = Color(0xFF4F46E5);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme:
          ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

```

## lib/data/datasource/local_datasource.dart

```dart
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../model/product.dart';

/// Hive-backed cache. Products are stored as JSON strings so no
/// code generation (build_runner) is needed.
class LocalDataSource {
  late final Box<String> _products;
  late final Box<bool> _deleted;
  late final Box _settings;

  Future<void> init() async {
    await Hive.initFlutter();
    _products = await Hive.openBox<String>('products');
    _deleted = await Hive.openBox<bool>('deleted_ids');
    _settings = await Hive.openBox('settings');
  }

  Product _decode(String s) =>
      Product.fromJson(jsonDecode(s) as Map<String, dynamic>);

  List<Product> getAll() => _products.values.map(_decode).toList();

  Product? get(int id) {
    final s = _products.get('$id');
    return s == null ? null : _decode(s);
  }

  Future<void> put(Product p) => _products.put('${p.id}', jsonEncode(p.toJson()));

  Future<void> putAll(List<Product> list) => _products.putAll({
        for (final p in list) '${p.id}': jsonEncode(p.toJson()),
      });

  /// Removes the product and remembers the id so refreshes don't bring it back.
  Future<void> delete(int id) async {
    await _products.delete('$id');
    await _deleted.put('$id', true);
  }

  bool isDeleted(int id) => _deleted.containsKey('$id');

  // ---- settings ----
  Set<int> get favorites =>
      (_settings.get('favorites', defaultValue: <int>[]) as List)
          .cast<int>()
          .toSet();

  Future<void> saveFavorites(Set<int> ids) =>
      _settings.put('favorites', ids.toList());

  bool get isDark => _settings.get('dark', defaultValue: false) as bool;

  Future<void> saveDark(bool value) => _settings.put('dark', value);
}

```

## lib/data/datasource/remote_datasource.dart

```dart
import 'package:dio/dio.dart';

import '../../core/constants.dart';
import '../model/product.dart';

/// Talks to https://dummyjson.com
class RemoteDataSource {
  RemoteDataSource({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConstants.baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ));

  final Dio _dio;

  Future<({List<Product> items, int total})> fetchProducts({
    required int skip,
    required int limit,
    String query = '',
  }) async {
    final res = await _dio.get(
      query.isEmpty ? '/products' : '/products/search',
      queryParameters: {
        'limit': limit,
        'skip': skip,
        if (query.isNotEmpty) 'q': query,
      },
    );
    final data = res.data as Map<String, dynamic>;
    final items = (data['products'] as List)
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
    return (items: items, total: (data['total'] as num).toInt());
  }

  Future<void> createProduct(Product p) =>
      _dio.post('/products/add', data: p.toApiBody());

  Future<void> updateProduct(Product p) =>
      _dio.put('/products/${p.id}', data: p.toApiBody());

  Future<void> deleteProduct(int id) => _dio.delete('/products/$id');
}

```

## lib/data/model/product.dart

```dart
class Product {
  const Product({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    this.discountPercentage = 0,
    this.rating = 0,
    this.stock = 0,
    this.brand = '',
    this.thumbnail = '',
    this.images = const [],
    this.tags = const [],
    this.sku = '',
    this.weight,
    this.warranty = '',
    this.shipping = '',
    this.availability = '',
    this.returnPolicy = '',
    this.reviews = const [],
    this.isLocal = false,
    this.isEdited = false,
  });

  final int id;
  final String title;
  final String description;
  final String category;
  final double price;
  final double discountPercentage;
  final double rating;
  final int stock;
  final String brand;
  final String thumbnail;
  final List<String> images;
  final List<String> tags;
  final String sku;
  final double? weight;
  final String warranty;
  final String shipping;
  final String availability;
  final String returnPolicy;
  final List<Map<String, dynamic>> reviews;

  /// Created in the app (does not exist on the server).
  final bool isLocal;

  /// Modified by the user; the local version wins over server data.
  final bool isEdited;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: (json['id'] as num).toInt(),
      title: (json['title'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      category: (json['category'] ?? '') as String,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      discountPercentage: (json['discountPercentage'] as num?)?.toDouble() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      brand: (json['brand'] ?? '') as String,
      thumbnail: (json['thumbnail'] ?? '') as String,
      images: List<String>.from(json['images'] as List? ?? const []),
      tags: List<String>.from(json['tags'] as List? ?? const []),
      sku: (json['sku'] ?? '') as String,
      weight: (json['weight'] as num?)?.toDouble(),
      warranty: (json['warrantyInformation'] ?? '') as String,
      shipping: (json['shippingInformation'] ?? '') as String,
      availability: (json['availabilityStatus'] ?? '') as String,
      returnPolicy: (json['returnPolicy'] ?? '') as String,
      reviews: (json['reviews'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      isLocal: json['isLocal'] as bool? ?? false,
      isEdited: json['isEdited'] as bool? ?? false,
    );
  }

  /// Used for the local cache (includes app-only flags).
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'price': price,
        'discountPercentage': discountPercentage,
        'rating': rating,
        'stock': stock,
        'brand': brand,
        'thumbnail': thumbnail,
        'images': images,
        'tags': tags,
        'sku': sku,
        'weight': weight,
        'warrantyInformation': warranty,
        'shippingInformation': shipping,
        'availabilityStatus': availability,
        'returnPolicy': returnPolicy,
        'reviews': reviews,
        'isLocal': isLocal,
        'isEdited': isEdited,
      };

  /// Body sent to the API for create / update.
  Map<String, dynamic> toApiBody() => {
        'title': title,
        'description': description,
        'category': category,
        'brand': brand,
        'price': price,
        'stock': stock,
        'thumbnail': thumbnail,
      };

  Product copyWith({
    String? title,
    String? description,
    String? category,
    String? brand,
    double? price,
    int? stock,
    String? thumbnail,
    List<String>? images,
    bool? isEdited,
  }) {
    return Product(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      discountPercentage: discountPercentage,
      rating: rating,
      stock: stock ?? this.stock,
      brand: brand ?? this.brand,
      thumbnail: thumbnail ?? this.thumbnail,
      images: images ?? this.images,
      tags: tags,
      sku: sku,
      weight: weight,
      warranty: warranty,
      shipping: shipping,
      availability: availability,
      returnPolicy: returnPolicy,
      reviews: reviews,
      isLocal: isLocal,
      isEdited: isEdited ?? this.isEdited,
    );
  }

  List<String> get allImages => images.isNotEmpty
      ? images
      : (thumbnail.isNotEmpty ? [thumbnail] : const []);

  double get discountedPrice => price * (1 - discountPercentage / 100);
}

```

## lib/data/model/product_page.dart

```dart
import 'product.dart';

/// One page of results returned by the repository.
class ProductPage {
  const ProductPage({
    required this.items,
    required this.nextSkip,
    required this.hasMore,
    required this.fromCache,
  });

  final List<Product> items;
  final int nextSkip;
  final bool hasMore;
  final bool fromCache;
}

```

## lib/data/repository/product_repository.dart

```dart
import 'package:dio/dio.dart';

import '../../core/app_exception.dart';
import '../datasource/local_datasource.dart';
import '../datasource/remote_datasource.dart';
import '../model/product.dart';
import '../model/product_page.dart';

/// Single source of truth for the UI.
///
/// Online  -> fetch from API, merge with local edits, refresh the cache.
/// Offline -> serve (and paginate / search) the cached data locally.
///
/// DummyJSON accepts POST/PUT/DELETE but only *simulates* them (nothing is
/// stored server-side), so the local cache is the real store for CRUD.
class ProductRepository {
  ProductRepository({
    required RemoteDataSource remote,
    required LocalDataSource local,
  })  : _remote = remote,
        _local = local;

  final RemoteDataSource _remote;
  final LocalDataSource _local;

  Set<int> get favorites => _local.favorites;
  Future<void> saveFavorites(Set<int> ids) => _local.saveFavorites(ids);

  Future<ProductPage> getProducts({
    required int skip,
    required int limit,
    String query = '',
  }) async {
    try {
      final remote =
          await _remote.fetchProducts(skip: skip, limit: limit, query: query);

      final merged = <Product>[];
      final toCache = <Product>[];
      for (final p in remote.items) {
        if (_local.isDeleted(p.id)) continue;
        final cached = _local.get(p.id);
        if (cached != null && cached.isEdited) {
          merged.add(cached); // keep the user's edits
        } else {
          merged.add(p);
          toCache.add(p);
        }
      }
      await _local.putAll(toCache);

      var items = merged;
      if (skip == 0) {
        final locals = _local
            .getAll()
            .where((p) => p.isLocal && _matches(p, query))
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
        items = [...locals, ...merged];
      }

      final nextSkip = skip + remote.items.length;
      return ProductPage(
        items: items,
        nextSkip: nextSkip,
        hasMore: nextSkip < remote.total,
        fromCache: false,
      );
    } catch (e) {
      // Offline / API failure -> fall back to cache.
      final all = _local.getAll();
      if (all.isEmpty) {
        throw e is DioException
            ? AppException.fromDio(e)
            : AppException('Unexpected response from the server.');
      }
      final cached = all.where((p) => _matches(p, query)).toList()
        ..sort((a, b) => a.id.compareTo(b.id)); // local (negative ids) first
      final page = cached.skip(skip).take(limit).toList(); // local pagination
      final nextSkip = skip + page.length;
      return ProductPage(
        items: page,
        nextSkip: nextSkip,
        hasMore: nextSkip < cached.length,
        fromCache: true,
      );
    }
  }

  Future<void> create(Product p) async {
    try {
      await _remote.createProduct(p);
    } on DioException catch (_) {
      // Offline: the local copy below is enough.
    }
    await _local.put(p);
  }

  Future<void> update(Product p) async {
    if (!p.isLocal) {
      try {
        await _remote.updateProduct(p);
      } on DioException catch (_) {}
    }
    await _local.put(p);
  }

  Future<void> delete(Product p) async {
    if (!p.isLocal) {
      try {
        await _remote.deleteProduct(p.id);
      } on DioException catch (_) {}
    }
    await _local.delete(p.id);
  }

  bool _matches(Product p, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return p.title.toLowerCase().contains(q) ||
        p.description.toLowerCase().contains(q) ||
        p.category.toLowerCase().contains(q) ||
        p.brand.toLowerCase().contains(q);
  }
}

```

## lib/main.dart

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'data/datasource/local_datasource.dart';
import 'data/datasource/remote_datasource.dart';
import 'data/repository/product_repository.dart';
import 'presentation/screens/splash_screen.dart';
import 'providers/product_provider.dart';
import 'providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Dependency injection: build the object graph once, pass it down.
  final local = LocalDataSource();
  await local.init();
  final repository = ProductRepository(remote: RemoteDataSource(), local: local);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(local)),
        ChangeNotifierProvider(create: (_) => ProductProvider(repository)),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: theme.mode,
      home: const SplashScreen(),
    );
  }
}

```

## lib/presentation/screens/detail_screen.dart

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/model/product.dart';
import '../../providers/product_provider.dart';
import '../widgets/product_image.dart';
import 'product_form_screen.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.product});

  final Product product;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Product _product = widget.product;

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<Product>(
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: _product)),
    );
    if (updated != null && mounted) setState(() => _product = updated);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('"${_product.title}" will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await context.read<ProductProvider>().deleteProduct(_product);
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Product deleted')));
  }

  @override
  Widget build(BuildContext context) {
    final p = _product;
    final provider = context.watch<ProductProvider>();
    final isFav = provider.isFavorite(p.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Favorite',
            onPressed: () => provider.toggleFavorite(p.id),
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav ? Colors.redAccent : null),
          ),
          IconButton(
              tooltip: 'Edit', onPressed: _edit, icon: const Icon(Icons.edit)),
          IconButton(
              tooltip: 'Delete',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: LayoutBuilder(builder: (context, box) {
        final gallery = _Gallery(images: p.allImages);
        final info = _Info(product: p);
        if (box.maxWidth >= 700) {
          // Tablet: gallery and details side by side.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16), child: gallery),
              ),
              Expanded(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16), child: info),
              ),
            ],
          );
        }
        return SingleChildScrollView(
          child: Column(
            children: [
              Padding(padding: const EdgeInsets.all(12), child: gallery),
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  child: info),
            ],
          ),
        );
      }),
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.images});

  final List<String> images;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.15,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: widget.images.isEmpty
                ? const ProductImage(url: '')
                : PageView.builder(
                    itemCount: widget.images.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (_, i) => ProductImage(
                        url: widget.images[i], fit: BoxFit.contain),
                  ),
          ),
        ),
        if (widget.images.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.images.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 18 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index ? scheme.primary : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = product;
    final rows = <(String, String)>[
      ('Stock', '${p.stock}'),
      if (p.sku.isNotEmpty) ('SKU', p.sku),
      if (p.weight != null) ('Weight', '${p.weight}'),
      if (p.availability.isNotEmpty) ('Availability', p.availability),
      if (p.warranty.isNotEmpty) ('Warranty', p.warranty),
      if (p.shipping.isNotEmpty) ('Shipping', p.shipping),
      if (p.returnPolicy.isNotEmpty) ('Returns', p.returnPolicy),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(p.title,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('\$${p.discountedPrice.toStringAsFixed(2)}',
                style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold)),
            if (p.discountPercentage > 0) ...[
              const SizedBox(width: 10),
              Text('\$${p.price.toStringAsFixed(2)}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(decoration: TextDecoration.lineThrough)),
              const SizedBox(width: 10),
              Chip(
                label: Text('-${p.discountPercentage.toStringAsFixed(0)}%'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.star_rounded, color: Colors.amber),
          const SizedBox(width: 4),
          Text(p.rating.toStringAsFixed(1), style: theme.textTheme.titleMedium),
          if (p.isLocal) ...[
            const SizedBox(width: 12),
            const Chip(
              avatar: Icon(Icons.phone_android, size: 16),
              label: Text('Added on this device'),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (p.category.isNotEmpty) Chip(label: Text(p.category)),
            if (p.brand.isNotEmpty) Chip(label: Text(p.brand)),
            for (final t in p.tags) Chip(label: Text('#$t')),
          ],
        ),
        const SizedBox(height: 12),
        Text('Description', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(p.description),
        const SizedBox(height: 16),
        Text('Details', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                    width: 110,
                    child: Text(r.$1,
                        style: TextStyle(color: theme.colorScheme.outline))),
                Expanded(child: Text(r.$2)),
              ],
            ),
          ),
        if (p.reviews.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Reviews (${p.reviews.length})',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final r in p.reviews)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text('${r['reviewerName'] ?? 'Anonymous'}'),
                subtitle: Text('${r['comment'] ?? ''}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 18, color: Colors.amber),
                    Text('${r['rating'] ?? ''}'),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

```

## lib/presentation/screens/home_screen.dart

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../data/model/product.dart';
import '../../providers/product_provider.dart';
import '../../providers/theme_provider.dart';
import '../widgets/product_card.dart';
import '../widgets/state_views.dart';
import 'detail_screen.dart';
import 'product_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // Infinite scrolling: load the next page near the bottom.
  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      context.read<ProductProvider>().loadMore();
    }
  }

  void _openDetail(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailScreen(product: product)),
    );
  }

  void _openForm() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProductFormScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ProductProvider>();
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            tooltip: 'Favorites only',
            onPressed: p.toggleFavoritesOnly,
            icon: Icon(p.favoritesOnly ? Icons.favorite : Icons.favorite_border),
          ),
          PopupMenuButton<SortOption>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            onSelected: p.setSort,
            itemBuilder: (_) => [
              for (final o in SortOption.values)
                CheckedPopupMenuItem(
                  value: o,
                  checked: p.sort == o,
                  child: Text(o.label),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Toggle dark mode',
            onPressed: theme.toggle,
            icon: Icon(theme.isDark ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onChanged: (v) {
                setState(() {});
                p.onQueryChanged(v);
              },
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                          p.onQueryChanged('');
                        },
                      ),
              ),
            ),
          ),
          if (p.fromCache) const _OfflineBanner(),
          Expanded(child: _buildBody(p)),
        ],
      ),
    );
  }

  Widget _buildBody(ProductProvider p) {
    switch (p.status) {
      case LoadStatus.loading:
        return const LoadingView();
      case LoadStatus.error:
        return ErrorView(
          message: p.error ?? 'Something went wrong.',
          onRetry: () => p.loadInitial(),
        );
      case LoadStatus.loaded:
        final items = p.visibleItems;
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: p.refresh,
            child: EmptyView(
              title: p.favoritesOnly ? 'No favorites yet' : 'No products found',
              message: p.favoritesOnly
                  ? 'Tap the heart on a product to save it here.'
                  : (p.query.isEmpty
                      ? 'Pull down to refresh or add a new product.'
                      : 'Nothing matches "${p.query}". Try another search.'),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: p.refresh,
          child: LayoutBuilder(builder: (context, box) {
            // Responsive: 1 column on phones, 2-3 on tablets.
            final cols = box.maxWidth >= 900 ? 3 : (box.maxWidth >= 600 ? 2 : 1);
            return CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisExtent: ProductCard.height,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final item = items[i];
                        return ProductCard(
                          product: item,
                          isFavorite: p.isFavorite(item.id),
                          onTap: () => _openDetail(item),
                          onFavorite: () => p.toggleFavorite(item.id),
                        );
                      },
                      childCount: items.length,
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _Footer(provider: p)),
              ],
            );
          }),
        );
    }
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.provider});

  final ProductProvider provider;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (provider.isLoadingMore) {
      child = const Center(child: CircularProgressIndicator());
    } else if (provider.loadMoreError) {
      child = Center(
        child: TextButton.icon(
          onPressed: provider.loadMore,
          icon: const Icon(Icons.refresh),
          label: const Text("Couldn't load more. Tap to retry"),
        ),
      );
    } else if (provider.hasMore) {
      child = Center(
        child: OutlinedButton(
          onPressed: provider.loadMore,
          child: const Text('Load more'),
        ),
      );
    } else {
      child = Center(
        child: Text("You've reached the end",
            style: Theme.of(context).textTheme.bodySmall),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 96),
      child: child,
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.wifi_off, size: 16, color: scheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline mode - showing saved data',
              style: TextStyle(color: scheme.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

```

## lib/presentation/screens/product_form_screen.dart

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/model/product.dart';
import '../../providers/product_provider.dart';

/// Used for both "Add" (product == null) and "Edit".
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Product? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.product?.title);
  late final _description =
      TextEditingController(text: widget.product?.description);
  late final _brand = TextEditingController(text: widget.product?.brand);
  late final _category = TextEditingController(text: widget.product?.category);
  late final _price =
      TextEditingController(text: widget.product?.price.toString());
  late final _stock =
      TextEditingController(text: widget.product?.stock.toString());
  late final _image = TextEditingController(text: widget.product?.thumbnail);
  bool _saving = false;

  bool get _isEdit => widget.product != null;

  @override
  void dispose() {
    for (final c in [_title, _description, _brand, _category, _price, _stock, _image]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'This field is required' : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final provider = context.read<ProductProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final img = _image.text.trim();
    final price = double.parse(_price.text.trim());
    final stock = int.parse(_stock.text.trim());

    final Product result;
    if (_isEdit) {
      final old = widget.product!;
      result = old.copyWith(
        title: _title.text.trim(),
        description: _description.text.trim(),
        brand: _brand.text.trim(),
        category: _category.text.trim(),
        price: price,
        stock: stock,
        thumbnail: img,
        images: img == old.thumbnail
            ? old.images
            : (img.isEmpty ? <String>[] : [img]),
        isEdited: true,
      );
      await provider.updateProduct(result);
    } else {
      result = Product(
        id: -DateTime.now().millisecondsSinceEpoch, // negative = local item
        title: _title.text.trim(),
        description: _description.text.trim(),
        brand: _brand.text.trim(),
        category: _category.text.trim(),
        price: price,
        stock: stock,
        thumbnail: img,
        images: img.isEmpty ? const [] : [img],
        isLocal: true,
      );
      await provider.addProduct(result);
    }

    messenger.showSnackBar(
      SnackBar(content: Text(_isEdit ? 'Product updated' : 'Product added')),
    );
    navigator.pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit product' : 'Add product')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Title'),
                  textInputAction: TextInputAction.next,
                  validator: _required,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                  validator: _required,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _brand,
                        decoration: const InputDecoration(labelText: 'Brand'),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _category,
                        decoration: const InputDecoration(labelText: 'Category'),
                        textInputAction: TextInputAction.next,
                        validator: _required,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _price,
                        decoration:
                            const InputDecoration(labelText: 'Price (\$)'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) {
                          final n = double.tryParse(v?.trim() ?? '');
                          return (n == null || n < 0) ? 'Enter a valid price' : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _stock,
                        decoration: const InputDecoration(labelText: 'Stock'),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          return (n == null || n < 0) ? 'Enter a valid number' : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _image,
                  decoration: const InputDecoration(
                      labelText: 'Image URL (optional)'),
                  keyboardType: TextInputType.url,
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    return (s.isNotEmpty && !s.startsWith('http'))
                        ? 'Must start with http:// or https://'
                        : null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_isEdit ? 'Save changes' : 'Add product'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

```

## lib/presentation/screens/splash_screen.dart

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.primary,
      body: Center(
        child: FadeTransition(
          opacity: _controller,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: scheme.onPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.shopping_bag_rounded,
                      size: 60, color: scheme.primary),
                ),
                const SizedBox(height: 20),
                Text(
                  AppConstants.appName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: scheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

```

## lib/presentation/widgets/product_card.dart

```dart
import 'package:flutter/material.dart';

import '../../data/model/product.dart';
import 'product_image.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
  });

  static const double height = 140;

  final Product product;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = [
      if (product.brand.isNotEmpty) product.brand,
      if (product.category.isNotEmpty) product.category,
    ].join(' • ');

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              SizedBox(
                width: 110,
                height: height,
                child: ProductImage(url: product.thumbnail),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (product.isLocal || product.isEdited)
                            Padding(
                              padding: const EdgeInsets.only(left: 4, right: 8),
                              child: Icon(
                                product.isLocal
                                    ? Icons.phone_android
                                    : Icons.edit_note,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.primary),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        product.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Text(
                            '\$${product.price.toStringAsFixed(2)}',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.star_rounded,
                              size: 16, color: Colors.amber),
                          Text(product.rating.toStringAsFixed(1),
                              style: theme.textTheme.bodySmall),
                          const Spacer(),
                          IconButton(
                            onPressed: onFavorite,
                            visualDensity: VisualDensity.compact,
                            iconSize: 20,
                            icon: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isFavorite ? Colors.redAccent : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

```

## lib/presentation/widgets/product_image.dart

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.url, this.fit = BoxFit.cover});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.secondaryContainer;
    final placeholder = Container(
      color: bg,
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, size: 32),
    );
    if (url.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: (_, __) => Container(
        color: bg,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        color: bg,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined, size: 32),
      ),
    );
  }
}

```

## lib/presentation/widgets/state_views.dart

```dart
import 'package:flutter/material.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 72, color: scheme.error),
            const SizedBox(height: 16),
            Text('Oops!', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scrollable so pull-to-refresh still works on an empty list.
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 100),
        Icon(Icons.inventory_2_outlined,
            size: 72, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 16),
        Text(title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
      ],
    );
  }
}

```

## lib/providers/product_provider.dart

```dart
import 'package:flutter/foundation.dart';

import '../core/app_exception.dart';
import '../core/constants.dart';
import '../data/model/product.dart';
import '../data/repository/product_repository.dart';
import '../services/debouncer.dart';

enum LoadStatus { loading, loaded, error }

enum SortOption {
  none('Default'),
  priceLow('Price: low to high'),
  priceHigh('Price: high to low'),
  rating('Top rated'),
  titleAz('Title: A to Z');

  const SortOption(this.label);
  final String label;
}

class ProductProvider extends ChangeNotifier {
  ProductProvider(this._repo) : _favorites = _repo.favorites {
    loadInitial();
  }

  final ProductRepository _repo;
  final _debouncer = Debouncer(const Duration(milliseconds: 500));

  List<Product> _items = [];
  Set<int> _favorites;
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  String _query = '';
  SortOption _sort = SortOption.none;
  bool _favoritesOnly = false;

  int _nextSkip = 0;
  bool _hasMore = false;
  bool _isLoadingMore = false;
  bool _loadMoreError = false;
  bool _fromCache = false;
  int _requestId = 0; // ignores stale responses (fast typing)

  // ---- getters ----
  LoadStatus get status => _status;
  String? get error => _error;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  bool get loadMoreError => _loadMoreError;
  bool get fromCache => _fromCache;
  SortOption get sort => _sort;
  bool get favoritesOnly => _favoritesOnly;
  String get query => _query;

  bool isFavorite(int id) => _favorites.contains(id);

  /// Items after applying the favorites filter and sorting.
  List<Product> get visibleItems {
    final list = _favoritesOnly
        ? _items.where((p) => _favorites.contains(p.id)).toList()
        : List<Product>.of(_items);
    switch (_sort) {
      case SortOption.priceLow:
        list.sort((a, b) => a.price.compareTo(b.price));
      case SortOption.priceHigh:
        list.sort((a, b) => b.price.compareTo(a.price));
      case SortOption.rating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case SortOption.titleAz:
        list.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case SortOption.none:
        break;
    }
    return list;
  }

  // ---- loading ----
  Future<void> loadInitial({bool silent = false}) async {
    final id = ++_requestId;
    if (!silent) {
      _status = LoadStatus.loading;
      notifyListeners();
    }
    try {
      final page = await _repo.getProducts(
        skip: 0,
        limit: AppConstants.pageSize,
        query: _query,
      );
      if (id != _requestId) return;
      _items = page.items;
      _nextSkip = page.nextSkip;
      _hasMore = page.hasMore;
      _fromCache = page.fromCache;
      _status = LoadStatus.loaded;
      _error = null;
    } on AppException catch (e) {
      if (id != _requestId) return;
      _status = LoadStatus.error;
      _error = e.message;
    } catch (_) {
      if (id != _requestId) return;
      _status = LoadStatus.error;
      _error = 'Something went wrong. Please try again.';
    }
    _isLoadingMore = false;
    _loadMoreError = false;
    notifyListeners();
  }

  /// Pull-to-refresh.
  Future<void> refresh() => loadInitial(silent: true);

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _status != LoadStatus.loaded) return;
    final id = _requestId;
    _isLoadingMore = true;
    _loadMoreError = false;
    notifyListeners();
    try {
      final page = await _repo.getProducts(
        skip: _nextSkip,
        limit: AppConstants.pageSize,
        query: _query,
      );
      if (id != _requestId) return;
      final existing = _items.map((p) => p.id).toSet();
      _items = [..._items, ...page.items.where((p) => !existing.contains(p.id))];
      _nextSkip = page.nextSkip;
      _hasMore = page.hasMore;
      _fromCache = page.fromCache;
    } catch (_) {
      if (id == _requestId) _loadMoreError = true;
    }
    if (id == _requestId) {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // ---- search / sort / filter ----
  void onQueryChanged(String value) {
    _debouncer.run(() {
      final q = value.trim();
      if (q == _query) return;
      _query = q;
      loadInitial();
    });
  }

  void setSort(SortOption option) {
    _sort = option;
    notifyListeners();
  }

  void toggleFavoritesOnly() {
    _favoritesOnly = !_favoritesOnly;
    notifyListeners();
  }

  Future<void> toggleFavorite(int id) async {
    _favorites = {..._favorites};
    if (!_favorites.remove(id)) _favorites.add(id);
    notifyListeners();
    await _repo.saveFavorites(_favorites);
  }

  // ---- CRUD ----
  Future<void> addProduct(Product p) async {
    await _repo.create(p);
    _items = [p, ..._items];
    notifyListeners();
  }

  Future<void> updateProduct(Product p) async {
    await _repo.update(p);
    _items = [for (final i in _items) i.id == p.id ? p : i];
    notifyListeners();
  }

  Future<void> deleteProduct(Product p) async {
    await _repo.delete(p);
    _items = _items.where((i) => i.id != p.id).toList();
    _favorites = {..._favorites}..remove(p.id);
    notifyListeners();
    await _repo.saveFavorites(_favorites);
  }

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }
}

```

## lib/providers/theme_provider.dart

```dart
import 'package:flutter/material.dart';

import '../data/datasource/local_datasource.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider(this._local) : _isDark = _local.isDark;

  final LocalDataSource _local;
  bool _isDark;

  bool get isDark => _isDark;
  ThemeMode get mode => _isDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> toggle() async {
    _isDark = !_isDark;
    notifyListeners();
    await _local.saveDark(_isDark);
  }
}

```

## lib/services/debouncer.dart

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

/// Delays an action until the user stops typing.
class Debouncer {
  Debouncer(this.delay);

  final Duration delay;
  Timer? _timer;

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() => _timer?.cancel();
}

```

## test/widget_test.dart

```dart
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

```

## README.md

```markdown
# Product Hub

A Flutter app that consumes the public **DummyJSON Products API** with full CRUD, offline Hive cache, pagination, search and a clean, responsive UI.

## API used

**DummyJSON** – <https://dummyjson.com/docs/products> (listed in the public-apis repository)

| Action | Endpoint |
|---|---|
| List + pagination | `GET /products?limit=20&skip=0` |
| Search | `GET /products/search?q=phone&limit=20&skip=0` |
| Create | `POST /products/add` |
| Update | `PUT /products/{id}` |
| Delete | `DELETE /products/{id}` |

> DummyJSON *simulates* writes (responds 200 but doesn't store anything). The app therefore sends the real request **and** saves the change in the local Hive cache, which is the persistent store for CRUD.

## Features

- Splash screen with animated logo, auto-navigates to Home
- Product list: image, title, subtitle (brand • category), short description, price, rating
- Search with **debounce** (500 ms) – server-side when online, local when offline
- Detail screen: image gallery, price/discount, tags, extra fields, reviews
- **CRUD**: add, edit, delete (API call + local persistence, validated form)
- **Local cache (Hive)**: open the app without internet and see previously fetched data
- **Pagination**: infinite scroll + "Load more" button (simulated locally when offline)
- Error handling: no internet, API failure, empty state, loading state, retry buttons
- Pull to refresh
- Responsive: 1 column on phones, 2–3 columns / split detail view on tablets
- Bonus: dark mode (persisted), favorites (persisted), sorting, favorites filter, debounced search, offline mode banner, repository pattern, dependency injection

## Packages used

| Package | Purpose |
|---|---|
| `dio` | HTTP client |
| `provider` | State management (`ChangeNotifier`) |
| `hive` / `hive_flutter` | Local cache & settings |
| `cached_network_image` | Image loading + disk cache |

## Architecture

```
lib/
├── core/            constants, theme, AppException
├── data/
│   ├── model/       Product, ProductPage
│   ├── datasource/  RemoteDataSource (Dio), LocalDataSource (Hive)
│   └── repository/  ProductRepository (API <-> cache logic)
├── presentation/
│   ├── screens/     splash, home, detail, product form
│   └── widgets/     product card, image, loading/error/empty views
├── providers/       ProductProvider, ThemeProvider
├── services/        Debouncer
└── main.dart        dependency wiring
```

**Data flow:** UI → Provider → Repository → (Remote API | Hive cache)

## Screenshots

| Splash | Home | Detail | Add / Edit | Dark mode | Tablet |
|---|---|---|---|---|---|
| _add_ | _add_ | _add_ | _add_ | _add_ | _add_ |

(Put images in `screenshots/` and link them here.)

## How to run

```bash
# 1. Generate the platform folders (android/, ios/ ...) once
flutter create --project-name product_hub .

# 2. Android: allow internet in release builds
#    add to android/app/src/main/AndroidManifest.xml, above <application>:
#    <uses-permission android:name="android.permission.INTERNET"/>

# 3. Install and run
flutter pub get
flutter run

# 4. Build the APK
flutter build apk --release
# -> build/app/outputs/flutter-apk/app-release.apk
```

## Testing offline mode

1. Run the app online and scroll a few pages.
2. Turn on airplane mode and restart the app – the cached data appears with an "Offline mode" banner.

```

