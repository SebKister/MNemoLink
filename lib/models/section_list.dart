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
  
  /// Check if all sections are selected
  bool get allSelected => sections.isNotEmpty && sections.every((section) => section.isSelected);
  
  /// Check if no sections are selected
  bool get noneSelected => sections.every((section) => !section.isSelected);
  
  /// Check if some sections are selected (for partial selection state)
  bool get someSelected => sections.any((section) => section.isSelected) && !allSelected;
  
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
  
  /// Toggle selection for all sections
  void toggleSelectAll() {
    if (allSelected) {
      deselectAll();
    } else {
      selectAll();
    }
  }

  /// Legacy getters/setters for compatibility with existing code
  List<Section> getSections() => sections;
  void setSections(List<Section> newSections) => sections = newSections;
}