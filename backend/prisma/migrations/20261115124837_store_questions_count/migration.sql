-- AlterTable
ALTER TABLE `stores` ADD COLUMN `questionsResetAt` DATETIME(3) NULL,
    ADD COLUMN `questionsThisMonth` INTEGER NOT NULL DEFAULT 0;
