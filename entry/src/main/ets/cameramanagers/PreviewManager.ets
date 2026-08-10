/*
 * Preview output stream management class.
 */

import { camera } from '@kit.CameraKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { CameraLogger as Logger } from '../camerautils/CameraLogger';
import { OutputManager, CreateOutputConfig } from './OutputManager';
import CameraConstant from '../cameraconstants/CameraConstants';

const TAG_LOG = 'PreviewManager';

/**
 * Preview output stream management class, responsible for managing the creation,
 * configuration, and release of the output stream.
 */
export class PreviewManager implements OutputManager {
  public output?: camera.PreviewOutput;
  public isActive: boolean = true;
  public onPreviewStart: () => void = () => {
  };

  constructor(onPreviewStart: () => void) {
    this.onPreviewStart = onPreviewStart;
  }

  async createOutput(config: CreateOutputConfig): Promise<camera.PreviewOutput | undefined> {
    const cameraOutputCap = config.cameraManager?.getSupportedOutputCapability(config.device, config.sceneMode);
    const displayRatio = config.profile.size.width / config.profile.size.height;
    const profileWidth = config.profile.size.width;
    const previewProfile = cameraOutputCap?.previewProfiles
      .sort((a, b) => Math.abs(a.size.width - profileWidth) - Math.abs(b.size.width - profileWidth))
      .find(pf => {
        const pfDisplayRatio = pf.size.width / pf.size.height;
        return pf.format === config.profile.format &&
          Math.abs(pfDisplayRatio - displayRatio) <= CameraConstant.PROFILE_DIFFERENCE;
      });
    if (!previewProfile) {
      Logger.error(TAG_LOG, 'Failed to get preview profile');
      return undefined;
    }
    try {
      this.output = config.cameraManager?.createPreviewOutput(previewProfile, config.surfaceId);
      if (this.output) {
        this.addOutputListener(this.output);
      }
    } catch (exception) {
      Logger.error(TAG_LOG, `createPreviewOutput failed, code is ${exception.code}, message is ${exception.message}`);
    }
    return this.output;
  }

  addOutputListener(output: camera.PreviewOutput): void {
    this.addFrameStartEventListener(output);
    this.addFrameEndEventListener(output);
  }

  addFrameStartEventListener(output: camera.PreviewOutput): void {
    output.on('frameStart', (err: BusinessError) => {
      if (err !== undefined && err.code !== 0) {
        Logger.error(TAG_LOG, `FrameStart callback Error, errorMessage: ${err.message}`);
        return;
      }
      Logger.info(TAG_LOG, 'Preview frame started');
      this.onPreviewStart();
    });
  }

  addFrameEndEventListener(output: camera.PreviewOutput): void {
    output.on('frameEnd', (err: BusinessError) => {
      if (err !== undefined && err.code !== 0) {
        Logger.error(TAG_LOG, `frameEnd callback Error, errorMessage: ${err.message}`);
        return;
      }
      Logger.info(TAG_LOG, 'Preview frame end');
    });
  }

  async release(): Promise<void> {
    try {
      await this.output?.release();
    } catch (exception) {
      Logger.error(TAG_LOG, `release failed, code is ${exception.code}, message is ${exception.message}`);
    }
    this.output = undefined;
  }

  getSupportedFrameRates(): camera.FrameRateRange[] | undefined {
    return this.output?.getSupportedFrameRates();
  }

  setFrameRate(minFps: number, maxFps: number): void {
    try {
      this.output?.setFrameRate(minFps, maxFps);
    } catch (e) {
      Logger.error(TAG_LOG, 'setFrameRate error ' + JSON.stringify(e));
    }
  }
}
