export class AppError extends Error {
  constructor(public status: number, public code: string) {super(code);}
}
export function invariant(value: unknown, status: number, code: string): asserts value {
  if (!value) throw new AppError(status,code);
}
export function safeCode(error: unknown): string {
  return error instanceof AppError ? error.code : 'INTERNAL_ERROR';
}
