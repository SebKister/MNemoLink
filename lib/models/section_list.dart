import 'section.dart';

/// Manages a collection of survey sections
class SectionList {
  List<Section> sections;

  /// Default constructor
  SectionList({List<Section>? sections}) : sections = sections ?? <Section>[];

  /// Add a section to the list
  void add(Section section) => sections.add(section);

  /// Remove a section from the list
  bool remove(Section section) => sections.remove(section);

  /// Clear all sections
  void clear() => sections.clear();

  /// Check if the list is empty
  bool get isEmpty => sections.isEmpty;

  /// Check if the list is not empty
  bool get isNotEmpty => sections.isNotEmpty;

  /// Get the number of sections
  int get length => sections.length;

  /// Get a section by index
  Section operator [](int index) => sections[index];

  /// Set a section by index
  void operator []=(int index, Section section) => sections[index] = section;

  /// Get total length of all sections
  double get totalLength {
    double total = 0.0;
    for (final section in sections) {
      total += section.length;
    }
    return total;
  }

  /// Get only selected sections
  List<Section> get selectedSections => sections.where((section) => section.isSelected).toList();
  
  /// Get selection statistics in a single pass for better performance
  SelectionStats get selectionStats {
    if (sections.isEmpty) return SelectionStats.empty();
    
    int selectedCount = 0;
    for (final section in sections) {
      if (section.isSelected) selectedCount++;
    }
    
    return SelectionStats(
      total: sections.length,
      selected: selectedCount,
    );
  }
  
  /// Check if all sections are selected
  bool get allSelected {
    final stats = selectionStats;
    return stats.total > 0 && stats.selected == stats.total;
  }
  
  /// Check if no sections are selected
  bool get noneSelected => selectionStats.selected == 0;
  
  /// Check if some sections are selected (for partial selection state)
  bool get someSelected {
    final stats = selectionStats;
    return stats.selected > 0 && stats.selected < stats.total;
  }
  
  /// Select all sections
  void selectAll() {
    for (final section in sections) {
      section.isSelected = true;
    }
  }
  
  /// Deselect all sections
  void deselectAll() {
    for (final section in sections) {
      section.isSelected = false;
    }
  }
  
  /// Toggle selection for all sections (optimized)
  void toggleSelectAll() {
    final shouldSelectAll = selectionStats.selected < sections.length;
    for (final section in sections) {
      section.isSelected = shouldSelectAll;
    }
  }
  
  /// Set selection state for multiple sections efficiently
  void setSelectionForSections(List<Section> sectionsToUpdate, bool selected) {
    for (final section in sectionsToUpdate) {
      section.isSelected = selected;
    }
  }

  /// Legacy getters/setters for compatibility with existing code
  List<Section> getSections() => sections;
  void setSections(List<Section> newSections) => sections = newSections;
}

/// Efficient statistics for section selection state
class SelectionStats {
  final int total;
  final int selected;
  
  const SelectionStats({required this.total, required this.selected});
  
  const SelectionStats.empty() : total = 0, selected = 0;
  
  /// Get number of unselected sections
  int get unselected => total - selected;
  
  /// Check if all are selected
  bool get allSelected => total > 0 && selected == total;
  
  /// Check if none are selected
  bool get noneSelected => selected == 0;
  
  /// Check if some are selected
  bool get someSelected => selected > 0 && selected < total;
  
  @override
  String toString() => 'SelectionStats(selected: $selected, total: $total)';
}