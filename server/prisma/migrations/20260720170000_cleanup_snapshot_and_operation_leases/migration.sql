ALTER TABLE `Message`
  ADD COLUMN `isImportant` BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE `OAuthLoginSession`
  ADD COLUMN `appSessionId` VARCHAR(191) NULL;

CREATE INDEX `OAuthLoginSession_appSessionId_idx`
  ON `OAuthLoginSession`(`appSessionId`);

ALTER TABLE `EmailAccount`
  MODIFY `syncStatus` ENUM(
    'PENDING',
    'SYNCING',
    'PARTIAL',
    'READY',
    'FAILED',
    'DISCONNECTED'
  ) NOT NULL DEFAULT 'PENDING',
  ADD COLUMN `backfillPageToken` TEXT NULL,
  ADD COLUMN `backfillHistoryId` VARCHAR(255) NULL,
  ADD COLUMN `backfillComplete` BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN `backfillProcessed` INTEGER NOT NULL DEFAULT 0;

UPDATE `Message`
SET `isImportant` = true
WHERE `labels` IS NOT NULL
  AND (
    JSON_CONTAINS(`labels`, '"IMPORTANT"')
    OR JSON_CONTAINS(`labels`, '"STARRED"')
  );

ALTER TABLE `CleanupJob`
  ADD COLUMN `activeKey` VARCHAR(191) NULL;

CREATE UNIQUE INDEX `CleanupJob_activeKey_key`
  ON `CleanupJob`(`activeKey`);

ALTER TABLE `UnsubscribeJob`
  ADD COLUMN `operationKey` VARCHAR(191) NULL;

CREATE UNIQUE INDEX `UnsubscribeJob_operationKey_key`
  ON `UnsubscribeJob`(`operationKey`);

CREATE TABLE `CleanupPlan` (
  `id` VARCHAR(191) NOT NULL,
  `userId` VARCHAR(191) NOT NULL,
  `emailAccountId` VARCHAR(191) NOT NULL,
  `categories` JSON NOT NULL,
  `messageIds` JSON NOT NULL,
  `totalMessages` INTEGER NOT NULL,
  `estimatedSpaceBytes` INTEGER NOT NULL DEFAULT 0,
  `expiresAt` DATETIME(3) NOT NULL,
  `consumedAt` DATETIME(3) NULL,
  `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

  INDEX `CleanupPlan_userId_expiresAt_idx`(`userId`, `expiresAt`),
  INDEX `CleanupPlan_emailAccountId_expiresAt_idx`(`emailAccountId`, `expiresAt`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `CleanupPlan`
  ADD CONSTRAINT `CleanupPlan_userId_fkey`
  FOREIGN KEY (`userId`) REFERENCES `User`(`id`)
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `CleanupPlan`
  ADD CONSTRAINT `CleanupPlan_emailAccountId_fkey`
  FOREIGN KEY (`emailAccountId`) REFERENCES `EmailAccount`(`id`)
  ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE `CleanupJobItem` (
  `id` VARCHAR(191) NOT NULL,
  `cleanupJobId` VARCHAR(191) NOT NULL,
  `messageId` VARCHAR(191) NULL,
  `providerMessageId` VARCHAR(255) NOT NULL,
  `status` VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  `errorCode` VARCHAR(100) NULL,
  `processedAt` DATETIME(3) NULL,
  `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updatedAt` DATETIME(3) NOT NULL,

  UNIQUE INDEX `CleanupJobItem_cleanupJobId_messageId_key`(`cleanupJobId`, `messageId`),
  INDEX `CleanupJobItem_cleanupJobId_status_idx`(`cleanupJobId`, `status`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `CleanupJobItem`
  ADD CONSTRAINT `CleanupJobItem_cleanupJobId_fkey`
  FOREIGN KEY (`cleanupJobId`) REFERENCES `CleanupJob`(`id`)
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `CleanupJobItem`
  ADD CONSTRAINT `CleanupJobItem_messageId_fkey`
  FOREIGN KEY (`messageId`) REFERENCES `Message`(`id`)
  ON DELETE SET NULL ON UPDATE CASCADE;
