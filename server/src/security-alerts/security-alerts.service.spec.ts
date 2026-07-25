import { NotFoundException } from "@nestjs/common";
import { ListSecurityAlertsDto } from "./dto/list-security-alerts.dto";
import { SecurityAlertsService } from "./security-alerts.service";

describe("SecurityAlertsService", () => {
  it("returns a bounded user-scoped page with navigation message IDs", async () => {
    const detectedAt = new Date("2026-07-19T08:00:00.000Z");
    const prisma = {
      mockDataEnabled: false,
      securityAlert: {
        count: jest.fn().mockResolvedValue(3),
        findMany: jest.fn().mockResolvedValue([
          {
            id: "alert-3",
            userId: "user-1",
            senderId: "sender-1",
            messageId: "message-9",
            title: "Suspicious sender",
            reason: "Sender domain changed",
            riskLevel: "HIGH",
            status: "OPEN",
            detectedAt,
            resolvedAt: null,
            sender: { email: "alerts@example.test" },
          },
        ]),
      },
    };
    const service = new SecurityAlertsService(prisma as never);
    const query = Object.assign(new ListSecurityAlertsDto(), {
      page: 2,
      limit: 2,
    });

    await expect(service.list("user-1", query)).resolves.toEqual({
      items: [
        expect.objectContaining({
          id: "alert-3",
          senderId: "sender-1",
          messageId: "message-9",
        }),
      ],
      total: 3,
      page: 2,
      limit: 2,
      hasMore: false,
    });
    expect(prisma.securityAlert.count).toHaveBeenCalledWith({
      where: { userId: "user-1", status: "OPEN" },
    });
    expect(prisma.securityAlert.findMany).toHaveBeenCalledWith({
      where: { userId: "user-1", status: "OPEN" },
      orderBy: [{ riskLevel: "desc" }, { detectedAt: "desc" }],
      skip: 2,
      take: 2,
      include: { sender: true, message: true },
    });
  });

  it("scopes detail lookup to the current user and returns the public UI shape", async () => {
    const detectedAt = new Date("2026-07-19T08:00:00.000Z");
    const prisma = {
      mockDataEnabled: false,
      securityAlert: {
        findFirst: jest.fn().mockResolvedValue({
          id: "alert-1",
          userId: "user-1",
          senderId: "sender-1",
          messageId: null,
          title: "Suspicious sender",
          reason: "Sender domain changed",
          riskLevel: "HIGH",
          status: "OPEN",
          detectedAt,
          resolvedAt: null,
          sender: { email: "alerts@example.test" },
          message: null,
        }),
      },
    };
    const service = new SecurityAlertsService(prisma as never);

    await expect(service.getById("user-1", "alert-1")).resolves.toEqual({
      id: "alert-1",
      senderId: "sender-1",
      messageId: "",
      title: "Suspicious sender",
      email: "alerts@example.test",
      reason: "Sender domain changed",
      time: detectedAt.toISOString(),
      risk: "High Risk",
      colorKey: "danger",
      status: "OPEN",
      identityRiskScore: 0,
      identityRiskLevel: "LOW",
      identityStatus: "UNVERIFIED",
      identityEvidence: [],
      claimedBrand: undefined,
      authenticatedDomain: undefined,
      replyToEmail: undefined,
    });
    expect(prisma.securityAlert.findFirst).toHaveBeenCalledWith({
      where: { id: "alert-1", userId: "user-1" },
      include: { sender: true, message: true },
    });
  });

  it("does not return an alert owned by another user", async () => {
    const prisma = {
      mockDataEnabled: false,
      securityAlert: {
        findFirst: jest.fn().mockResolvedValue(null),
      },
    };
    const service = new SecurityAlertsService(prisma as never);

    await expect(service.getById("user-1", "foreign-alert")).rejects.toThrow(
      NotFoundException,
    );
    expect(prisma.securityAlert.findFirst).toHaveBeenCalledWith({
      where: { id: "foreign-alert", userId: "user-1" },
      include: { sender: true, message: true },
    });
  });

  it("supports dismissing preview alerts without accessing the database", async () => {
    const prisma = {
      mockDataEnabled: true,
      securityAlert: {
        findFirst: jest.fn(),
        update: jest.fn(),
      },
      auditLog: { create: jest.fn() },
    };
    const service = new SecurityAlertsService(prisma as never);

    await expect(
      service.dismiss("preview-user", "alert_bank_security"),
    ).resolves.toMatchObject({
      id: "alert_bank_security",
      status: "DISMISSED",
    });
    expect(prisma.securityAlert.findFirst).not.toHaveBeenCalled();
    expect(prisma.securityAlert.update).not.toHaveBeenCalled();
  });

  it("does not report a failed resolution after the alert changed when audit storage is unavailable", async () => {
    const resolved = { id: "alert-1", status: "RESOLVED" };
    const prisma = {
      mockDataEnabled: false,
      securityAlert: {
        findFirst: jest.fn().mockResolvedValue({ id: "alert-1" }),
        update: jest.fn().mockResolvedValue(resolved),
      },
      auditLog: {
        create: jest.fn().mockRejectedValue(new Error("audit unavailable")),
      },
    };
    const service = new SecurityAlertsService(prisma as never);

    await expect(service.resolve("user-1", "alert-1")).resolves.toBe(resolved);
    expect(prisma.securityAlert.findFirst).toHaveBeenCalledWith({
      where: { id: "alert-1", userId: "user-1" },
      select: { id: true },
    });
  });
});
