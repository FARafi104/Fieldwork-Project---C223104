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
