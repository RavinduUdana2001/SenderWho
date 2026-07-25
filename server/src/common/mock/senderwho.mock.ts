export const mockSenders = [
  {
    id: "sender_nike",
    name: "Nike",
    email: "news@nike.com",
    category: "Marketing",
    score: 92,
    initial: "N",
    colorKey: "primary",
    totalMessages: 128,
    unreadMessages: 8,
    riskLevel: "LOW",
    isBlocked: false,
    isTrusted: true,
  },
  {
    id: "sender_amazon",
    name: "Amazon",
    email: "order-update@gmail.com",
    category: "Orders",
    score: 90,
    initial: "A",
    colorKey: "orange",
    totalMessages: 96,
    unreadMessages: 3,
    riskLevel: "LOW",
    isBlocked: false,
    isTrusted: true,
  },
  {
    id: "sender_bank_of_america",
    name: "Bank of America",
    email: "alerts@bankofamerica.com",
    category: "Finance",
    score: 88,
    initial: "B",
    colorKey: "success",
    totalMessages: 74,
    unreadMessages: 2,
    riskLevel: "LOW",
    isBlocked: false,
    isTrusted: true,
  },
  {
    id: "sender_linkedin",
    name: "LinkedIn",
    email: "updates@linkedin.com",
    category: "Social",
    score: 76,
    initial: "L",
    colorKey: "indigo",
    totalMessages: 52,
    unreadMessages: 11,
    riskLevel: "MEDIUM",
    isBlocked: false,
    isTrusted: false,
  },
  {
    id: "sender_daily_deals",
    name: "Daily Deals",
    email: "deals@dailydeals.io",
    category: "Promotions",
    score: 42,
    initial: "D",
    colorKey: "danger",
    totalMessages: 180,
    unreadMessages: 64,
    riskLevel: "HIGH",
    isBlocked: false,
    isTrusted: false,
  },
] as const;

export const mockAlerts = [
  {
    id: "alert_bank_security",
    title: "Bank Security Alert",
    email: "secure-bank-alert@gmail.com",
    reason: "Impersonating a financial institution",
    time: "2 hours ago",
    risk: "High Risk",
    colorKey: "danger",
    status: "OPEN",
  },
  {
    id: "alert_prize_claim",
    title: "Prize Claim Center",
    email: "claims@win-prize-now.xyz",
    reason: "Known scam domain",
    time: "5 hours ago",
    risk: "High Risk",
    colorKey: "danger",
    status: "OPEN",
  },
  {
    id: "alert_top_picks",
    title: "Top Picks",
    email: "recommend@toppicks.co",
    reason: "Low trust score, high unsubscribe rate",
    time: "Yesterday",
    risk: "Medium Risk",
    colorKey: "warning",
    status: "OPEN",
  },
] as const;

export const mockCategories = [
  {
    id: "important",
    title: "Important",
    count: 128,
    iconKey: "star",
    colorKey: "warning",
  },
  {
    id: "people",
    title: "People",
    count: 86,
    iconKey: "person",
    colorKey: "primary",
  },
  {
    id: "orders",
    title: "Orders & Purchases",
    count: 236,
    iconKey: "shopping_bag",
    colorKey: "orange",
  },
  {
    id: "finance",
    title: "Finance",
    count: 98,
    iconKey: "account_balance",
    colorKey: "success",
  },
  {
    id: "newsletters",
    title: "Newsletters",
    count: 178,
    iconKey: "newspaper",
    colorKey: "indigo",
  },
  {
    id: "promotions",
    title: "Promotions",
    count: 342,
    iconKey: "sell",
    colorKey: "danger",
  },
  {
    id: "travel",
    title: "Travel",
    count: 37,
    iconKey: "flight",
    colorKey: "primary",
  },
  {
    id: "spam",
    title: "Spam / Junk",
    count: 312,
    iconKey: "report",
    colorKey: "danger",
  },
] as const;

export const mockPromotionEmails = [
  {
    id: "email_daily_deals_today",
    sender: "Daily Deals",
    email: "deals@dailydeals.io",
    subject: "Today only: 50% off sitewide",
    date: "Today, 9:15 AM",
  },
  {
    id: "email_top_picks_arrivals",
    sender: "Top Picks",
    email: "recommend@toppicks.co",
    subject: "New arrivals you will love",
    date: "Yesterday",
  },
  {
    id: "email_promohub_weekly",
    sender: "PromoHub",
    email: "offers@promohub.com",
    subject: "Your weekly promotion update",
    date: "Yesterday",
  },
  {
    id: "email_nike_sale",
    sender: "Nike",
    email: "news@nike.com",
    subject: "Summer sale starts now",
    date: "Mon",
  },
  {
    id: "email_style_weekly",
    sender: "Style Weekly",
    email: "hello@styleweekly.com",
    subject: "This week's trends and special offers",
    date: "May 12",
  },
] as const;

export const mockDashboard = {
  inboxHealth: {
    score: 78,
    status: "Good",
  },
  metrics: {
    totalSenders: 412,
    unreadEmails: 2843,
    newsletters: 178,
    spam: 312,
  },
  quickActions: ["all-senders", "bulk-clean", "unsubscribe"],
};

export const mockActivityInsights = {
  period: "This Month",
  stats: [
    {
      key: "emailsReceived",
      value: "842",
      label: "Emails Received",
      colorKey: "text",
    },
    {
      key: "emailsCleaned",
      value: "687",
      label: "Emails Cleaned",
      colorKey: "success",
    },
    {
      key: "spaceSaved",
      value: "243 MB",
      label: "Space Saved",
      colorKey: "indigo",
    },
  ],
  weeklyActivity: [
    { day: "Mon", value: 0.55 },
    { day: "Tue", value: 0.72 },
    { day: "Wed", value: 0.42 },
    { day: "Thu", value: 0.82 },
    { day: "Fri", value: 0.66 },
    { day: "Sat", value: 0.34 },
    { day: "Sun", value: 0.58 },
  ],
};

export const mockSettings = {
  account: {
    connectedAccountsCount: 1,
    displayName: "SenderWho User",
  },
  preferences: {
    notificationsEnabled: true,
    inboxScanFrequency: "Auto",
    theme: "System",
    categoriesEnabled: true,
  },
  emailManagement: {
    archivedEmails: 128,
    trashEmails: 43,
    blockedSenders: 1,
  },
};

export const mockPrivacySecurity = {
  twoFactorEnabled: false,
  blockedSenders: 1,
  trustedSenders: 3,
  dataRetention: "Metadata only",
  privacyMode: "Standard",
};

export const mockSearchFilters = {
  categories: [
    "Marketing",
    "Newsletters",
    "Social",
    "Orders",
    "Finance",
    "Updates",
    "Spam",
  ],
  trustScores: ["All", "High (75+)", "Medium (50-74)", "Low (<50)"],
  dateRanges: ["Any time", "Today", "This Week", "This Month"],
};
