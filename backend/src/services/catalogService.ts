import { Prisma, type Category, type Item, type Person } from "@prisma/client";
import { prisma } from "../db.js";
import { ApiError } from "../errors.js";
import { normaliseName } from "./normaliseName.js";

// A store's items, people and categories (contract "Store and setup"). Every
// query is scoped by storeId from the token, so an id from another store is
// simply not found.

export type ItemKind = "SOLD" | "BOUGHT";
export type ItemJson = { id: string; name: string; kind: ItemKind; unit: string | null; savedPrice: number | null; categoryId: string | null };
export type PersonJson = { id: string; name: string; whatsappNumber: string | null };
export type CategoryJson = { id: string; name: string; direction: "IN" | "OUT"; countedInProfit: boolean; fixed: boolean };

export type ItemInput = { name: string; kind: ItemKind; unit: string | null; savedPrice: number | null; categoryId: string | null };
export type ItemChanges = Partial<Omit<ItemInput, "kind">>;

// ---- Items ------------------------------------------------------------------

export async function listItems(storeId: string, filter: { q: string | null; kind: ItemKind | null }): Promise<ItemJson[]> {
  const items = await prisma.item.findMany({
    where: {
      storeId,
      ...(filter.kind === null ? {} : { kind: filter.kind }),
      ...(filter.q === null ? {} : { normalisedName: { contains: normaliseName(filter.q) } }),
    },
    orderBy: { name: "asc" },
  });
  return items.map(toItemJson);
}

export async function createItem(storeId: string, input: ItemInput): Promise<ItemJson> {
  await requireCategory(storeId, input.categoryId, input.kind);
  const data = { storeId, ...input, normalisedName: normaliseName(input.name) };
  return toItemJson(await withUniqueName(() => prisma.item.create({ data }), "Barang ini sudah ada"));
}

export async function updateItem(storeId: string, itemId: string, changes: ItemChanges): Promise<ItemJson> {
  const item = await findOwned(prisma.item.findFirst({ where: { id: itemId, storeId } }), "Barang tidak ditemukan");
  if (changes.categoryId !== undefined) {
    await requireCategory(storeId, changes.categoryId, item.kind);
  }
  const data = changes.name === undefined ? changes : { ...changes, normalisedName: normaliseName(changes.name) };
  return toItemJson(await withUniqueName(() => prisma.item.update({ where: { id: itemId }, data }), "Barang ini sudah ada"));
}

// Entries keep their lines: Line.itemId is set to null (schema onDelete).
export async function deleteItem(storeId: string, itemId: string): Promise<void> {
  const { count } = await prisma.item.deleteMany({ where: { id: itemId, storeId } });
  if (count === 0) {
    throw new ApiError({ code: "NOT_FOUND", message: "Barang tidak ditemukan" });
  }
}

// ---- People -----------------------------------------------------------------

export async function listPeople(storeId: string, q: string | null): Promise<PersonJson[]> {
  const people = await prisma.person.findMany({
    where: { storeId, ...(q === null ? {} : { name: { contains: q.trim() } }) },
    orderBy: { name: "asc" },
  });
  return people.map(toPersonJson);
}

export async function createPerson(storeId: string, input: { name: string; whatsappNumber: string | null }): Promise<PersonJson> {
  return toPersonJson(await prisma.person.create({ data: { storeId, ...input } }));
}

export async function updatePerson(storeId: string, personId: string, changes: Partial<{ name: string; whatsappNumber: string | null }>): Promise<PersonJson> {
  await findOwned(prisma.person.findFirst({ where: { id: personId, storeId } }), "Orang tidak ditemukan");
  return toPersonJson(await prisma.person.update({ where: { id: personId }, data: changes }));
}

// Their entries stay, without a person (schema onDelete).
export async function deletePerson(storeId: string, personId: string): Promise<void> {
  const { count } = await prisma.person.deleteMany({ where: { id: personId, storeId } });
  if (count === 0) {
    throw new ApiError({ code: "NOT_FOUND", message: "Orang tidak ditemukan" });
  }
}

// ---- Categories -------------------------------------------------------------

export async function listCategories(storeId: string): Promise<CategoryJson[]> {
  const categories = await prisma.category.findMany({ where: { storeId }, orderBy: [{ fixed: "desc" }, { name: "asc" }] });
  return categories.map(toCategoryJson);
}

export async function createCategory(storeId: string, input: { name: string; direction: "IN" | "OUT"; countedInProfit: boolean }): Promise<CategoryJson> {
  return toCategoryJson(await withUniqueName(() => prisma.category.create({ data: { storeId, ...input, fixed: false } }), "Kategori ini sudah ada"));
}

export async function updateCategory(storeId: string, categoryId: string, changes: Partial<{ name: string; countedInProfit: boolean }>): Promise<CategoryJson> {
  const category = await findOwned(prisma.category.findFirst({ where: { id: categoryId, storeId } }), "Kategori tidak ditemukan");
  requireNotFixed(category, "Kategori tetap tidak bisa diubah");
  return toCategoryJson(await withUniqueName(() => prisma.category.update({ where: { id: categoryId }, data: changes }), "Kategori ini sudah ada"));
}

// Spec §4.2: fixed categories cannot be deleted. Lines and items of a deleted
// category keep existing without one (schema onDelete).
export async function deleteCategory(storeId: string, categoryId: string): Promise<void> {
  const category = await findOwned(prisma.category.findFirst({ where: { id: categoryId, storeId } }), "Kategori tidak ditemukan");
  requireNotFixed(category, "Kategori tetap tidak bisa dihapus");
  await prisma.category.delete({ where: { id: categoryId } });
}

// ---- Shared -----------------------------------------------------------------

// An item's category must be this store's, and point the same way: a sold item
// in a money-in category, a bought item in a money-out one.
async function requireCategory(storeId: string, categoryId: string | null, kind: ItemKind): Promise<void> {
  if (categoryId === null) {
    return;
  }
  const category = await prisma.category.findFirst({ where: { id: categoryId, storeId } });
  if (category === null || category.direction !== (kind === "SOLD" ? "IN" : "OUT")) {
    throw new ApiError({ code: "VALIDATION_FAILED", message: "Kategori tidak cocok", fields: { categoryId: "Kategori tidak cocok" } });
  }
}

function requireNotFixed(category: Category, message: string): void {
  if (category.fixed) {
    throw new ApiError({ code: "VALIDATION_FAILED", message, fields: { categoryId: message } });
  }
}

async function findOwned<T>(lookup: Promise<T | null>, notFoundMessage: string): Promise<T> {
  const record = await lookup;
  if (record === null) {
    throw new ApiError({ code: "NOT_FOUND", message: notFoundMessage });
  }
  return record;
}

// The database's unique index decides a duplicate name, even for two requests at once.
async function withUniqueName<T>(write: () => Promise<T>, message: string): Promise<T> {
  try {
    return await write();
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
      throw new ApiError({ code: "VALIDATION_FAILED", message, fields: { name: message } });
    }
    throw error;
  }
}

function toItemJson(item: Item): ItemJson {
  return { id: item.id, name: item.name, kind: item.kind, unit: item.unit, savedPrice: item.savedPrice, categoryId: item.categoryId };
}

function toPersonJson(person: Person): PersonJson {
  return { id: person.id, name: person.name, whatsappNumber: person.whatsappNumber };
}

function toCategoryJson(category: Category): CategoryJson {
  return { id: category.id, name: category.name, direction: category.direction, countedInProfit: category.countedInProfit, fixed: category.fixed };
}
