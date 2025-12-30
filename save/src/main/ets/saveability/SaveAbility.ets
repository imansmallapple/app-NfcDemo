import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { bundleManager } from '@kit.AbilityKit';
import { HCEService } from '../services/HCEService';

const DOMAIN = 0x0000;
const TAG = 'SaveAbility-HCE';

let nfcElementName: bundleManager.ElementName;

hilog.info(DOMAIN, TAG, '✅ SaveAbility class loaded - HCE Only Mode');

export default class SaveAbility extends UIAbility {
  private hceService: HCEService = HCEService.getInstance();

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      console.log('[SaveAbility-HCE] ========== onCreate START ==========');
      hilog.warn(DOMAIN, TAG, 'onCreate: Initializing HCE NFC Card Emulation');

      // Initialize ElementName for HCE
      nfcElementName = {
        bundleName: want.bundleName ?? '',
        abilityName: want.abilityName ?? '',
        moduleName: want.moduleName,
      };

      console.log('[SaveAbility-HCE] ElementName: ' + nfcElementName.bundleName + '/' + nfcElementName.abilityName);
      hilog.info(DOMAIN, TAG, 'ElementName: bundle=%{public}s, ability=%{public}s, module=%{public}s',
        nfcElementName.bundleName, nfcElementName.abilityName, nfcElementName.moduleName);

      // Initialize HCE service - this checks device HCE capability
      console.log('[SaveAbility-HCE] Initializing HCE service...');
      let initResult = this.hceService.initialize(nfcElementName);
      console.log('[SaveAbility-HCE] HCE initialize: ' + (initResult ? 'SUCCESS' : 'FAILED'));
      hilog.info(DOMAIN, TAG, 'HCE initialization result: %{public}s', initResult ? 'SUCCESS' : 'FAILED');

      console.log('[SaveAbility-HCE] ========== onCreate END ==========');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'CRITICAL ERROR in onCreate: %{public}s', JSON.stringify(error));
      console.log('[SaveAbility-HCE] CRITICAL ERROR: ' + JSON.stringify(error));
    }
  }

  onDestroy(): void {
    hilog.warn(DOMAIN, TAG, 'onDestroy: Stopping HCE service');
    console.log('[SaveAbility-HCE] ========== onDestroy ==========');
    
    try {
      // Stop HCE when app is destroyed
      if (canIUse('SystemCapability.Communication.NFC.Core') && nfcElementName) {
        let stopResult = this.hceService.stopHCE(nfcElementName);
        console.log('[SaveAbility-HCE] HCE stopped: ' + (stopResult ? 'SUCCESS' : 'FAILED'));
        hilog.info(DOMAIN, TAG, 'HCE service stopped');
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Error stopping HCE: %{public}s', JSON.stringify(error));
      console.log('[SaveAbility-HCE] Error stopping HCE: ' + JSON.stringify(error));
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.warn(DOMAIN, TAG, 'onWindowStageCreate: Loading UI');
    console.log('[SaveAbility-HCE] Loading UI page...');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load page: %{public}s', JSON.stringify(err));
        console.log('[SaveAbility-HCE] Failed to load page: ' + JSON.stringify(err));
        return;
      }
      console.log('[SaveAbility-HCE] UI page loaded successfully');
      hilog.info(DOMAIN, TAG, 'UI page loaded successfully');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.warn(DOMAIN, TAG, 'onForeground: Starting HCE card emulation');
    console.log('[SaveAbility-HCE] ========== onForeground START ==========');
    
    try {
      // NOTE: HCE is started by Index.ets UI page, not by SaveAbility
      // SaveAbility only handles APDU callbacks and responses
      // This prevents conflicts between multiple startHCE calls
      
      console.log('[SaveAbility-HCE] ✅ SaveAbility initialized (HCE started by UI page)');
      hilog.warn(DOMAIN, TAG, 'SaveAbility initialized - HCE will be started by UI page');

      // Register APDU callback FIRST (before subscription)
      console.log('[SaveAbility-HCE] Setting up APDU callback...');
      this.hceService.setApduCommandCallback((apduCommand: number[]) => {
        let apduHex = this.arrayToHex(apduCommand);
        hilog.warn(DOMAIN, TAG, '✅ APDU RECEIVED IN CALLBACK: %{public}s', apduHex);
        console.log('[SaveAbility-HCE] ========== ✅ APDU CALLBACK TRIGGERED ==========');
        console.log('[SaveAbility-HCE] ✅ APDU COMMAND RECEIVED: ' + apduHex);
        
        // Generate response for this APDU
        const response = this.generateAPDUResponse(apduCommand);
        let responseHex = this.arrayToHex(response);
        console.log('[SaveAbility-HCE] Generated response: ' + responseHex);
        hilog.info(DOMAIN, TAG, 'Generated APDU response: %{public}s', responseHex);
        
        // Send response immediately
        console.log('[SaveAbility-HCE] >>> SENDING RESPONSE APDU <<<');
        this.hceService.sendAPDUResponse(response).then(() => {
          hilog.info(DOMAIN, TAG, '✅ RESPONSE APDU SENT: %{public}s', responseHex);
          console.log('[SaveAbility-HCE] ✅✅✅ RESPONSE APDU SUCCESSFULLY SENT ✅✅✅');
          AppStorage.setOrCreate('lastApduStatus', '✅ Response: ' + responseHex);
        }).catch((error: Error) => {
          hilog.error(DOMAIN, TAG, '❌ FAILED TO SEND RESPONSE: %{public}s', error.message);
          console.log('[SaveAbility-HCE] ❌❌❌ FAILED TO SEND RESPONSE ❌❌❌');
          AppStorage.setOrCreate('lastApduStatus', '❌ Error: ' + error.message);
        });
      });

      console.log('[SaveAbility-HCE] ✅ APDU callback registered');
      hilog.info(DOMAIN, TAG, '✅ APDU command callback registered successfully');

      // Subscribe to HCE events immediately (callback is already set above)
      console.log('[SaveAbility-HCE] Subscribing to HCE APDU events...');
      this.hceService.subscribeToAPDU();
      console.log('[SaveAbility-HCE] ✅ Subscribed to HCE APDU events');
      hilog.info(DOMAIN, TAG, '✅ Subscribed to APDU event listener');

      // Get and log HCE status
      let status = this.hceService.getStatus();
      console.log('[SaveAbility-HCE] HCE Status: ' + status);
      hilog.info(DOMAIN, TAG, 'HCE Status: %{public}s', status);

      console.log('[SaveAbility-HCE] ✅ SaveAbility APDU handler ready');
      hilog.warn(DOMAIN, TAG, '✅ SaveAbility APDU handler ready and waiting for NFC reader commands');
      console.log('[SaveAbility-HCE] ========== onForeground END ==========');
      
    } catch (error) {
      hilog.error(DOMAIN, TAG, '❌ CRITICAL ERROR in onForeground: %{public}s', JSON.stringify(error));
      console.log('[SaveAbility-HCE] ❌ CRITICAL ERROR: ' + JSON.stringify(error));
    }
  }

  onBackground(): void {
    hilog.warn(DOMAIN, TAG, 'onBackground: App entering background');
    console.log('[SaveAbility-HCE] App entering background - HCE may pause');
  }

  /**
   * Convert byte array to hex string for logging
   */
  private arrayToHex(arr: number[] | Uint8Array): string {
    if (!arr) return '';
    return Array.from(arr).map(b => ('0' + (b & 0xFF).toString(16)).slice(-2)).join(' ').toUpperCase();
  }

  /**
   * Generate APDU response for NFC reader based on command
   * Supports standard card emulation commands
   */
  private generateAPDUResponse(apduCommand: number[]): number[] {
    if (!apduCommand || apduCommand.length === 0) {
      console.log('[SaveAbility-HCE] Invalid APDU command');
      return [0x6F, 0x00]; // Unknown error
    }

    const cla = apduCommand[0]; // Class byte
    const ins = apduCommand[1]; // Instruction byte
    const p1 = apduCommand[2];  // P1
    const p2 = apduCommand[3];  // P2

    let apduDesc = '[CLA:0x' + cla.toString(16).toUpperCase().padStart(2, '0') + 
                   ' INS:0x' + ins.toString(16).toUpperCase().padStart(2, '0') + 
                   ' P1:0x' + p1.toString(16).toUpperCase().padStart(2, '0') + 
                   ' P2:0x' + p2.toString(16).toUpperCase().padStart(2, '0') + ']';
    
    console.log('[SaveAbility-HCE] Processing APDU: ' + apduDesc);

    // SELECT command (0xA4) - AID selection
    if (ins === 0xA4) {
      console.log('[SaveAbility-HCE] → SELECT command, returning AID');
      
      // Extract the requested AID from the APDU command
      // APDU format: 00 A4 04 00 [length] [AID bytes]
      let requestedAIDArray: number[] = [];
      if (apduCommand.length > 5) {
        let aidLength = apduCommand[4];
        for (let i = 5; i < 5 + aidLength && i < apduCommand.length; i++) {
          requestedAIDArray.push(apduCommand[i]);
        }
      }
      
      // Convert requested AID to hex string for logging
      let requestedAIDHex = requestedAIDArray
        .map(b => ('0' + (b & 0xFF).toString(16)).slice(-2).toUpperCase())
        .join('');
      
      console.log('[SaveAbility-HCE] Requested AID: ' + requestedAIDHex);
      
      // Determine card type based on requested AID
      let cardType = 'Unknown Card';
      switch (requestedAIDHex) {
        case 'A0000000031010':
          cardType = 'Bank Card';
          break;
      }
      
      // Update UI with detected card
      AppStorage.setOrCreate('lastApduStatus', '✅ ' + cardType + ' detected');
      
      // Build SELECT response with the requested AID
      // FCI Template: 6F [length] 84 [aidLength] [AID bytes] 90 00
      const selectResponse: number[] = [
        0x6F, // FCI Template tag
        (0x02 + requestedAIDArray.length), // Length: 0x84 tag + length field + AID bytes + 0x90 + 0x00
        0x84, // DF Name tag
        requestedAIDArray.length, // Length of AID
        ...requestedAIDArray, // Requested AID bytes
        0x90, 0x00  // Success (SW1=0x90, SW2=0x00)
      ];
      
      console.log('[SaveAbility-HCE] Responding with AID: ' + cardType + ' (' + requestedAIDHex + ')');
      return selectResponse;
    }

    // GET RESPONSE command (0xC0) - Retrieve response data
    if (ins === 0xC0) {
      console.log('[SaveAbility-HCE] → GET RESPONSE command');
      const responseData = [
        0xCA, 0xFE, 0xBA, 0xBE, // Simulated card data
        0x00, 0x00, 0x10, 0x00, // Balance/Points info
        0x90, 0x00  // Success
      ];
      return responseData;
    }

    // READ BINARY command (0xB0) - Read card memory
    if (ins === 0xB0) {
      console.log('[SaveAbility-HCE] → READ BINARY command');
      const binaryData = [
        0x53, 0x61, 0x76, 0x65, // "Save" in ASCII
        0x43, 0x61, 0x72, 0x64, // "Card" in ASCII  
        0x90, 0x00  // Success
      ];
      return binaryData;
    }

    // UPDATE BINARY command (0xD0) - Write to card
    if (ins === 0xD0) {
      console.log('[SaveAbility-HCE] → UPDATE BINARY command, data written');
      return [0x90, 0x00]; // Success
    }

    // VERIFY command (0x20) - Verify PIN
    if (ins === 0x20) {
      console.log('[SaveAbility-HCE] → VERIFY PIN command, verification success');
      return [0x90, 0x00]; // Success - PIN verified
    }

    // GET CHALLENGE command (0x84) - Request challenge
    if (ins === 0x84) {
      console.log('[SaveAbility-HCE] → GET CHALLENGE command');
      return [
        0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01, // 8-byte challenge
        0x90, 0x00  // Success
      ];
    }

    // Default: Return success for unknown/unsupported commands
    console.log('[SaveAbility-HCE] → Unknown/unsupported APDU, returning success');
    return [0x90, 0x00]; // General success response
  }
}
