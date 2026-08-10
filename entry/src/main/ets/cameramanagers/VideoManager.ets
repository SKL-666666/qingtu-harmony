/*
 * Video output stream management class.
 */

import { media } from '@kit.MediaKit';
import { camera } from '@kit.CameraKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { sensor } from '@kit.SensorServiceKit';
import { Decimal } from '@kit.ArkTS';
import { image } from '@kit.ImageKit';
import { colorSpaceManager } from '@kit.ArkGraphics2D';
import { BusinessError } from '@kit.BasicServicesKit';
import { CameraLogger as Logger } from '../camerautils/CameraLogger';
import { OutputManager, CreateOutputConfig } from './OutputManager';
import CameraConstant from '../cameraconstants/CameraConstants';

const TAG_LOG = 'video';

enum QualityLevel {
  NORMAL,
  HIGHER
}

export enum AVRecorderState {
  IDLE = 'idle',
  PREPARED = 'prepared',
  STARTED = 'started',
  PAUSED = 'paused',
  STOPPED = 'stopped',
  RELEASED = 'released',
  ERROR = 'error'
}

/**
 * video output stream management class, responsible for managing the creation,
 * configuration, and release of the output stream
 */
export class VideoManager implements OutputManager {
  public output: camera.VideoOutput | undefined = undefined;
  public state: media.AVRecorderState = AVRecorderState.IDLE;
  public isActive: boolean = false;
  private avRecorder: media.AVRecorder | undefined = undefined;
  private avConfig: media.AVRecorderConfig | undefined = undefined;
  private avProfile: media.AVRecorderProfile | undefined = undefined;
  private videoProfile: camera.VideoProfile | undefined = undefined;
  private context: Context | undefined = undefined;
  private cameraPosition: number = camera.CameraPosition.CAMERA_POSITION_BACK;
  private qualityLevel: QualityLevel = QualityLevel.NORMAL;
  private videoUri: string = '';
  private file: fileIo.File | undefined = undefined;
  private callback: (pixelMap: image.PixelMap, url: string) => void = () => {
  };

  constructor(context: Context) {
    this.context = context;
  }

  setIsActive(isActive: boolean): void {
    this.isActive = isActive;
  }

  async createOutput(config: CreateOutputConfig): Promise<camera.VideoOutput | undefined> {
    try {
      this.avRecorder = await media.createAVRecorder();
      this.avRecorder.on('stateChange', state => {
        this.state = state;
        Logger.info(TAG_LOG, 'on avRecorder state change: ', state);
      });
    } catch (error) {
      Logger.error(TAG_LOG, 'createAVRecorder call failed. Error code: %{public}s', error.code);
    }
    if (this.avRecorder === undefined || this.avRecorder === null) {
      return undefined;
    }

    this.setVideoProfile(config.cameraManager, config.profile, config.device);
    await this.setAVConfig();
    await this.prepare();
    await this.createVideoOutput(config.cameraManager);
    return this.output;
  }

  async prepare(): Promise<void> {
    try {
      if (this.avRecorder?.state === AVRecorderState.IDLE && this.avConfig) {
        await this.avRecorder.prepare(this.avConfig);
        Logger.info(TAG_LOG, 'Succeeded in preparing');
      }
    } catch (error) {
      Logger.error(TAG_LOG, `Failed to prepare and catch error is  ${error.message}`);
    }
  }

  isSupportMirror(): boolean | undefined {
    let isSupported: boolean | undefined = this.output?.isMirrorSupported();
    return isSupported;
  }

  async start(isFront: boolean): Promise<void> {
    try {
      if (this.avRecorder?.state === AVRecorderState.PREPARED) {
        if (this.isSupportMirror() && isFront) {
          this.output?.enableMirror(true);
        }
        await this.avRecorder.updateRotation(this.getVideoRotation(await this.getGravity()));
        await this.output?.start();
        await this.avRecorder?.start();
      }
    } catch (error) {
      Logger.info(TAG_LOG, `Failed to start and catch error is  ${error.message}`);
    }
  }

  async stop(): Promise<void> {
    try {
      if (this.avRecorder?.state === AVRecorderState.STARTED ||
        this.avRecorder?.state === AVRecorderState.PAUSED) {
        await this.avRecorder.stop();
        await this.output?.stop();
        const thumbnail = await this.getVideoThumbnail();
        if (thumbnail) {
          this.callback(thumbnail, this.videoUri);
        }
      }
    } catch (error) {
      Logger.error(TAG_LOG, `Failed to stop and catch error is  ${error.message}`);
    }
  }

  async pause(): Promise<void> {
    try {
      if (this.avRecorder?.state === AVRecorderState.STARTED) {
        await this.avRecorder.pause();
        await this.output?.stop();
      }
    } catch (error) {
      Logger.error(TAG_LOG, `Failed to pause and catch error is  ${error.message}`);
    }
  }

  async resume(): Promise<void> {
    try {
      if (this.avRecorder?.state === AVRecorderState.PAUSED) {
        await this.output?.start();
        await this.avRecorder.resume();
      }
    } catch (error) {
      Logger.error(TAG_LOG, `Failed to resume and catch error is  ${error.message}`);
    }
  }

  async release(): Promise<void> {
    try {
      await this.avRecorder?.release();
      await this.output?.release();
      this.file && await fileIo.close(this.file.fd);
    } catch (exception) {
      Logger.error(TAG_LOG, `release failed, code is ${exception.code}, message is ${exception.message}`);
    }
    this.avRecorder?.off('stateChange');
    this.avRecorder = undefined;
    this.output = undefined;
    this.file = undefined;
  }

  getCurrentOutput(): camera.VideoOutput | undefined {
    return this.output;
  }

  setVideoCallback(callback: (pixelMap: image.PixelMap, url: string) => void): void {
    this.callback = callback;
  }

  async createVideoOutput(cameraManager: camera.CameraManager | undefined): Promise<void> {
    if (!this.avRecorder || this.avRecorder.state !== AVRecorderState.PREPARED) {
      return;
    }
    try {
      let videoSurfaceId = await this.avRecorder.getInputSurface();
      this.output = cameraManager?.createVideoOutput(this.videoProfile, videoSurfaceId);
    } catch (error) {
      Logger.error(TAG_LOG,
        `Failed to create the output instance. Error code: ${error.code}`);
    }
  }

  setVideoProfile(cameraManager: camera.CameraManager | undefined, targetProfile: camera.Profile,
    device: camera.CameraDevice): void {
    this.cameraPosition = device.cameraPosition;
    let cameraOutputCap: camera.CameraOutputCapability | undefined =
      cameraManager?.getSupportedOutputCapability(device,
        camera.SceneMode.NORMAL_VIDEO);
    let videoProfilesArray: camera.VideoProfile[] | undefined = cameraOutputCap?.videoProfiles;
    if (videoProfilesArray?.length) {
      try {
        const displayRatio = targetProfile.size.width / targetProfile.size.height;
        const profileWidth = targetProfile.size.width;
        const videoProfile = videoProfilesArray
          .sort((a, b) => Math.abs(a.size.width - profileWidth) - Math.abs(b.size.width - profileWidth))
          .find(pf => {
            const pfDisplayRatio = pf.size.width / pf.size.height;
            return Math.abs(pfDisplayRatio - displayRatio) <= CameraConstant.PROFILE_DIFFERENCE &&
              pf.format === camera.CameraFormat.CAMERA_FORMAT_YUV_420_SP;
          });
        if (!videoProfile) {
          Logger.error(TAG_LOG, 'Failed to get video profile');
          return;
        }
        this.videoProfile = videoProfile;
      } catch (error) {
        Logger.error(TAG_LOG, `Failed to createPhotoOutput. Error: ${JSON.stringify(error)}`);
      }
    }
  }

  getCameraImageRotation(): camera.ImageRotation {
    return this.cameraPosition === camera.CameraPosition.CAMERA_POSITION_FRONT
      ? camera.ImageRotation.ROTATION_270
      : camera.ImageRotation.ROTATION_90;
  }

  async setAVConfig(): Promise<void> {
    let options: photoAccessHelper.CreateOptions = {
      title: Date.now().toString()
    };
    let videoAccessHelper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(this.context);
    try {
      this.videoUri = await videoAccessHelper.createAsset(photoAccessHelper.PhotoType.VIDEO, 'mp4', options);
      this.file = fileIo.openSync(this.videoUri, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
    } catch (exception) {
      Logger.error(TAG_LOG, `createAsset failed, code is ${exception.code}, message is ${exception.message}`);
    }

    if (!this.file) {
      Logger.error(TAG_LOG, 'createAsset failed, file undefined');
      return;
    }

    this.avProfile = {
      audioBitrate: 48000,
      audioChannels: 2,
      audioCodec: media.CodecMimeType.AUDIO_AAC,
      audioSampleRate: 48000,
      fileFormat: media.ContainerFormatType.CFT_MPEG_4,
      videoBitrate: 32000000,
      videoCodec: (this.qualityLevel === QualityLevel.HIGHER &&
        this.cameraPosition === camera.CameraPosition.CAMERA_POSITION_BACK) ?
        media.CodecMimeType.VIDEO_HEVC : media.CodecMimeType.VIDEO_AVC,
      videoFrameWidth: this.videoProfile?.size.width,
      videoFrameHeight: this.videoProfile?.size.height,
      videoFrameRate: this.cameraPosition === camera.CameraPosition.CAMERA_POSITION_BACK ?
        60 : 30,
    };

    this.avConfig = {
      audioSourceType: media.AudioSourceType.AUDIO_SOURCE_TYPE_CAMCORDER,
      videoSourceType: media.VideoSourceType.VIDEO_SOURCE_TYPE_SURFACE_YUV,
      profile: this.avProfile,
      url: `fd://${this.file.fd}`,
      metadata: {
        videoOrientation: this.getCameraImageRotation().toString()
      }
    };
  }

  getRealData(data: sensor.GravityResponse | sensor.AccelerometerResponse): number {
    let getDeviceDegree: number = 0;
    let x = data.x;
    let y = data.y;
    let z = data.z;
    if ((x * x + y * y) * 3 < z * z) {
      return getDeviceDegree;
    } else {
      try {
        let sd: Decimal = Decimal.atan2(y, -x);
        let sc: Decimal = Decimal.round(Number(sd) / 3.141592653589 * 180);
        getDeviceDegree = 90 - Number(sc);
        getDeviceDegree = getDeviceDegree >= 0 ? getDeviceDegree % 360 : getDeviceDegree % 360 + 360;
      } catch (exception) {
        Logger.error(TAG_LOG, `getRealData failed, code is ${exception.code}, message is ${exception.message}`);
      }
    }
    return getDeviceDegree;
  }

  async getGravity(): Promise<number> {
    try {
      let isSupportedGravity: boolean = false;
      let data = await sensor.getSensorList();
      for (let i = 0; i < data.length; i++) {
        if (data[i].sensorId === sensor.SensorId.GRAVITY) {
          isSupportedGravity = true;
          break;
        }
      }
      if (isSupportedGravity === true) {
        const promise: Promise<number> = new Promise((resolve) => {
          sensor.once(sensor.SensorId.GRAVITY, (data: sensor.GravityResponse) => {
            resolve(this.getRealData(data));
          });
        });
        return promise;
      } else {
        const promise: Promise<number> = new Promise((resolve) => {
          sensor.once(sensor.SensorId.ACCELEROMETER, (data: sensor.AccelerometerResponse) => {
            resolve(this.getRealData(data));
          });
        });
        return promise;
      }
    } catch (error) {
      Logger.error(TAG_LOG, `Failed to getGravity and catch error is  ${error.message}`);
      return 0;
    }
  }

  getVideoRotation(deviceDegree: number): camera.ImageRotation {
    let videoRotation: camera.ImageRotation = this.getCameraImageRotation();
    try {
      if (this.output) {
        videoRotation = this.output.getVideoRotation(deviceDegree);
      }
      Logger.info(TAG_LOG, `Video rotation is: ${videoRotation}`);
    } catch (error) {
      Logger.error(TAG_LOG, `Failed to getVideoRotation and catch error is: ${error.message}`);
    }
    return videoRotation;
  }

  async getVideoThumbnail(): Promise<image.PixelMap | undefined> {
    let pixelMap: image.PixelMap | undefined;
    if (!this.file) {
      return pixelMap;
    }
    try {
      let avImageGenerator: media.AVImageGenerator = await media.createAVImageGenerator();
      let dataSrc: media.AVFileDescriptor = {
        fd: this.file.fd,
      };
      avImageGenerator.fdSrc = dataSrc;
      let timeUs = 0;
      let queryOption = media.AVImageQueryOptions.AV_IMAGE_QUERY_NEXT_SYNC;
      let param: media.PixelMapParams = {
        width: 300,
        height: 300
      };
      pixelMap = await avImageGenerator.fetchFrameByTime(timeUs, queryOption, param);
      avImageGenerator.release().catch((err: BusinessError) => {
        Logger.error(TAG_LOG, `avImageGenerator.release failed, code is ${err.code}, message is ${err.message}`);
      });
    } catch (error) {
      Logger.error(TAG_LOG, `Failed to getVideoThumbnail and catch error is  ${error.message}`);
    }
    return pixelMap;
  }

  isRecording(): boolean {
    return this.state === AVRecorderState.STARTED || this.state === AVRecorderState.PAUSED;
  }

  setVideoStabilizationMode(session: camera.VideoSession): boolean {
    let mode: camera.VideoStabilizationMode = camera.VideoStabilizationMode.AUTO;
    try {
      let isSupported: boolean = session.isVideoStabilizationModeSupported(mode);
      if (!isSupported) {
        Logger.info(TAG_LOG, `videoStabilizationMode: ${mode} is not support`);
        return false;
      }
      Logger.info(TAG_LOG, `setVideoStabilizationMode: ${mode}`);
      session.setVideoStabilizationMode(mode);
      let activeVideoStabilizationMode = session.getActiveVideoStabilizationMode();
      Logger.info(TAG_LOG, `activeVideoStabilizationMode: ${activeVideoStabilizationMode}`);
      return isSupported;
    } catch (exception) {
      Logger.error(TAG_LOG,
        `setVideoStabilizationMode failed, code is ${exception.code}, message is ${exception.message}`);
      return false;
    }
  }

  getSupportedColorSpaces(session: camera.VideoSession): colorSpaceManager.ColorSpace[] {
    let colorSpaces: colorSpaceManager.ColorSpace[] = [];
    try {
      colorSpaces = session.getSupportedColorSpaces();
    } catch (error) {
      Logger.error(TAG_LOG, `The getSupportedColorSpaces call failed. Error code: ${error.message}`);
    }
    return colorSpaces;
  }

  setColorSpaceAfterCommitConfig(session: camera.VideoSession, isHdr: boolean): void {
    let colorSpace: colorSpaceManager.ColorSpace =
      isHdr ? colorSpaceManager.ColorSpace.BT2020_HLG_LIMIT : colorSpaceManager.ColorSpace.BT709_LIMIT;
    let colorSpaces: colorSpaceManager.ColorSpace[] = this.getSupportedColorSpaces(session);
    if (!colorSpaces.includes(colorSpace)) {
      Logger.info(TAG_LOG, `colorSpace: ${colorSpace} is not support`);
      return;
    }
    try {
      Logger.info(TAG_LOG, `setColorSpace: ${colorSpace}`);
      session.setColorSpace(colorSpace);
    } catch (exception) {
      Logger.error(TAG_LOG, `setColorSpace failed, code is ${exception.code}, message is ${exception.message}`);
    }
    try {
      let activeColorSpace: colorSpaceManager.ColorSpace = session.getActiveColorSpace();
      Logger.info(TAG_LOG, `activeColorSpace: ${activeColorSpace}`);
    } catch (error) {
      Logger.error(TAG_LOG, `getActiveColorSpace Faild: ${error.message}`);
    }
  }
}
