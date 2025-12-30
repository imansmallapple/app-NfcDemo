import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = "NFC_UI"

interface SavedCard {
  id: string;
  name: string;
  type: string;
  uid: string;
  technology: string[];
  description: string;
  color: string;
  createdAt: number;
  updatedAt: number;
}

@Entry
@Component
struct Index {
  @State nfcStatus: string = 'Approach card';
  @StorageLink('tagUID') tagUID: string = '';
  @StorageLink('cardType') cardType: string = ''; // 新增：卡片类型
  @StorageLink('nfcCardInfo') nfcCardInfo: string = '';
  @StorageLink('selectedCardId') selectedCardId: string = '';
  @StorageLink('selectedCardInfo') selectedCardInfo: string = '';
  @State toastMessage: string = '';
  @State showToast: boolean = false;
  @State lastTagUID: string = '';
  @State selectedCard: SavedCard | null = null;
  @State showCardDetails: boolean = false;
  @State cardMatched: boolean = false;

  aboutToAppear(): void {
    if (canIUse("SystemCapability.Communication.NFC.Core")) {
      hilog.info(0x0000, TAG, "Device supports NFC");
    } else {
      hilog.warn(0x0000, TAG, "Device does not support NFC");
      this.nfcStatus = 'NFC not supported';
    }
    this.loadSelectedCard();
  }

  onPageShow(): void {
    this.loadSelectedCard();
    // Watch for tagUID changes and show toast when detected
    if (this.tagUID && this.tagUID !== this.lastTagUID) {
      this.lastTagUID = this.tagUID;
      this.checkCardMatch();
      this.toastMessage = `Card detected: ${this.tagUID}`;
      this.showToast = true;
      // Auto-hide toast after 2 seconds
      setTimeout(() => {
        this.showToast = false;
      }, 2000);
    } else if (!this.tagUID && this.lastTagUID) {
      this.lastTagUID = '';
      this.cardMatched = false;
    }
  }

  private loadSelectedCard(): void {
    const cardInfoStr = AppStorage.get<string>('selectedCardInfo');
    if (cardInfoStr) {
      try {
        this.selectedCard = JSON.parse(cardInfoStr);
        hilog.info(0x0000, TAG, 'Loaded selected card: %{public}s', this.selectedCard?.name || 'Unknown');
      } catch (error) {
        hilog.error(0x0000, TAG, 'Failed to parse card info: %{public}s', JSON.stringify(error));
      }
    } else {
      this.selectedCard = null;
    }
  }

  private checkCardMatch(): void {
    if (this.selectedCard && this.tagUID) {
      this.cardMatched = this.selectedCard.uid === this.tagUID;
      if (this.cardMatched) {
        this.showCardDetails = true;
        hilog.info(0x0000, TAG, 'Card matched: %{public}s', this.selectedCard.name);
      }
    }
  }

  build() {
    Stack() {
      Navigation() {
        Column({ space: 12 }) {
          // Title
          Text('NFC Reader')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .textAlign(TextAlign.Center)
            .width('100%')
            .padding({ top: 12 })
            .fontColor('#1976D2')

          // Selected card info
          if (this.selectedCard) {
            Column() {
              Text('Selected Card:')
                .fontSize(11)
                .fontColor('#666')
                .margin({ bottom: 4 })

              Text(this.selectedCard.name)
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
            }
            .width('90%')
            .padding(10)
            .backgroundColor(this.selectedCard.color)
            .borderRadius(6)
            .alignItems(HorizontalAlign.Center)
          }

          Blank()
            .layoutWeight(1)

          // Status display
          if (this.tagUID == '') {
            // Not detected state
            Column() {
              Text('📳')
                .fontSize(48)
                .textAlign(TextAlign.Center)
                .margin({ bottom: 12 })

              Text('Ready')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .textAlign(TextAlign.Center)
                .fontColor('#666')
            }
            .width('90%')
            .height(100)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          } else {
            // Detected state - show card information without type judgment
            Column({ space: 8 }) {
              Column({ space: 4 }) {
                if (this.cardMatched) {
                  Text('✅ CARD MATCHED')
                    .fontSize(12)
                    .fontColor('#4CAF50')
                    .fontWeight(FontWeight.Bold)
                } else {
                  Text('🔍 CARD DETECTED')
                    .fontSize(12)
                    .fontColor('#1976D2')
                    .fontWeight(FontWeight.Bold)
                }

                Divider()
                  .strokeWidth(1)
                  .color('#E0E0E0')
                  .width('80%')

                Text('Serial Number')
                  .fontSize(9)
                  .fontColor('#999')

                Text(this.tagUID)
                  .fontSize(11)
                  .width('85%')
                  .textAlign(TextAlign.Center)
                  .padding(8)
                  .backgroundColor('#F5F5F5')
                  .borderRadius(4)
                  .fontColor('#333333')
                  .fontWeight(FontWeight.Bold)
                  .fontFamily('monospace')

                // Card type display
                if (this.cardType) {
                  Column() {
                    Divider()
                      .strokeWidth(1)
                      .color('#E0E0E0')
                      .width('80%')
                      .margin({ top: 8, bottom: 4 })

                    Text('Card Type')
                      .fontSize(9)
                      .fontColor('#999')

                    Text(this.cardType)
                      .fontSize(11)
                      .width('85%')
                      .textAlign(TextAlign.Center)
                      .padding(6)
                      .backgroundColor('#E8F5E9')
                      .borderRadius(4)
                      .fontColor('#2E7D32')
                      .fontWeight(FontWeight.Medium)
                  }
                }
              }
              .width('95%')
              .padding(12)
              .backgroundColor('#FFFFFF')
              .borderRadius(8)
              .alignItems(HorizontalAlign.Center)
              .border({ width: 1, color: '#CCCCCC' })
            }
            .width('100%')
            .padding(12)
            .alignItems(HorizontalAlign.Center)
          }

          Blank()
            .layoutWeight(1)

          // Bottom hint
          Text('▶ Approach card to read')
            .fontSize(13)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Medium)
            .textAlign(TextAlign.Center)
            .width('90%')
            .padding({ top: 10, bottom: 10, left: 16, right: 16 })
            .backgroundColor('#1976D2')
            .borderRadius(8)
            .margin({ bottom: 16 })
        }
        .height('100%')
        .width('100%')
        .padding(12)
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(HorizontalAlign.Center)
      }
      .hideTitleBar(true)
      .hideToolBar(true)
      .backgroundColor('#FAFAFA')
      .borderRadius('50%')

      // Toast notification
      if (this.showToast && this.toastMessage) {
        Column() {
          Text(this.toastMessage)
            .fontSize(12)
            .fontColor('#FFFFFF')
            .textAlign(TextAlign.Center)
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        }
        .position({ bottom: '20%' })
        .backgroundColor('rgba(0, 0, 0, 0.8)')
        .borderRadius(6)
        .padding(8)
      }
    }
    .width('100%')
    .height('100%')
  }
}