
---

# 🛒 Vision Mart - Inventory & POS Management System

**Vision Mart** is a robust, Flutter-based Inventory and Point of Sale (POS) management application designed for small to medium-sized retail businesses. It streamlines daily operations including stock management, sales invoicing, due tracking (Khata), expense recording, and business analytics.

Built with **Flutter** and **Firebase**, utilizing **Riverpod** for state management to ensure a scalable and reactive architecture.

---

## 📱 Features

### 📦 Inventory Management

* **Batch Receiving:** Efficiently add multiple products to stock via a batch inward challan.
* **Stock Tracking:** Real-time updates on current stock levels.
* **Audit Logs:** Automatically tracks who added, updated, or deleted products.
* **Product Management:** Edit product details, set MRP, buying price, and commission percentages.

### 💰 Point of Sale (POS)

* **Cart System:** Add items to a cart, adjust quantities, and apply discounts.
* **Stock Validation:** Prevents selling more items than available in inventory.
* **Invoicing:** Generates professional **PDF Invoices** with support for thermal printing.
* **Customer Address:** Captures customer details including name, phone, and address for delivery.

### 📒 Due Management (Khata)

* **Track Dues:** Monitor customers with outstanding balances.
* **Partial Payments:** Record partial payments and automatically calculate remaining dues.
* **Payment Receipts:** Generate PDF money receipts for every payment received.
* **Auto-Clearance:** Automatically marks transactions as "Cash" when the full due is cleared.

### 📊 Analytics & Reports

* **Business Dashboard:** View quick summaries of sales and profit.
* **Date Filters:** Analyze sales by Today, This Week, This Month, or custom date ranges.
* **Financial Analysis:** View Revenue, Net Profit, and Total Items sold.
* **Sales History:** Reprint invoices from historical data.

### 💸 Expense Tracking

* **Categorization:** Track expenses by category (Rent, Salary, Transport, etc.).
* **Daily Grouping:** View expenses grouped by date.

### 🎨 UI & UX

* **Dark Mode Support:** Fully optimized high-contrast Dark Mode (Red/Green/Yellow/White palette) for low-light usage.
* **Responsive Design:** Clean Material 3 design.

---

## 🛠️ Tech Stack

* **Framework:** [Flutter](https://flutter.dev/) (SDK 3.9+)
* **Language:** [Dart](https://dart.dev/)
* **Backend:** [Firebase](https://firebase.google.com/)
* **Firebase Auth:** Admin authentication.
* **Cloud Firestore:** Real-time NoSQL database.


* **State Management:** [Flutter Riverpod](https://pub.dev/packages/flutter_riverpod) (v2.x)
* **PDF & Printing:** `pdf`, `printing` packages.
* **Utilities:** `intl` (Formatting), `google_fonts`.

---

## 📂 Project Structure

The project follows a **Feature-First** architecture for better scalability and maintainability:

```text
lib/
├── firebase_options.dart      # Firebase Configuration
├── main.dart                  # Entry point & Theme setup
└── src/
    ├── services/              # Global services (AuthService)
    └── features/
        ├── authentication/    # Login screen & Auth Logic
        ├── inventory/         # Product Model, Repository, Screens
        ├── sales/             # POS Logic, Cart, PDF Generation
        ├── analytics/         # Reports & Charts
        ├── expenses/          # Expense Tracking
        └── due_management/    # Due collection & Receipts

```

---

## 🚀 Getting Started

Follow these steps to run the project locally.

### Prerequisites

* Flutter SDK installed.
* Dart SDK installed.
* A Firebase Project created.

### Installation

1. **Clone the repository:**
```bash
git clone https://github.com/your-username/vision-mart-app.git
cd vision-mart-app

```


2. **Install dependencies:**
```bash
flutter pub get

```


3. **Firebase Setup:**
* This project relies on Firebase. You must configure your own Firebase project.
* Install the Firebase CLI and run `flutterfire configure` to generate the correct `firebase_options.dart` for your project.
* *Note: Ensure Authentication (Email/Password) and Firestore Database are enabled in your Firebase Console.*


4. **Run the app:**
```bash
flutter run

```



---

## 📸 Screenshots

| Dashboard (Light) | Inventory (Dark) | POS Cart | Invoice PDF |
| --- | --- | --- | --- |
| *(Add Image)* | *(Add Image)* | *(Add Image)* | *(Add Image)* |

---

## 📝 Configuration

### Firestore Collections Schema

The app automatically generates the following collections in Firestore:

* `products`: Inventory items.
* `sales`: Individual line-item sales records.
* `sales_invoices`: Grouped invoice headers.
* `inventory_logs`: History of stock movement.
* `expenses`: Operational expenses.

### PDF Generation

The app uses the `printing` package. It generates A4 size invoices for Sales and A6 size receipts for Due Payments. Ensure a PDF viewer or a connected printer is available on the device.

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the project.
2. Create your feature branch (`git checkout -b feature/AmazingFeature`).
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4. Push to the branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](https://www.google.com/search?q=LICENSE) file for details.

---

**Developed for A & R Vision Mart.**