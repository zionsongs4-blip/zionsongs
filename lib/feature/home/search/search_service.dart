import 'package:isar/isar.dart';

import '../hymn/app_initializer.dart';
import 'home_search_controller.dart';
import 'home_search_repository.dart';

class SearchService {
  SearchService._();

  static final SearchService instance = SearchService._();

  HomeSearchController? _controller;

  HomeSearchController get controller {
    _controller ??= HomeSearchController(
      repository: HomeSearchRepository(isar: AppInitializer.isar),
    );
    return _controller!;
  }
}
