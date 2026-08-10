/*
 * Camera manager data class.
 */

import { CameraManager } from '../cameramanagers/CameraManager';
import { ImageReceiverManager } from '../cameramanagers/ImageReceiverManager';
import { MetadataManager } from '../cameramanagers/MetadataManager';
import { PhotoManager } from '../cameramanagers/PhotoManager';
import { PreviewManager } from '../cameramanagers/PreviewManager';
import { VideoManager } from '../cameramanagers/VideoManager';

/**
 * Camera manager data class.
 */
export class CameraManagerModel {
  public previewManager: PreviewManager;
  public photoManager: PhotoManager;
  public videoManager: VideoManager;
  public imageReceiverManager: ImageReceiverManager;
  public metadataManager: MetadataManager;
  public cameraManager: CameraManager;

  constructor(context: Context, previewManager: PreviewManager, photoManager: PhotoManager, videoManager: VideoManager,
    imageReceiverManager: ImageReceiverManager, metadataManager: MetadataManager) {
    this.previewManager = previewManager;
    this.photoManager = photoManager;
    this.videoManager = videoManager;
    this.imageReceiverManager = imageReceiverManager;
    this.metadataManager = metadataManager;
    this.cameraManager = new CameraManager(context, [previewManager,
      photoManager, videoManager, imageReceiverManager, metadataManager]);
  }
}
