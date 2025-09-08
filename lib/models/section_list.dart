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

  /// Merge new sections with existing sections, resolving conflicts
  /// 
  /// Merge behavior:
  /// - Case 1: New section doesn't exist → Add it to existing sections
  /// - Case 2: Section exists with same properties (shot count, start/end depths) → Skip (no duplicate)
  /// - Case 3: Section exists with same name but different properties → Add with incremented name
  void mergeSections(List<Section> newSections) {
    for (final newSection in newSections) {
      _mergeSection(newSection);
    }
  }

  /// Merge a single section, handling conflicts
  void _mergeSection(Section newSection) {
    final existingSection = _findConflictingSection(newSection);
    
    if (existingSection == null) {
      // Case 1: Section does not exist - add it
      sections.add(newSection);
    } else {
      if (_areSectionsIdentical(existingSection, newSection)) {
        // Case 2: Section exists with same properties (shot count, depth range) - skip it
        return;
      } else {
        // Case 3: Section exists with same name but different properties - add with new name
        final uniqueName = _generateUniqueName(newSection.name);
        newSection.name = uniqueName;
        sections.add(newSection);
      }
    }
  }

  /// Find existing section that conflicts with the new section
  Section? _findConflictingSection(Section newSection) {
    for (final section in sections) {
      if (section.name == newSection.name) {
        return section;
      }
    }
    return null;
  }

  /// Check if two sections are identical based on shot count and depth range
  /// Sections are considered identical if they have:
  /// - Same number of shots
  /// - Same starting depth  
  /// - Same ending depth
  bool _areSectionsIdentical(Section section1, Section section2) {
    if (section1.shots.length != section2.shots.length) {
      return false;
    }
    
    if (section1.depthStart != section2.depthStart) {
      return false;
    }
    
    if (section1.depthEnd != section2.depthEnd) {
      return false;
    }
    
    return true;
  }

  /// Generate a unique section name by incrementing suffix
  String _generateUniqueName(String baseName) {
    if (baseName.length < 3) {
      baseName = baseName.padRight(3, '0');
    }
    
    String newName = _incrementName(baseName);
    
    while (_nameExists(newName)) {
      newName = _incrementName(newName);
    }
    
    return newName;
  }

  /// Check if a name already exists
  bool _nameExists(String name) {
    for (final section in sections) {
      if (section.name == name) {
        return true;
      }
    }
    return false;
  }

  /// Increment section name following format (AA1->AA2, AA9->AB0, AZ9->BA0)
  String _incrementName(String sectionName) {
    if (sectionName.length != 3) {
      return sectionName;
    }
    
    final chars = sectionName.split('');
    final letter1 = chars[0];
    final letter2 = chars[1];
    final number = int.tryParse(chars[2]) ?? 0;
    
    if (number < 9) {
      return '$letter1$letter2${number + 1}';
    } else {
      if (letter2 != 'Z') {
        final nextLetter2 = String.fromCharCode(letter2.codeUnitAt(0) + 1);
        return '$letter1${nextLetter2}0';
      } else {
        if (letter1 != 'Z') {
          final nextLetter1 = String.fromCharCode(letter1.codeUnitAt(0) + 1);
          return '${nextLetter1}A0';
        } else {
          return 'AA0';
        }
      }
    }
  }

  /// Legacy getters/setters for compatibility with existing code
  List<Section> getSections() => sections;
  void setSections(List<Section> newSections) => sections = newSections;
}