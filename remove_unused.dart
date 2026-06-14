import 'dart:io';

void main() {
  final file = File('lib/feature/orders/order_detail_page.dart');
  String content = file.readAsStringSync();

  // Find start of helper section
  final startIndex = content.indexOf('// === WIDGETS HELPER (MOVIDOS FUERA DEL BUILD PARA CLARIDAD) ====');
  if (startIndex == -1) return;

  // We want to delete specific functions. 
  // Let's find their start and end by counting braces.
  
  String removeFunction(String src, String functionName) {
    int start = src.indexOf(functionName);
    if (start == -1) return src;
    
    // find the previous 'Widget ' or 'Future<void> ' or 'void '
    int defStart = src.lastIndexOf(RegExp(r'(Widget|Future<void>|void)\s+'), start);
    if (defStart == -1) defStart = start;

    int braceCount = 0;
    bool inBrace = false;
    int end = -1;
    for (int i = start; i < src.length; i++) {
      if (src[i] == '{') {
        braceCount++;
        inBrace = true;
      } else if (src[i] == '}') {
        braceCount--;
      }
      
      if (inBrace && braceCount == 0) {
        end = i;
        break;
      }
    }
    
    if (end != -1) {
      // Find the start of the documentation comment if any
      int docStart = src.lastIndexOf(RegExp(r'///.*'), defStart);
      if (docStart != -1 && docStart > defStart - 100) { // arbitrary bound
          defStart = docStart;
      }
      return src.substring(0, defStart) + src.substring(end + 1);
    }
    return src;
  }

  content = removeFunction(content, '_buildDeliveryAddressTile');
  content = removeFunction(content, '_buildInfoCard');
  content = removeFunction(content, '_buildInfoTile');
  content = removeFunction(content, '_buildSummaryRow');
  content = removeFunction(content, '_buildPaymentSummaryRow');
  content = removeFunction(content, '_buildTitleRow');
  content = removeFunction(content, '_handleMarkAsPaid');
  content = removeFunction(content, '_handleMarkAsUnpaid');
  content = removeFunction(content, '_handleChangeStatus');
  content = removeFunction(content, '_showDeleteConfirmationDialog');

  file.writeAsStringSync(content);
  print('Removed unused functions');
}
