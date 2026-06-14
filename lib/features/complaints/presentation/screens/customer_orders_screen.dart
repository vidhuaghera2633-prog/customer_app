import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/fade_in.dart';

class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  String userName = "User";
  String userEmail = "";
  String? customerId;
  bool isLoading = true;
  List<Map<String, dynamic>> userProducts = [];
  List<Map<String, dynamic>> userInvoices = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
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
                'product_name': data['product_name'] ?? 'Product',
                'serial_number': data['serial_number'] ?? '',
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
    } catch (e) {
      debugPrint("Error loading orders: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showOrderDetails(Map<String, dynamic> product) {
    // Find matching invoice
    final matchingInvoice = userInvoices.firstOrNull;
    final invoiceNo = matchingInvoice != null ? matchingInvoice['invoice_number'] : 'N/A';

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
              _detailRow("Product Name", product['product_name'] ?? 'N/A'),
              _detailRow("Serial Number", product['serial_number'] ?? 'N/A'),
              _detailRow("Invoice Number", invoiceNo),
              _detailRow("Purchase Date", purchaseDateStr),
              _detailRow("Warranty Expiry", warrantyDateStr),
              if (matchingInvoice != null) ...[
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
                      _downloadBillTextFile(matchingInvoice, product);
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

  Widget _detailRow(String label, String value) {
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
Customer Name  : $userName
Customer Email : $userEmail

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
            content: Text("Failed to download invoice: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: "My Orders",
      showBack: Navigator.canPop(context),
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Order History",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff0D47A1),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Select a product from your orders below to view warranty info, invoice detail, or download billing statement.",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: userProducts.isEmpty
                        ? Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: const Text(
                              "No orders found under your account.",
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: userProducts.length,
                            itemBuilder: (context, index) {
                              final product = userProducts[index];
                              return FadeInWidget(
                                delay: index * 100,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.02),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                    leading: const CircleAvatar(
                                      backgroundColor: Color(0xffE3F2FD),
                                      child: Icon(Icons.shopping_bag, color: Color(0xff0D47A1)),
                                    ),
                                    title: Text(
                                      product['product_name'] ?? 'Product',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xff263238),
                                      ),
                                    ),
                                    trailing: const Icon(Icons.chevron_right, color: Color(0xff0D47A1)),
                                    onTap: () => _showOrderDetails(product),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
