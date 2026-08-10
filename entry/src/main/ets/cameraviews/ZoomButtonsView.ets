/*
 * Zoom buttons view - focal length setting.
 */

import { findRangeIndex, toFixed } from '../camerautils/CommonUtil';
import PreviewViewModel from '../cameramodels/PreviewViewModel';
import { AppTheme } from '../common/constants/Theme';

/**
 * Focal length setting button component, used to set wide-angle and different zoom levels.
 */
@Component
struct ZoomButtonsView {
  @ObjectLink previewVM: PreviewViewModel;

  getZoomButtonText(zoom: number, index: number): string {
    const minZoom = this.previewVM.zoomRange[0];
    const currentZoomIndex: number = findRangeIndex(this.previewVM.currentZoom, this.previewVM.zooms);
    if (index === 0 && (this.previewVM.currentZoom === minZoom || currentZoomIndex !== index)) {
      return 'w';
    }
    if (this.previewVM.currentZoom === zoom || currentZoomIndex !== index) {
      return `${zoom}x`;
    }
    return `${toFixed(this.previewVM.currentZoom, 1)}x`;
  }

  getZoomButtonBorderWidth(index: number): number {
    const currentZoomIndex: number = findRangeIndex(this.previewVM.currentZoom, this.previewVM.zooms);
    return currentZoomIndex === index ? 1.5 : 0;
  }

  build() {
    Row({ space: 8 }) {
      ForEach(this.previewVM.zooms, (zoom: number, index: number) => {
        Text(this.getZoomButtonText(zoom, index))
          .width(32)
          .height(32)
          .fontColor(AppTheme.TEXT_PRIMARY)
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .borderWidth(this.getZoomButtonBorderWidth(index))
          .borderColor(AppTheme.TEXT_PRIMARY)
          .borderRadius('50%')
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.previewVM.setCameraSmoothZoom(zoom);
            this.previewVM.currentZoom = zoom;
          })
      }, (zoom: number) => zoom.toString());
    }
  }
}
export default ZoomButtonsView;
