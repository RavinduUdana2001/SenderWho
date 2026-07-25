-- CreateTable
CREATE TABLE `User` (
    `id` VARCHAR(191) NOT NULL,
    `email` VARCHAR(191) NOT NULL,
    `displayName` VARCHAR(191) NULL,
    `avatarUrl` VARCHAR(191) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL,
    `deletedAt` DATETIME(3) NULL,

    UNIQUE INDEX `User_email_key`(`email`),
    INDEX `User_deletedAt_idx`(`deletedAt`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `EmailAccount` (
    `id` VARCHAR(191) NOT NULL,
    `userId` VARCHAR(191) NOT NULL,
    `provider` ENUM('GOOGLE', 'MICROSOFT', 'YAHOO', 'IMAP') NOT NULL,
    `providerAccountId` VARCHAR(191) NOT NULL,
    `emailAddress` VARCHAR(191) NOT NULL,
    `displayName` VARCHAR(191) NULL,
    `accessTokenEncrypted` TEXT NULL,
    `refreshTokenEncrypted` TEXT NULL,
    `tokenExpiresAt` DATETIME(3) NULL,
    `scopes` JSON NULL,
    `syncStatus` ENUM('PENDING', 'SYNCING', 'READY', 'FAILED', 'DISCONNECTED') NOT NULL DEFAULT 'PENDING',
    `lastSyncedAt` DATETIME(3) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL,

    INDEX `EmailAccount_userId_emailAddress_idx`(`userId`, `emailAddress`),
    INDEX `EmailAccount_syncStatus_idx`(`syncStatus`),
    UNIQUE INDEX `EmailAccount_provider_providerAccountId_key`(`provider`, `providerAccountId`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Sender` (
    `id` VARCHAR(191) NOT NULL,
    `userId` VARCHAR(191) NOT NULL,
    `emailAccountId` VARCHAR(191) NOT NULL,
    `name` VARCHAR(191) NULL,
    `email` VARCHAR(191) NOT NULL,
    `domain` VARCHAR(191) NOT NULL,
    `category` ENUM('IMPORTANT', 'PEOPLE', 'ORDERS', 'FINANCE', 'NEWSLETTERS', 'PROMOTIONS', 'TRAVEL', 'SOCIAL', 'SPAM', 'UNKNOWN') NOT NULL DEFAULT 'UNKNOWN',
    `trustScore` INTEGER NOT NULL DEFAULT 50,
    `riskLevel` ENUM('LOW', 'MEDIUM', 'HIGH', 'CRITICAL') NOT NULL DEFAULT 'LOW',
    `firstSeenAt` DATETIME(3) NULL,
    `lastSeenAt` DATETIME(3) NULL,
    `totalMessages` INTEGER NOT NULL DEFAULT 0,
    `unreadMessages` INTEGER NOT NULL DEFAULT 0,
    `isBlocked` BOOLEAN NOT NULL DEFAULT false,
    `isTrusted` BOOLEAN NOT NULL DEFAULT false,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL,

    INDEX `Sender_userId_category_idx`(`userId`, `category`),
    INDEX `Sender_userId_riskLevel_idx`(`userId`, `riskLevel`),
    INDEX `Sender_domain_idx`(`domain`),
    UNIQUE INDEX `Sender_emailAccountId_email_key`(`emailAccountId`, `email`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Message` (
    `id` VARCHAR(191) NOT NULL,
    `userId` VARCHAR(191) NOT NULL,
    `emailAccountId` VARCHAR(191) NOT NULL,
    `senderId` VARCHAR(191) NULL,
    `providerMessageId` VARCHAR(191) NOT NULL,
    `threadId` VARCHAR(191) NULL,
    `subject` VARCHAR(191) NULL,
    `snippet` TEXT NULL,
    `receivedAt` DATETIME(3) NOT NULL,
    `isRead` BOOLEAN NOT NULL DEFAULT false,
    `labels` JSON NULL,
    `riskFlags` JSON NULL,
    `sizeBytes` INTEGER NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `Message_userId_receivedAt_idx`(`userId`, `receivedAt`),
    INDEX `Message_senderId_idx`(`senderId`),
    INDEX `Message_isRead_idx`(`isRead`),
    UNIQUE INDEX `Message_emailAccountId_providerMessageId_key`(`emailAccountId`, `providerMessageId`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `SecurityAlert` (
    `id` VARCHAR(191) NOT NULL,
    `userId` VARCHAR(191) NOT NULL,
    `emailAccountId` VARCHAR(191) NOT NULL,
    `senderId` VARCHAR(191) NULL,
    `messageId` VARCHAR(191) NULL,
    `title` VARCHAR(191) NOT NULL,
    `reason` TEXT NOT NULL,
    `riskLevel` ENUM('LOW', 'MEDIUM', 'HIGH', 'CRITICAL') NOT NULL,
    `status` ENUM('OPEN', 'RESOLVED', 'DISMISSED') NOT NULL DEFAULT 'OPEN',
    `detectedAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `resolvedAt` DATETIME(3) NULL,

    INDEX `SecurityAlert_userId_status_idx`(`userId`, `status`),
    INDEX `SecurityAlert_riskLevel_idx`(`riskLevel`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `CleanupSuggestion` (
    `id` VARCHAR(191) NOT NULL,
    `userId` VARCHAR(191) NOT NULL,
    `emailAccountId` VARCHAR(191) NOT NULL,
    `category` ENUM('MARKETING', 'NEWSLETTERS', 'SPAM', 'OLD_UNREAD', 'LARGE_ATTACHMENTS') NOT NULL,
    `messageCount` INTEGER NOT NULL,
    `estimatedSpaceBytes` INTEGER NOT NULL DEFAULT 0,
    `status` ENUM('QUEUED', 'RUNNING', 'COMPLETED', 'FAILED', 'CANCELED') NOT NULL DEFAULT 'QUEUED',
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `CleanupSuggestion_userId_category_idx`(`userId`, `category`),
    INDEX `CleanupSuggestion_emailAccountId_idx`(`emailAccountId`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `CleanupJob` (
    `id` VARCHAR(191) NOT NULL,
    `userId` VARCHAR(191) NOT NULL,
    `emailAccountId` VARCHAR(191) NOT NULL,
    `status` ENUM('QUEUED', 'RUNNING', 'COMPLETED', 'FAILED', 'CANCELED') NOT NULL DEFAULT 'QUEUED',
    `totalMessages` INTEGER NOT NULL DEFAULT 0,
    `processedMessages` INTEGER NOT NULL DEFAULT 0,
    `failedMessages` INTEGER NOT NULL DEFAULT 0,
    `startedAt` DATETIME(3) NULL,
    `completedAt` DATETIME(3) NULL,
    `metadata` JSON NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL,

    INDEX `CleanupJob_userId_status_idx`(`userId`, `status`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `UnsubscribeJob` (
    `id` VARCHAR(191) NOT NULL,
    `userId` VARCHAR(191) NOT NULL,
    `senderId` VARCHAR(191) NOT NULL,
    `status` ENUM('QUEUED', 'RUNNING', 'COMPLETED', 'FAILED', 'CANCELED') NOT NULL DEFAULT 'QUEUED',
    `method` ENUM('LIST_UNSUBSCRIBE_HEADER', 'UNSUBSCRIBE_LINK', 'MANUAL') NOT NULL,
    `unsubscribeUrl` TEXT NULL,
    `metadata` JSON NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `completedAt` DATETIME(3) NULL,

    INDEX `UnsubscribeJob_userId_status_idx`(`userId`, `status`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `AuditLog` (
    `id` VARCHAR(191) NOT NULL,
    `userId` VARCHAR(191) NULL,
    `action` VARCHAR(191) NOT NULL,
    `targetType` VARCHAR(191) NULL,
    `targetId` VARCHAR(191) NULL,
    `metadata` JSON NULL,
    `ipAddress` VARCHAR(191) NULL,
    `userAgent` VARCHAR(191) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `AuditLog_userId_createdAt_idx`(`userId`, `createdAt`),
    INDEX `AuditLog_action_idx`(`action`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `EmailAccount` ADD CONSTRAINT `EmailAccount_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Sender` ADD CONSTRAINT `Sender_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Sender` ADD CONSTRAINT `Sender_emailAccountId_fkey` FOREIGN KEY (`emailAccountId`) REFERENCES `EmailAccount`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Message` ADD CONSTRAINT `Message_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Message` ADD CONSTRAINT `Message_emailAccountId_fkey` FOREIGN KEY (`emailAccountId`) REFERENCES `EmailAccount`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Message` ADD CONSTRAINT `Message_senderId_fkey` FOREIGN KEY (`senderId`) REFERENCES `Sender`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `SecurityAlert` ADD CONSTRAINT `SecurityAlert_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `SecurityAlert` ADD CONSTRAINT `SecurityAlert_emailAccountId_fkey` FOREIGN KEY (`emailAccountId`) REFERENCES `EmailAccount`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `SecurityAlert` ADD CONSTRAINT `SecurityAlert_senderId_fkey` FOREIGN KEY (`senderId`) REFERENCES `Sender`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `SecurityAlert` ADD CONSTRAINT `SecurityAlert_messageId_fkey` FOREIGN KEY (`messageId`) REFERENCES `Message`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `CleanupSuggestion` ADD CONSTRAINT `CleanupSuggestion_emailAccountId_fkey` FOREIGN KEY (`emailAccountId`) REFERENCES `EmailAccount`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `CleanupJob` ADD CONSTRAINT `CleanupJob_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `CleanupJob` ADD CONSTRAINT `CleanupJob_emailAccountId_fkey` FOREIGN KEY (`emailAccountId`) REFERENCES `EmailAccount`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `UnsubscribeJob` ADD CONSTRAINT `UnsubscribeJob_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `UnsubscribeJob` ADD CONSTRAINT `UnsubscribeJob_senderId_fkey` FOREIGN KEY (`senderId`) REFERENCES `Sender`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `AuditLog` ADD CONSTRAINT `AuditLog_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `User`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
