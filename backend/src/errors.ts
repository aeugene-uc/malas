import type { NextFunction, Request, Response } from "express";

export type ApiErrorCode =
  | "VALIDATION_FAILED"
  | "UNAUTHORIZED"
  | "FORBIDDEN"
  | "CONSENT_REQUIRED"
  | "NOT_FOUND"
  | "IDEMPOTENCY_CONFLICT"
  | "PLAN_LIMIT_REACHED"
  | "INTERNAL";

const statusByCode: Record<ApiErrorCode, number> = {
  VALIDATION_FAILED: 400,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  CONSENT_REQUIRED: 403,
  NOT_FOUND: 404,
  IDEMPOTENCY_CONFLICT: 409,
  PLAN_LIMIT_REACHED: 429,
  INTERNAL: 500,
};

export class ApiError extends Error {
  readonly code: ApiErrorCode;
  readonly fields: Record<string, string>;

  constructor(options: { code: ApiErrorCode; message: string; fields?: Record<string, string> }) {
    super(options.message);
    this.name = "ApiError";
    this.code = options.code;
    this.fields = options.fields ?? {};
  }

  get status(): number {
    return statusByCode[this.code];
  }
}

export function handleNotFound(_req: Request, res: Response): void {
  res.status(404).json({ error: { code: "NOT_FOUND", message: "Rute tidak ditemukan", fields: {} } });
}

// Express needs all four parameters to recognise this as an error handler.
export function handleError(error: unknown, _req: Request, res: Response, next: NextFunction): void {
  if (res.headersSent) {
    next(error);
    return;
  }
  if (error instanceof ApiError) {
    res.status(error.status).json({
      error: { code: error.code, message: error.message, fields: error.fields },
    });
    return;
  }
  // An unexpected error is logged in full and reported without its details, so
  // a stack trace never reaches an owner's phone.
  console.error(error);
  res.status(500).json({
    error: { code: "INTERNAL", message: "Ada masalah di server", fields: {} },
  });
}
