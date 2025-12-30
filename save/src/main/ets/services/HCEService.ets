import { cardEmulation } from '@kit.ConnectivityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { bundleManager } from '@kit.AbilityKit';

const TAG = 'HCEService';
const DOMAIN = 0x0000;

// Static log to verify HCEService is loaded
hilog.info(DOMAIN, TAG, 'HCEService module loaded');

export class HCEService {
  private static instance: HCEService;
  private hceService: cardEmulation.HceService | null = null;
  private elementName: bundleManager.ElementName | null = null;
  private isHceRunning: boolean = false;
  private onApduCommand: ((command: number[]) => void) | null = null;

  private constructor() {}

  static getInstance(): HCEService {
    if (!HCEService.instance) {
      HCEService.instance = new HCEService();
    }
    return HCEService.instance;
  }

  /**
   * Initialize HCE service according to official documentation
   */
  initialize(elementName: bundleManager.ElementName): boolean {
    try {
      this.elementName = elementName;
      
      // Check if device supports HCE according to official API
      let hceSupported: boolean = cardEmulation.hasHceCapability();
      hilog.info(DOMAIN, TAG, 'Device HCE capability check result: %{public}s', hceSupported ? 'SUPPORTED' : 'NOT SUPPORTED');
      console.log('[HCEService] ========== HCE CAPABILITY CHECK ==========');
      console.log('[HCEService] Device supports HCE: ' + hceSupported);
      console.log('[HCEService] SystemCapability: Communication.NFC.CardEmulation');
      console.log('[HCEService] Required permission: ohos.permission.NFC_CARD_EMULATION');
      console.log('[HCEService] ==========================================');
      
      if (!hceSupported) {
        hilog.error(DOMAIN, TAG, 'Device does not support HCE - check device capabilities or permissions');
        console.log('[HCEService] ERROR: This device/wearable does not support HCE card emulation');
        return false;
      }

      // Create HceService instance
      this.hceService = new cardEmulation.HceService();
      hilog.info(DOMAIN, TAG, 'HCEService initialized successfully');
      console.log('[HCEService] ✓ HCEService instance created successfully');
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'HCEService initialization failed: %{public}s', JSON.stringify(error));
      console.log('[HCEService] Initialization error: ' + JSON.stringify(error));
      return false;
    }
  }

  /**
   * Start HCE with AID list according to official documentation
   * Uses the v9+ start() method which takes elementName and aidList
   */
  startHCE(elementName: bundleManager.ElementName, aidList: string[]): boolean {
    if (!this.hceService || !elementName) {
      hilog.error(DOMAIN, TAG, 'HCEService not initialized');
      console.log('[HCEService] ERROR: HCEService not initialized, hceService=' + (this.hceService ? 'exists' : 'null'));
      return false;
    }

    try {
      console.log('[HCEService] Starting HCE with ' + aidList.length + ' AIDs: ' + JSON.stringify(aidList));
      hilog.info(DOMAIN, TAG, 'Starting HCE with AIDs: %{public}s', JSON.stringify(aidList));

      // Use official API v9+ start() method
      // This sets the app as foreground priority and registers AIDs dynamically
      this.hceService.start(elementName, aidList);
      
      this.isHceRunning = true;
      hilog.info(DOMAIN, TAG, 'HCE started successfully');
      console.log('[HCEService] HCE started successfully, isHceRunning=' + this.isHceRunning);
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to start HCE: %{public}s', JSON.stringify(error));
      console.log('[HCEService] ERROR starting HCE: ' + JSON.stringify(error));
      this.isHceRunning = false;
      return false;
    }
  }

  /**
   * Stop HCE according to official documentation
   * Uses the v9+ stop() method
   */
  stopHCE(elementName: bundleManager.ElementName): boolean {
    if (!this.hceService || !elementName) {
      hilog.error(DOMAIN, TAG, 'HCEService not initialized');
      return false;
    }

    try {
      hilog.info(DOMAIN, TAG, 'Stopping HCE');
      console.log('[HCEService] Stopping HCE');

      // Use official API v9+ stop() method
      // This unsubscribes from hceCmd, exits foreground priority, and releases AIDs
      this.hceService.stop(elementName);
      
      this.isHceRunning = false;
      hilog.info(DOMAIN, TAG, 'HCE stopped successfully');
      console.log('[HCEService] HCE stopped');
      return true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to stop HCE: %{public}s', JSON.stringify(error));
      console.log('[HCEService] Stop HCE error: ' + JSON.stringify(error));
      return false;
    }
  }

  /**
   * Subscribe to APDU commands from external NFC readers
   * According to official documentation, this should be called in onCreate
   */
  subscribeToAPDU(): void {
    if (!this.hceService) {
      hilog.error(DOMAIN, TAG, 'HCEService not initialized');
      return;
    }

    try {
      hilog.info(DOMAIN, TAG, 'Subscribing to APDU commands');
      console.log('[HCEService] Subscribing to APDU commands');

      // Subscribe to 'hceCmd' event according to official API
      // The callback receives APDU data from external NFC readers
      this.hceService.on('hceCmd', (err: BusinessError | null, apduData: number[]) => {
        if (err) {
          hilog.error(DOMAIN, TAG, 'APDU command error: %{public}s', JSON.stringify(err));
          console.log('[HCEService] APDU error: ' + JSON.stringify(err));
          return;
        }

        if (!apduData || apduData.length === 0) {
          hilog.warn(DOMAIN, TAG, 'Received empty APDU command');
          return;
        }

        hilog.info(DOMAIN, TAG, 'Received APDU command: %{public}s', this.arrayToHex(apduData));
        console.log('[HCEService] Received APDU: ' + this.arrayToHex(apduData));

        // Call the registered callback if available
        if (this.onApduCommand) {
          console.log('[HCEService] 📢 Triggering registered APDU callback...');
          hilog.info(DOMAIN, TAG, 'Triggering APDU callback');
          this.onApduCommand(apduData);
        } else {
          console.log('[HCEService] ⚠️ WARNING: onApduCommand callback is NULL - not registered!');
          hilog.warn(DOMAIN, TAG, 'WARNING: onApduCommand callback is NULL');
        }
      });
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to subscribe to APDU: %{public}s', JSON.stringify(error));
      console.log('[HCEService] Subscribe error: ' + JSON.stringify(error));
    }
  }

  /**
   * Unsubscribe from APDU commands
   * Removes the 'hceCmd' event listener
   */
  unsubscribeFromAPDU(): void {
    if (!this.hceService) {
      hilog.error(DOMAIN, TAG, 'HCEService not initialized');
      return;
    }

    try {
      hilog.info(DOMAIN, TAG, 'Unsubscribing from APDU commands');
      console.log('[HCEService] Unsubscribing from APDU commands');

      // Unsubscribe from 'hceCmd' event
      this.hceService.off('hceCmd');
      
      hilog.info(DOMAIN, TAG, 'Successfully unsubscribed from APDU commands');
      console.log('[HCEService] ✅ Unsubscribed from APDU commands');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to unsubscribe from APDU: %{public}s', JSON.stringify(error));
      console.log('[HCEService] Unsubscribe error: ' + JSON.stringify(error));
    }
  }

  /**
   * Send APDU response to external NFC reader
   * Uses official API v9+ transmit() method
   */
  sendAPDUResponse(responseData: number[]): Promise<void> {
    if (!this.hceService) {
      let errorMsg = 'HCEService not initialized';
      hilog.error(DOMAIN, TAG, 'Failed to send APDU response: %{public}s', errorMsg);
      console.log('[HCEService] ERROR: ' + errorMsg);
      return Promise.reject(new Error(errorMsg));
    }

    try {
      let hexData = this.arrayToHex(responseData);
      hilog.info(DOMAIN, TAG, 'Sending APDU response: %{public}s', hexData);
      console.log('[HCEService] Sending APDU response: ' + hexData);

      // Use official API v9+ transmit() method
      // This is a synchronous call that immediately sends the data
      this.hceService.transmit(responseData);
      
      hilog.info(DOMAIN, TAG, 'APDU response sent successfully: %{public}s', hexData);
      console.log('[HCEService] ✅ APDU response sent: ' + hexData);
      return Promise.resolve();
    } catch (error) {
      let errorMsg = 'Failed to send APDU response: ' + JSON.stringify(error);
      hilog.error(DOMAIN, TAG, errorMsg);
      console.log('[HCEService] ❌ ' + errorMsg);
      return Promise.reject(error);
    }
  }

  /**
   * Set callback for handling APDU commands
   */
  setApduCommandCallback(callback: (command: number[]) => void): void {
    this.onApduCommand = callback;
    hilog.info(DOMAIN, TAG, 'APDU command callback registered');
    console.log('[HCEService] 📝 APDU command callback registered successfully');
  }

  /**
   * Check if HCE is running
   */
  isRunning(): boolean {
    return this.isHceRunning;
  }

  /**
   * Get HCE status
   */
  getStatus(): string {
    try {
      if (!cardEmulation.hasHceCapability()) {
        return 'HCE not supported';
      }
    } catch {
      return 'Error checking HCE capability';
    }
    return this.isHceRunning ? 'HCE running' : 'HCE stopped';
  }

  /**
   * Helper method to convert byte array to hex string
   */
  private arrayToHex(arr: number[] | Uint8Array): string {
    if (!arr) return '';
    return Array.from(arr).map(b => ('0' + (b & 0xFF).toString(16)).slice(-2)).join(' ').toUpperCase();
  }

  /**
   * Re-initialize APDU subscription after HCE restart (for card switching)
   * This properly re-registers the subscription when switching between different AIDs
   */
  reSubscribeToAPDU(): void {
    if (!this.hceService) {
      hilog.error(DOMAIN, TAG, 'HCEService not initialized, cannot re-subscribe');
      return;
    }

    try {
      hilog.info(DOMAIN, TAG, 'Re-initializing APDU subscription after HCE restart');
      console.log('[HCEService] Re-initializing APDU subscription after HCE restart');

      // Call the standard subscription method again
      // The callback should still be registered from SetApduCommandCallback
      this.subscribeToAPDU();
      
      hilog.info(DOMAIN, TAG, 'Successfully re-subscribed to APDU after HCE restart');
      console.log('[HCEService] ✅ Successfully re-subscribed to APDU');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to re-subscribe to APDU: %{public}s', JSON.stringify(error));
      console.log('[HCEService] ❌ Re-subscription error: ' + JSON.stringify(error));
    }
  }}