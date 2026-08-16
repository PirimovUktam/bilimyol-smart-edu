import { SubjectType } from '@/core/types/common';

export interface Course {
  id: string;
  title: string;
  subject: SubjectType;
  description: string;
  iconName: string;
  primaryColor: string;
  secondaryColor: string;
  skills: string[]; // skill IDs
  lessons: string[]; // lesson IDs
  totalStudentsEstimate?: number;
}
