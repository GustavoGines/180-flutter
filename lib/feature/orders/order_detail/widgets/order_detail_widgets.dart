import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/client_address.dart';
import '../../../../core/utils/launcher_utils.dart';

class OrderInfoCard extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final Color backgroundColor;
  final Color borderColor;

  const OrderInfoCard({
    super.key,
    this.title,
    required this.children,
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    final Color cardColor = isDarkMode ? cs.surface : backgroundColor;
    final Color titleColor = isDarkMode ? cs.onSurface : Colors.black87;
    final BorderSide border = isDarkMode
        ? BorderSide(color: borderColor, width: 3.0)
        : BorderSide(color: borderColor.withAlpha(77), width: 1);

    return Card(
      elevation: isDarkMode ? 0 : 0.5,
      margin: const EdgeInsets.only(bottom: 16),
      color: cardColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                title!,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
            ),
          if (title != null)
            Divider(
              indent: 16,
              endIndent: 16,
              thickness: 0.5,
              height: 1,
              color: isDarkMode ? cs.outlineVariant : borderColor.withAlpha(77),
            ),
          Padding(
            padding: EdgeInsets.only(bottom: title != null ? 8.0 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class OrderInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const OrderInfoTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primaryTextColor = cs.onSurface;
    final secondaryTextColor = cs.onSurfaceVariant;

    return ListTile(
      leading: Icon(
        icon,
        color: secondaryTextColor,
        size: 26,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: primaryTextColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 15,
          color: secondaryTextColor,
        ),
      ),
      trailing: trailing,
      dense: true,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
    );
  }
}

class OrderDeliveryAddressTile extends StatelessWidget {
  final ClientAddress? address;
  final double deliveryCost;

  const OrderDeliveryAddressTile({
    super.key,
    required this.address,
    required this.deliveryCost,
  });

  void _handleMapsLaunch(ClientAddress addr) {
    if (addr.latitude != null && addr.longitude != null) {
      final query = '${addr.latitude},${addr.longitude}';
      launchGoogleMaps(query);
      return;
    }
    if (addr.googleMapsUrl != null && addr.googleMapsUrl!.isNotEmpty) {
      launchExternalUrl(addr.googleMapsUrl!);
      return;
    }
    if (addr.addressLine1 != null && addr.addressLine1!.isNotEmpty) {
      launchGoogleMaps(addr.addressLine1!);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final addr = address;

    if (addr == null) {
      if (deliveryCost == 0) {
        return const OrderInfoTile(
          icon: Icons.storefront_outlined,
          title: 'Entrega',
          subtitle: 'Retira en local',
        );
      }
      return const OrderInfoTile(
        icon: Icons.location_off_outlined,
        title: 'Dirección',
        subtitle: 'No especificada (pero con envío)',
      );
    }

    return OrderInfoTile(
      icon: Icons.location_on_outlined,
      title: 'Dirección de Entrega',
      subtitle: addr.displayAddress,
      trailing: IconButton(
        icon: Icon(
          Icons.map_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        tooltip: 'Ver en Google Maps',
        onPressed: () => _handleMapsLaunch(addr),
      ),
    );
  }
}

class OrderDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isList;
  final bool isNote;
  final bool isSubTotal;
  final Color? highlight;

  const OrderDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.isList = false,
    this.isNote = false,
    this.isSubTotal = false,
    this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final labelColor = cs.onSurfaceVariant;
    final valueColor = isSubTotal ? cs.onSurface : cs.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        crossAxisAlignment: isList || isNote
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Text(
            '$label ',
            style: TextStyle(color: labelColor, fontWeight: FontWeight.normal),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: highlight ?? (isSubTotal ? cs.onSurface : valueColor),
                fontStyle: isNote ? FontStyle.italic : FontStyle.normal,
                fontWeight: isSubTotal ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OrderSummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final NumberFormat currencyFormat;
  final bool isTotal;
  final bool highlight;

  const OrderSummaryRow({
    super.key,
    required this.label,
    required this.amount,
    required this.currencyFormat,
    this.isTotal = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mainTextColor = cs.onSurface;
    final secondaryTextColor = cs.onSurfaceVariant;

    final formattedAmount = currencyFormat.format(
      label == 'Seña Recibida:' ? amount.abs() : amount,
    );
    final sign = label == 'Seña Recibida:' ? '-' : '';

    final style = TextStyle(
      fontSize: isTotal ? 16 : 14,
      fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
      color: highlight ? cs.error : (isTotal ? mainTextColor : secondaryTextColor),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('$sign$formattedAmount', style: style),
        ],
      ),
    );
  }
}
