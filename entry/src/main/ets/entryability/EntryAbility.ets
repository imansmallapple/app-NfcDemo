import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { tag } from '@kit.ConnectivityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { bundleManager } from '@kit.AbilityKit';
import { vibrator } from '@kit.SensorServiceKit';

const DOMAIN = 0x0000;
const TAG = 'NfcReader';

let nfcTagElementName: bundleManager.ElementName;
let foregroundRegister: boolean = false;
let isFirstOpen: boolean = true;  // Flag to prevent vibration on first app open

export default class EntryAbility extends UIAbility {
  onCreate(want: Want) {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');

    // Check if device supports NFC
    if (!canIUse('SystemCapability.Communication.NFC.Core')) {
      hilog.error(DOMAIN, TAG, 'Device does not support NFC');
      return;
    }

    // Initialize ElementName for readerMode
    nfcTagElementName = {
      bundleName: want.bundleName ?? '',
      abilityName: want.abilityName ?? '',
      moduleName: want.moduleName,
    };

    // If app is launched via NFC tag, handle TagInfo from Intent
    let tagInfo: tag.TagInfo | null = null;
    if (canIUse('SystemCapability.Communication.NFC.Core')) {
      try {
        tagInfo = tag.getTagInfo(want);
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'getTagInfo error = %{public}s', JSON.stringify(error));
      }
    }

    if (tagInfo != null) {
      hilog.info(DOMAIN, TAG, 'Got tagInfo from want, UID: %{public}s', this.arrayToHex(tagInfo.uid || []));
      // Don't vibrate on first app open, only vibrate when readerMode detects cards later
      this.processTagInfo(tagInfo, false);
    } else {
      hilog.info(DOMAIN, TAG, 'No tag info in want, waiting for foreground readerMode');
      isFirstOpen = false;  // Mark first open as complete
    }
  }

  private processTagInfo(tagInfo: tag.TagInfo, shouldVibrate: boolean = true): void {
    hilog.info(DOMAIN, TAG, 'Processing tag info');
    
    // Check if device supports NFC
    if (!canIUse('SystemCapability.Communication.NFC.Core')) {
      hilog.error(DOMAIN, TAG, 'NFC not supported');
      return;
    }

    // Vibration feedback when tag detected (only if shouldVibrate is true)
    if (shouldVibrate) {
      this.triggerVibration();
    }

    if (tagInfo.uid == null) {
      hilog.error(DOMAIN, TAG, 'uid is invalid');
      return;
    }

    // Extract card UID/ID
    let displayId = this.arrayToHex(tagInfo.uid || []);
    
    hilog.info(DOMAIN, TAG, 'Card detected - Serial: %{public}s', displayId);
    console.log('[NfcReader] Card Detected - Serial: ' + displayId);
    
    // Try to detect card type via ISO-DEP AID selection
    let cardType = 'Unknown Card';
    if (tagInfo.technology && tagInfo.technology.includes(tag.ISO_DEP)) {
      this.detectCardTypeViaAPDU(tagInfo).then((detectedType) => {
        this.updateCardUI(displayId, detectedType);
      }).catch(() => {
        // APDU detection failed, use technology-based detection as fallback
        cardType = this.detectCardTypeByTechnology(tagInfo);
        this.updateCardUI(displayId, cardType);
      });
    } else {
      cardType = this.detectCardTypeByTechnology(tagInfo);
      this.updateCardUI(displayId, cardType);
    }
  }

  private updateCardUI(displayId: string, cardType: string): void {
    hilog.info(DOMAIN, TAG, 'Card Type: %{public}s', cardType);
    console.log('[NfcReader] Card Type: ' + cardType);
    
    // Update UI with card info
    let cardInfo = `Serial: ${displayId}`;
    AppStorage.setOrCreate('tagUID', displayId);
    AppStorage.setOrCreate('cardType', cardType);
    AppStorage.setOrCreate('nfcCardInfo', cardInfo);
    
    console.log('[NfcReader] Card Info: ' + cardInfo);
  }

  private async detectCardTypeViaAPDU(tagInfo: tag.TagInfo): Promise<string> {
    try {
      if (!canIUse('SystemCapability.Communication.NFC.Core')) {
        return 'Payment Card (ISO-DEP)';
      }

      let isodepTag = tag.getIsoDep(tagInfo);
      if (!isodepTag) {
        hilog.warn(DOMAIN, TAG, 'Cannot get ISO-DEP connection');
        return 'Payment Card (ISO-DEP)';
      }

      // Connect to the card
      isodepTag.connect();
      hilog.info(DOMAIN, TAG, 'ISO-DEP connected');

      // List of common AIDs to try
      interface AidEntry {
        aid: number[];
        name: string;
      }

      // AIDs from module.json5 configuration
      let bankAid1: number[] = [0xA0, 0x00, 0x00, 0x00, 0x03, 0x10, 0x10];
      let memberAid: number[] = [0xA0, 0x00, 0x00, 0x00, 0x04, 0x10, 0x10];
      let transitAid: number[] = [0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01];
      let bankAid2: number[] = [0xA0, 0x00, 0x00, 0x00, 0x05, 0x10, 0x10];

      let aidsToTry: AidEntry[] = [
        { aid: bankAid1, name: 'Bank Card' },
        { aid: memberAid, name: 'Member Card' },
        { aid: transitAid, name: 'Transit Card' },
        { aid: bankAid2, name: 'ID Card' },
      ];

      // Try to select each AID with timeout
      for (let aidEntry of aidsToTry) {
        try {
          let selectCommand = this.buildSelectCommand(aidEntry.aid);
          // Use transmit() for ISO-DEP APDU communication (HarmonyOS official API)
          // Add timeout: wrap in Promise.race with timeout
          let response: number[] = await Promise.race([
            isodepTag.transmit(selectCommand),
            new Promise<number[]>((_, reject) => 
              setTimeout(() => reject(new Error('APDU timeout')), 1000)
            )
          ]);

          if (response && response.length > 0) {
            // Check for 9000 status (success)
            if (response.length >= 2) {
              let sw1 = response[response.length - 2];
              let sw2 = response[response.length - 1];
              if (sw1 === 0x90 && sw2 === 0x00) {
                hilog.info(DOMAIN, TAG, 'Card AID detected: %{public}s', aidEntry.name);
                console.log('[NfcReader] Detected AID: ' + aidEntry.name);
                return aidEntry.name + ' Card';
              }
            }
          }
        } catch (err) {
          // Continue to next AID on timeout or error
          hilog.debug(DOMAIN, TAG, 'AID selection failed: %{public}s', aidEntry.name);
        }
      }

      return 'Payment Card (ISO-DEP)';
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'ISO-DEP AID detection failed: %{public}s', JSON.stringify(error));
      return 'Payment Card (ISO-DEP)';
    }
  }

  private buildSelectCommand(aid: number[]): number[] {
    // Build SELECT command: 00 A4 04 00 <length> <AID>
    let command: number[] = [0x00, 0xA4, 0x04, 0x00, aid.length];
    for (let byte of aid) {
      command.push(byte);
    }
    return command;
  }

  private detectCardTypeByTechnology(tagInfo: tag.TagInfo): string {
    if (!tagInfo.technology || tagInfo.technology.length === 0) {
      return 'Unknown Card';
    }

    let hasNfcA = false;
    let hasNfcB = false;
    let hasNfcF = false;
    let hasNfcV = false;
    let hasIsoDep = false;

    if (canIUse('SystemCapability.Communication.NFC.Core')) {
      for (let tech of tagInfo.technology) {
        if (tech === tag.NFC_A) {
          hasNfcA = true;
        } else if (tech === tag.NFC_B) {
          hasNfcB = true;
        } else if (tech === tag.NFC_F) {
          hasNfcF = true;
        } else if (tech === tag.NFC_V) {
          hasNfcV = true;
        } else if (tech === tag.ISO_DEP) {
          hasIsoDep = true;
        }
      }
    }

    // Heuristic detection based on technology
    // Priority: specific protocols > generic protocols
    
    if (hasNfcF) {
      return 'FeliCa / Transit Card';
    }
    
    if (hasNfcV) {
      return 'Type V Card (ICODE)';
    }
    
    // ISO-DEP is typically used for payment cards and advanced cards
    if (hasIsoDep && (hasNfcA || hasNfcB)) {
      return 'Payment Card (ISO-DEP)';
    }
    
    if (hasNfcA && !hasNfcB && !hasNfcF && !hasNfcV) {
      return 'NDEF / Data Tag';
    }
    
    if (hasNfcA && hasNfcB) {
      return 'Multi-Tech Card (A+B)';
    }

    return 'Unknown Card Type';
  }

  private arrayToHex(arr: Uint8Array | number[]): string {
    if (!arr) return '';
    return Array.from(arr).map(b => ('0' + (b & 0xFF).toString(16)).slice(-2)).join(' ').toUpperCase();
  }

  private triggerVibration(): void {
    try {
      // Check if device supports vibration
      if (canIUse('SystemCapability.Sensors.MiscDevice')) {
        // Vibrate for 200 milliseconds
        let vibrateEffect: vibrator.VibrateEffect = {
          type: 'time',
          duration: 200
        };
        vibrator.startVibration(vibrateEffect, { usage: 'notification' }).then(() => {
          hilog.info(DOMAIN, TAG, 'Vibration triggered');
        }).catch((err: BusinessError) => {
          hilog.warn(DOMAIN, TAG, 'Vibration failed: %{public}s', JSON.stringify(err));
        });
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'Vibration error: %{public}s', JSON.stringify(error));
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground');
    // Mark first open as complete when entering foreground
    if (isFirstOpen) {
      isFirstOpen = false;
    }
    
    if (nfcTagElementName != undefined && canIUse('SystemCapability.Communication.NFC.Core')) {
      let techList: number[] = [];
      if (canIUse('SystemCapability.Communication.NFC.Core')) {
        techList = [tag.NFC_A, tag.NFC_B, tag.NFC_F, tag.NFC_V, tag.ISO_DEP];
      }
      try {
        if (canIUse('SystemCapability.Communication.NFC.Core')) {
          tag.on('readerMode', nfcTagElementName, techList, (error: BusinessError | null, tagInfo: tag.TagInfo) => {
            if (!error && tagInfo) {
              // Always vibrate when NFC reader mode detects a card
              this.processTagInfo(tagInfo, true);
            } else if (error) {
              hilog.info(DOMAIN, TAG, 'Reader mode error: %{public}s', JSON.stringify(error));
            }
          });
        }
        foregroundRegister = true;
        hilog.info(DOMAIN, TAG, 'Reader mode registered successfully');
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Failed to register reader mode: %{public}s', JSON.stringify(error));
      }
    }
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
    if (foregroundRegister && canIUse('SystemCapability.Communication.NFC.Core')) {
      foregroundRegister = false;
      try {
        if (canIUse('SystemCapability.Communication.NFC.Core')) {
          tag.off('readerMode', nfcTagElementName);
        }
        hilog.info(DOMAIN, TAG, 'Reader mode unregistered');
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Failed to unregister reader mode: %{public}s', JSON.stringify(error));
      }
    }
  }
}