import { tag } from '@kit.ConnectivityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { vibrator } from '@kit.SensorServiceKit';
import { bundleManager } from '@kit.AbilityKit';

const TAG = 'NFCReaderService';
const DOMAIN = 0x0000;

export interface NFCReadResult {
  uid: string;
  technology: string[];
  success: boolean;
  error?: string;
}

export class NFCReaderService {
  private static instance: NFCReaderService;
  private isListening: boolean = false;
  private elementName: bundleManager.ElementName | null = null;
  private onTagDetected: ((result: NFCReadResult) => void) | null = null;

  private constructor() {}

  static getInstance(): NFCReaderService {
    if (!NFCReaderService.instance) {
      NFCReaderService.instance = new NFCReaderService();
    }
    return NFCReaderService.instance;
  }

  /**
   * Start listening for NFC tags
   */
  startReaderMode(elementName: bundleManager.ElementName, callback: (result: NFCReadResult) => void): boolean {
    console.log('[NFCReaderService] Starting NFC reader mode...');
    hilog.info(DOMAIN, TAG, 'Starting NFC reader mode...');
    
    if (this.isListening) {
      hilog.warn(DOMAIN, TAG, 'Reader mode already active, stopping first');
      this.stopReaderMode();
    }

    this.elementName = elementName;
    this.onTagDetected = callback;

    try {
      hilog.info(DOMAIN, TAG, 'Setting up NFC technology filters');
      const techList = [
        tag.NFC_A,
        tag.NFC_B,
        tag.NFC_F,
        tag.NFC_V,
        tag.ISO_DEP
      ];

      hilog.info(DOMAIN, TAG, 'Registering NFC reader mode listener');
      console.log('[NFCReaderService] Registering with elementName: ' + JSON.stringify(elementName));
      
      tag.on('readerMode', elementName, techList, (error: BusinessError, tagInfo: tag.TagInfo) => {
        console.log('[NFCReaderService] Reader mode callback triggered');
        hilog.info(DOMAIN, TAG, 'Reader mode callback triggered');
        this.handleTagDetected(error, tagInfo);
      });

      this.isListening = true;
      hilog.info(DOMAIN, TAG, 'NFC reader mode started successfully - waiting for cards');
      console.log('[NFCReaderService] NFC reader mode started successfully');
      return true;
    } catch (error) {
      console.log('[NFCReaderService] Error starting reader mode: ' + JSON.stringify(error));
      hilog.error(DOMAIN, TAG, 'Failed to start reader mode: %{public}s', JSON.stringify(error));
      this.isListening = false;
      return false;
    }
  }

  /**
   * Stop listening for NFC tags
   */
  stopReaderMode(): boolean {
    if (!this.isListening || !this.elementName) {
      return false;
    }

    try {
      tag.off('readerMode', this.elementName);
      this.isListening = false;
      this.onTagDetected = null;
      hilog.info(DOMAIN, TAG, 'Reader mode stopped');
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to stop reader mode: %{public}s', JSON.stringify(error));
      return false;
    }
  }

  private handleTagDetected(error: BusinessError, tagInfo: tag.TagInfo): void {
    console.log('[NFCReaderService] Tag detection callback invoked');
    hilog.info(DOMAIN, TAG, 'Tag detection callback invoked');
    
    if (error) {
      console.log('[NFCReaderService] Tag detection error: ' + JSON.stringify(error));
      hilog.error(DOMAIN, TAG, 'Tag detection error code: %{public}d, message: %{public}s', error.code, error.message);
      if (this.onTagDetected) {
        this.onTagDetected({
          uid: '',
          technology: [],
          success: false,
          error: `Error ${error.code}: ${error.message}`
        });
      }
      return;
    }

    try {
      hilog.info(DOMAIN, TAG, 'Processing detected tag');
      const uid = this.arrayToHex(tagInfo.uid || []);
      const technologies = this.getTechnologyNames(tagInfo.technology || []);

      console.log('[NFCReaderService] Card detected! UID: ' + uid);
      hilog.info(DOMAIN, TAG, 'Card detected! UID: %{public}s, Technologies: %{public}s', uid, JSON.stringify(technologies));

      // Trigger vibration
      this.triggerVibration();

      if (this.onTagDetected) {
        this.onTagDetected({
          uid,
          technology: technologies,
          success: true
        });
      }
    } catch (err) {
      console.log('[NFCReaderService] Error processing tag: ' + JSON.stringify(err));
      hilog.error(DOMAIN, TAG, 'Error processing tag: %{public}s', JSON.stringify(err));
      if (this.onTagDetected) {
        this.onTagDetected({
          uid: '',
          technology: [],
          success: false,
          error: 'Error processing tag data'
        });
      }
    }
  }

  private arrayToHex(data: number[]): string {
    return data.map((byte: number) => {
      const hex = byte.toString(16).toUpperCase();
      return hex.length === 1 ? '0' + hex : hex;
    }).join(' ');
  }

  private getTechnologyNames(techs: number[]): string[] {
    const names: string[] = [];
    for (const tech of techs) {
      if (tech === tag.NFC_A) names.push('NFC_A');
      else if (tech === tag.NFC_B) names.push('NFC_B');
      else if (tech === tag.NFC_F) names.push('NFC_F');
      else if (tech === tag.NFC_V) names.push('NFC_V');
      else if (tech === tag.ISO_DEP) names.push('ISO_DEP');
    }
    return names;
  }

  private triggerVibration(): void {
    try {
      const vibrateEffect: vibrator.VibrateEffect = {
        type: 'time',
        duration: 200
      };
      vibrator.startVibration(vibrateEffect, { usage: 'notification' }).then(() => {
        hilog.info(DOMAIN, TAG, 'Vibration triggered');
      }).catch((err: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'Vibration failed: %{public}s', JSON.stringify(err));
      });
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Vibration error: %{public}s', JSON.stringify(error));
    }
  }

  isReading(): boolean {
    return this.isListening;
  }
}
