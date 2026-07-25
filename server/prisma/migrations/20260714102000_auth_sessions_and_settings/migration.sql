-- CreateTable
CREATE TABLE `AppSession` (
    `id` VARCHAR(191) NOT NULL,
    `userId` VARCHAR(191) NOT NULL,
    `tokenHash` VARCHAR(64) NOT NULL,
    `expiresAt` DATETIME(3) NOT NULL,
    `lastUsedAt` DATETIME(3) NULL,
    `revokedAt` DATETIME(3) NULL,
    `userAgent` VARCHAR(500) NULL,
    `ipAddress` VARCHAR(64) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    UNIQUE INDEX `AppSession_tokenHash_key`(`tokenHash`),
    INDEX `AppSession_userId_revokedAt_idx`(`userId`, `revokedAt`),
    INDEX `AppSession_expiresAt_idx`(`expiresAt`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `OAuthLoginSession` (
    `id` VARCHAR(191) NOT NULL,
    `secretHash` VARCHAR(64) NOT NULL,
    `provider` ENUM('GOOGLE', 'MICROSOFT', 'YAHOO', 'IMAP') NOT NULL,
    `status` ENUM('PENDING', 'COMPLETED', 'FAILED', 'EXCHANGED') NOT NULL DEFAULT 'PENDING',
    `userId` VARCHAR(191) NULL,
    `expiresAt` DATETIME(3) NOT NULL,
    `exchangedAt` DATETIME(3) NULL,
    `error` TEXT NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL,

    UNIQUE INDEX `OAuthLoginSession_secretHash_key`(`secretHash`),
    INDEX `OAuthLoginSession_status_expiresAt_idx`(`status`, `expiresAt`),
    INDEX `OAuthLoginSession_userId_idx`(`userId`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `UserSettings` (
    `userId` VARCHAR(191) NOT NULL,
    `notificationsEnabled` BOOLEAN NOT NULL DEFAULT true,
    `inboxScanFrequency` VARCHAR(32) NOT NULL DEFAULT 'Auto',
    `theme` VARCHAR(32) NOT NULL DEFAULT 'System',
    `twoFactorEnabled` BOOLEAN NOT NULL DEFAULT false,
    `dataRetention` VARCHAR(64) NOT NULL DEFAULT 'Metadata only',
    `privacyMode` VARCHAR(32) NOT NULL DEFAULT 'Standard',
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL,

    PRIMARY KEY (`userId`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `AppSession` ADD CONSTRAINT `AppSession_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `OAuthLoginSession` ADD CONSTRAINT `OAuthLoginSession_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `UserSettings` ADD CONSTRAINT `UserSettings_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AlterTable
ALTER TABLE `Message` ADD COLUMN `hasAttachments` BOOLEAN NOT NULL DEFAULT false;
