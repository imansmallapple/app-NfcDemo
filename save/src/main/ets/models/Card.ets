/**
 * Card Information Model
 */
export interface Card {
  id: string;              // Unique identifier
  name: string;            // Card name (e.g., "My Work Card")
  type: CardType;          // Card type
  uid: string;             // Card UID in hex format
  technology: string[];    // NFC technologies
  description: string;     // Optional description
  color: string;           // Card display color
  createdAt: number;       // Creation timestamp
  updatedAt: number;       // Last update timestamp
}

export enum CardType {
  BANK_CARD = 'bank_card'
}

export const CardTypeLabels: Record<CardType, string> = {
  [CardType.BANK_CARD]: 'Bank Card'
};

export const CardTypeColors: Record<CardType, string> = {
  [CardType.BANK_CARD]: '#9C27B0'       // Purple
};

export function generateCardId(): string {
  return 'card_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
}
