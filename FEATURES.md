# Courier App - Feature Documentation

**Last Updated:** 2025-01-27  
**Version:** 1.0  
**Status:** Active Development

---

## 📋 Table of Contents

- [Overview](#overview)
- [Feature Status Legend](#feature-status-legend)
- [Current Features](#current-features)
- [Pending Features](#pending-features)
- [User Stories](#user-stories)
- [Technical Notes](#technical-notes)

---

## Overview

This document tracks all features, both implemented and planned, for the Courier App. It serves as a living document that should be updated as features are added, modified, or completed.

**App Purpose:** A courier delivery management system supporting customers, drivers, and administrators with order creation, tracking, payment collection, and analytics.

**Target Market:** Greater Toronto Area (GTA), Canada

---

## Feature Status Legend

- ✅ **Implemented** - Feature is complete and working
- 🚧 **In Progress** - Feature is currently being developed
- 📋 **Planned** - Feature is planned but not yet started
- 🔄 **Under Review** - Feature needs discussion/decision
- ❌ **Cancelled** - Feature was planned but cancelled
- 🐛 **Bug** - Known issue with existing feature

---

## Current Features

### 🔐 Authentication & User Management

| Feature | Status | Description | Notes |
|---------|--------|-------------|-------|
| Email/Password Sign Up | ✅ | Users can create accounts with email and password | Includes email format validation |
| Phone/Password Sign Up | ✅ | Users can create accounts with Canadian phone number and password | Validates Canadian area codes |
| Email/Phone Login | ✅ | Users can login with either email or phone number | Single input field with auto-detection |
| Duplicate Email Check | ✅ | Prevents duplicate email addresses during signup | Real-time validation |
| Duplicate Phone Check | ✅ | Prevents duplicate phone numbers during signup | Real-time validation |
| Canadian Phone Validation | ✅ | Validates North American format and Canadian area codes | Supports all Canadian provinces |
| Role-Based Access | ✅ | Three user roles: Customer, Driver, Admin | Enforced at UI and data level |
| Driver Code System | ✅ | Admin can create driver invite codes | Codes tracked in Firestore |
| User Profile Management | ✅ | Users can update name, email, phone, addresses | Stored in Firestore |
| Sign Out | ✅ | Users can sign out from all roles | Clears authentication state |

### 📦 Order Management

| Feature | Status | Description | Notes |
|---------|--------|-------------|-------|
| Create Order | ✅ | Customers can create delivery orders | Includes pickup/dropoff addresses |
| Address Search | ✅ | Autocomplete address search using MapKit | No smart suggestions (removed) |
| Route Calculation | ✅ | Calculates route between pickup and dropoff | Uses MapKit routing |
| Cost Calculation | ✅ | Dynamic cost based on route distance and package options | Updates when route changes |
| Package Customization | ✅ | Size, weight, fragile, speed options | Affects delivery cost |
| Order Status Tracking | ✅ | Tracks: Pending → Assigned → Picked Up → In Transit → Delivered | Also supports Cancelled |
| Order History | ✅ | Users can view past orders | Filtered by user role |
| Order Details View | ✅ | Detailed view of order information | Shows all order fields |
| Real-time Order Updates | ✅ | Orders update in real-time across all views | Uses Firestore listeners |

### 💰 Payment System

| Feature | Status | Description | Notes |
|---------|--------|-------------|-------|
| Payment Responsibility | ✅ | Sender or Receiver can pay | Selected during order creation |
| Payment Methods | ✅ | Cash or Card/Tap Pay options | Same options for both parties |
| Payment Status Tracking | ✅ | Tracks: Pending → Paid → Failed → Refunded | Shown in order details |
| Collect Payment (Sender) | ✅ | Driver can collect payment during pickup | Button enabled when order is assigned |
| Collect Payment (Receiver) | ✅ | Driver can collect payment during delivery | Button enabled when order is picked up |
| Payment Collection Enforcement | ✅ | Cannot mark as picked up/delivered until payment collected | For sender/receiver respectively |

### 🚗 Driver Features

| Feature | Status | Description | Notes |
|---------|--------|-------------|-------|
| View Available Orders | ✅ | Drivers see all pending orders | Filtered by availability |
| Accept Orders | ✅ | Drivers can accept orders | Changes status to Assigned |
| View Assigned Orders | ✅ | Drivers see their active orders | Shows customer name (not userID) |
| Mark as Picked Up | ✅ | Driver confirms package pickup | Requires payment if sender pays |
| Mark as Delivered | ✅ | Driver confirms delivery | Requires payment if receiver pays |
| Delivery Photo Upload | ✅ | Driver can upload photo proof of delivery | Stored in Firebase Storage |
| Delivery Notes | ✅ | Driver can add notes about delivery | Stored with order |
| Online/Offline Toggle | ✅ | Driver can set availability status | Controls order visibility |
| View Completed Orders | ✅ | Driver can see order history | Filtered by driver ID |

### 👤 Customer Features

| Feature | Status | Description | Notes |
|---------|--------|-------------|-------|
| Create New Order | ✅ | Full order creation interface | All customization options |
| View Active Orders | ✅ | See orders in progress | Filtered by status |
| View Order History | ✅ | See completed/cancelled orders | Chronological list |
| Track Order Status | ✅ | Real-time status updates | Shows current order state |
| View Order Details | ✅ | Full order information | Includes route, cost, status |
| Profile Management | ✅ | Update personal information | Name, email, phone, addresses |

### 👨‍💼 Admin Features

| Feature | Status | Description | Notes |
|---------|--------|-------------|-------|
| Dashboard Overview | ✅ | Key metrics and recent activity | Total orders, users, revenue |
| View All Orders | ✅ | Complete order list with filtering | Search, sort, filter by status |
| Order Management | ✅ | Admin can update order status | Manual status changes |
| Assign Drivers | ✅ | Admin can manually assign drivers | Override automatic assignment |
| Cancel Orders | ✅ | Admin can cancel any order | With reason tracking |
| User Management | ✅ | View all users (drivers and customers) | Grouped by role |
| Analytics Dashboard | ✅ | Revenue, completion rates, trends | Time range selection |
| Driver Performance | ✅ | Top drivers by orders and revenue | Performance metrics |
| Driver Code Management | ✅ | Create and manage driver invite codes | Activate/deactivate codes |
| Order Status Breakdown | ✅ | Visual breakdown by status | Percentage calculations |
| Daily Orders Chart | ✅ | Orders per day visualization | Bar chart display |

### 🗺️ Map & Routing

| Feature | Status | Description | Notes |
|---------|--------|-------------|-------|
| Route Visualization | ✅ | Map view showing delivery route | Uses MapKit |
| Distance Calculation | ✅ | Calculates route distance | In miles |
| ETA Calculation | ✅ | Estimated time of arrival | In minutes |
| Address Autocomplete | ✅ | Search and select addresses | MapKit integration |

### 🔔 Notifications & Communication

| Feature | Status | Description | Notes |
|---------|--------|-------------|-------|
| Profile Notifications Toggle | ✅ | User preference for notifications | Stored in profile |
| *Push Notifications* | 📋 | *Real-time push notifications* | *Not yet implemented* |

### 📊 Data & Analytics

| Feature | Status | Description | Notes |
|---------|--------|-------------|-------|
| Order Analytics | ✅ | Revenue, completion rates, trends | Admin dashboard |
| Driver Analytics | ✅ | Performance metrics per driver | Orders completed, revenue |
| Time Range Filtering | ✅ | Analytics for different time periods | 24h, 7d, 30d, 90d, all time |
| Order Status Analytics | ✅ | Breakdown by status with percentages | Visual cards |
| Revenue Insights | ✅ | Completed vs cancelled orders | Completion rate calculations |

---

## Pending Features

### 🔄 High Priority

| Feature | Status | Description | Priority | Estimated Effort |
|---------|--------|-------------|----------|-----------------|
| Push Notifications | 📋 | Real-time notifications for order updates | High | Medium |
| Email Verification | 📋 | Verify email addresses during signup | High | Low |
| Password Reset | 📋 | Forgot password functionality | High | Medium |
| OTP Phone Verification | 📋 | SMS-based phone verification | High | High |
| In-App Messaging | 📋 | Direct communication between customer/driver | High | High |
| Rating System | 📋 | Rate drivers and customers after delivery | High | Medium |
| Receipt Generation | 📋 | Generate and email receipts | Medium | Medium |
| Payment Integration | 📋 | Stripe/Square integration for card payments | High | High |
| Driver Earnings Dashboard | 📋 | Driver-specific earnings and stats | Medium | Low |
| Order Cancellation (Customer) | 📋 | Allow customers to cancel their own orders | Medium | Low |

### 📋 Medium Priority

| Feature | Status | Description | Priority | Estimated Effort |
|---------|--------|-------------|----------|-----------------|
| Multiple Package Support | 📋 | Allow multiple packages per order | Medium | Medium |
| Scheduled Deliveries | 📋 | Schedule orders for future dates/times | Medium | High |
| Recurring Orders | 📋 | Set up recurring delivery schedules | Low | High |
| Delivery Time Windows | 📋 | Specify preferred delivery times | Medium | Medium |
| Photo Upload (Customer) | 📋 | Customer can upload package photos | Low | Low |
| Order Editing | 📋 | Edit order details before driver accepts | Medium | Medium |
| Driver Location Tracking | 📋 | Real-time driver location on map | High | High |
| Customer Live Tracking | 📋 | Customer can see driver location | High | High |
| Delivery Instructions | 📋 | Enhanced delivery instructions field | Low | Low |
| Order Templates | 📋 | Save frequently used addresses/options | Low | Medium |
| Multi-language Support | 📋 | Support for French (Canada) | Low | High |
| Dark Mode Optimization | 📋 | Improve dark mode UI | Low | Low |

### 🔄 Under Review / Discussion Needed

| Feature | Status | Description | Notes |
|---------|--------|-------------|-------|
| Third-Party Payment | 🔄 | Payment from someone other than sender/receiver | Previously removed, may reconsider |
| Subscription Plans | 🔄 | Monthly/yearly subscription for customers | Business model discussion |
| Driver Commission System | 🔄 | Percentage-based driver earnings | Payment structure |
| Insurance Integration | 📋 | Package insurance options | Legal/compliance |
| Signature Capture | 📋 | Digital signature on delivery | Legal proof |
| Barcode/QR Scanning | 📋 | Package tracking via barcodes | Inventory management |

---

## User Stories

### Customer Stories

1. **As a customer**, I want to create a delivery order quickly so that I can send packages efficiently.
   - ✅ Implemented: Full order creation flow with address search and customization

2. **As a customer**, I want to track my order in real-time so I know when it will arrive.
   - ✅ Implemented: Real-time status updates and order details view

3. **As a customer**, I want to choose who pays for the delivery so I can send packages on behalf of others.
   - ✅ Implemented: Payment responsibility selection (sender/receiver)

4. **As a customer**, I want to see my order history so I can track past deliveries.
   - ✅ Implemented: Order history view with status filtering

### Driver Stories

1. **As a driver**, I want to see available orders so I can accept deliveries.
   - ✅ Implemented: Available orders tab with order details

2. **As a driver**, I want to collect payment easily so I can complete deliveries.
   - ✅ Implemented: Payment collection buttons with status enforcement

3. **As a driver**, I want to upload delivery photos so I have proof of delivery.
   - ✅ Implemented: Photo upload during delivery confirmation

4. **As a driver**, I want to see my earnings so I can track my income.
   - 📋 Planned: Driver earnings dashboard

5. **As a driver**, I want to set my availability so I control when I receive orders.
   - ✅ Implemented: Online/offline toggle

### Admin Stories

1. **As an admin**, I want to see all orders so I can manage the business.
   - ✅ Implemented: Complete order list with filtering and search

2. **As an admin**, I want to view analytics so I can make business decisions.
   - ✅ Implemented: Comprehensive analytics dashboard

3. **As an admin**, I want to manage drivers so I can control access.
   - ✅ Implemented: Driver code system and user management

4. **As an admin**, I want to manually assign orders so I can handle special cases.
   - ✅ Implemented: Manual driver assignment interface

---

## Technical Notes

### Architecture

- **Framework:** SwiftUI
- **Backend:** Firebase (Authentication, Firestore, Storage)
- **Maps:** MapKit (Apple Maps)
- **State Management:** `@StateObject`, `@Published`, `ObservableObject`
- **Data Models:** `AppUser`, `Order`, `Profile`, `PaymentResponsibility`, `PaymentMethod`, `PaymentStatus`

### Key Files

- `FirebaseService.swift` - Core Firebase operations
- `FirebaseAuthStore.swift` - Authentication state management
- `FirebaseOrderStore.swift` - Order data management
- `FirebaseProfileStore.swift` - User profile management
- `UserPageView.swift` - Customer interface
- `DriverPageView.swift` - Driver interface
- `AdminPageView.swift` - Admin interface
- `Order.swift` - Order data model
- `AppUser.swift` - User data model

### Security

- **Firestore Rules:** Role-based access control
- **Authentication:** Firebase Auth with email/phone
- **Data Validation:** Client-side validation for all inputs
- **Payment Security:** Payment status tracking (actual payment processing pending)

### Known Issues / Limitations

1. **Camera Testing:** Cannot test camera features on simulator (requires physical device)
2. **Payment Processing:** Payment collection is tracked but not processed (no Stripe/Square integration yet)
3. **Push Notifications:** Not implemented (requires APNs setup)
4. **Email Verification:** Not implemented (requires SMTP configuration)
5. **Password Reset:** Not implemented (requires email service)

### Future Technical Considerations

- **Offline Support:** Consider local caching for offline order viewing
- **Performance:** Optimize Firestore queries for large datasets
- **Error Handling:** Enhanced error messages and retry logic
- **Testing:** Unit tests and UI tests for critical flows
- **CI/CD:** Automated testing and deployment pipeline
- **Monitoring:** Crash reporting and analytics (Firebase Crashlytics)

---

## Changelog

### 2025-01-27
- ✅ Removed smart address suggestions from UserPageView
- ✅ Updated driver page to show customer names instead of userIDs
- ✅ Simplified payment collection UI (removed redundant messages)
- ✅ Implemented payment collection enforcement (cannot mark as picked up/delivered until payment collected)
- ✅ Fixed cost recalculation when route changes

### Previous Updates
- ✅ Implemented payment responsibility system (sender/receiver)
- ✅ Added payment method selection (Cash, Card/Tap Pay)
- ✅ Added payment status tracking
- ✅ Implemented duplicate email/phone checking during signup
- ✅ Added Canadian phone number validation
- ✅ Implemented unified email/phone login
- ✅ Fixed Firestore permission issues
- ✅ Fixed order ID validation to prevent crashes
- ✅ Made payment fields optional for backward compatibility

---

## Notes for Developers

### Adding New Features

1. **Update this document** when starting a new feature
2. **Change status** from 📋 to 🚧 when in progress
3. **Change status** to ✅ when complete
4. **Add to Changelog** when feature is released
5. **Update User Stories** if applicable

### Feature Status Updates

- Mark features as ✅ only when fully tested and working
- Use 🐛 for bugs in existing features
- Use 🔄 for features that need discussion before implementation
- Keep priority and effort estimates updated

### Documentation Maintenance

- Review and update this document weekly
- Remove completed features from "Pending" section
- Add new ideas to "Under Review" section
- Keep technical notes current with architecture changes

---

**End of Document**


