-- CreateTable
CREATE TABLE `users` (
    `id` VARCHAR(191) NOT NULL,
    `phone` VARCHAR(191) NOT NULL,
    `passwordHash` VARCHAR(191) NOT NULL,
    `name` VARCHAR(191) NOT NULL,
    `consentAt` DATETIME(3) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    UNIQUE INDEX `users_phone_key`(`phone`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `stores` (
    `id` VARCHAR(191) NOT NULL,
    `ownerId` VARCHAR(191) NOT NULL,
    `name` VARCHAR(191) NOT NULL,
    `businessTypes` JSON NOT NULL,
    `closedDays` JSON NOT NULL,
    `timezone` VARCHAR(191) NOT NULL DEFAULT 'Asia/Jakarta',
    `dayChangeHour` INTEGER NOT NULL DEFAULT 4,
    `reminderTime` VARCHAR(191) NULL,
    `plan` ENUM('GRATIS', 'PRO', 'PRO_PLUS') NOT NULL DEFAULT 'GRATIS',
    `trialEndsAt` DATETIME(3) NULL,
    `aiReadsThisMonth` INTEGER NOT NULL DEFAULT 0,
    `aiReadsResetAt` DATETIME(3) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `stores_ownerId_idx`(`ownerId`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `categories` (
    `id` VARCHAR(191) NOT NULL,
    `storeId` VARCHAR(191) NOT NULL,
    `name` VARCHAR(191) NOT NULL,
    `direction` ENUM('IN', 'OUT') NOT NULL,
    `countedInProfit` BOOLEAN NOT NULL DEFAULT true,
    `fixed` BOOLEAN NOT NULL DEFAULT false,

    INDEX `categories_storeId_idx`(`storeId`),
    UNIQUE INDEX `categories_storeId_name_direction_key`(`storeId`, `name`, `direction`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `items` (
    `id` VARCHAR(191) NOT NULL,
    `storeId` VARCHAR(191) NOT NULL,
    `name` VARCHAR(191) NOT NULL,
    `normalisedName` VARCHAR(191) NOT NULL,
    `kind` ENUM('SOLD', 'BOUGHT') NOT NULL,
    `categoryId` VARCHAR(191) NULL,
    `savedPrice` INTEGER NULL,
    `unit` VARCHAR(191) NULL,

    INDEX `items_storeId_idx`(`storeId`),
    INDEX `items_categoryId_idx`(`categoryId`),
    UNIQUE INDEX `items_storeId_normalisedName_kind_key`(`storeId`, `normalisedName`, `kind`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `people` (
    `id` VARCHAR(191) NOT NULL,
    `storeId` VARCHAR(191) NOT NULL,
    `name` VARCHAR(191) NOT NULL,
    `whatsappNumber` VARCHAR(191) NULL,

    INDEX `people_storeId_idx`(`storeId`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `transactions` (
    `id` VARCHAR(191) NOT NULL,
    `storeId` VARCHAR(191) NOT NULL,
    `businessDate` DATE NOT NULL,
    `direction` ENUM('IN', 'OUT') NOT NULL,
    `total` INTEGER NOT NULL,
    `personId` VARCHAR(191) NULL,
    `dueDate` DATE NULL,
    `linkedTransactionId` VARCHAR(191) NULL,
    `source` ENUM('TYPED', 'VOICE', 'PHOTO', 'NOTEBOOK') NOT NULL,
    `inputId` VARCHAR(191) NULL,
    `note` TEXT NULL,
    `deletedAt` DATETIME(3) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `transactions_storeId_businessDate_idx`(`storeId`, `businessDate`),
    INDEX `transactions_storeId_direction_businessDate_idx`(`storeId`, `direction`, `businessDate`),
    INDEX `transactions_personId_idx`(`personId`),
    INDEX `transactions_inputId_idx`(`inputId`),
    INDEX `transactions_linkedTransactionId_idx`(`linkedTransactionId`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `lines` (
    `id` VARCHAR(191) NOT NULL,
    `transactionId` VARCHAR(191) NOT NULL,
    `itemId` VARCHAR(191) NULL,
    `categoryId` VARCHAR(191) NULL,
    `quantity` DECIMAL(12, 3) NULL,
    `unit` VARCHAR(191) NULL,
    `unitPrice` INTEGER NULL,
    `lineTotal` INTEGER NOT NULL,
    `discount` INTEGER NOT NULL DEFAULT 0,

    INDEX `lines_transactionId_idx`(`transactionId`),
    INDEX `lines_itemId_idx`(`itemId`),
    INDEX `lines_categoryId_idx`(`categoryId`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `payments` (
    `id` VARCHAR(191) NOT NULL,
    `transactionId` VARCHAR(191) NOT NULL,
    `date` DATE NOT NULL,
    `amount` INTEGER NOT NULL,
    `label` VARCHAR(191) NULL,

    INDEX `payments_transactionId_idx`(`transactionId`),
    INDEX `payments_date_idx`(`date`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `edit_history` (
    `id` VARCHAR(191) NOT NULL,
    `transactionId` VARCHAR(191) NOT NULL,
    `at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `previous` JSON NOT NULL,

    INDEX `edit_history_transactionId_idx`(`transactionId`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `inputs` (
    `id` VARCHAR(191) NOT NULL,
    `storeId` VARCHAR(191) NOT NULL,
    `kind` ENUM('VOICE', 'PHOTO', 'NOTEBOOK', 'TYPED') NOT NULL,
    `transcript` TEXT NULL,
    `photoRef` VARCHAR(191) NULL,
    `imageHash` VARCHAR(191) NULL,
    `status` ENUM('QUEUED', 'READ', 'FAILED') NOT NULL DEFAULT 'QUEUED',
    `model` VARCHAR(191) NULL,
    `tokens` INTEGER NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `inputs_storeId_status_idx`(`storeId`, `status`),
    INDEX `inputs_storeId_imageHash_idx`(`storeId`, `imageHash`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `alerts` (
    `id` VARCHAR(191) NOT NULL,
    `storeId` VARCHAR(191) NOT NULL,
    `rule` VARCHAR(191) NOT NULL,
    `itemId` VARCHAR(191) NULL,
    `categoryId` VARCHAR(191) NULL,
    `entryId` VARCHAR(191) NULL,
    `value` VARCHAR(191) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `seen` BOOLEAN NOT NULL DEFAULT false,
    `muted` BOOLEAN NOT NULL DEFAULT false,

    INDEX `alerts_storeId_seen_idx`(`storeId`, `seen`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `stores` ADD CONSTRAINT `stores_ownerId_fkey` FOREIGN KEY (`ownerId`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `categories` ADD CONSTRAINT `categories_storeId_fkey` FOREIGN KEY (`storeId`) REFERENCES `stores`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `items` ADD CONSTRAINT `items_storeId_fkey` FOREIGN KEY (`storeId`) REFERENCES `stores`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `items` ADD CONSTRAINT `items_categoryId_fkey` FOREIGN KEY (`categoryId`) REFERENCES `categories`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `people` ADD CONSTRAINT `people_storeId_fkey` FOREIGN KEY (`storeId`) REFERENCES `stores`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `transactions` ADD CONSTRAINT `transactions_storeId_fkey` FOREIGN KEY (`storeId`) REFERENCES `stores`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `transactions` ADD CONSTRAINT `transactions_personId_fkey` FOREIGN KEY (`personId`) REFERENCES `people`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `transactions` ADD CONSTRAINT `transactions_inputId_fkey` FOREIGN KEY (`inputId`) REFERENCES `inputs`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `transactions` ADD CONSTRAINT `transactions_linkedTransactionId_fkey` FOREIGN KEY (`linkedTransactionId`) REFERENCES `transactions`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `lines` ADD CONSTRAINT `lines_transactionId_fkey` FOREIGN KEY (`transactionId`) REFERENCES `transactions`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `lines` ADD CONSTRAINT `lines_itemId_fkey` FOREIGN KEY (`itemId`) REFERENCES `items`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `lines` ADD CONSTRAINT `lines_categoryId_fkey` FOREIGN KEY (`categoryId`) REFERENCES `categories`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `payments` ADD CONSTRAINT `payments_transactionId_fkey` FOREIGN KEY (`transactionId`) REFERENCES `transactions`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `edit_history` ADD CONSTRAINT `edit_history_transactionId_fkey` FOREIGN KEY (`transactionId`) REFERENCES `transactions`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `inputs` ADD CONSTRAINT `inputs_storeId_fkey` FOREIGN KEY (`storeId`) REFERENCES `stores`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `alerts` ADD CONSTRAINT `alerts_storeId_fkey` FOREIGN KEY (`storeId`) REFERENCES `stores`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `alerts` ADD CONSTRAINT `alerts_itemId_fkey` FOREIGN KEY (`itemId`) REFERENCES `items`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
