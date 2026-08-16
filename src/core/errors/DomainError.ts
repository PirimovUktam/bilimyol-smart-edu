export class DomainError extends Error {
  constructor(message: string, public readonly code: string = 'DOMAIN_ERROR') {
    super(message);
    this.name = 'DomainError';
  }
}

export class DuplicateActionError extends DomainError {
  constructor(message: string = 'Ushbu amal avval bajarilgan.') {
    super(message, 'DUPLICATE_ACTION');
    this.name = 'DuplicateActionError';
  }
}

export class EntityNotFoundError extends DomainError {
  constructor(entityName: string, id: string) {
    super(`${entityName} topilmadi: ${id}`, 'NOT_FOUND');
    this.name = 'EntityNotFoundError';
  }
}
