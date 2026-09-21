/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { common } from '@kit.AbilityKit';
import { ImageConstants } from '../common/constants/ImageConstants';
import { ImageInfo, ImageSourceType } from '../common/types/ImageTypes';
import { LogUtils, PerformanceMonitor } from '../common/utils/LogUtils';

const MAX_SELECT_COUNT: number = 9;

/**
 * 保存结果项
 */
export interface SaveResultItem {
  index: number;
  data: ArrayBuffer;      // 待保存的图片数据
  success: boolean;
  uri?: string;
  error?: string;
}

/**
 * 解码目标尺寸
 */
interface DecodeSize {
  width: number;
  height: number;
}

/**
 * 文件服务 - 处理图片选择、加载和保存
 */
export class FileService {
  private static instance: FileService;

  private constructor() {}

  public static getInstance(): FileService {
    if (!FileService.instance) {
      FileService.instance = new FileService();
    }
    return FileService.instance;
  }

  /**
   * 从相册选择多张图片
   */
  public async selectMultipleImagesFromGallery(): Promise<ImageInfo[]> {
    try {
      const photoPicker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const mimeType: photoAccessHelper.PhotoViewMIMETypes = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      const selectOptions: photoAccessHelper.PhotoSelectOptions = {
        MIMEType: mimeType,
        maxSelectNumber: MAX_SELECT_COUNT
      };
      const result: photoAccessHelper.PhotoSelectResult = await photoPicker.select(selectOptions);

      if (result.photoUris && result.photoUris.length > 0) {
        LogUtils.info('选择了 ' + result.photoUris.length + ' 张图片');
        const imageInfos: ImageInfo[] = [];
        for (let i = 0; i < result.photoUris.length; i++) {
          const uri: string = result.photoUris[i];
          try {
            const imageInfo: ImageInfo = await this.loadImageFromUri(uri, ImageSourceType.GALLERY);
            imageInfos.push(imageInfo);
          } catch (e) {
            LogUtils.warn('加载第 ' + (i + 1) + ' 张图片失败: ' + String(e));
          }
        }
        return imageInfos;
      }
      return [];
    } catch (error) {
      const err: Error = error instanceof Error ? error : new Error(String(error));
      LogUtils.error('选择图片失败', err);
      throw new Error('从相册选择图片失败: ' + err.message);
    }
  }

  /**
   * 从相册选择单张图片 (独立方法,避免多选导致内存泄漏)
   * 使用 maxSelectNumber: 1 限制为单选,只加载一张图片
   */
  public async selectImageFromGallery(): Promise<ImageInfo | null> {
    try {
      const photoPicker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const mimeType: photoAccessHelper.PhotoViewMIMETypes = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      const selectOptions: photoAccessHelper.PhotoSelectOptions = {
        MIMEType: mimeType,
        maxSelectNumber: 1
      };
      const result: photoAccessHelper.PhotoSelectResult = await photoPicker.select(selectOptions);

      if (result.photoUris && result.photoUris.length > 0) {
        const uri: string = result.photoUris[0];
        LogUtils.info('编辑页选择了 1 张图片');
        const imageInfo: ImageInfo = await this.loadImageFromUri(uri, ImageSourceType.GALLERY);
        return imageInfo;
      }
      return null;
    } catch (error) {
      const err: Error = error instanceof Error ? error : new Error(String(error));
      LogUtils.error('选择图片失败', err);
      throw new Error('从相册选择图片失败: ' + err.message);
    }
  }

  /**
   * 从URI加载图片
   *
   * 新 API (CoreVisionKit imageSuperResolution) 无 DMA 内存要求,
   * 使用普通 createPixelMap 解码即可。
   *
   * 关键: 超分固定输出 4 倍尺寸,输入过大将导致 OOM,
   * 因此在解码阶段就把长边约束到 MAX_INPUT_DIM(1024),使输出不超过 4096 像素。
   */
  public async loadImageFromUri(uri: string, sourceType: ImageSourceType): Promise<ImageInfo> {
    PerformanceMonitor.startTimer('loadImage');

    let file: fileIo.File | null = null;
    let imageSource: image.ImageSource | null = null;
    try {
      file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      LogUtils.info('打开文件成功, fd: ' + file.fd);

      imageSource = image.createImageSource(file.fd);
      if (imageSource === null || imageSource === undefined) {
        throw new Error('createImageSource返回null');
      }

      // 先获取原图尺寸
      const sourceInfo: image.ImageInfo = await imageSource.getImageInfo();
      const sourceW: number = sourceInfo.size.width;
      const sourceH: number = sourceInfo.size.height;
      LogUtils.info('原图尺寸: ' + sourceW + 'x' + sourceH);

      // 计算解码目标尺寸: 长边约束到 MAX_INPUT_DIM (防 4x 放大后 OOM)
      const targetSize: DecodeSize = this.calculateDecodeSize(sourceW, sourceH);
      LogUtils.info('解码目标尺寸: ' + targetSize.width + 'x' + targetSize.height);

      // 通过 DecodingOptions.desiredSize 让解码器直接输出目标尺寸,避免解码后再缩放
      const decodingOptions: image.DecodingOptions = {
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
        desiredSize: { width: targetSize.width, height: targetSize.height }
      };
      const pixelMap: image.PixelMap = await imageSource.createPixelMap(decodingOptions);

      if (pixelMap === null || pixelMap === undefined) {
        throw new Error('createPixelMap返回null');
      }

      LogUtils.info('PixelMap 创建成功');

      // 读取 EXIF 方向元数据(当前仅记录,不旋转)
      await this.applyExifOrientation(imageSource, pixelMap);
      const imgInfo: image.ImageInfo = pixelMap.getImageInfoSync();

      PerformanceMonitor.endTimer('loadImage');
      LogUtils.info('图片加载完成: ' + imgInfo.size.width + 'x' + imgInfo.size.height);

      const result: ImageInfo = {
        width: imgInfo.size.width,
        height: imgInfo.size.height,
        uri: uri,
        pixelMap: pixelMap,
        sourceType: sourceType
      };
      return result;
    } catch (error) {
      PerformanceMonitor.endTimer('loadImage');
      const err: Error = error instanceof Error ? error : new Error(String(error));
      LogUtils.error('加载图片失败', err);
      throw new Error('加载图片失败: ' + err.message);
    } finally {
      if (imageSource !== null) {
        try {
          imageSource.release();
        } catch (e) {
          LogUtils.warn('释放 ImageSource 失败');
        }
      }
      if (file !== null) {
        try {
          fileIo.closeSync(file.fd);
        } catch (e) {
          LogUtils.warn('关闭文件失败');
        }
      }
    }
  }

  /**
   * 计算解码目标尺寸: 长边约束到 MAX_INPUT_DIM
   * 超分固定输出 4 倍尺寸,输入过大将导致内存溢出
   */
  private calculateDecodeSize(width: number, height: number): DecodeSize {
    const maxDim: number = ImageConstants.MAX_INPUT_DIM;
    const maxSide: number = Math.max(width, height);
    if (maxSide <= maxDim) {
      const same: DecodeSize = { width: width, height: height };
      return same;
    }
    const ratio: number = maxDim / maxSide;
    const targetW: number = Math.max(1, Math.floor(width * ratio));
    const targetH: number = Math.max(1, Math.floor(height * ratio));
    const result: DecodeSize = { width: targetW, height: targetH };
    return result;
  }

  /**
   * 读取 EXIF 方向元数据
   * 当前仅记录方向,不做旋转(保持与历史版本一致的行为)
   * EXIF Orientation 值: 1=0°, 3=180°, 6=90°, 8=270°
   */
  private async applyExifOrientation(imageSource: image.ImageSource, _pixelMap: image.PixelMap): Promise<void> {
    try {
      const orientationValue: string =
        await imageSource.getImageProperty(image.PropertyKey.ORIENTATION);
      if (orientationValue === undefined || orientationValue === null || orientationValue.length === 0) {
        return;
      }
      const orientation: number = parseInt(orientationValue, 10);
      if (orientation !== 1) {
        LogUtils.info('检测到 EXIF Orientation=' + orientation + '(暂不旋转)');
      }
    } catch (e) {
      // 部分图片无 EXIF 元数据,忽略错误
      LogUtils.warn('读取 EXIF 方向失败: ' + String(e));
    }
  }

  /**
   * 将PixelMap打包为ArrayBuffer
   * @param pixelMap 像素图
   * @param format 输出格式,默认 image/jpeg
   * @param quality 质量 0-100,默认 95
   */
  public async packPixelMapToData(
    pixelMap: image.PixelMap,
    format: string = 'image/jpeg',
    quality: number = 95
  ): Promise<ArrayBuffer> {
    const imagePackerApi: image.ImagePacker = image.createImagePacker();
    const packOpts: image.PackingOption = {
      format: format,
      quality: quality
    };
    try {
      const imageData: ArrayBuffer = await imagePackerApi.packToData(pixelMap, packOpts);
      LogUtils.info('图片打包完成, 大小: ' + imageData.byteLength + ' bytes, 格式: ' + format);
      return imageData;
    } catch (error) {
      const err: Error = error instanceof Error ? error : new Error(String(error));
      LogUtils.error('图片打包失败', err);
      throw err;
    }
  }

  /**
   * 保存图片到系统图库 (相册)
   *
   * 使用 MediaAssetChangeRequest.createAssetRequest + addResource 方案,
   * 避免 fileIo.openSync/writeSync 对 content URI 不支持的问题.
   * 方案已在 PhotoManager.mediaLibSavePhotoSingle 中验证有效.
   *
   * @param context UIAbility 上下文
   * @param imageData 待保存图片二进制数据(JPEG ArrayBuffer)
   * @returns 保存后的资源 URI
   */
  public async saveToGallery(
    context: common.UIAbilityContext,
    imageData: ArrayBuffer
  ): Promise<string> {
    PerformanceMonitor.startTimer('saveImage');

    try {
      LogUtils.info('开始保存到系统图库(createAssetRequest+addResource)...');

      const phAccessHelper: photoAccessHelper.PhotoAccessHelper =
        photoAccessHelper.getPhotoAccessHelper(context);

      const photoType: photoAccessHelper.PhotoType = photoAccessHelper.PhotoType.IMAGE;
      const extension: string = ImageConstants.FILE_EXTENSION.replace('.', '');
      const options: photoAccessHelper.CreateOptions = {
        title: 'ProcessedImg_' + new Date().getTime()
      };

      const assetChangeRequest: photoAccessHelper.MediaAssetChangeRequest =
        photoAccessHelper.MediaAssetChangeRequest.createAssetRequest(
          context, photoType, extension, options);

      assetChangeRequest.addResource(photoAccessHelper.ResourceType.IMAGE_RESOURCE, imageData);

      await phAccessHelper.applyChanges(assetChangeRequest);

      const uri: string = assetChangeRequest.getAsset().uri;
      LogUtils.info('保存到系统图库成功! URI: ' + uri);

      const duration: number = PerformanceMonitor.endTimer('saveImage');
      LogUtils.info('保存耗时: ' + duration + 'ms');

      return uri;

    } catch (error) {
      PerformanceMonitor.endTimer('saveImage');
      const err: Error = error instanceof Error ? error : new Error(String(error));
      LogUtils.error('保存到系统图库失败', err);
      throw new Error('保存到图库失败: ' + err.message);
    }
  }

  /**
   * 批量保存图片到系统图库
   * 在 SaveButton 授权窗口内(API20+ 为 1 分钟),循环调用 createAsset + fileIo.write
   * @param items 待保存项列表
   * @param onProgress 进度回调 (已保存数/总数)
   * @returns 每项保存结果列表
   */
  public async saveAllImagesToAlbum(
    context: common.UIAbilityContext,
    items: SaveResultItem[],
    onProgress?: (saved: number, total: number) => void
  ): Promise<SaveResultItem[]> {
    const results: SaveResultItem[] = [];
    const total: number = items.length;

    let saved: number = 0;
    for (let i = 0; i < items.length; i++) {
      const item: SaveResultItem = items[i];
      try {
        const uri: string = await this.saveToGallery(context, item.data);
        results.push({ index: item.index, data: item.data, success: true, uri: uri });
        saved++;
      } catch (error) {
        const err: Error = error instanceof Error ? error : new Error(String(error));
        results.push({ index: item.index, data: item.data, success: false, error: err.message });
      }
      if (onProgress) {
        onProgress(i + 1, total);
      }
    }
    LogUtils.info('批量保存完成: ' + saved + '/' + total);
    return results;
  }

  /**
   * 获取最大选择数量
   */
  public getMaxSelectCount(): number {
    return MAX_SELECT_COUNT;
  }

  /**
   * 删除文件
   */
  public deleteFile(filePath: string): void {
    try {
      fileIo.accessSync(filePath);
      fileIo.unlinkSync(filePath);
      LogUtils.info('文件已删除: ' + filePath);
    } catch (e) {
      LogUtils.warn('删除文件失败');
    }
  }
}