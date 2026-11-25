# easy_split_getx example

Two runnable entry points sharing `lib/pages.dart`:

```bash
flutter run                          # classic GetX: GetMaterialApp + onGenerateRoute
flutter run -t lib/main_router.dart  # Navigator 2.0: GetMaterialApp.router + getPages
flutter test
```

- Classic pages use `Get.toNamed` / `Get.offNamed` / `Get.parameters`.
- Navigator 2.0 pages go through `Get.rootDelegate` (see `DemoNav` in `lib/pages.dart`).
- `/home` is the left pane (`EasySplitScope`); `/detail/:index`, `/secondary` and `/dialogs` are
  `EasySplitGetPage`s that open in the right pane; `/fullscreen` stays full screen at any width.
