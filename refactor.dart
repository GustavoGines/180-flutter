import 'dart:io';

void main() {
  final file = File('lib/feature/orders/order_detail_page.dart');
  String content = file.readAsStringSync();

  // We want to delete ONLY:
  // _buildDeliveryAddressTile
  // _buildInfoCard
  // _buildInfoTile
  // _buildSummaryRow
  // _buildPaymentSummaryRow
  // _buildTitleRow
  // We keep: _buildItemDetails, _buildDetailRow, _showImageDialog

  // 1. Replace calls
  content = content.replaceAll('_buildInfoCard(', 'OrderInfoCard(');
  content = content.replaceAll('_buildInfoTile(', 'OrderInfoTile(');
  content = content.replaceAll('_buildDeliveryAddressTile(context, order),', 'OrderDeliveryAddressTile(address: order.clientAddress, deliveryCost: order.deliveryCost ?? 0),');
  content = content.replaceAll('_buildSummaryRow(', 'OrderSummaryRow(');
  content = content.replaceAll('_buildPaymentSummaryRow(', 'OrderPaymentSummaryRow(');
  
  // Remove context: context, from OrderSummaryRow calls
  content = content.replaceAll(RegExp(r'context:\s*context,\n\s*\)'), ')');
  
  // 3. Replace controller calls
  content = content.replaceAll('_handleMarkAsPaid(context, ref, order)', 'ref.read(orderDetailControllerProvider).handleMarkAsPaid(context, order)');
  content = content.replaceAll('_handleMarkAsUnpaid(context, ref, order)', 'ref.read(orderDetailControllerProvider).handleMarkAsUnpaid(context, order)');
  content = content.replaceAll('_handleChangeStatus(context, ref, order, status)', 'ref.read(orderDetailControllerProvider).handleChangeStatus(context, order, status)');
  content = content.replaceAll('_showDeleteConfirmationDialog(context, ref, order)', 'ref.read(orderDetailControllerProvider).showDeleteConfirmationDialog(context, order)');

  // 4. Add imports
  if (!content.contains('order_detail_widgets.dart')) {
    content = content.replaceFirst(
      "import 'package:pasteleria_180_flutter/core/theme/order_status_colors.dart';",
      "import 'package:pasteleria_180_flutter/core/theme/order_status_colors.dart';\nimport 'order_detail/widgets/order_detail_widgets.dart';\nimport 'order_detail/order_detail_controller.dart';"
    );
  }

  file.writeAsStringSync(content);
  print('Refactor logic applied.');
}
