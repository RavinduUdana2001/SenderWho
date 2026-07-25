-- AlterTable
ALTER TABLE `EmailAccount` ADD COLUMN `historyId` VARCHAR(191) NULL,
    ADD COLUMN `lastSyncError` TEXT NULL,
    ADD COLUMN `syncStartedAt` DATETIME(3) NULL;

-- AlterTable
ALTER TABLE `Message` ADD COLUMN `isArchived` BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN `isTrashed` BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN `listUnsubscribePost` BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN `listUnsubscribeUrl` TEXT NULL;

-- CreateIndex
CREATE INDEX `Message_emailAccountId_isTrashed_idx` ON `Message`(`emailAccountId`, `isTrashed`);
