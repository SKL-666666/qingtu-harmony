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

/**
 * 图像处理常量定义
 */
export class ImageConstants {
  // 日志相关
  static readonly LOG_TAG: string = 'ImageSuperResolution';
  static readonly LOG_DOMAIN: number = 0x0000;

  // 图像处理相关
  // 新 API (CoreVisionKit imageSuperResolution) 固定 4 倍放大,无质量档位参数
  static readonly SR_SCALE: number = 4.0;
  static readonly MAX_IMAGE_WIDTH: number = 4096;
  static readonly MAX_IMAGE_HEIGHT: number = 4096;
  static readonly MIN_IMAGE_WIDTH: number = 100;
  static readonly MIN_IMAGE_HEIGHT: number = 100;

  // 输入尺寸护栏(防 OOM) - 新 API 固定输出 4 倍尺寸
  // 例: 4000x3000 输入 -> 16000x12000 输出,按 RGBA_8888 约 768MB,必然 OOM
  // 限制输入最长边 1024 -> 输出最长边 4096,兼顾画质与内存安全
  static readonly MAX_INPUT_DIM: number = 1024;
  // 解码尺寸下限,低于此值超分无意义
  static readonly MIN_INPUT_DIM: number = 32;

  // 内存管理相关
  static readonly MAX_CACHE_SIZE: number = 10;
  static readonly MEMORY_WARNING_THRESHOLD: number = 80;

  // 文件保存相关
  static readonly JPEG_QUALITY: number = 98;
  static readonly FILE_PREFIX: string = 'SR_';
  static readonly FILE_EXTENSION: string = '.jpg';

  // 超时设置
  static readonly PROCESS_TIMEOUT: number = 60000;
  static readonly LOAD_TIMEOUT: number = 10000;

  // UI相关
  static readonly DEFAULT_PADDING: number = 16;
  static readonly BORDER_RADIUS: number = 12;
  static readonly BUTTON_HEIGHT: number = 48;
  static readonly BUTTON_BORDER_RADIUS: number = 24;

  // 性能日志标签
  static readonly PERFORMANCE_TAG: string = 'Performance';

  // 质量等级
  static readonly QUALITY_NONE: number = 0;
  static readonly QUALITY_LOW: number = 1;
  static readonly QUALITY_MEDIUM: number = 2;
  static readonly QUALITY_HIGH: number = 3;

  // 质量描述 - 通过方法获取,避免内联对象字面量
  public static getQualityDescription(level: number): string {
    if (level === ImageConstants.QUALITY_NONE) {
      return '仅缩放,无清晰度增强效果';
    }
    if (level === ImageConstants.QUALITY_LOW) {
      return '低质量增强,处理速度较快';
    }
    if (level === ImageConstants.QUALITY_MEDIUM) {
      return '中等质量增强,平衡效果与速度';
    }
    if (level === ImageConstants.QUALITY_HIGH) {
      return '高质量增强,效果最佳但耗时较长';
    }
    return '未知质量级别';
  }
}

/**
 * 错误码定义
 */
export enum ErrorCode {
  SUCCESS = 0,
  UNKNOWN_ERROR = 1000,
  IMAGE_LOAD_ERROR = 1001,
  IMAGE_PROCESS_ERROR = 1002,
  IMAGE_SAVE_ERROR = 1003,
  PERMISSION_DENIED = 1004,
  MEMORY_INSUFFICIENT = 1005,
  TIMEOUT_ERROR = 1006,
  INVALID_PARAMETER = 1007,
  CAMERA_ERROR = 1008,
  FILE_IO_ERROR = 1009
}

/**
 * 错误消息管理类 - 使用方法代替内联对象字面量
 */
export class ErrorMessages {
  public static getMessage(code: ErrorCode): string {
    if (code === ErrorCode.SUCCESS) {
      return '操作成功';
    }
    if (code === ErrorCode.UNKNOWN_ERROR) {
      return '未知错误,请稍后重试';
    }
    if (code === ErrorCode.IMAGE_LOAD_ERROR) {
      return '图片加载失败,请检查图片格式';
    }
    if (code === ErrorCode.IMAGE_PROCESS_ERROR) {
      return '图像处理失败,可能是图片尺寸过大或不支持的格式';
    }
    if (code === ErrorCode.IMAGE_SAVE_ERROR) {
      return '图片保存失败,请检查存储空间';
    }
    if (code === ErrorCode.PERMISSION_DENIED) {
      return '权限被拒绝,请在设置中授予相应权限';
    }
    if (code === ErrorCode.MEMORY_INSUFFICIENT) {
      return '内存不足,请尝试处理较小尺寸的图片';
    }
    if (code === ErrorCode.TIMEOUT_ERROR) {
      return '处理超时,请尝试降低质量级别';
    }
    if (code === ErrorCode.INVALID_PARAMETER) {
      return '参数错误,请检查输入';
    }
    if (code === ErrorCode.CAMERA_ERROR) {
      return '相机调用失败,请检查相机权限';
    }
    if (code === ErrorCode.FILE_IO_ERROR) {
      return '文件操作失败,请检查文件路径';
    }
    return '未知错误';
  }
}