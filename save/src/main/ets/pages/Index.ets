import { hilog } from '@kit.PerformanceAnalysisKit';
import { HCEService } from '../services/HCEService';
import { bundleManager } from '@kit.AbilityKit';

const TAG = 'WearableHCE';

interface Card {
  id: string;
  name: string;
  aid: string;
  description: string;
}

@Entry
@Component
struct Index {
  @State hceStatus: string = 'Inactive';
  @State hceRunning: boolean = false;
  @State statusColor: Color = Color.Red;
  @State selectedCardIndex: number = 0;
  @State selectedCardName: string = 'Bank Card';
  @State apduReceived: string = 'Waiting for reader...'; // 新增：显示APDU接收状态
  @State lastApduTime: string = '';  // 新增：最后一次APDU接收时间
  @State aidList: string[] = [
    'A0000000031010'
  ];
  @State cards: Card[] = [
    {
      id: '1',
      name: 'Bank Card',
      aid: 'A0000000031010',
      description: 'Credit/Debit Card (ISO-DEP)'
    }
  ];

  hceService: HCEService = HCEService.getInstance();
  private elementName: bundleManager.ElementName = {
    bundleName: 'com.example.nfc_demo',
    abilityName: 'SaveAbility',
    moduleName: 'save'
  };
  
  aboutToAppear(): void {
    hilog.info(0x0000, TAG, 'Wearable HCE Page started');
    this.hceService.initialize(this.elementName);
    
    // Initialize current AID in AppStorage but don't start HCE
    // All cards start in Inactive state by default
    AppStorage.setOrCreate<string>('currentAID', this.cards[this.selectedCardIndex].aid);
    
    // DO NOT set any APDU callback here - SaveAbility handles that
    // DO NOT call subscribeToAPDU() here - SaveAbility will do it in onForeground
    // Multiple callback registrations or subscriptions will cause conflicts
    
    // Monitor AppStorage for APDU status updates (UI update without callback conflict)
    setInterval(() => {
      let status = AppStorage.get<string>('lastApduStatus') ?? '';
      if (status.includes('Response') && !this.apduReceived.includes('Reader detected')) {
        let now = new Date();
        this.lastApduTime = now.getHours().toString().padStart(2, '0') + ':' + 
                            now.getMinutes().toString().padStart(2, '0') + ':' + 
                            now.getSeconds().toString().padStart(2, '0');
        this.apduReceived = '✅ Reader detected! Response sent!';
        hilog.info(0x0000, TAG, 'APDU response detected - UI updated');
      }
    }, 50); // Check every 50ms
    
    this.updateStatus();
  }

  onPageShow(): void {
    this.updateStatus();
  }

  private updateStatus(): void {
    this.hceRunning = this.hceService.isRunning();
    this.hceStatus = this.hceRunning ? 'Active' : 'Inactive';
    this.statusColor = this.hceRunning ? Color.Green : Color.Red;
  }

  private toggleHCE(): void {
    if (this.hceRunning) {
      // Stop HCE - 断开与NFC reader的连接
      console.log('[Index] ⏹️ Stopping HCE');
      this.hceService.stopHCE(this.elementName);
      
      // 重置UI状态 - Reader Detection变回"Waiting"
      this.hceStatus = 'Inactive';
      this.statusColor = Color.Red;
      this.hceRunning = false;
      this.apduReceived = 'Waiting for reader...'; // 从"Detected"变回"Waiting"
      this.lastApduTime = ''; // 清空最后检测时间
      
      // 清除AppStorage中的APDU状态
      AppStorage.setOrCreate('lastApduStatus', '');
      AppStorage.setOrCreate('detectedCardType', '');
      AppStorage.setOrCreate('detectedAID', '');
      AppStorage.setOrCreate('currentAID', '');  // 清除currentAID
      
      hilog.info(0x0000, TAG, 'HCE stopped and Reader Detection reset');
    } else {
      // Start HCE
      const currentCard = this.cards[this.selectedCardIndex];
      AppStorage.setOrCreate<string>('currentAID', currentCard.aid);  // 设置当前卡片AID
      AppStorage.setOrCreate<string>('currentCardName', currentCard.name);
      
      const aidList: string[] = [currentCard.aid];
      console.log('[Index] 🚀 Starting HCE with AID: ' + aidList[0] + ' (' + currentCard.name + ')');
      
      let success = this.hceService.startHCE(this.elementName, aidList);
      if (success) {
        this.hceStatus = 'Active';
        this.statusColor = Color.Green;
        this.hceRunning = true;
        hilog.info(0x0000, TAG, 'HCE started with AID: %{public}s', currentCard.aid);
      } else {
        this.hceStatus = 'Error';
        this.statusColor = Color.Red;
        hilog.error(0x0000, TAG, 'Failed to start HCE');
      }
    }
  }

  private switchCard(): void {
    // 更新选中的卡片索引
    this.selectedCardIndex = (this.selectedCardIndex + 1) % this.cards.length;
    this.selectedCardName = this.cards[this.selectedCardIndex].name;
    const card = this.cards[this.selectedCardIndex];
    
    // 更新AppStorage中的当前卡片
    AppStorage.setOrCreate<string>('currentAID', card.aid);
    AppStorage.setOrCreate<string>('currentCardName', card.name);
    
    // 停止当前运行的HCE
    if (this.hceRunning) {
      console.log('[Index] 🔄 Switching card from ' + this.cards[(this.selectedCardIndex - 1 + this.cards.length) % this.cards.length].name + ' to ' + card.name);
      this.hceService.stopHCE(this.elementName);
      this.hceRunning = false;
    }
    
    // 重置Reader Detection状态 - 为新卡片准备
    this.apduReceived = 'Waiting for reader...';
    this.lastApduTime = '';
    AppStorage.setOrCreate('detectedCardType', '');
    AppStorage.setOrCreate('detectedAID', '');
    AppStorage.setOrCreate('lastApduStatus', '');
    
    // 将新卡片设置为Inactive状态，需要用户手动点击Start按钮来激活
    this.hceStatus = 'Inactive';
    this.statusColor = Color.Red;
    
    hilog.info(0x0000, TAG, 'Switched to card: %{public}s (AID: %{public}s) - Inactive state', card.name, card.aid);
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Navigation() {
        Scroll() {
          Column({ space: 6 }) {
            // HCE Status
            Column({ space: 2 }) {
              Text('HCE')
                .fontSize(12)
                .fontColor('#999999')
                .textAlign(TextAlign.Center)
                .width('100%')

              Text(this.hceStatus)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.statusColor)
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)

            // Current Card - Compact
            Column({ space: 2 }) {
              Text(this.selectedCardName)
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor('#333333')
                .textAlign(TextAlign.Center)
                .width('100%')

              Text(this.cards[this.selectedCardIndex].description)
                .fontSize(8)
                .fontColor('#888888')
                .textAlign(TextAlign.Center)
                .width('100%')
            }
            .width('90%')
            .padding(6)
            .backgroundColor('rgba(255,255,255,0.7)')
            .borderRadius(20)
            .alignSelf(ItemAlign.Center)

            // Control Buttons - Only Start/Stop (no switch as only one card)
            Row({ space: 6 }) {
              Button(this.hceRunning ? 'Stop' : 'Start', { type: ButtonType.Capsule, stateEffect: true })
                .width('100%')
                .height(40)
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .backgroundColor(this.hceRunning ? '#F44336' : '#4CAF50')
                .fontColor(Color.White)
                .onClick(() => this.toggleHCE())
            }
            .width('95%')
            .justifyContent(FlexAlign.Center)
            .alignSelf(ItemAlign.Center)

            // Active AID - With proper spacing
            Column({ space: 4 }) {
              Text('Active AID')
                .fontSize(9)
                .fontColor('#999999')
                .fontWeight(FontWeight.Bold)
                .textAlign(TextAlign.Center)
                .width('100%')

              Text(this.cards[this.selectedCardIndex].aid)
                .fontSize(9)
                .fontFamily('monospace')
                .fontColor('#1976D2')
                .textAlign(TextAlign.Center)
                .width('100%')
                .lineHeight(1.4)
                .padding({ top: 4, bottom: 4 })
            }
            .width('90%')
            .padding(10)
            .backgroundColor('rgba(255,255,255,0.7)')
            .borderRadius(18)
            .alignSelf(ItemAlign.Center)

            // Reader Detection Status - Simplified display
            Column({ space: 1 }) {
              Text('Reader Detection')
                .fontSize(10)
                .fontColor('#999999')
                .fontWeight(FontWeight.Bold)
                .textAlign(TextAlign.Center)
                .width('100%')

              // Status indicator
              Row({ space: 8 }) {
                Circle()
                  .width(12)
                  .height(12)
                  .fill(this.apduReceived.includes('✅') ? '#4CAF50' : '#FF9800')

                Text(this.apduReceived.includes('✅') ? 'Detected' : 'Waiting')
                  .fontSize(10)
                  .fontColor(this.apduReceived.includes('✅') ? '#4CAF50' : '#FF9800')
                  .fontWeight(FontWeight.Bold)
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .margin({ bottom: 5 })

              if (this.lastApduTime.length > 0) {
                Text('Last: ' + this.lastApduTime)
                  .fontSize(8)
                  .fontColor('#999999')
                  .textAlign(TextAlign.Center)
                  .width('100%')
                  .lineHeight(1.5)
              }
            }
            .width('90%')
            .padding(12)
            .backgroundColor(this.apduReceived.includes('✅') ? 'rgba(76,175,80,0.08)' : 'rgba(255,152,0,0.08)')
            .borderRadius(14)
            .border({ width: 1, color: this.apduReceived.includes('✅') ? '#4CAF50' : '#FF9800' })
            .alignSelf(ItemAlign.Center)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding(8)
        }
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
      }
      .hideToolBar(true)
      .hideTitleBar(true)
      .backgroundColor('#F8F8F8')
      .borderRadius('50%')
      .height('100%')
      .width('100%')
    }
    .height('100%')
    .width('100%')
    .backgroundColor(Color.Black)
  }
}
