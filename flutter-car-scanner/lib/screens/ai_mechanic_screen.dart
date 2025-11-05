import 'package:flutter/material.dart';
import 'package:flutter_car_scanner/data/repair_suggestions.dart';
import 'package:flutter_car_scanner/utils/dtc_helper.dart';

class AiMechanicScreen extends StatefulWidget {
  const AiMechanicScreen({super.key});

  @override
  State<AiMechanicScreen> createState() => _AiMechanicScreenState();
}

class _AiMechanicScreenState extends State<AiMechanicScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<String> _filteredDtcCodes = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _updateFilteredList();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toUpperCase().trim();
      _updateFilteredList();
    });
  }

  bool _isValidDtcFormat(String query) {
    if (query.length < 4 || query.length > 5) return false;
    final upper = query.toUpperCase();
    if (!['P', 'C', 'B', 'U'].contains(upper[0])) return false;
    if (upper.length == 5) {
      // P0301 format
      return RegExp(r'^[PCBU][0-9A-F]{4}$').hasMatch(upper);
    } else {
      // P030 format (partial)
      return RegExp(r'^[PCBU][0-9A-F]{3}$').hasMatch(upper);
    }
  }

  void _updateFilteredList() {
    final allDtcCodes = RepairSuggestions.database.keys.toList()..sort();
    
    if (_searchQuery.isEmpty) {
      _filteredDtcCodes = allDtcCodes;
    } else {
      _filteredDtcCodes = allDtcCodes.where((dtc) {
        final upperDtc = dtc.toUpperCase();
        final description = DtcHelper.getDescription(dtc).toUpperCase();
        final category = RepairSuggestions.getCategory(dtc)?.toUpperCase() ?? '';
        return upperDtc.contains(_searchQuery) || 
               description.contains(_searchQuery) ||
               category.contains(_searchQuery);
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Mechanic'),
        backgroundColor: const Color(0xFF7D3C98),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search DTC code or description...',
                  hintStyle: TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            // Info banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blueAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rule-based repair suggestions for ${_filteredDtcCodes.length} DTC codes',
                      style: TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // DTC List
            Expanded(
              child: _filteredDtcCodes.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredDtcCodes.length,
                      itemBuilder: (context, index) {
                        final dtcCode = _filteredDtcCodes[index];
                        return _buildDtcCard(dtcCode);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    // Chưa search - không hiển thị gì
    if (_searchQuery.isEmpty) {
      return const SizedBox.shrink();
    }

    // Search không có kết quả - hiển thị card với button search Google
    final description = DtcHelper.getDescription(_searchQuery);
    final howToRead = DtcHelper.getHowToRead(_searchQuery);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _buildDtcCardNotFound(_searchQuery, description, howToRead),
      ],
    );
  }

  Widget _buildDtcCardNotFound(String dtcCode, String description, String howToRead) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    dtcCode,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.orangeAccent,
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'Not in database',
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              howToRead,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Colors.white24),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.white54),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'This DTC code is not in our database. Search on Google for more information.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => DtcHelper.searchOnGoogle(dtcCode),
                icon: const Icon(Icons.search),
                label: Text('Search "$dtcCode" on Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDtcCard(String dtcCode) {
    final description = DtcHelper.getDescription(dtcCode);
    final suggestions = RepairSuggestions.getSuggestionList(dtcCode);
    final costRange = RepairSuggestions.getCostRange(dtcCode);
    final severity = RepairSuggestions.getSeverity(dtcCode);
    final category = RepairSuggestions.getCategory(dtcCode);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showDetailDialog(dtcCode),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      dtcCode,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: Colors.purpleAccent,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  if (severity != null) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getSeverityColor(severity).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _getSeverityColor(severity),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        severity,
                        style: TextStyle(
                          color: _getSeverityColor(severity),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              if (costRange != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.attach_money, size: 16, color: Colors.orangeAccent),
                    const SizedBox(width: 4),
                    Text(
                      'Est. Cost: $costRange',
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              if (suggestions != null && suggestions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.build, size: 16, color: Colors.blueAccent),
                    const SizedBox(width: 4),
                    Text(
                      '${suggestions.length} repair suggestions',
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.touch_app, size: 14, color: Colors.white54),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to view details',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.search, size: 18, color: Colors.blueAccent),
                    onPressed: () => DtcHelper.searchOnGoogle(dtcCode),
                    tooltip: 'Search on Google',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailDialog(String dtcCode) {
    final description = DtcHelper.getDescription(dtcCode);
    final howToRead = DtcHelper.getHowToRead(dtcCode);
    final suggestions = RepairSuggestions.getSuggestionList(dtcCode);
    final costRange = RepairSuggestions.getCostRange(dtcCode);
    final severity = RepairSuggestions.getSeverity(dtcCode);
    final category = RepairSuggestions.getCategory(dtcCode);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.2),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      dtcCode,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.blueAccent),
                      onPressed: () {
                        Navigator.of(context).pop();
                        DtcHelper.searchOnGoogle(dtcCode);
                      },
                      tooltip: 'Search on Google',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        howToRead,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      if (category != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text(
                              'Category: ',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            Text(
                              category,
                              style: const TextStyle(
                                color: Colors.purpleAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (costRange != null || severity != null) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Colors.white24),
                        const SizedBox(height: 12),
                        if (costRange != null)
                          Row(
                            children: [
                              Icon(Icons.attach_money, size: 16, color: Colors.orangeAccent),
                              const SizedBox(width: 6),
                              Text(
                                'Est. Cost: $costRange',
                                style: const TextStyle(
                                  color: Colors.orangeAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        if (severity != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.warning, size: 16, color: _getSeverityColor(severity)),
                              const SizedBox(width: 6),
                              const Text(
                                'Severity: ',
                                style: TextStyle(color: Colors.white54, fontSize: 14),
                              ),
                              Text(
                                severity,
                                style: TextStyle(
                                  color: _getSeverityColor(severity),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                      if (suggestions != null && suggestions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Colors.white24),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.build, size: 18, color: Colors.blueAccent),
                            const SizedBox(width: 6),
                            const Text(
                              'Repair Suggestions:',
                              style: TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...suggestions.map((suggestion) => Padding(
                              padding: const EdgeInsets.only(left: 8, bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '• ',
                                    style: TextStyle(color: Colors.white70, fontSize: 14),
                                  ),
                                  Expanded(
                                    child: Text(
                                      suggestion,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getSeverityColor(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'high':
        return Colors.redAccent;
      case 'medium':
        return Colors.orangeAccent;
      case 'low':
        return Colors.greenAccent;
      default:
        return Colors.white54;
    }
  }
}

