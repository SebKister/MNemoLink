import './section.dart';

 class SectionList {

   List<Section> sections = [];

   List<Section> getSections() {
    return sections;
  }

   void setSections(List<Section> sections) {
    this.sections = sections;
  }

   SectionList() {
    sections = [];
  }

  void clear() {
    sections.clear();
  }

}