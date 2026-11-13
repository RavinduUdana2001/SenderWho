import { SettingsService } from "./settings.service";

describe("SettingsService", () => {
  it("returns the persisted preference state when audit storage is unavailable", async () => {
    const settings = {
      notificationsEnabled: false,
      inboxScanFrequency: "DAILY",
      theme: "DARK",
    };
    const prisma = {
      userSettings: {
        upsert: jest.fn().mockResolvedValue(settings),
        update: jest.fn().mockResolvedValue(settings),
      },
      emailAccount: { count: jest.fn().mockResolvedValue(1) },
      message: { count: jest.fn().mockResolvedValue(0) },
      sender: { count: jest.fn().mockResolvedValue(0) },
      auditLog: {
        create: jest.fn().mockRejectedValue(new Error("audit unavailable")),
      },
    };
    const service = new SettingsService(prisma as never);

    await expect(
      service.updatePreferences("user-1", {
        notificationsEnabled: false,
        inboxScanFrequency: "DAILY",
        theme: "DARK",
      }),
    ).resolves.toMatchObject({ preferences: settings });
    expect(prisma.userSettings.update).toHaveBeenCalledTimes(1);
  });
});

describe("mailbox-scoped settings counts", () => {
  it("keeps archive, trash and sender-control counts in the selected mailbox", async () => {
    const messageCount = jest.fn().mockResolvedValue(2),
      senderCount = jest.fn().mockResolvedValue(1);
    const service = new SettingsService({
      userSettings: { upsert: jest.fn().mockResolvedValue({}) },
      emailAccount: { count: jest.fn().mockResolvedValue(2) },
      message: { count: messageCount },
      sender: { count: senderCount },
      appSession: { count: jest.fn().mockResolvedValue(1) },
    } as never);
    await service.getSettings("owner");
    await service.getPrivacySecurity("owner");
    for (const [args] of [
      ...messageCount.mock.calls,
      ...senderCount.mock.calls,
    ]) {
      expect(args.where).toMatchObject({
        userId: "owner",
        emailAccount: {
          userId: "owner",
          isPrimary: true,
          syncStatus: { not: "DISCONNECTED" },
        },
      });
    }
  });
});
