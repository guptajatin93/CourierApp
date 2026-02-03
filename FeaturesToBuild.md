High priority
Push notifications – No real-time alerts for order updates.
Email verification – No verification during signup.
Password reset – No “forgot password” flow.
OTP phone verification – No SMS verification for phone signup.
In-app messaging – No direct customer–driver chat.
Rating system – No post-delivery ratings for drivers/customers.
Real payment integration – Cash/card is tracked in-app only; no Stripe/Square (or similar).
Driver earnings dashboard – Drivers can’t see earnings/stats.
Customer order cancellation – Customers can’t cancel their own orders (only admin can cancel).
Medium priority
Receipt generation – No generated/emailed receipts.
Multiple packages per order – One package per order only.
Scheduled deliveries – No future date/time scheduling.
Order editing – Can’t edit an order after creation (before driver accepts).
Driver live location – No real-time driver location on map.
Customer live tracking – Customers can’t see driver location.
Delivery time windows – No preferred time slots.
Order templates / saved addresses – No quick reuse of addresses or options.
Other
Recurring orders, customer package photo upload, French (Canada), dark mode polish, signature capture, barcode/QR scanning, insurance options – All listed as planned or under review.
Known technical gaps
Payment – “Collect payment” is status-only; no real card processing.
Push – Needs APNs and backend setup.
Email – No SMTP/verification or password-reset emails.
Offline – No local caching for viewing orders offline.
Testing – Limited unit/UI test coverage noted.
So the main gaps are: account security (email/phone verification, password reset), real payments, push notifications, live tracking, ratings/messaging, and customer cancellation + driver earnings.