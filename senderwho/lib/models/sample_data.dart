import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_models.dart';

const senders = [
  SenderInfo(
    name: 'Nike',
    email: 'news@nike.com',
    category: 'Marketing',
    score: 92,
    initial: 'N',
    color: AppColors.primary,
  ),
  SenderInfo(
    name: 'Amazon',
    email: 'order-update@gmail.com',
    category: 'Orders',
    score: 90,
    initial: 'A',
    color: AppColors.orange,
  ),
  SenderInfo(
    name: 'Bank of America',
    email: 'alerts@bankofamerica.com',
    category: 'Finance',
    score: 88,
    initial: 'B',
    color: AppColors.success,
  ),
  SenderInfo(
    name: 'LinkedIn',
    email: 'updates@linkedin.com',
    category: 'Social',
    score: 76,
    initial: 'L',
    color: AppColors.indigo,
  ),
  SenderInfo(
    name: 'Daily Deals',
    email: 'deals@dailydeals.io',
    category: 'Promotions',
    score: 42,
    initial: 'D',
    color: AppColors.danger,
  ),
];

const alerts = [
  AlertItem(
    title: 'Bank Security Alert',
    email: 'secure-bank-alert@gmail.com',
    reason: 'Impersonating a financial institution',
    time: '2 hours ago',
    risk: 'High Risk',
    color: AppColors.danger,
  ),
  AlertItem(
    title: 'Prize Claim Center',
    email: 'claims@win-prize-now.xyz',
    reason: 'Known scam domain',
    time: '5 hours ago',
    risk: 'High Risk',
    color: AppColors.danger,
  ),
  AlertItem(
    title: 'Top Picks',
    email: 'recommend@toppicks.co',
    reason: 'Low trust score, high unsubscribe rate',
    time: 'Yesterday',
    risk: 'Medium Risk',
    color: AppColors.warning,
  ),
];

const categories = [
  CategoryItem(
    title: 'Important',
    count: '128',
    icon: Icons.star_border_rounded,
    color: AppColors.warning,
  ),
  CategoryItem(
    title: 'People',
    count: '86',
    icon: Icons.person_outline_rounded,
    color: AppColors.primary,
  ),
  CategoryItem(
    title: 'Orders & Purchases',
    count: '236',
    icon: Icons.shopping_bag_outlined,
    color: AppColors.orange,
  ),
  CategoryItem(
    title: 'Finance',
    count: '98',
    icon: Icons.account_balance_outlined,
    color: AppColors.success,
  ),
  CategoryItem(
    title: 'Newsletters',
    count: '178',
    icon: Icons.newspaper_rounded,
    color: AppColors.indigo,
  ),
  CategoryItem(
    title: 'Promotions',
    count: '342',
    icon: Icons.sell_outlined,
    color: AppColors.danger,
  ),
  CategoryItem(
    title: 'Travel',
    count: '37',
    icon: Icons.flight_takeoff_rounded,
    color: AppColors.primary,
  ),
  CategoryItem(
    title: 'Spam / Junk',
    count: '312',
    icon: Icons.report_gmailerrorred_rounded,
    color: AppColors.danger,
  ),
];

const promotionEmails = [
  EmailItem(
    sender: 'Daily Deals',
    email: 'deals@dailydeals.io',
    subject: 'Today only: 50% off sitewide',
    date: 'Today, 9:15 AM',
  ),
  EmailItem(
    sender: 'Top Picks',
    email: 'recommend@toppicks.co',
    subject: 'New arrivals you will love',
    date: 'Yesterday',
  ),
  EmailItem(
    sender: 'PromoHub',
    email: 'offers@promohub.com',
    subject: 'Your weekly promotion update',
    date: 'Yesterday',
  ),
  EmailItem(
    sender: 'Nike',
    email: 'news@nike.com',
    subject: 'Summer sale starts now',
    date: 'Mon',
  ),
  EmailItem(
    sender: 'Style Weekly',
    email: 'hello@styleweekly.com',
    subject: 'This week\'s trends and special offers',
    date: 'May 12',
  ),
  EmailItem(
    sender: 'Style Weekly',
    email: 'hello@styleweekly.com',
    subject: 'This week\'s trends and special offers',
    date: 'May 12',
  ),
  EmailItem(
    sender: 'Style Weekly',
    email: 'hello@styleweekly.com',
    subject: 'This week\'s trends and special offers',
    date: 'May 12',
  ),
];
