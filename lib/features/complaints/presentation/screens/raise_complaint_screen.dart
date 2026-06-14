import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/widgets/app_layout.dart';
import '../../../../core/theme/page_transition.dart';
import '../../../../core/widgets/fade_in.dart';

import 'complaint_preview_screen.dart';

class RaiseComplaintScreen extends StatefulWidget {
  const RaiseComplaintScreen({super.key});

  @override
  State<RaiseComplaintScreen> createState() => _RaiseComplaintScreenState();
}

class _RaiseComplaintScreenState extends State<RaiseComplaintScreen> {
  // Controllers
  final contactController = TextEditingController();
  final addressController = TextEditingController();
  final detailsController = TextEditingController();

  // Files
  PlatformFile? electricityBill;
  XFile? problemPhoto;
  PlatformFile? supportingDoc;

  // Date Time
  DateTime? complaintDateTime;

  // Product & Priority fields
  List<Map<String, dynamic>> products = [];
  String? selectedProductId;
  String selectedPriority = 'medium';
  bool productsLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      List<Map<String, dynamic>> loadedProducts = [];

      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users_id')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final customerId = userDoc.data()?['customer_id'];
          if (customerId != null) {
            final productSnapshot = await FirebaseFirestore.instance
                .collection('products')
                .where('customer_id', isEqualTo: customerId)
                .get();

            loadedProducts = productSnapshot.docs.map((doc) => {
              'id': doc.id,
              'name': doc.data()['product_name'] ?? 'Product',
              'serial': doc.data()['serial_number'] ?? '',
            }).toList();
          }
        }
      }

      // Add Solar products
      loadedProducts.addAll([
        {'id': 'solar_panel', 'name': 'Solar Panel', 'serial': 'SLR-PL-9092'},
        {'id': 'solar_water_heater', 'name': 'Solar Water Heater', 'serial': 'SLR-WH-4081'},
        {'id': 'solar_inverter', 'name': 'Solar Inverter', 'serial': 'SLR-INV-1025'},
      ]);

      setState(() {
        products = loadedProducts;
        if (products.isNotEmpty) {
          selectedProductId = products.first['id'];
        }
      });
    } catch (e) {
      debugPrint("Error loading products: $e");
      setState(() {
        products = [
          {'id': 'solar_panel', 'name': 'Solar Panel', 'serial': 'SLR-PL-9092'},
          {'id': 'solar_water_heater', 'name': 'Solar Water Heater', 'serial': 'SLR-WH-4081'},
          {'id': 'solar_inverter', 'name': 'Solar Inverter', 'serial': 'SLR-INV-1025'},
        ];
        selectedProductId = 'solar_panel';
      });
    } finally {
      if (mounted) {
        setState(() {
          productsLoading = false;
        });
      }
    }
  }

  // Pick Electricity Bill
  Future<void> pickElectricityBill() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
    );

    if (result != null) {
      setState(() {
        electricityBill = result.files.first;
      });
    }
  }

  // Pick Problem Photo
  Future<void> pickProblemPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        problemPhoto = picked;
      });
    }
  }

  // Pick Supporting Document
  Future<void> pickSupportingDoc() async {
    final result = await FilePicker.platform.pickFiles();

    if (result != null) {
      setState(() {
        supportingDoc = result.files.first;
      });
    }
  }

  // Pick Date & Time
  Future<void> pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      initialDate: DateTime.now(),
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time == null) return;

    setState(() {
      complaintDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: "Raise Service Request",
      showBack: true,

      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            FadeInWidget(
              delay: 100,
              child: const Text(
                "Create Service Request",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff0D47A1),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Product Dropdown
            FadeInWidget(
              delay: 150,
              child: productsLoading
                  ? const Center(child: CircularProgressIndicator())
                  : products.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Text(
                            "No purchased products found on your account. Please contact support to register your product.",
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        )
                      : Container(
                          margin: const EdgeInsets.only(bottom: 18),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButtonFormField<String>(
                              value: selectedProductId,
                              decoration: const InputDecoration(
                                labelText: 'Select Purchased Product',
                                prefixIcon: Icon(Icons.devices, color: Colors.blue),
                                border: InputBorder.none,
                              ),
                              items: products.map((p) {
                                return DropdownMenuItem<String>(
                                  value: p['id'],
                                  child: Text("${p['name']} (S/N: ${p['serial']})"),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  selectedProductId = val;
                                });
                              },
                            ),
                          ),
                        ),
            ),



            // Contact Number
            FadeInWidget(
              delay: 250,
              child: _inputField(
                label: "Contact Number",
                controller: contactController,
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),
            ),

            // Address
            FadeInWidget(
              delay: 300,
              child: _inputField(
                label: "Address",
                controller: addressController,
                icon: Icons.location_on,
                maxLines: 2,
                isOptional: true,
              ),
            ),

            // Problem Details (Description)
            FadeInWidget(
              delay: 350,
              child: _inputField(
                label: "Complaint / Problem Details",
                controller: detailsController,
                icon: Icons.report_problem,
                maxLines: 3,
              ),
            ),

            const SizedBox(height: 15),

            // Upload Bill
            FadeInWidget(
              delay: 400,
              child: _uploadTile(
                title: "Purchase Bill / Invoice (Optional)",
                subtitle: electricityBill?.name ?? "Upload Invoice Document",
                icon: Icons.picture_as_pdf,
                onTap: pickElectricityBill,
              ),
            ),

            // Upload Problem Photo
            FadeInWidget(
              delay: 450,
              child: _uploadTile(
                title: "Problem Photo (Optional)",
                subtitle: problemPhoto?.name ?? "Upload Problem Image",
                icon: Icons.image,
                onTap: pickProblemPhoto,
              ),
            ),

            // Supporting Document
            FadeInWidget(
              delay: 500,
              child: _uploadTile(
                title: "Supporting Document (Optional)",
                subtitle: supportingDoc?.name ?? "Upload Any Document",
                icon: Icons.attach_file,
                onTap: pickSupportingDoc,
              ),
            ),

            // Date & Time Picker
            FadeInWidget(
              delay: 550,
              child: _uploadTile(
                title: "Preferred Date & Time (Optional)",
                subtitle: complaintDateTime == null
                    ? "Select Date & Time"
                    : DateFormat("dd MMM yyyy • hh:mm a")
                    .format(complaintDateTime!),
                icon: Icons.calendar_today,
                onTap: pickDateTime,
              ),
            ),

            const SizedBox(height: 30),

            // Preview Button
            FadeInWidget(
              delay: 600,
              child: GestureDetector(
                onTap: (products.isEmpty || selectedProductId == null)
                    ? null
                    : () {
                        final selectedProduct = products.firstWhere((p) => p['id'] == selectedProductId);
                        Navigator.push(
                          context,
                          FadePageRoute(
                            page: ComplaintPreviewScreen(
                              contact: contactController.text,
                              address: addressController.text,
                              details: detailsController.text,
                              billFile: electricityBill,
                              problemPhoto: problemPhoto,
                              supportingDoc: supportingDoc,
                              dateTime: complaintDateTime,
                              productId: selectedProductId!,
                              productName: selectedProduct['name']!,
                              priority: selectedPriority,
                            ),
                          ),
                        );
                      },
                child: Container(
                  width: double.infinity,
                  height: 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: (products.isEmpty || selectedProductId == null)
                          ? [Colors.grey, Colors.grey]
                          : [const Color(0xff0D47A1), const Color(0xff1976D2)],
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      "PREVIEW COMPLAINT",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // Input Field Widget
  Widget _inputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool isOptional = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: isOptional ? "$label (Optional)" : label,
          prefixIcon: Icon(icon, color: Colors.blue),
        ),
      ),
    );
  }

  // Upload Tile Widget
  Widget _uploadTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: const Icon(Icons.upload, color: Colors.blue),
        onTap: onTap,
      ),
    );
  }
}