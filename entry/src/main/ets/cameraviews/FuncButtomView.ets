/*
 * Function button view - grid line, level, preview image toggles.
 */

import { showToast } from '../camerautils/CommonUtil';
import PreviewViewModel from '../cameramodels/PreviewViewModel';
import { AppTheme } from '../common/constants/Theme';

@Extend(SymbolGlyph)
function funcButtonStyle() {
  .fontSize(22)
  .fontColor([AppTheme.TEXT_PRIMARY])
  .borderRadius('50%')
  .padding(12)
  .backgroundColor(AppTheme.SURFACE_GLASS)
}

/**
 * Camera preview accessibility features, including controls and displays for grid lines,
 * a level, and dual-preview images
 */
@Component
export struct FuncButtonView {
  @ObjectLink previewVM: PreviewViewModel;

  @Builder
  gridLineButton() {
    SymbolGlyph(
      this.previewVM.isGridLineVisible
        ? $r('sys.symbol.camera_assistive_grid')
        : $r('sys.symbol.camera_assistive_grid_slash')
    )
      .funcButtonStyle()
      .onClick(() => {
        this.previewVM.isGridLineVisible = !this.previewVM.isGridLineVisible;
        const message = this.previewVM.isGridLineVisible ? $r('app.string.grid_line_open') : $r('app.string.grid_line_close');
        showToast(this.getUIContext(), message);
      })
  }

  @Builder
  levelButton() {
    SymbolGlyph($r('sys.symbol.horizontal_level'))
      .funcButtonStyle()
      .onClick(() => {
        this.previewVM.isLevelIndicatorVisible = !this.previewVM.isLevelIndicatorVisible;
        const message = this.previewVM.isLevelIndicatorVisible ? $r('app.string.level_open') : $r('app.string.level_close');
        showToast(this.getUIContext(), message);
      })
  }

  @Builder
  previewImageButton() {
    SymbolGlyph(this.previewVM.isPreviewImageVisible ? $r('sys.symbol.eye') : $r('sys.symbol.eye_slash'))
      .funcButtonStyle()
      .onClick(() => {
        this.previewVM.isPreviewImageVisible = !this.previewVM.isPreviewImageVisible;
        const message =
          this.previewVM.isPreviewImageVisible ? $r('app.string.preview_image_open') : $r('app.string.preview_image_close');
        showToast(this.getUIContext(), message);
      })
  }

  build() {
    Column({ space: 24 }) {
      this.gridLineButton()
      this.levelButton()
      this.previewImageButton()
    }
  }
}
