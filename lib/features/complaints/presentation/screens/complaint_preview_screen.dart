import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/widgets/app_layout.dart';
import 'success_screen.dart';
import '../../../../core/theme/page_transition.dart';

class ComplaintPreviewScreen extends StatefulWidget {
  final String contact;
  final String address;
  final String details;

  final PlatformFile? billFile;
  final XFile? problemPhoto;
  final PlatformFile? supportingDoc;

  final DateTime? dateTime;

  final String productId;
  final String productName;
  final String priority;

  const ComplaintPreviewScreen({
    super.key,
    this.contact = "",
    this.address = "",
    this.details = "",
    this.billFile,
    this.problemPhoto,
    this.supportingDoc,
    this.dateTime,
    required this.productId,
    required this.productName,
    required this.priority,
  });

  @override
  State<ComplaintPreviewScreen> createState() => _ComplaintPreviewScreenState();
}

class _ComplaintPreviewScreenState extends State<ComplaintPreviewScreen> {
  bool isLoading = false;

  Future<void> _submitComplaint() async {
    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You must be logged in to submit")),
        );
        return;
      }

      // 1. Fetch User details
      final userDoc = await FirebaseFirestore.instance
          .collection('users_id')
          .doc(user.uid)
          .get();
      
      final userName = userDoc.data()?['name'] ?? "Unknown User";
      final userEmail = userDoc.data()?['email'] ?? user.email;
      final customerId = userDoc.data()?['customer_id'] ?? '';

      // 2. Fetch Product details to populate Device details (matching Admin expectation)
      final productDoc = await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .get();

      String serial = '';
      String purchaseDateStr = '';
      String warrantyExpiryStr = '';

      if (productDoc.exists) {
        final productData = productDoc.data()!;
        serial = productData['serial_number'] ?? '';
        
        final purchaseDateVal = productData['purchase_date'];
        if (purchaseDateVal is Timestamp) {
          purchaseDateStr = DateFormat('yyyy-MM-dd').format(purchaseDateVal.toDate());
        }
        
        final warrantyEndVal = productData['warranty_end'];
        if (warrantyEndVal is Timestamp) {
          warrantyExpiryStr = DateFormat('yyyy-MM-dd').format(warrantyEndVal.toDate());
        }
      }

      final ticketId = DateTime.now().millisecondsSinceEpoch.toString();
      final ticketNo = 'TKT-${DateFormat('yyyyMMdd').format(DateTime.now())}-${ticketId.substring(ticketId.length - 4)}';

      // 3. Prepare Data (Aligned with Admin and Model structure)
      final complaintData = {
        'userId': user.uid,
        'customerId': customerId,
        'productId': widget.productId,
        'userName': userName,
        'userEmail': userEmail,
        'ticketNo': ticketNo,
        'title': widget.details.length > 30 
            ? "${widget.details.substring(0, 27)}..." 
            : widget.details,
        'issue': widget.details, 
        'description': widget.details, 
        'contact': widget.contact,
        'address': widget.address,
        'district': 'Default', 
        'complaintDate': widget.dateTime ?? DateTime.now(),
        'status': 'pending', // lowercase pending status
        'priority': widget.priority, 
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'billFileName': widget.billFile?.name,
        'photoFileName': widget.problemPhoto?.name,
        'docFileName': widget.supportingDoc?.name,
        'attachments': [], 
        'messages': [], 
        'notes': [],
        'parts': [],
        'device': {
          'type': widget.productName,
          'brand': '',
          'model': '',
          'serial': serial,
          'purchaseDate': purchaseDateStr,
          'warrantyExpiry': warrantyExpiryStr,
        },
        'customer': {
          'name': userName,
          'email': userEmail,
          'phone': widget.contact.isNotEmpty ? widget.contact : (userDoc.data()?['phone'] ?? ''),
        },
        'logs': [
          {
            'time': Timestamp.now(),
            'action': 'Complaint submitted by customer',
            'by': userName,
          }
        ],
      };

      // 4. Save to Firestore
      await FirebaseFirestore.instance
          .collection('complaints')
          .add(complaintData);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          FadePageRoute(page: const SuccessScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: "Complaint Preview",
      showBack: true,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: ListView(
          children: [
            // ✅ Header Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [Color(0xff0D47A1), Color(0xff1976D2)],
                ),
              ),
              child: const Text(
                "Preview Your Service Request",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 25),

            // ✅ Product Info
            _infoTile(Icons.devices, "Selected Product", widget.productName),

            // ✅ Priority Info
            _infoTile(Icons.priority_high, "Priority Level", widget.priority.toUpperCase()),

            // ✅ Contact
            _infoTile(Icons.phone, "Contact Number",
                widget.contact.isEmpty ? "Not Provided" : widget.contact),

            // ✅ Address
            _infoTile(Icons.location_on, "Address",
                widget.address.isEmpty ? "Not Provided" : widget.address),

            // ✅ Details
            _infoTile(Icons.report_problem, "Problem Details",
                widget.details.isEmpty ? "Not Provided" : widget.details),

            // ✅ Date & Time
            _infoTile(
              Icons.calendar_today,
              "Preferred Date & Time",
              widget.dateTime == null
                  ? "Not Selected"
                  : DateFormat("dd MMM yyyy • hh:mm a")
                      .format(widget.dateTime!),
            ),

            const SizedBox(height: 20),

            // ✅ Files Section
            const Text(
              "Attached Documents",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            _fileTile(
              title: "Purchase Bill / Invoice",
              value: widget.billFile?.name ?? "Not Uploaded",
            ),

            _fileTile(
              title: "Problem Photo",
              value: widget.problemPhoto?.name ?? "Not Uploaded",
            ),

            _fileTile(
              title: "Supporting Document",
              value: widget.supportingDoc?.name ?? "Not Uploaded",
            ),

            const SizedBox(height: 30),

            // ✅ Submit Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: isLoading ? null : _submitComplaint,
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "SUBMIT SERVICE REQUEST",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Info Tile Widget
  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ File Tile Widget
  Widget _fileTile({required String title, required String value}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_file, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "$title: $value",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
