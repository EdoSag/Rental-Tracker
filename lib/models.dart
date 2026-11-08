// Data models and fixed names.

const List<String> kTenants = ['יעקב', 'קטיה', 'אנה', 'ירון'];
const List<String> kPartners = ['ענר', 'רחל', 'שרית', 'אבי'];

const List<String> kHebrewMonths = [
  'ינואר', 'פברואר', 'מרץ', 'אפריל', 'מאי', 'יוני',
  'יולי', 'אוגוסט', 'ספטמבר', 'אוקטובר', 'נובמבר', 'דצמבר',
];

/// A month key in the form "YYYY-MM". Sorting the strings sorts the months.
String monthKey(int year, int month) =>
    '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

int monthYear(String key) => int.parse(key.substring(0, 4));
int monthNum(String key) => int.parse(key.substring(5, 7));

String monthLabel(String key) => '${kHebrewMonths[monthNum(key) - 1]} ${monthYear(key)}';

String addMonths(String key, int delta) {
  final total = monthYear(key) * 12 + (monthNum(key) - 1) + delta;
  return monthKey(total ~/ 12, total % 12 + 1);
}

/// One tenant in one month.
class TenantMonth {
  final String month;
  final int tenant; // 0..3
  double rent;
  double? elecPrev; // manual override of "last reading"; null = automatic
  double? elecCur;
  double? waterPrev;
  double? waterCur;
  double arnona;
  bool paid;

  TenantMonth({
    required this.month,
    required this.tenant,
    this.rent = 0,
    this.elecPrev,
    this.elecCur,
    this.waterPrev,
    this.waterCur,
    this.arnona = 0,
    this.paid = false,
  });

  Map<String, Object?> toMap() => {
        'month': month,
        'tenant': tenant,
        'rent': rent,
        'elec_prev': elecPrev,
        'elec_cur': elecCur,
        'water_prev': waterPrev,
        'water_cur': waterCur,
        'arnona': arnona,
        'paid': paid ? 1 : 0,
      };

  static double? _d(Object? v) => v == null ? null : (v as num).toDouble();

  factory TenantMonth.fromMap(Map<String, Object?> m) => TenantMonth(
        month: m['month'] as String,
        tenant: (m['tenant'] as num).toInt(),
        rent: _d(m['rent']) ?? 0,
        elecPrev: _d(m['elec_prev']),
        elecCur: _d(m['elec_cur']),
        waterPrev: _d(m['water_prev']),
        waterCur: _d(m['water_cur']),
        arnona: _d(m['arnona']) ?? 0,
        paid: (m['paid'] as num? ?? 0) != 0,
      );
}

/// The owner's own bills for a month.
class MonthExpense {
  final String month;
  double elec;
  double water;
  double arnona;
  double other;

  MonthExpense({required this.month, this.elec = 0, this.water = 0, this.arnona = 0, this.other = 0});

  double get cityTotal => elec + water + arnona;

  Map<String, Object?> toMap() =>
      {'month': month, 'elec': elec, 'water': water, 'arnona': arnona, 'other': other};

  factory MonthExpense.fromMap(Map<String, Object?> m) => MonthExpense(
        month: m['month'] as String,
        elec: (m['elec'] as num? ?? 0).toDouble(),
        water: (m['water'] as num? ?? 0).toDouble(),
        arnona: (m['arnona'] as num? ?? 0).toDouble(),
        other: (m['other'] as num? ?? 0).toDouble(),
      );
}

class Photo {
  final int? id;
  final String month;
  final int tenant;
  final String fileName; // relative to the photos directory

  Photo({this.id, required this.month, required this.tenant, required this.fileName});

  Map<String, Object?> toMap() =>
      {if (id != null) 'id': id, 'month': month, 'tenant': tenant, 'file': fileName};

  factory Photo.fromMap(Map<String, Object?> m) => Photo(
        id: (m['id'] as num?)?.toInt(),
        month: m['month'] as String,
        tenant: (m['tenant'] as num).toInt(),
        fileName: m['file'] as String,
      );
}

class Settings {
  double kwhPrice;
  double waterPrice;
  double mgmtPct; // percent, e.g. 8 means 8%
  List<double> rents; // per tenant
  List<double> partnerPcts; // percent per partner

  Settings({
    this.kwhPrice = 0.65,
    this.waterPrice = 12,
    this.mgmtPct = 0,
    List<double>? rents,
    List<double>? partnerPcts,
  })  : rents = rents ?? List.filled(kTenants.length, 0),
        partnerPcts = partnerPcts ?? List.filled(kPartners.length, 25);

  double get partnerPctSum => partnerPcts.fold(0.0, (a, b) => a + b);

  Map<String, double> toKv() => {
        'kwh_price': kwhPrice,
        'water_price': waterPrice,
        'mgmt_pct': mgmtPct,
        for (var i = 0; i < rents.length; i++) 'rent_$i': rents[i],
        for (var i = 0; i < partnerPcts.length; i++) 'partner_$i': partnerPcts[i],
      };

  factory Settings.fromKv(Map<String, double> kv) {
    final s = Settings();
    s.kwhPrice = kv['kwh_price'] ?? s.kwhPrice;
    s.waterPrice = kv['water_price'] ?? s.waterPrice;
    s.mgmtPct = kv['mgmt_pct'] ?? s.mgmtPct;
    for (var i = 0; i < s.rents.length; i++) {
      s.rents[i] = kv['rent_$i'] ?? 0;
    }
    for (var i = 0; i < s.partnerPcts.length; i++) {
      s.partnerPcts[i] = kv['partner_$i'] ?? 25;
    }
    return s;
  }
}
