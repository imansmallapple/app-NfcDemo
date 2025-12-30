import { Card, CardType, generateCardId } from '../models/Card';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'CardStorageService';
const DOMAIN = 0x0000;

/**
 * Service to manage card storage
 */
export class CardStorageService {
  private static instance: CardStorageService;
  private cards: Map<string, Card> = new Map();

  private constructor() {
    this.loadCards();
  }

  static getInstance(): CardStorageService {
    if (!CardStorageService.instance) {
      CardStorageService.instance = new CardStorageService();
    }
    return CardStorageService.instance;
  }

  /**
   * Add a new card
   */
  addCard(name: string, type: CardType, uid: string, technology: string[], description: string = ''): Card {
    const card: Card = {
      id: generateCardId(),
      name,
      type,
      uid,
      technology,
      description,
      color: this.getColorForType(type),
      createdAt: Date.now(),
      updatedAt: Date.now()
    };

    this.cards.set(card.id, card);
    this.saveCards();
    hilog.info(DOMAIN, TAG, 'Card added: %{public}s', name);
    return card;
  }

  /**
   * Get all cards
   */
  getAllCards(): Card[] {
    return Array.from(this.cards.values());
  }

  /**
   * Get card by ID
   */
  getCard(id: string): Card | undefined {
    return this.cards.get(id);
  }

  /**
   * Get card by UID
   */
  getCardByUid(uid: string): Card | undefined {
    for (const card of this.cards.values()) {
      if (card.uid === uid) {
        return card;
      }
    }
    return undefined;
  }

  /**
   * Update card
   */
  updateCard(id: string, updates: Partial<Card>): Card | undefined {
    const card = this.cards.get(id);
    if (card) {
      const updated: Card = {
        id: card.id,
        name: updates.name || card.name,
        type: updates.type || card.type,
        uid: updates.uid || card.uid,
        technology: updates.technology || card.technology,
        description: updates.description || card.description,
        color: updates.color || card.color,
        createdAt: card.createdAt,
        updatedAt: Date.now()
      };
      this.cards.set(id, updated);
      this.saveCards();
      hilog.info(DOMAIN, TAG, 'Card updated: %{public}s', id);
      return updated;
    }
    return undefined;
  }

  /**
   * Delete card
   */
  deleteCard(id: string): boolean {
    const deleted = this.cards.delete(id);
    if (deleted) {
      this.saveCards();
      hilog.info(DOMAIN, TAG, 'Card deleted: %{public}s', id);
    }
    return deleted;
  }

  /**
   * Clear all cards
   */
  clearAll(): void {
    this.cards.clear();
    this.saveCards();
    hilog.info(DOMAIN, TAG, 'All cards cleared');
  }

  /**
   * Load cards from storage
   */
  private loadCards(): void {
    try {
      const cardsJson = AppStorage.get<string>('savedCards');
      if (cardsJson) {
        const cardsArray: Card[] = JSON.parse(cardsJson);
        cardsArray.forEach(card => {
          this.cards.set(card.id, card);
        });
        hilog.info(DOMAIN, TAG, 'Loaded %{public}d cards', cardsArray.length);
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Error loading cards: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * Save cards to storage
   */
  private saveCards(): void {
    try {
      const cardsArray = Array.from(this.cards.values());
      AppStorage.setOrCreate('savedCards', JSON.stringify(cardsArray));
      hilog.info(DOMAIN, TAG, 'Cards saved: %{public}d', cardsArray.length);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Error saving cards: %{public}s', JSON.stringify(error));
    }
  }

  private getColorForType(type: CardType): string {
    const colorMap: Record<CardType, string> = {
      [CardType.BANK_CARD]: '#9C27B0'
    };
    return colorMap[type] || '#607D8B';
  }
}
