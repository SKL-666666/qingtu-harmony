/*
 * Output stream manager interface.
 */

import { camera } from '@kit.CameraKit';

// Standard Interface for Output Stream Configuration.
export interface CreateOutputConfig {
  cameraManager?: camera.CameraManager;
  device: camera.CameraDevice;
  profile: camera.Profile;
  sceneMode?: camera.SceneMode;
  surfaceId?: string;
}

// OutputManager interface
export interface OutputManager {
  output?: camera.CameraOutput;
  isActive: boolean;
  createOutput: (config: CreateOutputConfig) => Promise<camera.CameraOutput | undefined>;
  release: () => Promise<void>;
}
