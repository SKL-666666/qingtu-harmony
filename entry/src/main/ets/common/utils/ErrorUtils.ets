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

import { ErrorCode, ErrorMessages } from '../constants/ImageConstants';
import { AppError } from '../types/ImageTypes';

/**
 * 错误处理工具类
 */
export class ErrorUtils {
  /**
   * 创建应用错误对象
   */
  public static createError(code: ErrorCode, details?: string): AppError {
    const result: AppError = {
      code: code,
      message: ErrorMessages.getMessage(code),
      timestamp: Date.now()
    };
    if (details !== undefined) {
      result.details = details;
    }
    return result;
  }

  /**
   * 显示Error提示 (需传入 UIContext)
   */
  public static showErrorToast(uiContext: UIContext, error: Error): void {
    try {
      uiContext.getPromptAction().showToast({
        message: error.message,
        duration: 3000
      });
    } catch (_e) { /* ignore */ }
  }

  /**
   * 显示字符串错误提示 (需传入 UIContext)
   */
  public static showStringErrorToast(uiContext: UIContext, message: string): void {
    try {
      uiContext.getPromptAction().showToast({
        message: message,
        duration: 3000
      });
    } catch (_e) { /* ignore */ }
  }

  /**
   * 显示AppError对话框 (需传入 UIContext)
   */
  public static showAppErrorDialog(uiContext: UIContext, error: AppError): void {
    try {
      const dialogMessage: string = error.details !== undefined && error.details.length > 0 ?
        error.message + '\n详情: ' + error.details :
        error.message;
      uiContext.getPromptAction().showDialog({
        title: '操作失败',
        message: dialogMessage,
        buttons: [
          {
            text: '确定',
            color: '#007DFF'
          }
        ]
      });
    } catch (_e) { /* ignore */ }
  }

  /**
   * 显示成功提示 (需传入 UIContext)
   */
  public static showSuccessToast(uiContext: UIContext, message: string = '操作成功'): void {
    try {
      uiContext.getPromptAction().showToast({
        message: message,
        duration: 2000
      });
    } catch (_e) { /* ignore */ }
  }

  /**
   * 判断是否为致命错误
   */
  public static isFatalError(error: AppError): boolean {
    const fatalCodes: number[] = [
      ErrorCode.MEMORY_INSUFFICIENT,
      ErrorCode.PERMISSION_DENIED
    ];
    return fatalCodes.includes(error.code);
  }
}