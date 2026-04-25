import SwiftUI

// MARK: - Overview
//
// `TextSelectionCoordinator` ensures there’s at most one active selection across a view subtree.
//
// Selection can be driven by multiple independent overlays. For example, `Overflow`-backed
// scrollable regions install their own interaction views so selection works locally inside the
// scroll view, while the surrounding content can still be selectable.
//
// Each `TextSelectionModel` registers with a shared coordinator. When one model becomes selected,
// the coordinator clears selection in the others, preventing multiple active selections across
// local and non-scrollable regions.

#if TEXTUAL_ENABLE_TEXT_SELECTION
  @Observable
  final class TextSelectionCoordinator {
    private var models: [WeakBox<TextSelectionModel>] = []

    func register(_ model: TextSelectionModel) {
      models.append(WeakBox(model))
      compact()
    }

    func modelDidSelectText(_ model: TextSelectionModel) {
      // Clear selection in the other models
      for weakModel in models where weakModel.wrapped !== model {
        weakModel.wrapped?.selectedRange = nil
      }
      compact()
    }

    private func compact() {
      models.removeAll {
        $0.wrapped == nil
      }
    }
  }
#endif

// `StructuredText` applies this modifier to its own subtree so a single
// markup view's overlays (overflow scrolls, attachments, etc.) all share
// one coordinator and clear each other's selection.
//
// To coordinate selection across *sibling* `StructuredText` views (for
// example, multiple bubbles in a chat transcript) wrap the common
// ancestor with ``TextualNamespace/textSelectionScope()``. That installs
// a coordinator higher up the tree; the per-instance coordination below
// detects the inherited one and defers to it instead of shadowing.
struct TextSelectionCoordination: ViewModifier {
  #if TEXTUAL_ENABLE_TEXT_SELECTION
    @Environment(TextSelectionCoordinator.self) private var inherited:
      TextSelectionCoordinator?
    @State private var fallback = TextSelectionCoordinator()
  #endif

  func body(content: Content) -> some View {
    #if TEXTUAL_ENABLE_TEXT_SELECTION
      if inherited != nil {
        content
      } else {
        content.environment(fallback)
      }
    #else
      content
    #endif
  }
}
