class DomainError implements Exception {
  final String message;
  final String code;

  const DomainError(this.message, {this.code = 'DOMAIN_ERROR'});

  @override
  String toString() => 'DomainError: $message (code: $code)';
}

class DuplicateActionError extends DomainError {
  const DuplicateActionError([super.message = 'Ushbu amal avval bajarilgan.'])
      : super(code: 'DUPLICATE_ACTION');
}

class EntityNotFoundError extends DomainError {
  final String entityName;
  final String id;

  EntityNotFoundError(this.entityName, this.id)
      : super('$entityName topilmadi: $id', code: 'NOT_FOUND');
}
