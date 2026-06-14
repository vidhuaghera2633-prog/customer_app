import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/fade_in.dart';
import '../../../../core/theme/page_transition.dart';
import 'complaint_details_screen.dart';
import 'complaints_history_screen.dart';
import 'raise_complaint_screen.dart';
import 'complaints_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String userName = "User";

  @override
  void initState() {
    super.initState();
    _fetchUserName();
  }

  Future<void> _fetchUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users_id')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          userName = doc.data()?['name'] ?? "User";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return AppLayout(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            
            // ✅ Premium Header
            FadeInWidget(
              delay: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Hello, $userName 👋",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff0D47A1),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "How can we help you today?",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const CircleAvatar(
                    radius: 25,
                    backgroundColor: Color(0xffE3F2FD),
                    child: Icon(Icons.person, color: Colors.blue),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ✅ Status Overview Cards
            FadeInWidget(
              delay: 200,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('complaints')
                    .where('userId', isEqualTo: user?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  int pending = 0;
                  int active = 0;
                  int completed = 0;

                  if (snapshot.hasData) {
                    for (var doc in snapshot.data!.docs) {
                      String status = (doc['status'] ?? "Open").toString().toLowerCase();
                      if (status == "pending" || status == "open") pending++;
                      if (status == "in progress" || status == "active") active++;
                      if (status == "completed" || status == "done") completed++;
                    }
                  }

                  return Row(
                    children: [
                      _statusCard("Pending", pending, Colors.orange),
                      const SizedBox(width: 12),
                      _statusCard("Active", active, Colors.blue),
                      const SizedBox(width: 12),
                      _statusCard("Done", completed, Colors.green),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 30),

            // ✅ Quick Action Card
            FadeInWidget(
              delay: 300,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xff0D47A1), Color(0xff1976D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xff0D47A1).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Facing an issue?",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Report any problem and our technicians will resolve it quickly.",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue[800],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          FadePageRoute(page: const RaiseComplaintScreen()),
                        );
                      },
                      child: const Text(
                        "RAISE COMPLAINT",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // ✅ Registered Product & Bill Details
            FadeInWidget(
              delay: 350,
              child: _buildRegisteredProductSection(user?.uid),
            ),

            const SizedBox(height: 35),

            // ✅ Recent Complaints Header
            FadeInWidget(
              delay: 400,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Recent Activity",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff263238),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        FadePageRoute(page: const ComplaintHistoryScreen()),
                      );
                    },
                    child: const Text("View All"),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ✅ Limited Complaints List (Top 3 Only)
            FadeInWidget(
              delay: 500,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('complaints')
                    .where('userId', isEqualTo: user?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: const Center(
                        child: Text(
                          "No recent activity found",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs.toList();
                  docs.sort((a, b) {
                    Timestamp t1 = a['createdAt'] ?? Timestamp.now();
                    Timestamp t2 = b['createdAt'] ?? Timestamp.now();
                    return t2.compareTo(t1);
                  });

                  // Only show top 3 for clean UI
                  final recentDocs = docs.take(3).toList();

                  return Column(
                    children: recentDocs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      String dateStr = "Recently";
                      if (data['createdAt'] != null) {
                        dateStr = DateFormat("dd MMM").format((data['createdAt'] as Timestamp).toDate());
                      }
                      return _recentTile(doc.id, data['title'] ?? "Complaint", data['status'] ?? "Pending", dateStr);
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentTile(String id, String title, String status, String date) {
    Color statusColor;
    IconData statusIcon;

    final normalizedStatus = status.toLowerCase();

    switch (normalizedStatus) {
      case "pending":
      case "open":
        statusColor = Colors.orange;
        statusIcon = Icons.access_time_rounded;
        break;
      case "in progress":
      case "active":
        statusColor = Colors.blue;
        statusIcon = Icons.sync;
        break;
      case "completed":
      case "done":
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        break;
      case "rejected":
        statusColor = Colors.red;
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline_rounded;
    }
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ComplaintDetailsScreen(complaintId: id)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                statusIcon,
                color: statusColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              date,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisteredProductSection(String? uid) {
    if (uid == null) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users_id').doc(uid).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final customerId = userData['customer_id'];
        final userRealName = userData['name'] ?? 'User';
        final userRealEmail = userData['email'] ?? '';

        if (customerId == null) {
          return const SizedBox.shrink();
        }

        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('products')
              .where('customer_id', isEqualTo: customerId)
              .get(),
          builder: (context, productsSnapshot) {
            if (!productsSnapshot.hasData || productsSnapshot.data!.docs.isEmpty) {
              return const SizedBox.shrink();
            }

            return FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('invoices')
                  .where('customer_id', isEqualTo: customerId)
                  .get(),
              builder: (context, invoicesSnapshot) {
                final invoiceDoc = invoicesSnapshot.hasData && invoicesSnapshot.data!.docs.isNotEmpty
                    ? invoicesSnapshot.data!.docs.first
                    : null;
                
                final productsList = productsSnapshot.data!.docs;

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "My Orders",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff0D47A1),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Tap on any product to view order details, warranty status, and download your bill receipt.",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...productsList.map((productDoc) {
                        final productData = productDoc.data() as Map<String, dynamic>;
                        final productName = productData['product_name'] ?? 'Product';
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xffF6F8FC),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xffE3F2FD),
                              child: Icon(Icons.shopping_bag, color: Color(0xff0D47A1)),
                            ),
                            title: Text(
                              productName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xff263238),
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right, color: Color(0xff0D47A1)),
                            onTap: () {
                              _showOrderDetailsDialog(
                                context,
                                productData,
                                invoiceDoc?.data() as Map<String, dynamic>?,
                                userRealName,
                                userRealEmail,
                              );
                            },
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showOrderDetailsDialog(
    BuildContext context,
    Map<String, dynamic> product,
    Map<String, dynamic>? invoice,
    String realName,
    String realEmail,
  ) {
    final invoiceNo = invoice != null ? invoice['invoice_number'] ?? 'N/A' : 'N/A';
    final purchaseTimestamp = product['purchase_date'] as Timestamp?;
    final warrantyEndTimestamp = product['warranty_end'] as Timestamp?;
    
    DateTime? purchaseDate = purchaseTimestamp?.toDate();
    DateTime? warrantyEndDate = warrantyEndTimestamp?.toDate();
    bool isUnderWarranty = warrantyEndDate != null && warrantyEndDate.isAfter(DateTime.now());

    String purchaseDateStr = purchaseDate != null ? DateFormat('dd MMM yyyy').format(purchaseDate) : 'N/A';
    String warrantyDateStr = warrantyEndDate != null ? DateFormat('dd MMM yyyy').format(warrantyEndDate) : 'N/A';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  product['product_name'] ?? 'Product Details',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Warranty Status", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isUnderWarranty ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      isUnderWarranty ? "Under Warranty" : "Warranty Expired",
                      style: TextStyle(
                        color: isUnderWarranty ? Colors.green[700] : Colors.red[700],
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _productDetailRow("Product Name", product['product_name'] ?? 'N/A'),
              _productDetailRow("Serial Number", product['serial_number'] ?? 'N/A'),
              _productDetailRow("Invoice Number", invoiceNo),
              _productDetailRow("Purchase Date", purchaseDateStr),
              _productDetailRow("Warranty Expiry", warrantyDateStr),
              if (invoice != null) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.download, size: 18, color: Colors.white),
                    label: const Text("Download Bill / Receipt", style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff0D47A1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      _downloadBillTextFile(
                        invoice,
                        product,
                        realName,
                        realEmail,
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _productDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _downloadBillTextFile(
    Map<String, dynamic> invoice,
    Map<String, dynamic> product,
    String realName,
    String realEmail,
  ) async {
    try {
      final String invoiceNo = invoice['invoice_number'] ?? 'N/A';
      final DateTime pDate = (invoice['invoice_date'] as Timestamp).toDate();
      final DateTime wDate = (product['warranty_end'] as Timestamp).toDate();

      final invoiceContent = """
========================================
             INVOICE RECEIPT
========================================
Invoice Number : $invoiceNo
Invoice Date   : ${DateFormat('dd MMM yyyy').format(pDate)}
Customer Name  : $realName
Customer Email : $realEmail

----------------------------------------
PRODUCT DETAILS:
Product Name   : ${product['product_name']}
Serial Number  : ${product['serial_number']}
Warranty End   : ${DateFormat('dd MMM yyyy').format(wDate)}
Warranty Status: ${wDate.isAfter(DateTime.now()) ? 'Active' : 'Expired'}
----------------------------------------

Thank you for your purchase!
For service requests, contact support.
========================================
""";

      final downloadsDir = Directory('/Users/themangobook/Downloads');
      if (await downloadsDir.exists()) {
        final file = File('${downloadsDir.path}/Invoice_$invoiceNo.txt');
        await file.writeAsString(invoiceContent);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Invoice downloaded successfully to Downloads/Invoice_$invoiceNo.txt 📄"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception("Downloads directory not found");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const ValueKey('invoice_err'),
            content: Text("Failed to download invoice: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
