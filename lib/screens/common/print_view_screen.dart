import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../../config/api.dart';
import '../../config/module_registry.dart';
import '../../services/api_service.dart';
import '../../services/record_utils.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pp_widgets.dart';

/// Web print pages (erp-frontend/src/app/print/<route>/[uuid]) per module key.
/// They are public by UUID, so no login is needed to show them.
const printRoutes = <String, String>{
  'indent': 'indent',
  'order': 'order',
  'service_order': 'service-order',
  'goods_received_note': 'grn',
  'goods_issue_note': 'gin',
  'service_received_note': 'srn',
  'batching_plant': 'batching-plant',
  'bill_receive_register': 'brr',
  'payment_request': 'brb',
  'sale_order': 'og-sale-order',
  'budget_master': 'budget',
  'sale_claim_bill': 'sale-claim-bill',
  'sale_certified_bill': 'sale-certified-bill',
  'uncertified_statement': 'uncertified-statement',
  'sale': 'sale-bill',
  'purchases': 'purchase-bill',
  'receipt': 'sale-receipt-billing',
  'payment': 'payment',
  'contra': 'contra-entry',
  'debit_note': 'debit-note',
  'credit_note': 'credit-note',
  'journal': 'journal-entry',
  'petty_cash': 'petty-cash-docket',
  'daily_progress_report': 'dpr',
};

String? _uuidOf(Map<String, dynamic> data) {
  final direct = data['uuid'];
  if (direct is String && direct.isNotEmpty) return direct;
  for (final e in data.entries) {
    if (e.key.toLowerCase().endsWith('uuid') && e.value is String && (e.value as String).isNotEmpty) return e.value;
  }
  return null;
}

/// Same page the web opens with its "Download / Print" button, or null.
String? webPrintUrl(ErpModule m, Map<String, dynamic> data) {
  final route = printRoutes[m.key];
  final uuid = _uuidOf(data);
  if (route == null || uuid == null) return null;
  return '${ApiConfig.webUrl}/print/$route/${Uri.encodeComponent(uuid)}';
}

/// Opens the best document view for a record: the web print page when the
/// module has one, otherwise a PDF built on the phone (works offline).
Future<void> openDocumentView(BuildContext context, ErpModule m, Map<String, dynamic> data, {required String title}) {
  final url = webPrintUrl(m, data);
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => url != null
          ? WebPrintScreen(url: url, title: title, module: m, data: data)
          : PdfViewScreen(title: title, fileName: _fileName(title), makePdf: () => buildRecordPdf(m, data, title)),
    ),
  );
}

String _fileName(String title) => '${title.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')}.pdf';

// ─────────────────────────────────────────────────────────────────────────────
//  Web print page in a WebView — exactly what the web frontend prints.
// ─────────────────────────────────────────────────────────────────────────────

/// Entries of every module with a web print page open straight in that page
/// (fit to the screen, pinch to zoom). Modules without one keep the detail screen.
bool opensInPrint(ErpModule m) => printRoutes.containsKey(m.key);

/// One entry shown as its web print page. Loads the record first when the list
/// row doesn't carry the print id (uuid). "Details" still opens the old screen.
class RecordPrintScreen extends StatefulWidget {
  final ErpModule module;
  final Map<String, dynamic> record;
  final Widget Function() detailsScreen;
  const RecordPrintScreen({super.key, required this.module, required this.record, required this.detailsScreen});

  @override
  State<RecordPrintScreen> createState() => _RecordPrintScreenState();
}

class _RecordPrintScreenState extends State<RecordPrintScreen> {
  Map<String, dynamic>? _data;
  String? _error;

  ErpModule get m => widget.module;

  String get _title {
    final d = _data ?? widget.record;
    final tk = RecordUtils.titleKey(d, m.titleKey);
    return tk == null ? m.title : '${m.title} ${RecordUtils.text(d, tk)}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_uuidOf(widget.record) != null || m.detail == null) {
      setState(() => _data = widget.record);
      return;
    }
    try {
      final d = await ApiService.instance.get('${m.detail}/${widget.record[m.idKey]}', projectScoped: false);
      final row = d is List && d.isNotEmpty ? d.first : d;
      if (!mounted) return;
      setState(() => _data = row is Map ? {...widget.record, ...Map<String, dynamic>.from(row)} : widget.record);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _openDetails() => Navigator.push(context, MaterialPageRoute(builder: (_) => widget.detailsScreen()));

  @override
  Widget build(BuildContext context) {
    final detailsBtn = IconButton(
      tooltip: 'Details',
      icon: const Icon(Icons.list_alt_rounded, color: Colors.white),
      onPressed: _openDetails,
    );
    final data = _data;
    final url = data == null ? null : webPrintUrl(m, data);
    if (url != null) {
      return WebPrintScreen(url: url, title: _title, module: m, data: data!, extraActions: [detailsBtn]);
    }
    // Loaded, but this entry has no print id (an old record not yet given one
    // on the server): show the details straight away instead of an empty page.
    if (data != null && _error == null) return widget.detailsScreen();
    return Scaffold(
      appBar: PPAppBar(title: _title, subtitle: 'Document view', actions: [detailsBtn]),
      body: data == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : EmptyState(
              icon: Icons.description_outlined,
              title: 'Could not open this entry',
              message: _error,
              action: FilledButton(onPressed: _openDetails, child: const Text('Open details')),
            ),
    );
  }
}

class WebPrintScreen extends StatefulWidget {
  final String url, title;
  final ErpModule module;
  final Map<String, dynamic> data;

  /// Extra app-bar buttons (e.g. "Details" when the print page is the main view).
  final List<Widget> extraActions;
  const WebPrintScreen({
    super.key,
    required this.url,
    required this.title,
    required this.module,
    required this.data,
    this.extraActions = const [],
  });

  @override
  State<WebPrintScreen> createState() => _WebPrintScreenState();
}

class _WebPrintScreenState extends State<WebPrintScreen> {
  late final WebViewController _web;
  int _progress = 0;
  bool _failed = false;
  bool _making = false;

  // The A4-wide page (~920px) shrunk to fit the phone (the web print layout
  // does this too; done here as well so older web builds also fit), screen-only
  // bar hidden, and the page's own "Print / Save as PDF" buttons routed to the app.
  // Pinch with two fingers to zoom in.
  static const _prepare = '''
(function(){
  var r=document.documentElement, w=window.innerWidth;
  if(w && w<920 && !r.style.zoom){ r.style.zoom=String(w/920); r.style.backgroundColor='#f3f4f6'; }
  if(!document.getElementById('erp-mobile-css')){
    var s=document.createElement('style');s.id='erp-mobile-css';
    s.textContent='.print\\\\:hidden{display:none!important} body{background:#e5e7eb!important}';
    document.head.appendChild(s);
  }
  window.print=function(){ try{ ErpPrint.postMessage('print'); }catch(e){} };
})();
''';

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFE5E7EB))
      ..addJavaScriptChannel('ErpPrint', onMessageReceived: (_) => _makePdf())
      ..addJavaScriptChannel('ErpPdf', onMessageReceived: _onPdfChunk)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => mounted ? setState(() => _progress = p) : null,
        onPageFinished: (_) => _web.runJavaScript(_prepare),
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? true) setState(() => _failed = true);
        },
        // Stay on the print page; downloads (Excel/DOCX blobs) are not supported here.
        onNavigationRequest: (r) =>
            r.url.startsWith(widget.url) || r.url == 'about:blank' ? NavigationDecision.navigate : NavigationDecision.prevent,
      ))
      ..loadRequest(Uri.parse(widget.url));
    // Open zoomed out to the whole A4 width; pinch with two fingers to zoom in.
    final p = _web.platform;
    if (p is AndroidWebViewController) {
      p.setUseWideViewPort(true);
      p.enableZoom(true);
    } else {
      _web.enableZoom(true);
    }
  }

  /// Turn the rendered page into a real A4 PDF inside the page (html2canvas +
  /// jsPDF, the same libraries the web ERP uses) and open it to save / share / print.
  static const _toPdf = r'''
(async function(){
  function load(src){return new Promise(function(res,rej){
    if(document.querySelector('script[src="'+src+'"]'))return res();
    var s=document.createElement('script');s.src=src;s.onload=res;s.onerror=function(){rej('Could not load '+src)};document.head.appendChild(s);});}
  try{
    await load('https://cdn.jsdelivr.net/npm/html2canvas-pro@1.5.8/dist/html2canvas-pro.min.js');
    if(!window.jspdf) await load('https://cdn.jsdelivr.net/npm/jspdf@2.5.1/dist/jspdf.umd.min.js');
    var root=document.documentElement, z=root.style.zoom; root.style.zoom='';
    var el=document.querySelector('div.bg-white.mx-auto.shadow-md')||document.body;
    var c; try{ c=await html2canvas(el,{scale:2,useCORS:true,backgroundColor:'#ffffff',windowWidth:920}); } finally { root.style.zoom=z; }
    var pdf=new jspdf.jsPDF('p','mm','a4'); var W=210,H=297, m=6;
    var pxPerMm=c.width/(W-2*m), pageH=Math.floor((H-2*m)*pxPerMm);
    for(var y=0,i=0;y<c.height;y+=pageH,i++){
      var h=Math.min(pageH,c.height-y), pc=document.createElement('canvas'); pc.width=c.width; pc.height=h;
      var g=pc.getContext('2d'); g.fillStyle='#fff'; g.fillRect(0,0,pc.width,h); g.drawImage(c,0,-y);
      if(i) pdf.addPage(); pdf.addImage(pc.toDataURL('image/jpeg',0.92),'JPEG',m,m,W-2*m,h/pxPerMm);
    }
    var b64=pdf.output('datauristring').split(',')[1], n=300000;
    for(var k=0;k<b64.length;k+=n) ErpPdf.postMessage(b64.substr(k,n));
    ErpPdf.postMessage('__END__');
  }catch(e){ ErpPdf.postMessage('__ERR__'+e); }
})();
''';

  final _chunks = StringBuffer();

  void _onPdfChunk(JavaScriptMessage msg) {
    final m = msg.message;
    if (m.startsWith('__ERR__')) {
      _chunks.clear();
      setState(() => _making = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not make the PDF: ${m.substring(7)}')));
    } else if (m == '__END__') {
      final bytes = base64Decode(_chunks.toString());
      _chunks.clear();
      setState(() => _making = false);
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PdfViewScreen(title: widget.title, fileName: _fileName(widget.title), makePdf: () async => bytes),
      ));
    } else {
      _chunks.write(m);
    }
  }

  Future<void> _makePdf() async {
    if (_making) return;
    setState(() => _making = true);
    _chunks.clear();
    try {
      await _web.runJavaScript(_toPdf);
    } catch (e) {
      if (mounted) {
        setState(() => _making = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not make the PDF: $e')));
      }
    }
  }

  void _openBasic() => Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewScreen(
            title: widget.title,
            fileName: _fileName(widget.title),
            makePdf: () => buildRecordPdf(widget.module, widget.data, widget.title),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB),
      appBar: PPAppBar(
        title: widget.title,
        subtitle: 'Document view',
        actions: [
          ...widget.extraActions,
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              setState(() => _failed = false);
              _web.reload();
            },
          ),
          IconButton(
            tooltip: 'Save / share PDF',
            onPressed: _failed || _progress < 100 || _making ? null : _makePdf,
            icon: _making
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
          ),
        ],
      ),
      body: _failed
          ? EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Document needs internet',
              message: 'The printable page is loaded from the ERP server. You can still open a basic PDF made from the saved data.',
              action: FilledButton.icon(
                onPressed: _openBasic,
                style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('Open basic PDF'),
              ),
            )
          : Stack(children: [
              WebViewWidget(controller: _web),
              if (_progress < 100) LinearProgressIndicator(value: _progress / 100, minHeight: 2),
            ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PDF viewer (zoom, page view, share, save, print)
// ─────────────────────────────────────────────────────────────────────────────

class PdfViewScreen extends StatelessWidget {
  final String title, fileName;
  final Future<Uint8List> Function() makePdf;
  const PdfViewScreen({super.key, required this.title, required this.fileName, required this.makePdf});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5F6368),
      appBar: PPAppBar(title: title, subtitle: 'PDF'),
      body: PdfPreview(
        build: (_) => makePdf(),
        pdfFileName: fileName,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        loadingWidget: const CircularProgressIndicator(color: Colors.white),
        onError: (_, e) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not open the PDF: $e', style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PDF built on the phone from the record (modules without a web print page,
//  or when offline). Same structure as the detail screen.
// ─────────────────────────────────────────────────────────────────────────────

/// Built-in PDF fonts are Latin-1 only.
String _pdfSafe(String s) => s
    .replaceAll('₹', 'Rs. ')
    .replaceAll('—', '-')
    .replaceAll('–', '-')
    .replaceAll('•', '-')
    .replaceAll(RegExp(r'[‘’]'), "'")
    .replaceAll(RegExp(r'[“”]'), '"')
    .replaceAll(RegExp(r'[^\x00-\xFF]'), '?');

Uint8List? _logo;

Future<Uint8List?> _loadLogo() async {
  if (_logo != null) return _logo;
  try {
    final r = await http
        .get(Uri.parse('${ApiConfig.webUrl}/assets/pdf-images/erp_company_img_pdf.png'))
        .timeout(const Duration(seconds: 6));
    if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) _logo = r.bodyBytes;
  } catch (_) {}
  return _logo;
}

Future<Uint8List> buildRecordPdf(ErpModule m, Map<String, dynamic> data, String title) async {
  final logo = await _loadLogo();
  final doc = pw.Document(title: title, author: 'PRAX ERP');
  const ink = PdfColor.fromInt(0xFF1F2937);
  const muted = PdfColor.fromInt(0xFF6B7280);
  const line = PdfColor.fromInt(0xFFD1D5DB);
  const head = PdfColor.fromInt(0xFFF3F4F6);

  final scalars = <MapEntry<String, dynamic>>[];
  final maps = <MapEntry<String, Map>>[];
  final lists = <MapEntry<String, List>>[];
  void split(Map<String, dynamic> d) {
    for (final e in d.entries) {
      if (RecordUtils.isInternal(e.key)) continue;
      final v = e.value;
      if (v is Map) {
        if (v.isNotEmpty) maps.add(MapEntry(e.key, v));
      } else if (v is List) {
        if (v.isNotEmpty) lists.add(MapEntry(e.key, v));
      } else if (v != null && '$v'.trim().isNotEmpty) {
        scalars.add(e);
      }
    }
  }

  split(data);

  pw.Widget kvGrid(List<MapEntry<String, dynamic>> rows) {
    final cells = <pw.Widget>[
      for (final e in rows)
        pw.Container(
          width: 250,
          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.SizedBox(
              width: 100,
              child: pw.Text(_pdfSafe(RecordUtils.humanize(e.key)), style: const pw.TextStyle(fontSize: 8.5, color: muted)),
            ),
            pw.Text(': ', style: const pw.TextStyle(fontSize: 8.5, color: muted)),
            pw.Expanded(
              child: pw.Text(_pdfSafe(RecordUtils.format(e.key, e.value)), style: const pw.TextStyle(fontSize: 9, color: ink)),
            ),
          ]),
        ),
    ];
    return pw.Wrap(spacing: 14, children: cells);
  }

  pw.Widget section(String t) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 12, bottom: 5),
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        color: head,
        width: double.infinity,
        child: pw.Text(_pdfSafe(t.toUpperCase()), style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: ink)),
      );

  pw.Widget table(List rows) {
    final maps = rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (maps.isEmpty) {
      return pw.Text(_pdfSafe(rows.join(', ')), style: const pw.TextStyle(fontSize: 9));
    }
    final cols = <String>[];
    for (final r in maps) {
      for (final e in r.entries) {
        if (!RecordUtils.isInternal(e.key) && e.value is! Map && e.value is! List && !cols.contains(e.key)) cols.add(e.key);
      }
    }
    final shown = cols.take(8).toList();
    return pw.TableHelper.fromTextArray(
      headers: ['#', for (final c in shown) _pdfSafe(RecordUtils.humanize(c))],
      data: [
        for (var i = 0; i < maps.length; i++)
          ['${i + 1}', for (final c in shown) maps[i][c] == null ? '' : _pdfSafe(RecordUtils.format(c, maps[i][c]))],
      ],
      headerStyle: const pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: ink),
      cellStyle: const pw.TextStyle(fontSize: 7.5, color: ink),
      headerDecoration: const pw.BoxDecoration(color: head),
      border: pw.TableBorder.all(color: line, width: 0.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

  final now = DateTime.now();
  final stamp = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} '
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 28),
    header: (ctx) => pw.Column(children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        if (logo != null)
          pw.Image(pw.MemoryImage(logo), height: 40)
        else
          pw.Text('DISHAAN HI-TECH', style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: ink)),
        pw.Spacer(),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text(_pdfSafe(m.title.toUpperCase()), style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: ink)),
          pw.Text(_pdfSafe(title), style: const pw.TextStyle(fontSize: 9, color: muted)),
        ]),
      ]),
      pw.Divider(color: line, thickness: 0.8),
    ]),
    footer: (ctx) => pw.Row(children: [
      pw.Text('Generated from PRAX ERP mobile on $stamp', style: const pw.TextStyle(fontSize: 7, color: muted)),
      pw.Spacer(),
      pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: muted)),
    ]),
    build: (ctx) => [
      if (scalars.isNotEmpty) ...[section('Details'), kvGrid(scalars)],
      for (final e in maps) ...[
        section(RecordUtils.humanize(e.key)),
        kvGrid([
          for (final x in Map<String, dynamic>.from(e.value).entries)
            if (!RecordUtils.isInternal(x.key) && x.value is! Map && x.value is! List && x.value != null) x,
        ]),
      ],
      for (final e in lists) ...[section('${RecordUtils.humanize(e.key)} (${e.value.length})'), table(e.value)],
    ],
  ));
  return doc.save();
}
