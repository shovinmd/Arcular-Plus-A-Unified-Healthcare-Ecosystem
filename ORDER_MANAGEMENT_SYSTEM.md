# 🛒 Order Management System Documentation

## 📋 Overview

A comprehensive order management system for the Arcular Plus healthcare platform that enables users to order medicines from pharmacies and allows pharmacies to manage orders through a complete workflow with real-time status updates and email notifications.

## 🏗️ System Architecture

### Backend Components
- **Order Model** (`node_backend/models/Order.js`) - Complete order schema with status tracking
- **Order Controller** (`node_backend/controllers/orderController.js`) - CRUD operations + email notifications
- **Order Routes** (`node_backend/routes/orderRoutes.js`) - RESTful API endpoints
- **Email Service** - Automated notifications for status changes

### Frontend Components
- **Cart System** (`lib/screens/user/cart_screen.dart`) - Order placement with new API
- **User Orders** (`lib/screens/user/my_orders_screen.dart`) - Order tracking and status display
- **Pharmacy Orders** (`lib/screens/pharmacy/pharmacy_orders_screen.dart`) - Order management
- **API Service** (`lib/services/api_service.dart`) - Frontend-backend integration

## 🔄 Order Flow

### User Side Flow
```
Browse Medicines → Add to Cart → Place Order → Track Orders
     ↓
Status Updates: Pending → Confirmed → Shipped → Delivered
```

### Pharmacy Side Flow
```
Receive Email → View Orders → Confirm → Ship → Deliver
     ↓
Status Updates: Pending → Confirmed → Shipped → Delivered
```

## 📊 Order Status System

| Status | Color | Description | Next Actions |
|--------|-------|-------------|--------------|
| **Pending** | 🟠 Orange | Waiting for pharmacy confirmation | Confirm or Cancel |
| **Confirmed** | 🔵 Blue | Pharmacy confirmed, preparing | Ship |
| **Shipped** | 🟣 Purple | On the way to customer | Deliver |
| **Delivered** | 🟢 Green | Successfully delivered | Complete |
| **Cancelled** | 🔴 Red | Order cancelled | - |

## 🚀 Features Implemented

### User Features
- ✅ Browse medicines from all pharmacies
- ✅ Search medicines by name, category, type, supplier
- ✅ Add medicines to cart with quantity selection
- ✅ Place orders with delivery address and payment method
- ✅ Track order status with real-time updates
- ✅ View detailed order information and history
- ✅ Receive email notifications for status changes
- ✅ Filter orders by status (All, Pending, Confirmed, Shipped, Delivered, Cancelled)

### Pharmacy Features
- ✅ View all incoming orders with customer details
- ✅ Order statistics dashboard (total orders, pending, revenue)
- ✅ Update order status through complete workflow
- ✅ View detailed customer and order information
- ✅ Email notifications for new orders
- ✅ Filter orders by status
- ✅ Order management with action buttons

### Backend Features
- ✅ Complete order management with status tracking
- ✅ Email notification system for all status changes
- ✅ Order statistics and analytics
- ✅ Proper validation and error handling
- ✅ Firebase authentication integration
- ✅ MongoDB integration with proper indexing

## 📧 Email Notifications

### To Pharmacy
- **New Order Received**: Customer details, order items, total amount, delivery information
- **Order Confirmation**: Order ID, customer name, total amount, delivery method

### To User
- **Order Confirmed**: Order ID, status update, preparation notification
- **Order Shipped**: Order ID, tracking information, delivery notification
- **Order Delivered**: Order ID, delivery confirmation, thank you message

## 🛠️ API Endpoints

### Order Management
- `POST /api/orders/place` - Place a new order
- `GET /api/orders/user/:userId` - Get orders by user
- `GET /api/orders/pharmacy/:pharmacyId` - Get orders by pharmacy
- `PUT /api/orders/:orderId/status` - Update order status
- `GET /api/orders/:orderId` - Get order by ID
- `GET /api/orders/pharmacy/:pharmacyId/stats` - Get order statistics

### Medicine Search
- `GET /api/pharmacies/inventory/medicines/search` - Search medicines across pharmacies

## 📱 User Interface

### User Order Screen
- **Browse Tab**: Search and view medicines from all pharmacies
- **My Orders Tab**: Navigate to detailed order tracking screen
- **Prescriptions Tab**: View doctor-prescribed medicines

### User Orders Screen
- **Status Filtering**: Filter orders by status using tabs
- **Order Cards**: Display order information with status indicators
- **Order Details**: Detailed view with customer info, items, and totals
- **Real-time Updates**: Refresh to get latest order status

### Pharmacy Orders Screen
- **Statistics Dashboard**: Total orders, pending orders, revenue
- **Order Management**: View and manage incoming orders
- **Status Updates**: Confirm, ship, and deliver orders
- **Order Details**: Complete customer and order information

## 🔧 Technical Implementation

### Order Model Schema
```javascript
{
  orderId: String (unique),
  userId: String (ref: User),
  userName: String,
  userEmail: String,
  userPhone: String,
  userAddress: Object,
  pharmacyId: String (ref: Pharmacy),
  pharmacyName: String,
  pharmacyEmail: String,
  pharmacyPhone: String,
  pharmacyAddress: Object,
  items: [Object],
  subtotal: Number,
  deliveryFee: Number,
  totalAmount: Number,
  status: String (enum),
  deliveryMethod: String,
  paymentMethod: String,
  statusHistory: [Object],
  timestamps: true
}
```

### Status Update Method
```javascript
orderSchema.methods.updateStatus = function(newStatus, updatedBy, note) {
  this.status = newStatus;
  this.statusHistory.push({
    status: newStatus,
    timestamp: new Date(),
    note: note,
    updatedBy: updatedBy
  });
  // Set specific timestamps based on status
  return this.save();
};
```

### Email Notification System
```javascript
const sendEmail = async (to, subject, html) => {
  const transporter = nodemailer.createTransporter({
    service: 'gmail',
    auth: {
      user: process.env.EMAIL_USER,
      pass: process.env.EMAIL_PASS
    }
  });
  await transporter.sendMail({ from: process.env.EMAIL_USER, to, subject, html });
};
```

## 🎯 Usage Examples

### Placing an Order
```dart
final response = await ApiService.placeOrder(
  userId: user.uid,
  items: orderItems,
  userAddress: userAddress,
  deliveryMethod: 'Home Delivery',
  paymentMethod: 'Cash on Delivery',
  userNotes: 'Payment on delivery - Cash/UPI/Card accepted',
);
```

### Updating Order Status
```dart
await ApiService.updateOrderStatus(
  orderId: orderId,
  status: 'Confirmed',
  updatedBy: 'pharmacy',
  note: 'Order confirmed by pharmacy',
);
```

### Getting Order Statistics
```dart
final stats = await ApiService.getOrderStats(pharmacyId);
// Returns: { totalOrders, pendingOrders, confirmedOrders, shippedOrders, deliveredOrders, totalRevenue }
```

## 🔒 Security Features

- **Firebase Authentication**: All API endpoints require valid authentication
- **User Authorization**: Users can only access their own orders
- **Pharmacy Authorization**: Pharmacies can only access their own orders
- **Input Validation**: All inputs are validated on both frontend and backend
- **Error Handling**: Comprehensive error handling with user-friendly messages

## 📈 Performance Optimizations

- **Database Indexing**: Optimized indexes for order queries
- **Pagination**: Large order lists are paginated
- **Caching**: Order statistics are cached for better performance
- **Async Operations**: All database operations are asynchronous
- **Error Recovery**: Graceful error handling with retry mechanisms

## 🧪 Testing

### Backend Testing
- Order creation and validation
- Status update functionality
- Email notification delivery
- API endpoint responses
- Database operations

### Frontend Testing
- Order placement flow
- Status display and updates
- Navigation between screens
- Error handling and user feedback
- Real-time updates

## 🚀 Deployment

### Backend Deployment
1. Ensure all environment variables are set
2. Deploy to Render or preferred hosting platform
3. Configure email service credentials
4. Set up MongoDB connection
5. Test all API endpoints

### Frontend Deployment
1. Update API base URL for production
2. Build Flutter app for target platforms
3. Deploy to app stores or distribution platforms
4. Test order flow end-to-end

## 📝 Future Enhancements

- **Real-time Notifications**: Push notifications for status updates
- **Order Tracking**: GPS tracking for shipped orders
- **Payment Integration**: Online payment processing
- **Order History**: Extended order history and analytics
- **Bulk Operations**: Bulk order processing for pharmacies
- **Order Templates**: Save frequent orders as templates
- **Delivery Scheduling**: Schedule delivery times
- **Order Reviews**: Customer feedback and rating system

## 🐛 Troubleshooting

### Common Issues
1. **Order not placing**: Check user authentication and address validation
2. **Email not sending**: Verify email service credentials
3. **Status not updating**: Check pharmacy authorization and API calls
4. **Orders not loading**: Verify user/pharmacy ID and API endpoints

### Debug Steps
1. Check console logs for error messages
2. Verify API endpoint responses
3. Test with sample data
4. Check database connectivity
5. Verify email service configuration

## 📞 Support

For technical support or questions about the order management system:
- Check the console logs for error messages
- Verify all environment variables are set correctly
- Test API endpoints using Postman or similar tools
- Check database connectivity and data integrity

---

**Last Updated**: December 2024  
**Version**: 1.0.0  
**Status**: Production Ready ✅
