import 'package:flutter_test/flutter_test.dart';
import 'package:mnemolink/models/models.dart';

void main() {
  group('Selective Export Tests', () {
    test('Section selection state should work correctly', () {
      // Create a section with default selection (true)
      final section1 = Section(name: "Test Section 1");
      expect(section1.isSelected, true);
      
      // Create a section with explicit selection
      final section2 = Section(name: "Test Section 2", isSelected: false);
      expect(section2.isSelected, false);
      
      // Test setting selection
      section2.setIsSelected(true);
      expect(section2.isSelected, true);
      
      // Test toggle selection
      section2.toggleSelection();
      expect(section2.isSelected, false);
      section2.toggleSelection();
      expect(section2.isSelected, true);
    });

    test('SectionList selection methods should work correctly', () {
      // Create sections
      final section1 = Section(name: "Section 1");
      final section2 = Section(name: "Section 2");
      final section3 = Section(name: "Section 3");
      
      final sectionList = SectionList(sections: [section1, section2, section3]);
      
      // All should be selected by default
      expect(sectionList.allSelected, true);
      expect(sectionList.noneSelected, false);
      expect(sectionList.someSelected, false);
      expect(sectionList.selectedSections.length, 3);
      
      // Deselect one section
      section2.isSelected = false;
      expect(sectionList.allSelected, false);
      expect(sectionList.noneSelected, false);
      expect(sectionList.someSelected, true);
      expect(sectionList.selectedSections.length, 2);
      
      // Deselect all
      sectionList.deselectAll();
      expect(sectionList.allSelected, false);
      expect(sectionList.noneSelected, true);
      expect(sectionList.someSelected, false);
      expect(sectionList.selectedSections.length, 0);
      
      // Select all
      sectionList.selectAll();
      expect(sectionList.allSelected, true);
      expect(sectionList.noneSelected, false);
      expect(sectionList.someSelected, false);
      expect(sectionList.selectedSections.length, 3);
      
      // Test optimized toggle
      sectionList.toggleSelectAll(); // Should deselect all (since all are currently selected)
      expect(sectionList.noneSelected, true);
      
      sectionList.toggleSelectAll(); // Should select all (since none are currently selected)
      expect(sectionList.allSelected, true);
    });

    test('SelectionStats should provide efficient selection information', () {
      final section1 = Section(name: "Section 1", isSelected: true);
      final section2 = Section(name: "Section 2", isSelected: false);
      final section3 = Section(name: "Section 3", isSelected: true);
      
      final sectionList = SectionList(sections: [section1, section2, section3]);
      final stats = sectionList.selectionStats;
      
      expect(stats.total, 3);
      expect(stats.selected, 2);
      expect(stats.unselected, 1);
      expect(stats.someSelected, true);
      expect(stats.allSelected, false);
      expect(stats.noneSelected, false);
    });

    test('selectedSections should return only selected sections', () {
      final section1 = Section(name: "Section 1", isSelected: true);
      final section2 = Section(name: "Section 2", isSelected: false);
      final section3 = Section(name: "Section 3", isSelected: true);
      
      final sectionList = SectionList(sections: [section1, section2, section3]);
      final selectedSections = sectionList.selectedSections;
      
      expect(selectedSections.length, 2);
      expect(selectedSections[0].name, "Section 1");
      expect(selectedSections[1].name, "Section 3");
    });

    test('setSelectionForSections should efficiently update multiple sections', () {
      final section1 = Section(name: "Section 1", isSelected: true);
      final section2 = Section(name: "Section 2", isSelected: true);
      final section3 = Section(name: "Section 3", isSelected: true);
      
      final sectionList = SectionList(sections: [section1, section2, section3]);
      
      // Deselect specific sections
      sectionList.setSelectionForSections([section1, section3], false);
      
      expect(section1.isSelected, false);
      expect(section2.isSelected, true);
      expect(section3.isSelected, false);
      expect(sectionList.selectedSections.length, 1);
    });
  });
}