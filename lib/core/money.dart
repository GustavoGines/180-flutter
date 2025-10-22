import 'package:intl/intl.dart';
import 'json_utils.dart';

final _fmtArs = NumberFormat("'\$' #,##0.00", 'es_AR');
String ars(dynamic value) => _fmtArs.format(toNum(value).toDouble());
