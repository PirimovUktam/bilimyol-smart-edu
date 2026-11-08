export interface TutorMessage {
  id: string;
  sender: 'ai' | 'user';
  text: string;
  time: number;
  feedback?: 'helpful' | 'unhelpful';
}

const conversations = new Map<string, TutorMessage[]>();

export const readTutorHistory = (key: string): TutorMessage[] => conversations.get(key) ?? [];
export const writeTutorHistory = (key: string, messages: TutorMessage[]): void => {
  conversations.set(key, messages.slice(-60));
};
export const clearTutorHistory = (): void => conversations.clear();
