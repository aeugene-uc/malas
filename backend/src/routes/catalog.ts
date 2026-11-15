import { Router } from "express";
import { requireAuth, requireConsent } from "../auth.js";
import * as catalogController from "../controllers/catalogController.js";
import * as storeController from "../controllers/storeController.js";

// The store's settings and its items, people and categories. Reading needs a
// signed-in owner; every write also needs consent (UU 27/2022).

export const catalogRouter = Router();

catalogRouter.get("/stores/:id", requireAuth, storeController.getStore);
catalogRouter.patch("/stores/:id", requireAuth, requireConsent, storeController.updateStore);

catalogRouter.get("/items", requireAuth, catalogController.listItems);
catalogRouter.post("/items", requireAuth, requireConsent, catalogController.createItem);
catalogRouter.patch("/items/:id", requireAuth, requireConsent, catalogController.updateItem);
catalogRouter.delete("/items/:id", requireAuth, requireConsent, catalogController.deleteItem);

catalogRouter.get("/people", requireAuth, catalogController.listPeople);
catalogRouter.post("/people", requireAuth, requireConsent, catalogController.createPerson);
catalogRouter.patch("/people/:id", requireAuth, requireConsent, catalogController.updatePerson);
catalogRouter.delete("/people/:id", requireAuth, requireConsent, catalogController.deletePerson);

catalogRouter.get("/categories", requireAuth, catalogController.listCategories);
catalogRouter.post("/categories", requireAuth, requireConsent, catalogController.createCategory);
catalogRouter.patch("/categories/:id", requireAuth, requireConsent, catalogController.updateCategory);
catalogRouter.delete("/categories/:id", requireAuth, requireConsent, catalogController.deleteCategory);
