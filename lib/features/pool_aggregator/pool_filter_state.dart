enum FileCategory {
  all,
  images,
  videos,
  audio,
  documents,
  archives,
  folders;

  String get label {
    switch (this) {
      case FileCategory.all:
        return 'All';
      case FileCategory.images:
        return 'Images';
      case FileCategory.videos:
        return 'Videos';
      case FileCategory.audio:
        return 'Audio';
      case FileCategory.documents:
        return 'Documents';
      case FileCategory.archives:
        return 'Archives';
      case FileCategory.folders:
        return 'Folders';
    }
  }
}

class PoolFilterState {
  final String? selectedDeviceId; // null = Unified Pool
  final FileCategory category;
  final String searchQuery;
  final String? currentFolder; // for drilling into subfolders
  final bool isGridView;

  const PoolFilterState({
    this.selectedDeviceId,
    this.category = FileCategory.all,
    this.searchQuery = '',
    this.currentFolder,
    this.isGridView = true,
  });

  PoolFilterState copyWith({
    String? selectedDeviceId,
    bool clearDevice = false,
    FileCategory? category,
    String? searchQuery,
    String? currentFolder,
    bool clearFolder = false,
    bool? isGridView,
  }) {
    return PoolFilterState(
      selectedDeviceId: clearDevice ? null : (selectedDeviceId ?? this.selectedDeviceId),
      category: category ?? this.category,
      searchQuery: searchQuery ?? this.searchQuery,
      currentFolder: clearFolder ? null : (currentFolder ?? this.currentFolder),
      isGridView: isGridView ?? this.isGridView,
    );
  }
}
