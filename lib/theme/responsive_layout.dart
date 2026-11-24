/// Dimensões centralizadas para a biblioteca e o editor.
/// Permite ajustar os breakpoints sem espalhar números pelas telas.
class ResponsiveLayout {
  const ResponsiveLayout._();

  static bool libraryHasSidebar(double width) => width >= 860;
  static bool editorHasSidebar(double width) => width >= 780;
  static bool galleryHeaderIsStacked(double width) => width < 490;
  static bool galleryUsesSingleColumn(double width) => width < 560;
  static double galleryCardMaxWidth(double width) =>
      galleryUsesSingleColumn(width) ? 480 : 310;
  static double galleryCardHeight(double width) =>
      galleryUsesSingleColumn(width) ? 238 : 256;
}
