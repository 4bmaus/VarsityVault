enum ItemStatus { available, checkedOut, missing }

class InventoryItem {
  final String barcode;
  String name; 
  String? assignedToStudentId; 
  ItemStatus status;
  String? folderId; 
  double fineAmount; 
  DateTime? dateCheckedOut;
  List<String> checkoutHistory; // Tracks who had it and when

  InventoryItem({
    required this.barcode, 
    required this.name, 
    this.assignedToStudentId, 
    this.status = ItemStatus.available, 
    this.folderId, 
    this.fineAmount = 0.0,
    this.dateCheckedOut,
    List<String>? checkoutHistory,
  }) : checkoutHistory = checkoutHistory ?? [];
}

class InventoryFolder {
  final String id;
  String name;
  String? parentId; 
  
  InventoryFolder({
    required this.id, 
    required this.name, 
    this.parentId
  });
}