import { PrismaClient } from "@prisma/client";

// One client for the whole process. It connects on first query, so importing
// this in a test that never queries does not need a database.
export const prisma = new PrismaClient();
