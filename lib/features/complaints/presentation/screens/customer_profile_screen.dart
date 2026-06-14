import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  String userName = "Loading...";
  String userEmail = "...";
  String? customerId;

  int totalComplaints = 0;
  int pendingComplaints = 0;
  int completedComplaints = 0;

  List<Map<String, dynamic>> userProducts = [];
  List<Map<String, dynamic>> userInvoices = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      setState(() {
        userEmail = user.email ?? "";
      });

      // 1. Fetch user profile from users_id collection
      final userDoc = await FirebaseFirestore.instance
          .collection('users_id')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      if (mounted) {
        setState(() {
          userName = userData['name'] ?? "User";
          customerId = userData['customer_id'];
        });
      }

      if (customerId != null) {
        // 2. Fetch products
        final productsSnapshot = await FirebaseFirestore.instance
            .collection('products')
            .where('customer_id', isEqualTo: customerId)
            .get();

        // 3. Fetch invoices
        final invoicesSnapshot = await FirebaseFirestore.instance
            .collection('invoices')
            .where('customer_id', isEqualTo: customerId)
            .get();

        if (mounted) {
          setState(() {
            userProducts = productsSnapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'name': data['product_name'] ?? 'Product',
                'serial': data['serial_number'] ?? '',
                'purchase_date': data['purchase_date'],
                'warranty_end': data['warranty_end'],
              };
            }).toList();

            userInvoices = invoicesSnapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'invoice_number': data['invoice_number'] ?? '',
                'invoice_date': data['invoice_date'],
              };
            }).toList();
          });
        }
      }

      // 4. Fetch complaint stats
      final complaintsSnapshot = await FirebaseFirestore.instance
          .collection('complaints')
          .where('userId', isEqualTo: user.uid)
          .get();

      int total = complaintsSnapshot.docs.length;
      int pending = 0;
      int completed = 0;

      for (var doc in complaintsSnapshot.docs) {
        final status = (doc.data()['status'] ?? 'pending').toString().toLowerCase();
        if (status == 'pending' || status == 'open') {
          pending++;
        } else if (status == 'completed' || status == 'done') {
          completed++;
        }
      }

      if (mounted) {
        setState(() {
          totalComplaints = total;
          pendingComplaints = pending;
          completedComplaints = completed;
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showQRCode(Map<String, dynamic> product) {
    final qrData = "Product: ${product['name']}\nSerial: ${product['serial']}\nCustomer ID: $customerId";
    final qrUrl = "https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${Uri.encodeComponent(qrData)}";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          product['name'],
          style: const TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Scan this QR code to register or verify your product warranty.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[200]!),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Image.network(
                qrUrl,
                height: 200,
                width: 200,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    height: 200,
                    width: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
              ),
            ),
            const SizedBox(height: 15),
            Text(
              "S/N: ${product['serial']}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CLOSE", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadInvoice(Map<String, dynamic> invoice, Map<String, dynamic> product) async {
    try {
      final String invoiceNo = invoice['invoice_number'];
      final DateTime pDate = (invoice['invoice_date'] as Timestamp).toDate();
      final DateTime wDate = (product['warranty_end'] as Timestamp).toDate();

      final invoiceContent = """
========================================
             INVOICE RECEIPT
========================================
Invoice Number : $invoiceNo
Invoice Date   : ${DateFormat('dd MMM yyyy').format(pDate)}
Customer Name  : $userName
Customer Email : $userEmail

----------------------------------------
PRODUCT DETAILS:
Product Name   : ${product['name']}
Serial Number  : ${product['serial']}
Warranty End   : ${DateFormat('dd MMM yyyy').format(wDate)}
Warranty Status: ${wDate.isAfter(DateTime.now()) ? 'Active' : 'Expired'}
----------------------------------------

Thank you for your purchase!
For service requests, contact support.
========================================
""";

      // Save file in downloads folder (macOS)
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
            content: Text("Failed to download invoice: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xffF6F8FC),
      appBar: AppBar(
        title: const Text("My Account & Warranty", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xff0D47A1),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ✅ Gradient Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 35),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xff0D47A1), Color(0xff1976D2)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 45, color: Colors.blue),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userEmail,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // ✅ Complaint Stats Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statCard("Total Tickets", totalComplaints.toString(), Icons.receipt_long, Colors.blue),
                  _statCard("Pending", pendingComplaints.toString(), Icons.pending_actions, Colors.orange),
                  _statCard("Resolved", completedComplaints.toString(), Icons.check_circle, Colors.green),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ✅ Purchased Products List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "My Purchased Products",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xff0D47A1)),
                  ),
                  const SizedBox(height: 12),
                  if (userProducts.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Center(
                        child: Text("No products linked to your account.", style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    ...userProducts.map((product) {
                      final warrantyEndVal = product['warranty_end'];
                      DateTime? warrantyEndDate;
                      bool isUnderWarranty = false;
                      String warrantyDateStr = "N/A";

                      if (warrantyEndVal is Timestamp) {
                        warrantyEndDate = warrantyEndVal.toDate();
                        isUnderWarranty = warrantyEndDate.isAfter(DateTime.now());
                        warrantyDateStr = DateFormat('dd MMM yyyy').format(warrantyEndDate);
                      }

                      // Find matching invoice
                      final matchingInvoice = userInvoices.firstOrNull;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    product['name'],
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
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
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            _productDetailRow("Serial Number", product['serial']),
                            if (product['purchase_date'] is Timestamp)
                              _productDetailRow(
                                "Purchase Date",
                                DateFormat('dd MMM yyyy').format((product['purchase_date'] as Timestamp).toDate()),
                              ),
                            _productDetailRow("Warranty Expiry", warrantyDateStr),
                            if (matchingInvoice != null)
                              _productDetailRow("Invoice Number", matchingInvoice['invoice_number']),

                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.qr_code, size: 18),
                                    label: const Text("Warranty QR", style: TextStyle(fontSize: 13)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[800],
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    onPressed: () => _showQRCode(product),
                                  ),
                                ),
                                if (matchingInvoice != null) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.download, size: 18),
                                      label: const Text("Download Bill", style: TextStyle(fontSize: 13)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.blue[800],
                                        side: BorderSide(color: Colors.blue[800]!),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      onPressed: () => _downloadInvoice(matchingInvoice, product),
                                    ),
                                  ),
                                ],
                              ],
                            )
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 105,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _productDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}